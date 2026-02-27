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
    tz_data.initializeTimeZones();
    // Set local timezone — adjust if needed, or detect via device
    print('NotificationService: Initializing timezones: Asia/Kolkata');
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    print('NotificationService: Local time is: ${DateTime.now()}');

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // Request permission on Android 13+
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      print('NotificationService: Requesting Android permissions');
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    print('NotificationService: Plugin initialized');

    _initialized = true;
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'campx_class_reminders',
    'Class Reminders',
    channelDescription: 'Reminders before each class period begins',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  /// Schedule a notification [minutesBefore] minutes before [entry] on [date].
  Future<void> scheduleClassReminder({
    required TimetableEntry entry,
    required DateTime date,
    int minutesBefore = 10,
  }) async {
    if (!_initialized) await initialize();
    
    // Construct fire time directly in Kolkata timezone
    final parts = entry.startTime.split(':');
    if (parts.length < 2) return;
    
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
    
    print('NotificationService: Scheduling ${entry.subjectName}');
    print('NotificationService: Current time (Kolkata): $nowKolkata');
    print('NotificationService: Scheduled fire time (Kolkata): $fireAt');

    if (fireAt.isBefore(nowKolkata)) {
      print('NotificationService: SKIPPING - Fire time is in the past.');
      return; 
    }

    try {
      await _plugin.zonedSchedule(
        _notifId(entry, date),
        '📚 Class in $minutesBefore min',
        '${entry.subjectName} — Period ${entry.period} at ${entry.startTime}',
        fireAt,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('NotificationService: SUCCESS scheduled with ID ${_notifId(entry, date)}');
    } catch (e) {
      print('NotificationService: ERROR scheduling: $e');
      // If exact alarm fails, try non-exact as fallback
      if (e.toString().contains('exact_alarm')) {
        print('NotificationService: Retrying with inexact scheduling...');
        await _plugin.zonedSchedule(
          _notifId(entry, date),
          '📚 Class in $minutesBefore min',
          '${entry.subjectName} — Period ${entry.period} at ${entry.startTime}',
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  /// Show a notification immediately to verify basic functionality.
  Future<void> showInstantTestNotification() async {
    if (!_initialized) await initialize();
    print('NotificationService: Showing instant test notification');
    await _plugin.show(
      8888,
      '🔔 Test Notification',
      'If you see this, basic notifications are WORKING!',
      _details,
    );
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() {
    print('NotificationService: Cancelling ALL notifications');
    return _plugin.cancelAll();
  }

  /// Cancel notifications for a specific day.
  Future<void> cancelForDate(DateTime date, List<TimetableEntry> entries) {
    print('NotificationService: Cancelling ${entries.length} notifications for $date');
    return Future.wait(entries.map((e) => _plugin.cancel(_notifId(e, date))));
  }

  /// Schedule all reminders for [date]'s timetable.
  Future<void> scheduleAllForDate({
    required DateTime date,
    required List<TimetableEntry> entries,
    int minutesBefore = 10,
  }) async {
    await cancelAll(); // Clean slate for simplicity in debugging
    for (final e in entries) {
      await scheduleClassReminder(
          entry: e, date: date, minutesBefore: minutesBefore);
    }
  }

  /// Unique notification ID based on entry + date (fits in int32).
  int _notifId(TimetableEntry entry, DateTime date) =>
      (date.month * 10000000 + date.day * 100000 + entry.period * 1000 + (entry.subjectId % 1000))
          .abs() %
      (1 << 30);
}
