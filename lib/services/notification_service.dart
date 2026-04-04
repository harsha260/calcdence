import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/timetable_entry.dart';

/// Manages local notifications for class reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call once in main() before runApp.
  Future<void> initialize() async {
    if (_initialized) return;
    debugPrint('NotificationService: Starting initialization');
    try {
      tz_data.initializeTimeZones();
      // Set local timezone — adjust if needed, or detect via device
      debugPrint('NotificationService: Initializing timezones: Asia/Kolkata');
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('NotificationService: Local time is: ${DateTime.now()}');

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      debugPrint('NotificationService: Initializing plugin...');
      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Explicitly create notification channel for Android 14
      if (androidPlugin != null) {
        debugPrint('NotificationService: Creating custom notification channel');
        await androidPlugin.createNotificationChannel(_channel);

        debugPrint(
          'NotificationService: Requesting initial Android permissions',
        );
        // We use wait with a timeout or just print to see if we get stuck here
        debugPrint(
          'NotificationService: Requesting notification permission...',
        );
        await androidPlugin.requestNotificationsPermission();
        debugPrint(
          'NotificationService: Notification permission request returned',
        );

        debugPrint('NotificationService: Requesting exact alarm permission...');
        await androidPlugin.requestExactAlarmsPermission();
        debugPrint(
          'NotificationService: Exact alarm permission request returned',
        );
      }

      debugPrint('NotificationService: Plugin initialized successfully');
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: Initialization failed with error: $e');
    }
  }

  /// Check if we have required permissions
  Future<Map<String, bool>> checkPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return {'notifications': true, 'exactAlarms': true};
    }

    final notifs = await androidPlugin.areNotificationsEnabled() ?? false;
    final exact = await androidPlugin.canScheduleExactNotifications() ?? false;

    return {'notifications': notifs, 'exactAlarms': exact};
  }

  /// Manually request exact alarm permission
  Future<void> requestExactPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      debugPrint('NotificationService: Opening exact alarm settings');
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'campx_class_reminders',
    'Class Reminders',
    description: 'Reminders before each class period begins',
    importance: Importance.high,
  );

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'campx_class_reminders',
    'Class Reminders',
    channelDescription: 'Reminders before each class period begins',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
  );

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id);
  }

  /// Schedule a generic reminder for a to-do item.
  Future<void> scheduleTodoReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await initialize();
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'campx_todo_channel',
          'To-Do Reminders',
          channelDescription: 'Reminders for scheduled tasks',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a notification [minutesBefore] minutes before [entry] on [date].
  Future<void> scheduleClassReminder({
    required TimetableEntry entry,
    required DateTime date,
    int minutesBefore = 10,
  }) async {
    if (!_initialized) await initialize();

    debugPrint(
      '[DEBUG] NotificationService: Scheduling for ${entry.subjectName} (P${entry.period})',
    );
    debugPrint(
      '[DEBUG] NotificationService: Raw startTime: ${entry.startTime}',
    );

    // Construct fire time directly in Kolkata timezone
    final parts = entry.startTime.split(':');
    if (parts.length < 2) {
      debugPrint(
        '[DEBUG] NotificationService: ABORT - Invalid startTime format',
      );
      return;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    final nowKolkata = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    );

    final fireAt = scheduledDate.subtract(Duration(minutes: minutesBefore));

    debugPrint(
      '[DEBUG] NotificationService: Current time (Kolkata): $nowKolkata',
    );
    debugPrint(
      '[DEBUG] NotificationService: Target class time: $scheduledDate',
    );
    debugPrint('[DEBUG] NotificationService: Scheduled fire time: $fireAt');

    if (fireAt.isBefore(nowKolkata)) {
      debugPrint(
        '[DEBUG] NotificationService: SKIPPING - Fire time is in the PAST.',
      );
      return;
    }

    try {
      final id = _notifId(entry, date);
      debugPrint(
        '[DEBUG] NotificationService: Calling zonedSchedule with ID: $id',
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      bool canScheduleExact = true;
      if (androidPlugin != null) {
        canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }

      if (canScheduleExact) {
        await _plugin.zonedSchedule(
          id,
          'Class in $minutesBefore min',
          '${entry.subjectName} - Period ${entry.period} at ${entry.startTime}',
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        debugPrint(
          '[DEBUG] NotificationService: Exact permission missing, falling back to inexact.',
        );
        await _plugin.zonedSchedule(
          id,
          'Class in $minutesBefore min',
          '${entry.subjectName} - Period ${entry.period} at ${entry.startTime}',
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      debugPrint('[DEBUG] NotificationService: SUCCESS - Scheduled ID $id');
    } catch (e) {
      debugPrint(
        '[DEBUG] NotificationService: EXCEPTION during scheduling: $e',
      );
      // Final fallback to inexact for any unexpected error
      try {
        await _plugin.zonedSchedule(
          _notifId(entry, date),
          'Class in $minutesBefore min',
          '${entry.subjectName} - Period ${entry.period} at ${entry.startTime}',
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (innerE) {
        debugPrint(
          '[DEBUG] NotificationService: FATAL scheduling error: $innerE',
        );
      }
    }
  }

  /// Show a notification immediately to verify basic functionality.
  Future<void> showInstantTestNotification() async {
    if (!_initialized) await initialize();
    debugPrint('NotificationService: Showing instant test notification');
    await _plugin.show(
      8888,
      'Test Notification',
      'If you see this, basic notifications are WORKING!',
      _details,
    );
  }

  /// Show a simple immediate notification for absent class.
  Future<void> showAbsentNotification({
    required String subjectName,
    required String date,
    int? period,
    String? time,
  }) async {
    if (!_initialized) await initialize();
    debugPrint(
      'NotificationService: Showing absent notification for $subjectName',
    );

    String message = 'You were marked absent for $subjectName on $date.';
    if (period != null && time != null) {
      message =
          'You were marked absent for $subjectName (Period $period at $time) on $date.';
    }

    await _plugin.show(
      DateTime.now().millisecond,
      'Marked Absent',
      message,
      _details,
    );
  }

  /// Show a simple immediate notification for morning college check.
  Future<void> showMorningCollegeCheck() async {
    if (!_initialized) await initialize();
    debugPrint('NotificationService: Showing morning college check');
    await _plugin.show(
      9999, // Fixed ID so it replaces previous ones
      'Going to college today?',
      'You have classes scheduled today. Tap to update your status.',
      _details,
    );
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() {
    debugPrint('NotificationService: Cancelling ALL notifications');
    return _plugin.cancelAll();
  }

  /// Cancel notifications for a specific day.
  Future<void> cancelForDate(DateTime date, List<TimetableEntry> entries) {
    debugPrint(
      'NotificationService: Cancelling ${entries.length} notifications for $date',
    );
    return Future.wait(entries.map((e) => _plugin.cancel(_notifId(e, date))));
  }

  /// Schedule all reminders for [date]'s timetable.
  Future<void> scheduleAllForDate({
    required DateTime date,
    required List<TimetableEntry> entries,
    int minutesBefore = 10,
  }) async {
    await cancelAll(); // Clean slate for simplicity in debugging

    if (entries.isNotEmpty) {
      await scheduleMorningToggle(date: date);
    }

    for (final e in entries) {
      await scheduleClassReminder(
        entry: e,
        date: date,
        minutesBefore: minutesBefore,
      );
    }
  }

  /// Schedule morning toggle at 8:00 AM if there are classes today.
  Future<void> scheduleMorningToggle({required DateTime date}) async {
    if (!_initialized) await initialize();

    final nowKolkata = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      8,
      0,
      0,
    );

    if (scheduledDate.isBefore(nowKolkata)) return;

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      bool canScheduleExact = true;
      if (androidPlugin != null) {
        canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }

      if (canScheduleExact) {
        await _plugin.zonedSchedule(
          8000, // Static ID for morning toggle
          'Going to college today?',
          'You have classes today. Are you going to attend?',
          scheduledDate,
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        await _plugin.zonedSchedule(
          8000,
          'Going to college today?',
          'You have classes today. Are you going to attend?',
          scheduledDate,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      debugPrint(
        '[DEBUG] NotificationService: Scheduled Morning Toggle at 8:00 AM',
      );
    } catch (e) {
      debugPrint(
        '[DEBUG] NotificationService: Failed scheduling morning toggle: $e',
      );
    }
  }

  /// Generate a unique notification ID that fits in a 32-bit signed integer.
  /// Format: DayIndex (1 digit) + SubjectId (last 4 digits) + Period (1 digit)
  int _notifId(TimetableEntry entry, DateTime date) {
    final dayIndex = date.weekday; // 1-7
    final subjPart = (entry.subjectId % 10000); // last 4 digits
    final periodPart = (entry.period % 10);

    // Combine into a number like XYZZZP (X=Day, Y=Spare, ZZZ=Subj, P=Period)
    // Using simple offset to ensure it's unique but within 2^31 - 1
    final id = (dayIndex * 1000000) + (subjPart * 10) + periodPart;
    debugPrint(
      '[DEBUG] NotificationService: Generated ID $id for Day:$dayIndex Subj:${entry.subjectId} Period:${entry.period}',
    );
    return id;
  }
}
