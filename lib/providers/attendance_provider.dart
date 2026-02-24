import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../services/api_service.dart' as api;
import 'dart:math' as math;

/// Attendance loading state enum
enum AttendanceState {
  initial,
  loading,
  loaded,
  error,
}

/// Attendance Provider - Manages attendance data and state
class AttendanceProvider extends ChangeNotifier {
  final api.CampXApiService _apiService = api.CampXApiService();

  AttendanceState _state = AttendanceState.initial;
  Attendance? _attendance;
  String? _errorMessage;
  Map<int, String> _nameMap = {};

  // The semester to fetch subjects for
  static const int _semNo = 4;

  // Public getter for subject codes
  List<int> get subjectCodes =>
      _attendance?.subjects.map((s) => s.subjectCode).toList() ?? [];

  AttendanceState get state => _state;
  Attendance? get attendance => _attendance;
  String? get errorMessage => _errorMessage;
  Map<int, String> get nameMap => _nameMap;
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
      // ── Step 1: subjects API ─────────────────────────────────────────
      final subjectsList = await _apiService.getSubjects(semNo: _semNo);
      print('AttendanceProvider: Fetched ${subjectsList.length} subjects from API');

      // Build id → name map and collect IDs that have attendance
      final nameMap = <int, String>{};
      final attendanceIds = <int>[];

      for (final s in subjectsList) {
        final id = s['id'];
        print('AttendanceProvider: Processing subject: $s');
        if (id == null) continue;
        final subjectId = (id is int) ? id : int.tryParse(id.toString());
        if (subjectId == null) continue;

        final bool hasAttendance = s['hasAttendance'] == true;
        if (!hasAttendance) continue;

        // Raw name from API; strip stray newlines/carriage-returns
        final rawName = (s['name'] as String? ?? '')
            .replaceAll(RegExp(r'[\r\n]+'), ' ')
            .trim();
        // Prefer hardcoded short-name if available, else use API name
        final name = AppConstants.subjectNames[subjectId] ??
            (rawName.isEmpty ? 'Subject $subjectId' : rawName);

        nameMap[subjectId] = name;
        attendanceIds.add(subjectId);
      }

      // Fallback: if subjects API returned nothing, use hardcoded list
      if (attendanceIds.isEmpty) {
        print('AttendanceProvider: No subjects with attendance found in API, using fallback list');
        for (final code in AppConstants.subjectCodes) {
          attendanceIds.add(code);
          nameMap[code] = AppConstants.subjectNames[code] ?? 'Subject $code';
        }
      }
      print('AttendanceProvider: Final attendanceIds to fetch: $attendanceIds');

      // ── Step 2: fetch attendance per subject ─────────────────────────
      final subjects = <Subject>[];

      for (final id in attendanceIds) {
        try {
          print('AttendanceProvider: Fetching attendance for subject code: $id');
          final data = await _apiService.getSubjectAttendance(id);
          print('AttendanceProvider: Received data for $id: $data');
          // Inject name from the subjects API (code is already injected by api_service)
          data['subjectName'] = nameMap[id] ?? 'Subject $id';
          final subject = Subject.fromJson(data);
          print('AttendanceProvider: Parsed subject: ${subject.subjectName}, Total: ${subject.totalClasses}');
          // Only include subjects that have at least 1 conducted class
          if (subject.totalClasses > 0) {
            subjects.add(subject);
          }
        } catch (e) {
          print('AttendanceProvider: Error fetching attendance for $id: $e');
        }
      }

      // ── Calculate overall ────────────────────────────────────────────
      int totalAttended = 0;
      int totalConducted = 0;
      for (final s in subjects) {
        totalAttended += s.classesAttended;
        totalConducted += s.totalClasses;
      }

      final overallPercentage =
          totalConducted > 0 ? (totalAttended / totalConducted * 100) : 0.0;

      _attendance = Attendance(
        subjects: subjects,
        overallPercentage: overallPercentage,
        totalAttended: totalAttended,
        totalConducted: totalConducted,
      );

      // ── Step 3: timetable API ───────────────────────────────────────
      // We pass the nameMap to the TimetableProvider so it can resolve subject names
      // using the same names we just fetched.
      // ignore: use_build_context_synchronously
      // context.read<TimetableProvider>().fetchTimetable(nameMap: nameMap);
      // Wait, we don't have context here. We'll handle this from the UI side or
      // pass the provider in. For now, we'll expose the nameMap.
      _nameMap = nameMap;

      _state = AttendanceState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AttendanceState.error;
    }

    notifyListeners();
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

/// Calculator for attendance calculations
class AttendanceCalculator {
  /// Calculate how many classes can be skipped while maintaining target percentage
  /// Formula: x = floor((P - (R * T)) / R)
  /// Where:
  /// - P = classes attended
  /// - T = total classes conducted
  /// - R = target percentage (as decimal, e.g., 0.75 for 75%)
  static int calculateBunkableClasses(int attended, int total, double targetPercent) {
    if (total == 0 || targetPercent <= 0 || targetPercent > 1) return 0;
    
    final currentPercent = total > 0 ? attended / total : 0.0;
    
    // Can only skip if current percentage > target
    if (currentPercent <= targetPercent) return 0;
    
    // Calculate using formula: floor((P - R*T) / R)
    final bunkable = ((attended - (targetPercent * total)) / targetPercent).floor();
    
    return math.max(0, bunkable);
  }

  /// Calculate how many consecutive classes need to be attended to reach target
  /// Formula: x = ceil((R * T - P) / (1 - R))
  /// Where:
  /// - P = classes attended
  /// - T = total classes conducted
  /// - R = target percentage (as decimal, e.g., 0.75 for 75%)
  static int calculateRecoveryClasses(int attended, int total, double targetPercent) {
    if (total == 0 || targetPercent <= 0 || targetPercent > 1) return 0;
    
    final currentPercent = total > 0 ? attended / total : 0.0;
    
    // No need to recover if already at or above target
    if (currentPercent >= targetPercent) return 0;
    
    // Calculate using formula: ceil((R*T - P) / (1 - R))
    final needed = ((targetPercent * total - attended) / (1 - targetPercent)).ceil();
    
    return math.max(0, needed);
  }

  /// Calculate required attendance percentage for remaining classes to reach target
  static double calculateRequiredPercentage(int attended, int total, double targetPercent) {
    if (total == 0 || targetPercent <= 0) return 0;
    
    final remaining = 100 - (attended / total * 100);
    if (remaining <= 0) return 0;
    
    // P + x >= R * (T + x)
    // P - R*T >= (R - 1) * x
    // x <= (P - R*T) / (R - 1)
    
    final required = (targetPercent * total - attended) / (1 - targetPercent);
    return required;
  }
}
