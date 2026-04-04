import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../services/api_service.dart' as api;
import '../services/notification_service.dart';
import '../repositories/attendance_repository.dart';

/// Attendance loading state enum
enum AttendanceState { initial, loading, loaded, error }

/// Attendance Provider - Manages attendance data and state
class AttendanceProvider extends ChangeNotifier {
  final api.CampXApiService _apiService;
  late final AttendanceRepository _repository;

  AttendanceProvider(this._apiService) {
    _repository = AttendanceRepository(_apiService);
  }

  AttendanceState _state = AttendanceState.initial;
  Attendance? _attendance;
  String? _errorMessage;
  Map<int, String> _nameMap = {};
  List<TimetableEntry> _allSessions = [];

  // Public getter for subject codes
  List<int> get subjectCodes =>
      _attendance?.subjects.map((s) => s.subjectCode).toList() ?? [];

  AttendanceState get state => _state;
  Attendance? get attendance => _attendance;
  String? get errorMessage => _errorMessage;
  Map<int, String> get nameMap => _nameMap;
  List<TimetableEntry> get allSessions => _allSessions;
  bool get isLoading => _state == AttendanceState.loading;
  bool get hasData => _attendance != null && _attendance!.subjects.isNotEmpty;

  /// Fetch all attendance data.
  /// Step 1: fetch subject list to get names and IDs.
  /// Step 2: for each subject that has attendance, fetch individual attendance.
  Future<void> fetchAttendance() async {
    _state = AttendanceState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchFullAttendance();

      _attendance = result.attendance;
      _nameMap = result.nameMap;
      _allSessions = result.sessions; // Store for TimetableProvider to pick up

      debugPrint(
        'AttendanceProvider: Total sessions collected: ${_allSessions.length}',
      );

      await _checkAndNotifyAbsences(result.attendance.subjects);

      _state = AttendanceState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AttendanceState.error;
    }

    notifyListeners();
  }

  /// Compares fetched attendance with local stored attendance to find new absences.
  Future<void> _checkAndNotifyAbsences(List<Subject> newSubjects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storageKey = 'last_known_attendance';
      final lastKnownString = prefs.getString(storageKey);

      if (lastKnownString != null) {
        final Map<String, dynamic> lastKnown = jsonDecode(lastKnownString);
        for (final subject in newSubjects) {
          final String key = subject.subjectCode.toString();
          if (lastKnown.containsKey(key)) {
            final oldAttended = lastKnown[key]['attended'] as int;
            final oldConducted = lastKnown[key]['conducted'] as int;

            // Check if conducted increased but attended did NOT (meaning absent)
            final diffConducted = subject.totalClasses - oldConducted;
            final diffAttended = subject.classesAttended - oldAttended;

            if (diffConducted > 0 && diffAttended < diffConducted) {
              // Absent detected!
              final absentsCount = diffConducted - diffAttended;
              debugPrint(
                'AttendanceProvider: Detected $absentsCount new absence(s) for ${subject.subjectName}',
              );

              // Find the most recent absent session from our fetched allSessions
              // Sort sessions descending to find the latest
              final recentAbsences =
                  _allSessions
                      .where(
                        (s) =>
                            s.subjectId == subject.subjectCode &&
                            s.isAttended == false,
                      )
                      .toList()
                    ..sort((a, b) {
                      final aDate = a.sessionDate ?? '';
                      final bDate = b.sessionDate ?? '';
                      if (aDate != bDate) return bDate.compareTo(aDate);
                      // If same date, sort by period descending
                      return b.period.compareTo(a.period);
                    });

              TimetableEntry? latestAbsence;
              if (recentAbsences.isNotEmpty) {
                latestAbsence = recentAbsences.first;
              }

              await NotificationService().showAbsentNotification(
                subjectName: subject.subjectName,
                date:
                    latestAbsence?.sessionDate ??
                    DateTime.now().toLocal().toString().split(' ')[0],
                period: latestAbsence?.period,
                time: latestAbsence?.startTime,
              );
            }
          }
        }
      }

      // Store current state for next time
      final Map<String, dynamic> newState = {};
      for (final subject in newSubjects) {
        newState[subject.subjectCode.toString()] = {
          'attended': subject.classesAttended,
          'conducted': subject.totalClasses,
        };
      }
      await prefs.setString(storageKey, jsonEncode(newState));
    } catch (e) {
      debugPrint('AttendanceProvider: Error checking absences: $e');
    }
  }

  /// Refresh attendance data
  Future<void> refresh() async {
    await fetchAttendance();
  }

  /// Get a specific subject by code
  Subject? getSubjectByCode(int subjectCode) {
    if (_attendance == null) return null;
    return _attendance!.subjects.firstWhere(
      (s) => s.subjectCode == subjectCode,
      orElse: () => Subject(
        subjectCode: subjectCode,
        subjectName: 'Unknown',
        classesAttended: 0,
        totalClasses: 0,
        percentage: 0,
      ),
    );
  }

  /// Clear attendance data
  void clear() {
    _attendance = null;
    _state = AttendanceState.initial;
    _errorMessage = null;
    notifyListeners();
  }
}
