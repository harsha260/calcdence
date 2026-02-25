/// Represents a single period in the classroom timetable.
class TimetableEntry {
  final int id;
  final String day;      // e.g. "MONDAY", "TUESDAY", ...
  final int period;      // 1-based period number
  final int subjectId;
  final String subjectName;
  final String startTime; // e.g. "09:00"
  final String endTime;   // e.g. "09:50"
  final String? sessionDate; // e.g. "2026-02-25" (ISO format)

  const TimetableEntry({
    required this.id,
    required this.day,
    required this.period,
    required this.subjectId,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    this.sessionDate,
  });

  /// Parse from raw API map.
  /// The CampX timetable API may use different field names; we try multiple.
  factory TimetableEntry.fromJson(
    Map<String, dynamic> json, {
    Map<int, String> nameMap = const {},
  }) {
    int _toInt(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    final id = _toInt(json['id']);

    // Day: might be "MONDAY" / "Monday" / 1-7 integer
    String day;
    final rawDay = json['day'] ?? json['dayOfWeek'] ?? json['weekDay'] ?? json['day_name'] ?? json['weekday'] ?? '';
    final sessionDate = json['sessionDate']?.toString() ?? '';
    print('TimetableEntry: Parsing. rawDay: "$rawDay", sessionDate: "$sessionDate"');

    if (rawDay is int) {
      const dayNames = [
        '',
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY',
        'SUNDAY'
      ];
      day = rawDay >= 1 && rawDay <= 7 ? dayNames[rawDay] : 'MONDAY';
    } else if (rawDay.toString().isNotEmpty) {
      final s = rawDay.toString().toUpperCase();
      if (s.startsWith('MON')) day = 'MONDAY';
      else if (s.startsWith('TUE')) day = 'TUESDAY';
      else if (s.startsWith('WED')) day = 'WEDNESDAY';
      else if (s.startsWith('THU')) day = 'THURSDAY';
      else if (s.startsWith('FRI')) day = 'FRIDAY';
      else if (s.startsWith('SAT')) day = 'SATURDAY';
      else if (s.startsWith('SUN')) day = 'SUNDAY';
      else day = 'MONDAY';
    } else {
      day = 'MONDAY';
    }
    String? formattedSessionDate;
    if (sessionDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(sessionDate);
        formattedSessionDate = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        const dayNames = [
          '',
          'MONDAY',
          'TUESDAY',
          'WEDNESDAY',
          'THURSDAY',
          'FRIDAY',
          'SATURDAY',
          'SUNDAY'
        ];
        day = dayNames[dt.weekday]; // Overwrite day from sessionDate if available
        print('TimetableEntry: Derived day $day and date $formattedSessionDate from sessionDate $sessionDate');
      } catch (e) {
        print('TimetableEntry: Error parsing sessionDate: $e');
      }
    }
    print('TimetableEntry: Resolved day to: $day');

    int period = _toInt(json['period'] ?? json['periodNo'] ?? json['slotNo'] ?? json['slot'] ?? 0);

    final subjectId = _toInt(json['subjectId'] ?? json['subject_id'] ?? json['courseId']);

    final apiName =
        (json['subjectName'] ?? json['subject']?['name'] ?? '').toString();
    final subjectName = nameMap[subjectId] ??
        (apiName.isNotEmpty ? apiName : 'Subject $subjectId');

    // Times — try multiple field names
    final startTime = (json['startTime'] ??
        json['start_time'] ??
        json['fromTime'] ??
        (period > 0 ? _periodToTime(period, isStart: true) : '08:50')).toString();
    final endTime = (json['endTime'] ??
        json['end_time'] ??
        json['toTime'] ??
        (period > 0 ? _periodToTime(period, isStart: false) : '09:40')).toString();

    // If period is missing or 0, try to deduce it from startTime
    if (period <= 1) {
      final deduced = _startTimeToPeriod(startTime);
      if (deduced > 0) period = deduced;
    }

    return TimetableEntry(
      id: id,
      day: day,
      period: period > 0 ? period : 1,
      subjectId: subjectId,
      subjectName: subjectName,
      startTime: startTime,
      endTime: endTime,
      sessionDate: formattedSessionDate,
    );
  }

  /// Deduce period number for ANITS slots based on start time
  static int _startTimeToPeriod(String t) {
    try {
      // Handle "08:50", "8:50", "08:50:00"
      final parts = t.split(':');
      if (parts.length < 2) return 0;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final totalMinutes = hour * 60 + minute;

      // ANITS Slots in minutes from midnight:
      // P1: 08:50 (530)
      // P2: 09:40 (580)
      // P3: 10:30 (630)
      // P4: 11:20 (680)
      // P5: 13:00 (780)
      // P6: 13:50 (830)
      // P7: 14:40 (880)
      
      if (totalMinutes >= 510 && totalMinutes <= 540) return 1;
      if (totalMinutes > 540 && totalMinutes <= 590) return 2;
      if (totalMinutes > 590 && totalMinutes <= 640) return 3;
      if (totalMinutes > 640 && totalMinutes <= 700) return 4;
      if (totalMinutes >= 760 && totalMinutes <= 800) return 5;
      if (totalMinutes > 800 && totalMinutes <= 850) return 6;
      if (totalMinutes > 850 && totalMinutes <= 900) return 7;
    } catch (e) {
      print('TimetableEntry: Deduction error: $e');
    }
    return 0;
  }

  /// Fallback: map period number to default ANITS time slots.
  static String _periodToTime(int period, {required bool isStart}) {
    // Typical 7-period schedule: 9:00-4:30 with 1h lunch
    const slots = [
      ('09:00', '09:50'),
      ('09:50', '10:40'),
      ('10:50', '11:40'),
      ('11:40', '12:30'),
      ('13:10', '14:00'),
      ('14:00', '14:50'),
      ('14:50', '15:40'),
    ];
    final idx = (period - 1).clamp(0, slots.length - 1);
    return isStart ? slots[idx].$1 : slots[idx].$2;
  }

  /// Convert startTime string ("HH:mm") to a DateTime on the given date.
  DateTime startDateTime(DateTime date) => _parseTime(startTime, date);
  DateTime endDateTime(DateTime date) => _parseTime(endTime, date);

  static DateTime _parseTime(String t, DateTime date) {
    final parts = t.split(':');
    if (parts.length < 2) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
      parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0,
    );
  }

  /// Weekday integer matching DateTime.weekday (1=Mon … 7=Sun)
  int get weekday {
    const map = {
      'MONDAY': 1, 'TUESDAY': 2, 'WEDNESDAY': 3,
      'THURSDAY': 4, 'FRIDAY': 5, 'SATURDAY': 6, 'SUNDAY': 7,
    };
    return map[day] ?? 1;
  }

  @override
  String toString() => '$day P$period: $subjectName ($startTime–$endTime)';
}
