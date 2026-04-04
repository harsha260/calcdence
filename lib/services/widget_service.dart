import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/timetable_entry.dart';

class WidgetService {
  static const String _appGroupId = 'group.campx.attendance';
  static const String _androidWidgetName = 'AttendanceWidgetProvider';
  static const String _calendarWidgetName = 'CalendarWidgetProvider';

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('WidgetService Init Error: $e');
    }
  }

  static Future<void> updateWidgetData(
      Attendance attendance, List<TimetableEntry> todayClasses) async {
    try {
      // Basic Attendance Stats
      await HomeWidget.saveWidgetData<String>(
          'percentage', '${attendance.overallPercentage.toStringAsFixed(1)}%');
      await HomeWidget.saveWidgetData<String>('attended_conducted',
          '${attendance.totalAttended}/${attendance.totalConducted}');

      // Determine the next class
      String nextClassText = 'No more classes today';
      String allClassesText = 'No classes today';
      if (todayClasses.isNotEmpty) {
        final now = DateTime.now();
        for (var entry in todayClasses) {
          final endTime = entry.endDateTime(now);
          if (now.isBefore(endTime)) {
            nextClassText =
                '${entry.subjectName} (${entry.startTime} - ${entry.endTime})';
            break;
          }
        }
        allClassesText = todayClasses
            .map((e) => '${e.subjectName} (${e.startTime})')
            .join('\n');
      }

      await HomeWidget.saveWidgetData<String>('next_class', nextClassText);
      await HomeWidget.saveWidgetData<String>('all_classes', allClassesText);

      // Update both widgets
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: 'AttendanceWidget',
      );

      await HomeWidget.updateWidget(
        name: _calendarWidgetName,
      );

      debugPrint('Widget data updated successfully.');
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }
}
