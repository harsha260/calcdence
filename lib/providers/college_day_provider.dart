import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the student plans to go to college on each calendar day.
/// Key format: "going_YYYY-MM-DD"
class CollegeDayProvider extends ChangeNotifier {
  static const String _prefix = 'going_';

  final Map<String, bool> _cache = {};

  /// Whether the student's going-to-college flag is ON for [date].
  bool isGoingOnDate(DateTime date) {
    final key = _key(date);
    return _cache[key] ?? false;
  }

  bool get isGoingToday => isGoingOnDate(DateTime.now());

  /// Load today's value from SharedPreferences.
  Future<void> loadToday() async {
    final key = _key(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    _cache[key] = prefs.getBool(key) ?? false;
    notifyListeners();
  }

  /// Toggle the going-to-college flag for today.
  Future<void> toggleToday() async {
    final key = _key(DateTime.now());
    final newValue = !(_cache[key] ?? false);
    _cache[key] = newValue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, newValue);
  }

  static String _key(DateTime date) =>
      '$_prefix${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
