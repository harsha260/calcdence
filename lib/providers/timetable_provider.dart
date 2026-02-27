import 'package:flutter/foundation.dart';
import '../models/timetable_entry.dart';
import '../services/api_service.dart' as api;

enum TimetableState { initial, loading, loaded, error }

/// Fetches and caches the classroom timetable from the CampX API.
class TimetableProvider extends ChangeNotifier {
  final api.CampXApiService _apiService = api.CampXApiService();

  TimetableState _state = TimetableState.initial;
  List<TimetableEntry> _templateEntries = [];
  List<TimetableEntry> _specificEntries = [];
  final Set<String> _holidays = {}; // Stores dates as "YYYY-MM-DD"
  String? _errorMessage;

  TimetableState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == TimetableState.loaded;
  List<TimetableEntry> get entries => _templateEntries; 
  Set<String> get holidayDates => _holidays;

  bool isHoliday(DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _holidays.contains(dateStr) || date.weekday == DateTime.sunday;
  }

  /// All periods for a given weekday (1=Mon…5=Fri), sorted by start time.
  List<TimetableEntry> periodsForWeekday(int weekday) => _templateEntries
      .where((e) => e.weekday == weekday)
      .toList()
    ..sort((a, b) {
      // Ensure "09:00" vs "10:00" sorts correctly
      final aTime = a.startTime.padLeft(5, '0');
      final bTime = b.startTime.padLeft(5, '0');
      return aTime.compareTo(bTime);
    });

  /// Today's periods.
  List<TimetableEntry> get todayPeriods =>
      periodsForDate(DateTime.now());

  /// Periods on a specific date.
  /// Start with template, then overlay real attendance logs if found.
  List<TimetableEntry> periodsForDate(DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    if (isHoliday(date)) return [];

    final template = periodsForWeekday(date.weekday);
    if (template.isEmpty) return [];

    final logs = _specificEntries.where((e) => e.sessionDate == dateStr).toList();
    if (logs.isEmpty) {
      // Debug: print('TimetableProvider: No logs found for $dateStr');
      return template;
    }

    print('TimetableProvider: Merging ${logs.length} logs for $dateStr into ${template.length} template slots');
    final result = <TimetableEntry>[];
    final usedLogs = <int>{};

    for (var temp in template) {
      print('TimetableProvider: Slot ${temp.subjectName} P${temp.period} (id:${temp.subjectId})');
      int logIndex = -1;
      // Try exact subject + period match first
      for (int i = 0; i < logs.length; i++) {
        if (usedLogs.contains(i)) continue;
        final log = logs[i];
        if (log.subjectId == temp.subjectId && log.period == temp.period) {
          logIndex = i;
          print('  -> Exact match with log $i (P${log.period})');
          break;
        }
      }

      // If no exact match, try subject + time match
      if (logIndex == -1) {
        for (int i = 0; i < logs.length; i++) {
          if (usedLogs.contains(i)) continue;
          final log = logs[i];
          if (log.subjectId == temp.subjectId) {
            try {
              final tParts = temp.startTime.split(':');
              final lParts = log.startTime.split(':');
              if (tParts.length >= 2 && lParts.length >= 2) {
                final tMin = int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
                final lMin = int.parse(lParts[0]) * 60 + int.parse(lParts[1]);
                if ((tMin - lMin).abs() <= 30) {
                  logIndex = i;
                  print('  -> Time window match with log $i (${log.startTime})');
                  break;
                }
              }
            } catch (_) {}
          }
        }
      }

      if (logIndex != -1) {
        final log = logs[logIndex];
        usedLogs.add(logIndex);
        final merged = temp.copyWith(
          sessionDate: dateStr,
          isAttended: log.isAttended,
          topic: log.topic ?? temp.topic,
          startTime: log.startTime.isNotEmpty ? log.startTime : temp.startTime,
          endTime: log.endTime.isNotEmpty ? log.endTime : temp.endTime,
        );
        print('  -> Merged with log $logIndex. isAttended: ${merged.isAttended}');
        result.add(merged);
      } else {
        print('  -> No log match found');
        result.add(temp.copyWith(sessionDate: dateStr));
      }
    }

    for (int i = 0; i < logs.length; i++) {
      if (!usedLogs.contains(i)) {
        print('TimetableProvider: Adding unmatched log: ${logs[i].subjectName} ${logs[i].startTime}');
        result.add(logs[i]);
      }
    }

    return result..sort((a, b) {
      final aTime = a.startTime.padLeft(5, '0');
      final bTime = b.startTime.padLeft(5, '0');
      return aTime.compareTo(bTime);
    });
  }

  /// How many periods per day does [subjectId] appear on average?
  /// Uses template entries for calculation.
  double periodsPerDayForSubject(int subjectId) {
    if (_templateEntries.isEmpty) return 0;
    // Count occurrences per weekday
    final byday = <int, int>{};
    for (final e in _templateEntries) {
      if (e.subjectId == subjectId) {
        byday[e.weekday] = (byday[e.weekday] ?? 0) + 1;
      }
    }
    if (byday.isEmpty) return 0;
    // Average over the days it appears
    return byday.values.fold(0, (a, b) => a + b) / 5; // 5 working days
  }

  /// Fetch from API and merge with hardcoded template.
  Future<void> fetchTimetable({Map<int, String> nameMap = const {}}) async {
    if (_state == TimetableState.loading) return;
    _state = TimetableState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load stable hardcoded template first
      _templateEntries = _getHardcodedTimetable(nameMap);
      
      // 2. Attempt to fetch real timetable from API for specific date records
      print('TimetableProvider: Fetching dynamic timetable from API...');
      final rawApiEntries = await _apiService.getTimetable();
      
      final processedSpecific = <TimetableEntry>[];
      final datesWithClasses = <String>{};

      for (var json in rawApiEntries) {
        final entry = TimetableEntry.fromJson(json, nameMap: nameMap);
        final sessionDate = entry.sessionDate;
        
        if (sessionDate != null) {
          final subjectLower = entry.subjectName.toLowerCase();
          final statusLower = (json['attendanceStatus'] ?? '').toString().toLowerCase();
          
          if (subjectLower.contains('holiday') || statusLower.contains('holiday')) {
            _holidays.add(sessionDate);
          } else {
            datesWithClasses.add(sessionDate);
            _splitPeriodIfNeeded(entry, processedSpecific, () => processedSpecific.length + 1000);
          }
        }
      }

      _specificEntries = processedSpecific;

      // Scan empty dates between first and last date in response
      if (datesWithClasses.isNotEmpty) {
        final dates = datesWithClasses.map((d) => DateTime.parse(d)).toList()..sort();
        final first = dates.first;
        final last = dates.last;
        
        for (int i = 0; i <= last.difference(first).inDays; i++) {
          final date = first.add(Duration(days: i));
          final dStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          
          if (!datesWithClasses.contains(dStr) && date.weekday != DateTime.sunday) {
            // If it has periods in template but 0 in API, it's a holiday
            if (periodsForWeekday(date.weekday).isNotEmpty) {
              _holidays.add(dStr);
            }
          }
        }
      }
      
      print('TimetableProvider: Loaded ${_templateEntries.length} template entries and ${_specificEntries.length} specific date overrides.');
      
      _state = TimetableState.loaded;
    } catch (e) {
      print('TimetableProvider: Error fetching dynamic timetable: $e');
      // If API fails, we still have the template loaded, so we can consider it "loaded"
      if (_templateEntries.isNotEmpty) {
        _state = TimetableState.loaded;
      } else {
        _errorMessage = e.toString();
        _state = TimetableState.error;
      }
    }
    notifyListeners();
  }

  /// Add or update specific session entries (e.g. from subject logs)
  void updateSpecificEntries(List<TimetableEntry> sessions) {
    if (sessions.isEmpty) return;
    
    // Create a map for quick lookup and deduplication by date + period
    final Map<String, TimetableEntry> entryMap = {
      for (var e in _specificEntries) 
        if (e.sessionDate != null) "${e.sessionDate}_${e.subjectId}_${e.period}": e
    };

    print('TimetableProvider: updateSpecificEntries received ${sessions.length} sessions. Current specific count: ${_specificEntries.length}');
    for (var s in sessions) {
      if (s.sessionDate == null) continue;
      final key = "${s.sessionDate}_${s.subjectId}_${s.period}";
      
      // Update or add
      if (!entryMap.containsKey(key)) {
        entryMap[key] = s;
      } else if (s.isAttended != null) {
        // Upgrade existing entry with attendance data
        final existing = entryMap[key]!;
        entryMap[key] = existing.copyWith(
          isAttended: s.isAttended,
          topic: s.topic ?? existing.topic,
        );
      }
    }

    _specificEntries = entryMap.values.toList();
    print('TimetableProvider: Final specificEntries count: ${_specificEntries.length}');
    notifyListeners();
  }

  List<TimetableEntry> _getHardcodedTimetable(Map<int, String> nameMap) {
    final entries = <TimetableEntry>[];
    int nextId = 1;

    void add(String day, int startPeriod, int subjectId, String start, String end) {
      final name = nameMap[subjectId] ?? (subjectId == 0 ? 'Holiday' : 'Subject $subjectId');
      final entry = TimetableEntry(
        id: nextId++,
        day: day,
        period: startPeriod,
        subjectId: subjectId,
        subjectName: name,
        startTime: start,
        endTime: end,
      );
      
      _splitPeriodIfNeeded(entry, entries, () => nextId++);
    }

    // Monday
    add('MONDAY', 1, 1345, '08:50', '09:40'); // DAA
    add('MONDAY', 2, 1332, '09:40', '10:30'); // EIPR
    add('MONDAY', 3, 1346, '10:30', '11:20'); // DBMS
    add('MONDAY', 4, 1346, '11:20', '12:10'); // DBMS
    add('MONDAY', 5, 1350, '13:00', '13:50'); // AI
    add('MONDAY', 6, 1343, '13:50', '14:40'); // CD

    // Tuesday
    add('TUESDAY', 1, 1337, '08:50', '09:40'); // COMP
    add('TUESDAY', 2, 1345, '09:40', '10:30'); // DAA
    add('TUESDAY', 3, 1350, '10:30', '11:20'); // AI
    add('TUESDAY', 4, 1343, '11:20', '12:10'); // CD
    add('TUESDAY', 5, 1348, '13:00', '15:30'); // DBMS/COMP LAB (1348=DBMS Lab)

    // Wednesday
    add('WEDNESDAY', 1, 1343, '08:50', '09:40'); // CD
    add('WEDNESDAY', 2, 1349, '09:40', '10:30'); // PP
    add('WEDNESDAY', 3, 1347, '10:30', '11:20'); // NAB
    add('WEDNESDAY', 4, 1347, '11:20', '12:10'); // NAB
    add('WEDNESDAY', 5, 1337, '13:00', '13:50'); // COMP
    add('WEDNESDAY', 6, 1337, '13:50', '14:40'); // COMP
    add('WEDNESDAY', 7, 1346, '14:40', '15:30'); // DBMS

    // Thursday
    add('THURSDAY', 1, 1345, '08:50', '09:40'); // DAA
    add('THURSDAY', 2, 1348, '09:40', '11:20'); // DBMS/COMP LAB
    add('THURSDAY', 3, 1348, '11:20', '12:10'); // DBMS/COMP LAB
    add('THURSDAY', 4, 1350, '13:00', '13:50'); // AI
    add('THURSDAY', 5, 1658, '13:50', '15:30'); // PCS (1658=T&P)

    // Friday
    add('FRIDAY', 1, 1337, '08:50', '09:40'); // COMP
    add('FRIDAY', 2, 1345, '09:40', '10:30'); // DAA
    add('FRIDAY', 3, 1332, '10:30', '11:20'); // EIPR
    add('FRIDAY', 4, 1343, '11:20', '12:10'); // CD
    add('FRIDAY', 5, 1349, '13:00', '15:30'); // PYTHON LAB (ID 1349 from subjects API)

    return entries;
  }

  void _splitPeriodIfNeeded(TimetableEntry entry, List<TimetableEntry> destination, int Function() idGenerator) {
    final sParts = entry.startTime.split(':');
    final eParts = entry.endTime.split(':');
    if (sParts.length >= 2 && eParts.length >= 2) {
      final startMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final duration = endMin - startMin;

      // If duration is roughly 100 mins (90-110), split into two
      if (duration >= 90 && duration <= 110) {
        final midMin = startMin + 50;
        final midTime = "${(midMin ~/ 60).toString().padLeft(2, '0')}:${(midMin % 60).toString().padLeft(2, '0')}";

        destination.add(entry.copyWith(id: idGenerator(), endTime: midTime));
        destination.add(entry.copyWith(id: idGenerator(), period: entry.period + 1, startTime: midTime));
        return;
      }

      // If duration is roughly 150 mins (140-160), split into three
      if (duration >= 140 && duration <= 160) {
        final p1EndMin = startMin + 50;
        final p2EndMin = startMin + 100;
        final p1End = "${(p1EndMin ~/ 60).toString().padLeft(2, '0')}:${(p1EndMin % 60).toString().padLeft(2, '0')}";
        final p2End = "${(p2EndMin ~/ 60).toString().padLeft(2, '0')}:${(p2EndMin % 60).toString().padLeft(2, '0')}";

        destination.add(entry.copyWith(id: idGenerator(), endTime: p1End));
        destination.add(entry.copyWith(id: idGenerator(), period: entry.period + 1, startTime: p1End, endTime: p2End));
        destination.add(entry.copyWith(id: idGenerator(), period: entry.period + 2, startTime: p2End));
        return;
      }
    }
    destination.add(entry);
  }
}
