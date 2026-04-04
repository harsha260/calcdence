import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/attendance.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../services/api_service.dart';

class AttendanceRepositoryResult {
  final Attendance attendance;
  final List<TimetableEntry> sessions;
  final Map<int, String> nameMap;

  AttendanceRepositoryResult({
    required this.attendance,
    required this.sessions,
    required this.nameMap,
  });
}

class AttendanceRepository {
  final CampXApiService _apiService;
  static const int _semNo = 4;
  static const String _cachedSubjectsKey = 'cached_subjects_map';

  AttendanceRepository(this._apiService);

  Future<AttendanceRepositoryResult> fetchFullAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    
    // ── Step 1: Fetch subjects API ─────────────────────────────────────────
    final nameMap = <int, String>{};
    final attendanceIds = <int>[];
    
    try {
      final subjectsList = await _apiService.getSubjects(semNo: _semNo);
      print('AttendanceRepository: Fetched ${subjectsList.length} subjects from API');

      for (final s in subjectsList) {
        final id = s['id'];
        if (id == null) continue;
        final subjectId = (id is int) ? id : int.tryParse(id.toString());
        if (subjectId == null) continue;

        final bool hasAttendance = s['hasAttendance'] == true;
        if (!hasAttendance) continue;

        final rawName = (s['name'] as String? ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
        final name = rawName.isEmpty ? 'Subject $subjectId' : rawName;

        nameMap[subjectId] = name;
        attendanceIds.add(subjectId);
      }
      
      // Save to cache for future offline or failed API calls
      if (nameMap.isNotEmpty) {
        final cachedData = nameMap.map((k, v) => MapEntry(k.toString(), v));
        await prefs.setString(_cachedSubjectsKey, jsonEncode(cachedData));
      }
    } catch (e) {
      print('AttendanceRepository: Failed to fetch subjects from API, checking cache. Error: $e');
    }

    // ── Fallback to Cache or Hardcoded ─────────────────────────────────────
    if (attendanceIds.isEmpty) {
      final cachedString = prefs.getString(_cachedSubjectsKey);
      if (cachedString != null) {
        try {
          final Map<String, dynamic> cachedData = jsonDecode(cachedString);
          cachedData.forEach((key, value) {
            final id = int.tryParse(key);
            if (id != null) {
              attendanceIds.add(id);
              nameMap[id] = value.toString();
            }
          });
          print('AttendanceRepository: Loaded ${attendanceIds.length} subjects from cache.');
        } catch (e) {
          print('AttendanceRepository: Failed to parse cached subjects: $e');
        }
      }
    }

    // Ultimate fallback if API fails and cache is empty
    if (attendanceIds.isEmpty) {
      print('AttendanceRepository: No subjects found in API or cache, using fallback list');
      for (final code in AppConstants.fallbackSubjectCodes) {
        attendanceIds.add(code);
        nameMap[code] = AppConstants.fallbackSubjectNames[code] ?? 'Subject $code';
      }
    }

    // ── Step 2: Fetch attendance per subject ─────────────────────────
    final subjects = <Subject>[];
    final allSessions = <TimetableEntry>[];

    for (final id in attendanceIds) {
      try {
        final data = await _apiService.getSubjectAttendance(id);
        
        data['subjectName'] = nameMap[id] ?? 'Subject $id';
        final subject = Subject.fromJson(data);
        
        final rawLogs = data['timeline'] ??
                       data['attendanceLogs'] ?? 
                       data['sessionList'] ?? 
                       data['attendance_logs'] ?? 
                       data['session_logs'] ??
                       data['data'];
        
        if (rawLogs is List) {
          for (var log in rawLogs) {
            if (log is Map) {
              final logMap = Map<String, dynamic>.from(log);
              logMap['subjectId'] = id;
              logMap['subjectName'] = subject.subjectName;
              
              final entry = TimetableEntry.fromJson(logMap, nameMap: nameMap);
              if (entry.sessionDate != null) {
                allSessions.add(entry);
              }
            }
          }
        }

        if (subject.totalClasses > 0) {
          subjects.add(subject);
        }
      } catch (e) {
        print('AttendanceRepository: Error fetching attendance for $id: $e');
      }
    }

    // ── Step 3: Calculate overall ────────────────────────────────────────────
    int totalAttended = 0;
    int totalConducted = 0;
    for (final s in subjects) {
      totalAttended += s.classesAttended;
      totalConducted += s.totalClasses;
    }

    final overallPercentage = totalConducted > 0 ? (totalAttended / totalConducted * 100) : 0.0;

    final attendance = Attendance(
      subjects: subjects,
      overallPercentage: overallPercentage,
      totalAttended: totalAttended,
      totalConducted: totalConducted,
    );

    return AttendanceRepositoryResult(
      attendance: attendance,
      sessions: allSessions,
      nameMap: nameMap,
    );
  }
}