import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/target_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/college_day_provider.dart';
import '../providers/notification_provider.dart';
import '../constants.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import 'login_screen.dart';
import 'subject_detail_screen.dart';
import 'overall_detail_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'announcement_screen.dart';
import 'todo_screen.dart';
import '../services/notification_service.dart';

/// Home Screen - Attendance Dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Theory, Practical, High, Low, Below Target

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    print('HomeScreen: _refreshData triggered');
    final attendanceProv = context.read<AttendanceProvider>();
    await attendanceProv.fetchAttendance();
    print('HomeScreen: Attendance fetch complete. hasData: ${attendanceProv.hasData}');
    
    // Once attendance (and nameMap) is loaded, fetch timetable
    if (attendanceProv.hasData) {
      print('HomeScreen: Attendance data available, fetching timetable.');
      final timetableProv = context.read<TimetableProvider>();
      await timetableProv.fetchTimetable(nameMap: attendanceProv.nameMap);
      
      // Sync real subject-wise session logs to the timetable
      timetableProv.updateSpecificEntries(attendanceProv.allSessions);
      
      print('HomeScreen: Timetable fetch complete. Sessions synced: ${attendanceProv.allSessions.length}');
      
      // If user is going to college today, schedule notifications
      final collegeDay = context.read<CollegeDayProvider>();
      final notifProv = context.read<NotificationProvider>();
      if (collegeDay.isGoingToday && timetableProv.isLoaded) {
        print('HomeScreen: User is going to college, scheduling notifications for today.');
        await NotificationService().scheduleAllForDate(
          date: DateTime.now(),
          entries: timetableProv.todayPeriods,
          minutesBefore: notifProv.remindMinutes,
        );
      }
    } else {
      print('HomeScreen: No attendance data, skipping timetable fetch.');
    }
    
    // Load college day status
    print('HomeScreen: Loading college day status.');
    // ignore: use_build_context_synchronously
    context.read<CollegeDayProvider>().loadToday();
  }

  Future<void> _handleRefresh() async {
    await _refreshData();
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementScreen()),
              );
            },
            tooltip: 'Announcements',
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TodoScreen()),
              );
            },
            tooltip: 'To-Do List',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
            tooltip: 'Calendar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, _) {
          if (attendanceProvider.isLoading && !attendanceProvider.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (attendanceProvider.state == AttendanceState.error &&
              !attendanceProvider.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    attendanceProvider.errorMessage ?? 'Failed to load attendance',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleRefresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!attendanceProvider.hasData) {
            return const Center(
              child: Text('No attendance data available'),
            );
          }

          final attendance = attendanceProvider.attendance!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                // Daily Status Card
                SliverToBoxAdapter(
                  child: Consumer<CollegeDayProvider>(
                    builder: (context, collegeDay, _) => _buildDailyStatusCard(collegeDay),
                  ),
                ),

                // Overall Attendance Card (tappable → calculator)
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OverallDetailScreen(
                          attended: attendance.totalAttended,
                          conducted: attendance.totalConducted,
                          percentage: attendance.overallPercentage,
                          subjects: attendance.subjects,
                        ),
                      ),
                    ),
                    child: _buildOverallCard(attendance.overallPercentage,
                        attendance.totalAttended, attendance.totalConducted),
                  ),
                ),


                // Bunk Recommender Card
                SliverToBoxAdapter(
                  child: Consumer3<AttendanceProvider, TimetableProvider, TargetProvider>(
                    builder: (context, attendanceProv, timetableProv, targetProv, _) {
                      if (!attendanceProv.hasData || !timetableProv.isLoaded) return const SizedBox.shrink();
                      return _buildBunkRecommender(attendanceProv, timetableProv, targetProv);
                    },
                  ),
                ),

                // Search and Filter Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search subjects...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All'),
                              _buildFilterChip('High %'),
                              _buildFilterChip('Low %'),
                              _buildFilterChip('Below Target'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Subject List Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Your Subjects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Subject List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                 // Subject Cards
                sliver: Consumer2<AttendanceProvider, TargetProvider>(
                  builder: (context, attendanceProv, targetProv, _) {
                    var subjects = attendanceProv.attendance?.subjects ?? [];
                    
                    // Apply Search
                    if (_searchQuery.isNotEmpty) {
                      subjects = subjects.where((s) => s.subjectName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                    }
                    
                    // Apply Filter
                    final target = targetProv.target;
                    switch (_selectedFilter) {
                      case 'High %':
                        subjects = List.from(subjects)..sort((a, b) => b.percentage.compareTo(a.percentage));
                        break;
                      case 'Low %':
                        subjects = List.from(subjects)..sort((a, b) => a.percentage.compareTo(b.percentage));
                        break;
                      case 'Below Target':
                        subjects = subjects.where((s) => s.percentage < target).toList();
                        break;
                    }

                    if (subjects.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('No subjects found'),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subject = subjects[index];
                          return _buildSubjectCard(subject);
                        },
                        childCount: subjects.length,
                      ),
                    );
                  },
                ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallCard(
      double percentage, int attended, int conducted) {
    final isAboveThreshold = percentage >= AppConstants.attendanceThreshold;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAboveThreshold
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isAboveThreshold ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Overall Attendance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$attended / $conducted classes attended',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAboveThreshold ? '✓ Above 75%' : '⚠ Below 75%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap for calculator →',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        selectedColor: Colors.deepPurple.withOpacity(0.2),
        checkmarkColor: Colors.deepPurple,
        labelStyle: TextStyle(
          color: isSelected ? Colors.deepPurple : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
    );
  }

  Widget _buildDailyStatusCard(CollegeDayProvider provider) {
    final isGoing = provider.isGoingToday;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      color: Colors.deepPurple.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              isGoing ? Icons.directions_bus : Icons.home,
              color: Colors.deepPurple,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGoing ? "Going to College" : "Staying Home",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isGoing ? "Notifications enabled" : "Notifications muted",
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            Switch(
              value: isGoing,
              onChanged: (val) async {
                final timetableProv = context.read<TimetableProvider>();
                final notifProv = context.read<NotificationProvider>();
                await provider.toggleToday();
                // Schedule or cancel notifications
                if (val && timetableProv.isLoaded) {
                  await NotificationService().scheduleAllForDate(
                    date: DateTime.now(),
                    entries: timetableProv.todayPeriods,
                    minutesBefore: notifProv.remindMinutes,
                  );
                } else {
                  await NotificationService().cancelAll();
                }
              },
              activeThumbColor: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBunkRecommender(
    AttendanceProvider attendanceProv,
    TimetableProvider timetableProv,
    TargetProvider targetProv,
  ) {
    final today = timetableProv.todayPeriods;
    if (today.isEmpty) return const SizedBox.shrink();

    final target = targetProv.target;
    final List<Map<String, dynamic>> tips = [];
    final List<TimetableEntry> sortedToday = List.from(today)
      ..sort((a, b) => a.startTime.padLeft(5, '0').compareTo(b.startTime.padLeft(5, '0')));

    int i = 0;
    while (i < sortedToday.length) {
      final period = sortedToday[i];
      final subjectId = period.subjectId;
      final subject = attendanceProv.getSubjectByCode(subjectId);
      
      if (subject == null) {
        i++;
        continue;
      }

      // Find consecutive periods for same subject
      int count = 1;
      int j = i + 1;
      while (j < sortedToday.length && sortedToday[j].subjectId == subjectId) {
        count++;
        j++;
      }

      final p = subject.classesAttended;
      final t = subject.totalClasses;
      final percentageIfBunked = (p / (t + count)) * 100;
      final isSafe = percentageIfBunked >= target;
      final currentSurplus = subject.percentage - target;

      String periodLabel = 'Period ${period.period}';
      if (count > 1) {
        periodLabel = 'Periods ${period.period}-${sortedToday[j-1].period}';
      }

      tips.add({
        'name': subject.subjectName,
        'currentSurplus': currentSurplus,
        'isSafe': isSafe,
        'pctIfBunked': percentageIfBunked,
        'label': periodLabel,
        'time': period.startTime,
        'count': count,
      });

      i = j;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Today\'s Bunking Tips',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];
              final isSafe = tip['isSafe'] as bool;
              final percentageIfBunked = tip['pctIfBunked'] as double;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          tip['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isSafe ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            size: 14,
                            color: isSafe ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSafe ? 'Safe (${percentageIfBunked.toStringAsFixed(1)}%)' : 'Risky (${percentageIfBunked.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSafe ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tip['label']} • ${tip['time']}',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    // Determine color based on target
    final target = context.read<TargetProvider>().target;
    final isAboveThreshold = subject.percentage >= target;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubjectDetailScreen(subject: subject),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Attendance Circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAboveThreshold
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: isAboveThreshold ? Colors.green : Colors.red,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${subject.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isAboveThreshold ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Subject Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        subject.subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${subject.subjectCode}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Classes Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${subject.classesAttended}',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' / ${subject.totalClasses}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAboveThreshold
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subject.statusLabel,
                      style: TextStyle(
                        color: isAboveThreshold ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinkCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
