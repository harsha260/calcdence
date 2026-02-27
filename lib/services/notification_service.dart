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
      print('NotificationService: Requesting initial Android permissions');
      await androidPlugin.requestNotificationsPermission();
      // Only request exact alarm permission if needed (Android 13+)
      await androidPlugin.requestExactAlarmsPermission();
    }

    print('NotificationService: Plugin initialized');

    _initialized = true;
  }

  /// Check if we have required permissions
  Future<Map<String, bool>> checkPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return {'notifications': true, 'exactAlarms': true};

    final notifs = await androidPlugin.areNotificationsEnabled() ?? false;
    final exact = await androidPlugin.canScheduleExactNotifications() ?? false;
    
    return {
      'notifications': notifs,
      'exactAlarms': exact,
    };
  }

  /// Manually request exact alarm permission
  Future<void> requestExactPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      print('NotificationService: Opening exact alarm settings');
      await androidPlugin.requestExactAlarmsPermission();
    }
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
    
    print('[DEBUG] NotificationService: Scheduling for ${entry.subjectName} (P${entry.period})');
    print('[DEBUG] NotificationService: Raw startTime: ${entry.startTime}');
    
    // Construct fire time directly in Kolkata timezone
    final parts = entry.startTime.split(':');
    if (parts.length < 2) {
      print('[DEBUG] NotificationService: ABORT - Invalid startTime format');
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
    
    print('[DEBUG] NotificationService: Current time (Kolkata): $nowKolkata');
    print('[DEBUG] NotificationService: Target class time: $scheduledDate');
    print('[DEBUG] NotificationService: Scheduled fire time: $fireAt');

    if (fireAt.isBefore(nowKolkata)) {
      print('[DEBUG] NotificationService: SKIPPING - Fire time is in the PAST.');
      return; 
    }

    try {
      final id = _notifId(entry, date);
      print('[DEBUG] NotificationService: Calling zonedSchedule with ID: $id');
      await _plugin.zonedSchedule(
        id,
        '📚 Class in $minutesBefore min',
        '${entry.subjectName} — Period ${entry.period} at ${entry.startTime}',
        fireAt,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('[DEBUG] NotificationService: SUCCESS - Scheduled ID $id');
    } catch (e) {
      print('[DEBUG] NotificationService: EXCEPTION: $e');
      // If exact alarm fails, try non-exact as fallback
      if (e.toString().contains('exact_alarm')) {
        print('[DEBUG] NotificationService: Fallback to inexact scheduling...');
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
