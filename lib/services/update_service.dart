import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool updateAvailable;
  final String updateUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    required this.updateUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Checks for updates against a GitHub repository releases API
  /// Set GITHUB_REPO in .env (e.g. "username/repo")
  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // e.g. "1.0.0"

      final repo = dotenv.env['GITHUB_REPO'] ?? 'harsha260/calcdence';
      if (repo.isEmpty) {
        debugPrint(
          'UpdateService: GITHUB_REPO not set. Skipping update check.',
        );
        return null;
      }

      final url = Uri.parse(
        'https://api.github.com/repos/$repo/releases/latest',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestTag = data['tag_name'] as String;
        // Strip 'v' if present
        if (latestTag.startsWith('v')) {
          latestTag = latestTag.substring(1);
        }

        final updateUrl =
            data['html_url'] as String? ?? 'https://github.com/$repo/releases';
        final releaseNotes =
            data['body'] as String? ?? 'A new version is available!';

        final hasUpdate = _isVersionGreater(latestTag, currentVersion);

        return AppUpdateInfo(
          latestVersion: latestTag,
          currentVersion: currentVersion,
          updateAvailable: hasUpdate,
          updateUrl: updateUrl,
          releaseNotes: releaseNotes,
        );
      } else {
        debugPrint(
          'UpdateService: Failed to fetch updates. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Error checking for updates: $e');
    }
    return null;
  }

  /// Launch the update URL in the external browser
  Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('UpdateService: Could not launch $url');
    }
  }

  /// Compares v1 and v2. Returns true if v1 > v2.
  bool _isVersionGreater(String v1, String v2) {
    try {
      final v1Parts = v1.split('.').map(int.parse).toList();
      final v2Parts = v2.split('.').map(int.parse).toList();
      for (int i = 0; i < v1Parts.length; i++) {
        if (i >= v2Parts.length) return true; // v1 has more parts
        if (v1Parts[i] > v2Parts[i]) return true;
        if (v1Parts[i] < v2Parts[i]) return false;
      }
      return false;
    } catch (e) {
      return false; // Fallback on parsing error
    }
  }
}
