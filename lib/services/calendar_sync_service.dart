import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timetable_entry.dart';

class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  static const String _syncEnabledKey = 'calendar_sync_enabled';
  static const String _calendarIdKey = 'campx_calendar_id';

  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? false;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);

    if (enabled) {
      // Create or find calendar when enabled
      await _ensureCalendarExists();
    } else {
      // Optional: Delete the created calendar when disabled?
      // For now, let's just keep it but stop syncing new events.
    }
  }

  Future<String?> _ensureCalendarExists() async {
    final prefs = await SharedPreferences.getInstance();
    String? calendarId = prefs.getString(_calendarIdKey);

    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        debugPrint("Calendar permissions not granted.");
        return null;
      }
    }

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      if (calendarId != null) {
        final exists = calendarsResult.data!.any((c) => c.id == calendarId);
        if (exists) return calendarId;
      }

      // Try to find an existing one by name
      final existingCal = calendarsResult.data!.cast<Calendar?>().firstWhere(
            (c) => c?.name == 'CampX Timetable',
            orElse: () => null,
          );

      if (existingCal != null) {
        await prefs.setString(_calendarIdKey, existingCal.id!);
        return existingCal.id;
      }
    }

    // Create a new calendar
    final createResult = await _deviceCalendarPlugin.createCalendar(
      'CampX Timetable',
      calendarColor: Colors.deepPurple,
      localAccountName: 'Calcdence',
    );

    if (createResult.isSuccess && createResult.data != null) {
      await prefs.setString(_calendarIdKey, createResult.data!);
      return createResult.data;
    }

    debugPrint("Failed to create calendar.");
    return null;
  }

  Future<void> syncTimetable(
    List<TimetableEntry> entries,
    DateTime date,
  ) async {
    if (!await isSyncEnabled()) return;

    final calendarId = await _ensureCalendarExists();
    if (calendarId == null) return;

    // Delete existing events for the day to avoid duplicates
    final startOfDay = TZDateTime.local(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final deleteResult = await _deviceCalendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: startOfDay, endDate: endOfDay),
    );

    if (deleteResult.isSuccess && deleteResult.data != null) {
      for (var event in deleteResult.data!) {
        if (event.eventId != null) {
          await _deviceCalendarPlugin.deleteEvent(calendarId, event.eventId!);
        }
      }
    }

    // Add new events
    for (var entry in entries) {
      if (entry.subjectName.isEmpty) continue;

      final startTime = _parseTime(date, entry.startTime);
      final endTime = _parseTime(date, entry.endTime);

      if (startTime == null || endTime == null) continue;

      final event = Event(
        calendarId,
        title: entry.subjectName,
        description:
            'Class Period: ${entry.period}\nTopic: ${entry.topic ?? "N/A"}',
        start: startTime,
        end: endTime,
      );

      await _deviceCalendarPlugin.createOrUpdateEvent(event);
    }

    debugPrint("Synced ${entries.length} events to calendar $calendarId");
  }

  TZDateTime? _parseTime(DateTime date, String timeString) {
    try {
      // timeString format: "10:00 AM" or "02:30 PM"
      final parts = timeString.split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);

      if (parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts[1].toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }

      return TZDateTime.local(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return null;
    }
  }
}
