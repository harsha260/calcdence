import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/target_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/notification_service.dart';
import '../models/timetable_entry.dart';

/// Settings Screen - Debug/Configuration options
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<ThemeProvider, TargetProvider>(
        builder: (context, themeProv, targetProv, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch between light and dark themes'),
                  secondary: Icon(
                    themeProv.isDark ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.deepPurple,
                  ),
                  value: themeProv.isDark,
                  onChanged: (val) => themeProv.toggle(),
                  activeColor: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 16),

              // Attendance Target
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.track_changes, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Attendance Target: ${targetProv.target.toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: targetProv.target,
                        min: 50,
                        max: 95,
                        divisions: 45,
                        label: '${targetProv.target.toInt()}%',
                        activeColor: Colors.deepPurple,
                        onChanged: (val) => targetProv.setTarget(val),
                      ),
                      const Text(
                        'This affects visual status and bunk/recovery recommendations.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
          
          // Test Buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Debug Tools',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<AttendanceProvider>().fetchAttendance();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refreshing attendance...')),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Attendance'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await NotificationService().showInstantTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Instant notification triggered!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Instant Test (Direct)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final testTime = DateTime.now().add(const Duration(seconds: 5));
                        await NotificationService().scheduleClassReminder(
                          entry: TimetableEntry(
                            id: 9999,
                            day: 'TODAY',
                            period: 0,
                            subjectId: 0,
                            subjectName: 'Test Reminder',
                            startTime: testTime.toIso8601String().substring(11, 19),
                            endTime: '',
                          ),
                          date: DateTime.now(),
                          minutesBefore: 0,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Scheduled notification in 5s (Exact)')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.timer),
                    label: const Text('Scheduled Test (In 5s)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  ),
);
}

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
