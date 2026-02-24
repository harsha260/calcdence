import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages notification settings like "minutes before" reminder time.
class NotificationProvider extends ChangeNotifier {
  static const String _keyMinutes = 'notif_minutes';

  int _remindMinutes = 10;

  int get remindMinutes => _remindMinutes;

  NotificationProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _remindMinutes = prefs.getInt(_keyMinutes) ?? 10;
    notifyListeners();
  }

  Future<void> setRemindMinutes(int minutes) async {
    if (minutes < 0 || minutes > 60) return;
    _remindMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMinutes, minutes);
  }
}
