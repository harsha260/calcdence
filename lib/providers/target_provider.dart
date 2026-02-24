import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's configurable attendance target percentage.
class TargetProvider extends ChangeNotifier {
  static const String _key = 'campx_target_pct';
  static const double defaultTarget = 75.0;

  double _target = defaultTarget;

  double get target => _target;

  TargetProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _target = prefs.getDouble(_key) ?? defaultTarget;
    notifyListeners();
  }

  Future<void> setTarget(double value) async {
    _target = value.clamp(50.0, 100.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _target);
  }
}
