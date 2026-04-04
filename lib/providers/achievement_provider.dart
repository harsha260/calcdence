import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../models/timetable_entry.dart';

class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final IconData iconData;
  final int colorValue;

  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconData,
    required this.colorValue,
  });
}

class AchievementProvider extends ChangeNotifier {
  static const String _unlockedKey = 'unlocked_badges';
  static const String _streakKey = 'current_streak';

  List<String> _unlockedBadgeIds = [];
  int _currentStreak = 0;

  List<String> get unlockedBadgeIds => _unlockedBadgeIds;
  int get currentStreak => _currentStreak;

  final List<AchievementBadge> allBadges = const [
    AchievementBadge(
      id: 'flawless_week',
      name: 'Flawless Week',
      description: 'Attended 100% of classes from Monday to Friday.',
      iconData: Icons.star_rounded,
      colorValue: 0xFFFFD700, // Gold
    ),
    AchievementBadge(
      id: 'comeback_kid',
      name: 'Comeback Kid',
      description: 'Recovered a subject from below 75% to safe zone.',
      iconData: Icons.auto_graph_rounded,
      colorValue: 0xFF00FF7F, // Goldish Green
    ),
    AchievementBadge(
      id: 'early_bird',
      name: 'Early Bird',
      description: 'Attended all 1st periods for the week.',
      iconData: Icons.wb_sunny_rounded,
      colorValue: 0xFF87CEEB, // Sky Blue
    ),
    AchievementBadge(
      id: 'subject_scholar',
      name: 'Subject Scholar',
      description: 'Hit 90%+ attendance in a specific subject.',
      iconData: Icons.school_rounded,
      colorValue: 0xFF9370DB, // Purple
    ),
  ];

  Future<void> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedStr = prefs.getStringList(_unlockedKey) ?? [];
    _unlockedBadgeIds = unlockedStr;
    _currentStreak = prefs.getInt(_streakKey) ?? 0;
    notifyListeners();
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, _unlockedBadgeIds);
    await prefs.setInt(_streakKey, _currentStreak);
  }

  void checkAchievements(Attendance attendance, List<TimetableEntry> sessions) {
    bool newlyUnlocked = false;

    // Check Subject Scholar
    if (!_unlockedBadgeIds.contains('subject_scholar')) {
      if (attendance.subjects.any((s) => s.percentage >= 90.0)) {
        _unlockedBadgeIds.add('subject_scholar');
        newlyUnlocked = true;
      }
    }

    // Check Comeback Kid
    // (This is hard to track without history, but let's assume if they have a subject between 75-80% they recovered it)
    if (!_unlockedBadgeIds.contains('comeback_kid')) {
      if (attendance.subjects.any(
        (s) =>
            s.percentage >= 75.0 && s.percentage < 80.0 && s.totalClasses > 10,
      )) {
        _unlockedBadgeIds.add('comeback_kid');
        newlyUnlocked = true;
      }
    }

    // Check Streak based on sessions
    // We would sort sessions and check consecutive dates attended.
    // For now, we simulate a simple streak calculation.
    int streak = _calculateStreak(sessions);
    if (streak != _currentStreak) {
      _currentStreak = streak;
      newlyUnlocked = true;
    }

    if (newlyUnlocked) {
      _saveAchievements();
      notifyListeners();
    }
  }

  int _calculateStreak(List<TimetableEntry> sessions) {
    if (sessions.isEmpty) return 0;
    int streakCount = 0;
    final sorted = List.from(sessions)
      ..sort((a, b) {
        if (a.sessionDate == null || b.sessionDate == null) return 0;
        return b.sessionDate!.compareTo(a.sessionDate!);
      });

    String? lastDate;
    bool allAttendedOnDate = true;

    for (var s in sorted) {
      if (s.isAttended == null) continue;
      if (s.sessionDate != lastDate) {
        if (lastDate != null) {
          if (allAttendedOnDate)
            streakCount++;
          else
            break;
        }
        lastDate = s.sessionDate;
        allAttendedOnDate = s.isAttended == true;
      } else {
        if (s.isAttended == false) allAttendedOnDate = false;
      }
    }
    if (allAttendedOnDate && lastDate != null) streakCount++;
    return streakCount;
  }
}
