import 'package:flutter/foundation.dart';
import '../models/timetable_entry.dart';
import '../services/api_service.dart' as api;

enum TimetableState { initial, loading, loaded, error }

/// Fetches and caches the classroom timetable from the CampX API.
class TimetableProvider extends ChangeNotifier {
  final api.CampXApiService _apiService = api.CampXApiService();

  TimetableState _state = TimetableState.initial;
  List<TimetableEntry> _entries = [];
  String? _errorMessage;

  TimetableState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == TimetableState.loaded;
  List<TimetableEntry> get entries => _entries;

  /// All periods for a given weekday (1=Mon…5=Fri), sorted by period number.
  List<TimetableEntry> periodsForWeekday(int weekday) => _entries
      .where((e) => e.weekday == weekday)
      .toList()
    ..sort((a, b) => a.period.compareTo(b.period));

  /// Today's periods.
  List<TimetableEntry> get todayPeriods =>
      periodsForWeekday(DateTime.now().weekday);

  /// Periods on a specific date.
  List<TimetableEntry> periodsForDate(DateTime date) =>
      periodsForWeekday(date.weekday);

  /// How many periods per day does [subjectId] appear on average?
  /// Uses real timetable data instead of dividing by 7.
  double periodsPerDayForSubject(int subjectId) {
    if (_entries.isEmpty) return 0;
    // Count occurrences per weekday
    final byday = <int, int>{};
    for (final e in _entries) {
      if (e.subjectId == subjectId) {
        byday[e.weekday] = (byday[e.weekday] ?? 0) + 1;
      }
    }
    if (byday.isEmpty) return 0;
    // Average over the days it appears
    return byday.values.fold(0, (a, b) => a + b) / 5; // 5 working days
  }

  /// Fetch from API (NO - now using hardcoded template per user request).
  Future<void> fetchTimetable({Map<int, String> nameMap = const {}}) async {
    if (_state == TimetableState.loading) return;
    _state = TimetableState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Per user request: hardcode the timetable as the API data is unreliable/outdated
      _entries = _getHardcodedTimetable(nameMap);
      _state = TimetableState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = TimetableState.error;
    }
    notifyListeners();
  }

  List<TimetableEntry> _getHardcodedTimetable(Map<int, String> nameMap) {
    final entries = <TimetableEntry>[];
    int nextId = 1;

    void add(String day, int period, int subjectId, String startTime, String endTime) {
      final name = nameMap[subjectId] ?? (subjectId == 0 ? 'Holiday' : 'Subject $subjectId');
      entries.add(TimetableEntry(
        id: nextId++,
        day: day,
        period: period,
        subjectId: subjectId,
        subjectName: name,
        startTime: startTime,
        endTime: endTime,
      ));
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
    add('FRIDAY', 5, 1344, '13:00', '15:30'); // PP LAB (Using 1344 for Lab context)

    return entries;
  }
}
