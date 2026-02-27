import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/target_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/college_day_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../models/timetable_entry.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

              // Notification Settings
              Consumer<NotificationProvider>(
                builder: (context, notifProv, _) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Text(
                                'Remind me: ${notifProv.remindMinutes} mins before',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: notifProv.remindMinutes.toDouble(),
                            min: 0,
                            max: 60,
                            divisions: 12, // 5 min increments
                            label: '${notifProv.remindMinutes} mins',
                            activeColor: Colors.deepPurple,
                            onChanged: (val) async {
                              final mins = val.round();
                              await notifProv.setRemindMinutes(mins);
                              
                              // Re-schedule if going to college today
                              final collegeDay = context.read<CollegeDayProvider>();
                              final timetableProv = context.read<TimetableProvider>();
                              if (collegeDay.isGoingToday && timetableProv.isLoaded) {
                                await NotificationService().scheduleAllForDate(
                                  date: DateTime.now(),
                                  entries: timetableProv.todayPeriods,
                                  minutesBefore: mins,
                                );
                              }
                            },
                          ),
                          const Text(
                            'Notifications will fire this many minutes before each class starts.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

          const SizedBox(height: 16),

          // GitHub Update Checker
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update, color: Colors.blue),
              title: const Text('Check for Updates'),
              subtitle: const Text('Check for the latest version on GitHub'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: _checkForUpdates,
            ),
          ),

          const SizedBox(height: 16),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.shade100),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Calcdence Evolution v1.1.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    },
  ),
);
}

  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/harsha260/calcdence/releases/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] ?? 'Unknown';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Update Check'),
              content: Text('Latest Version: $latestVersion\nCurrent Version: 1.0.0+1'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          );
        }
      } else {
        throw Exception('Failed to check updates');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking updates: $e')));
      }
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
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
