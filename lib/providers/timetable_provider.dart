import 'package:flutter/foundation.dart';
import '../models/timetable_entry.dart';
import '../services/api_service.dart' as api;

enum TimetableState { initial, loading, loaded, error }

/// Fetches and caches the classroom timetable from the CampX API.
class TimetableProvider extends ChangeNotifier {
  final api.CampXApiService _apiService;

  TimetableProvider(this._apiService);

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
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _holidays.contains(dateStr) || date.weekday == DateTime.sunday;
  }

  /// All periods for a given weekday (1=Mon…5=Fri), sorted by start time.
  List<TimetableEntry> periodsForWeekday(int weekday) =>
      _templateEntries.where((e) => e.weekday == weekday).toList()
        ..sort((a, b) {
          // Ensure "09:00" vs "10:00" sorts correctly
          final aTime = a.startTime.padLeft(5, '0');
          final bTime = b.startTime.padLeft(5, '0');
          return aTime.compareTo(bTime);
        });

  /// Today's periods.
  List<TimetableEntry> get todayPeriods => periodsForDate(DateTime.now());

  /// Periods on a specific date.
  /// Start with template, then overlay real attendance logs if found.
  List<TimetableEntry> periodsForDate(DateTime date) {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    if (isHoliday(date)) return [];

    final template = periodsForWeekday(date.weekday);
    if (template.isEmpty) return [];

    final logs = _specificEntries
        .where((e) => e.sessionDate == dateStr)
        .toList();
    if (logs.isEmpty) {
      // Debug: debugPrint('TimetableProvider: No logs found for $dateStr');
      return template;
    }

    debugPrint(
      'TimetableProvider: Merging ${logs.length} logs for $dateStr into ${template.length} template slots',
    );
    final result = <TimetableEntry>[];
    final usedLogs = <int>{};

    for (var temp in template) {
      debugPrint(
        'TimetableProvider: Slot ${temp.subjectName} P${temp.period} (id:${temp.subjectId})',
      );
      int logIndex = -1;
      // Try exact subject + period match first
      for (int i = 0; i < logs.length; i++) {
        if (usedLogs.contains(i)) continue;
        final log = logs[i];
        if (log.subjectId == temp.subjectId && log.period == temp.period) {
          logIndex = i;
          debugPrint('  -> Exact match with log $i (P${log.period})');
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
                  debugPrint(
                    '  -> Time window match with log $i (${log.startTime})',
                  );
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
        debugPrint(
          '  -> Merged with log $logIndex. isAttended: ${merged.isAttended}',
        );
        result.add(merged);
      } else {
        debugPrint('  -> No log match found');
        result.add(temp.copyWith(sessionDate: dateStr));
      }
    }

    for (int i = 0; i < logs.length; i++) {
      if (!usedLogs.contains(i)) {
        debugPrint(
          'TimetableProvider: Adding unmatched log: ${logs[i].subjectName} ${logs[i].startTime}',
        );
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
      debugPrint('TimetableProvider: Fetching dynamic timetable from API...');
      final rawApiEntries = await _apiService.getTimetable();

      final processedSpecific = <TimetableEntry>[];
      final datesWithClasses = <String>{};

      for (var json in rawApiEntries) {
        final entry = TimetableEntry.fromJson(json, nameMap: nameMap);
        final sessionDate = entry.sessionDate;

        if (sessionDate != null) {
          final subjectLower = entry.subjectName.toLowerCase();
          final statusLower = (json['attendanceStatus'] ?? '')
              .toString()
              .toLowerCase();

          if (subjectLower.contains('holiday') ||
              statusLower.contains('holiday')) {
            _holidays.add(sessionDate);
          } else {
            datesWithClasses.add(sessionDate);
            _splitPeriodIfNeeded(
              entry,
              processedSpecific,
              () => processedSpecific.length + 1000,
            );
          }
        }
      }

      _specificEntries = processedSpecific;

      // Scan empty dates between first and last date in response
      if (datesWithClasses.isNotEmpty) {
        final dates = datesWithClasses.map((d) => DateTime.parse(d)).toList()
          ..sort();
        final first = dates.first;
        final last = dates.last;

        for (int i = 0; i <= last.difference(first).inDays; i++) {
          final date = first.add(Duration(days: i));
          final dStr =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          if (!datesWithClasses.contains(dStr) &&
              date.weekday != DateTime.sunday) {
            // If it has periods in template but 0 in API, it's a holiday
            if (periodsForWeekday(date.weekday).isNotEmpty) {
              _holidays.add(dStr);
            }
          }
        }
      }

      debugPrint(
        'TimetableProvider: Loaded ${_templateEntries.length} template entries and ${_specificEntries.length} specific date overrides.',
      );

      _state = TimetableState.loaded;
    } catch (e) {
      debugPrint('TimetableProvider: Error fetching dynamic timetable: $e');
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
        if (e.sessionDate != null)
          "${e.sessionDate}_${e.subjectId}_${e.period}": e,
    };

    debugPrint(
      'TimetableProvider: updateSpecificEntries received ${sessions.length} sessions. Current specific count: ${_specificEntries.length}',
    );
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
    debugPrint(
      'TimetableProvider: Final specificEntries count: ${_specificEntries.length}',
    );
    notifyListeners();
  }

  List<TimetableEntry> _getHardcodedTimetable(Map<int, String> nameMap) {
    final entries = <TimetableEntry>[];
    int nextId = 1;

    void add(
      String day,
      int startPeriod,
      int subjectId,
      String start,
      String end,
    ) {
      final name =
          nameMap[subjectId] ??
          (subjectId == 0 ? 'Holiday' : 'Subject $subjectId');
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

    // Determine which subject IDs to use
    final availableIds = nameMap.keys.where((id) => id != 0).toList();
    if (availableIds.isEmpty) return entries;

    int getId(int index) {
      if (availableIds.isEmpty) return 0;
      return availableIds[index % availableIds.length];
    }

    // Try to map our hardcoded concepts to whatever subjects we have
    // If the specific hardcoded ID exists, use it. Otherwise use a fallback from the available IDs.
    int getSubject(int preferredId, int fallbackIndex) {
      if (nameMap.containsKey(preferredId)) return preferredId;
      return getId(fallbackIndex);
    }

    final idDAA = getSubject(1345, 0);
    final idEIPR = getSubject(1332, 1);
    final idDBMS = getSubject(1346, 2);
    final idAI = getSubject(1350, 3);
    final idCD = getSubject(1343, 4);
    final idCOMP = getSubject(1337, 5);
    final idDBMSLab = getSubject(1348, 6);
    final idPP = getSubject(1349, 7);
    final idNAB = getSubject(1347, 8);
    final idPCS = getSubject(1658, 9);

    // Monday
    add('MONDAY', 1, idDAA, '08:50', '09:40');
    add('MONDAY', 2, idEIPR, '09:40', '10:30');
    add('MONDAY', 3, idDBMS, '10:30', '11:20');
    add('MONDAY', 4, idDBMS, '11:20', '12:10');
    add('MONDAY', 5, idAI, '13:00', '13:50');
    add('MONDAY', 6, idCD, '13:50', '14:40');

    // Tuesday
    add('TUESDAY', 1, idCOMP, '08:50', '09:40');
    add('TUESDAY', 2, idDAA, '09:40', '10:30');
    add('TUESDAY', 3, idAI, '10:30', '11:20');
    add('TUESDAY', 4, idCD, '11:20', '12:10');
    add('TUESDAY', 5, idDBMSLab, '13:00', '15:30');

    // Wednesday
    add('WEDNESDAY', 1, idCD, '08:50', '09:40');
    add('WEDNESDAY', 2, idPP, '09:40', '10:30');
    add('WEDNESDAY', 3, idNAB, '10:30', '11:20');
    add('WEDNESDAY', 4, idNAB, '11:20', '12:10');
    add('WEDNESDAY', 5, idCOMP, '13:00', '13:50');
    add('WEDNESDAY', 6, idCOMP, '13:50', '14:40');
    add('WEDNESDAY', 7, idDBMS, '14:40', '15:30');

    // Thursday
    add('THURSDAY', 1, idDAA, '08:50', '09:40');
    add('THURSDAY', 2, idDBMSLab, '09:40', '11:20');
    add('THURSDAY', 3, idDBMSLab, '11:20', '12:10');
    add('THURSDAY', 4, idAI, '13:00', '13:50');
    add('THURSDAY', 5, idPCS, '13:50', '15:30');

    // Friday
    add('FRIDAY', 1, idCOMP, '08:50', '09:40');
    add('FRIDAY', 2, idDAA, '09:40', '10:30');
    add('FRIDAY', 3, idEIPR, '10:30', '11:20');
    add('FRIDAY', 4, idCD, '11:20', '12:10');
    add('FRIDAY', 5, idPP, '13:00', '15:30');

    return entries;
  }

  void _splitPeriodIfNeeded(
    TimetableEntry entry,
    List<TimetableEntry> destination,
    int Function() idGenerator,
  ) {
    final sParts = entry.startTime.split(':');
    final eParts = entry.endTime.split(':');
    if (sParts.length >= 2 && eParts.length >= 2) {
      final startMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final duration = endMin - startMin;

      // If duration is roughly 100 mins (90-110), split into two
      if (duration >= 90 && duration <= 110) {
        final midMin = startMin + 50;
        final midTime =
            "${(midMin ~/ 60).toString().padLeft(2, '0')}:${(midMin % 60).toString().padLeft(2, '0')}";

        destination.add(entry.copyWith(id: idGenerator(), endTime: midTime));
        destination.add(
          entry.copyWith(
            id: idGenerator(),
            period: entry.period + 1,
            startTime: midTime,
          ),
        );
        return;
      }

      // If duration is roughly 150 mins (140-160), split into three
      if (duration >= 140 && duration <= 160) {
        final p1EndMin = startMin + 50;
        final p2EndMin = startMin + 100;
        final p1End =
            "${(p1EndMin ~/ 60).toString().padLeft(2, '0')}:${(p1EndMin % 60).toString().padLeft(2, '0')}";
        final p2End =
            "${(p2EndMin ~/ 60).toString().padLeft(2, '0')}:${(p2EndMin % 60).toString().padLeft(2, '0')}";

        destination.add(entry.copyWith(id: idGenerator(), endTime: p1End));
        destination.add(
          entry.copyWith(
            id: idGenerator(),
            period: entry.period + 1,
            startTime: p1End,
            endTime: p2End,
          ),
        );
        destination.add(
          entry.copyWith(
            id: idGenerator(),
            period: entry.period + 2,
            startTime: p2End,
          ),
        );
        return;
      }
    }
    destination.add(entry);
  }
}
