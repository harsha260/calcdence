import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

/// Secure Storage Service - Handles credential storage using platform-specific secure storage
/// Uses iOS Keychain / Android Keystore
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save username securely
  Future<void> saveUsername(String username) async {
    await _storage.write(key: ApiConstants.usernameKey, value: username);
  }

  /// Get saved username
  Future<String?> getUsername() async {
    return await _storage.read(key: ApiConstants.usernameKey);
  }

  /// Save password securely
  Future<void> savePassword(String password) async {
    await _storage.write(key: ApiConstants.passwordKey, value: password);
  }

  /// Get saved password
  Future<String?> getPassword() async {
    return await _storage.read(key: ApiConstants.passwordKey);
  }

  /// Save session key
  Future<void> saveSessionKey(String sessionKey) async {
    await _storage.write(key: ApiConstants.sessionKeyKey, value: sessionKey);
  }

  /// Get saved session key
  Future<String?> getSessionKey() async {
    return await _storage.read(key: ApiConstants.sessionKeyKey);
  }

  /// Check if credentials are saved
  Future<bool> hasStoredCredentials() async {
    final username = await getUsername();
    final password = await getPassword();
    return username != null && password != null;
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear only session (keep credentials)
  Future<void> clearSession() async {
    await _storage.delete(key: ApiConstants.sessionKeyKey);
  }
}
