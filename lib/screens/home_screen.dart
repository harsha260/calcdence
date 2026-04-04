import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/attendance_provider.dart';
import '../providers/target_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/college_day_provider.dart';
import '../providers/notification_provider.dart';
import '../constants.dart';
import '../models/timetable_entry.dart';
import 'overall_detail_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'announcement_screen.dart';
import 'todo_screen.dart';
import '../services/notification_service.dart';
import '../widgets/overall_attendance_card.dart';
import '../widgets/subject_list_tile.dart';

/// Home Screen - Attendance Dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedFilter =
      'All'; // All, Theory, Practical, High, Low, Below Target

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    debugPrint('HomeScreen: _refreshData triggered');
    final attendanceProv = context.read<AttendanceProvider>();
    final collegeDay = context.read<CollegeDayProvider>();
    final notifProv = context.read<NotificationProvider>();

    // Load local settings first
    await Future.wait([collegeDay.loadToday(), notifProv.loadSettings()]);
    debugPrint(
      'HomeScreen: CollegeDay isGoingToday: ${collegeDay.isGoingToday}',
    );

    await attendanceProv.fetchAttendance();
    debugPrint(
      'HomeScreen: Attendance fetch complete. hasData: ${attendanceProv.hasData}',
    );

    // Once attendance (and nameMap) is loaded, fetch timetable
    if (attendanceProv.hasData) {
      debugPrint('HomeScreen: Attendance data available, fetching timetable.');
      final timetableProv = context.read<TimetableProvider>();
      await timetableProv.fetchTimetable(nameMap: attendanceProv.nameMap);

      // Sync real subject-wise session logs to the timetable
      timetableProv.updateSpecificEntries(attendanceProv.allSessions);

      debugPrint(
        'HomeScreen: Timetable fetch complete. Sessions synced: ${attendanceProv.allSessions.length}',
      );

      // If user is going to college today, schedule notifications
      if (collegeDay.isGoingToday && timetableProv.isLoaded) {
        debugPrint(
          'HomeScreen: User is going to college, auto-scheduling notifications for today.',
        );
        await NotificationService().scheduleAllForDate(
          date: DateTime.now(),
          entries: timetableProv.todayPeriods,
          minutesBefore: notifProv.remindMinutes,
        );
      }
    } else {
      debugPrint('HomeScreen: No attendance data, skipping timetable fetch.');
    }
  }

  Future<void> _handleRefresh() async {
    await _refreshData();
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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TodoScreen()));
            },
            tooltip: 'To-Do List',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
            },
            tooltip: 'Calendar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, _) {
          if (attendanceProvider.isLoading && !attendanceProvider.hasData) {
            return _buildShimmerLoading();
          }

          if (attendanceProvider.state == AttendanceState.error &&
              !attendanceProvider.hasData) {
            return _buildErrorState(attendanceProvider.errorMessage);
          }

          if (!attendanceProvider.hasData) {
            return const Center(child: Text('No attendance data available'));
          }

          final attendance = attendanceProvider.attendance!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                // Daily Status Card
                SliverToBoxAdapter(
                  child: Consumer<CollegeDayProvider>(
                    builder: (context, collegeDay, _) =>
                        _buildDailyStatusCard(collegeDay),
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
                    child: OverallAttendanceCard(
                      percentage: attendance.overallPercentage,
                      attended: attendance.totalAttended,
                      conducted: attendance.totalConducted,
                    ),
                  ),
                ),

                // Bunk Recommender Card
                SliverToBoxAdapter(
                  child:
                      Consumer3<
                        AttendanceProvider,
                        TimetableProvider,
                        TargetProvider
                      >(
                        builder:
                            (
                              context,
                              attendanceProv,
                              timetableProv,
                              targetProv,
                              _,
                            ) {
                              if (!attendanceProv.hasData ||
                                  !timetableProv.isLoaded) {
                                return const SizedBox.shrink();
                              }
                              return _buildBunkRecommender(
                                attendanceProv,
                                timetableProv,
                                targetProv,
                              );
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
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
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
                        subjects = subjects
                            .where(
                              (s) => s.subjectName.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                            )
                            .toList();
                      }

                      // Apply Filter
                      final target = targetProv.target;
                      switch (_selectedFilter) {
                        case 'High %':
                          subjects = List.from(subjects)
                            ..sort(
                              (a, b) => b.percentage.compareTo(a.percentage),
                            );
                          break;
                        case 'Low %':
                          subjects = List.from(subjects)
                            ..sort(
                              (a, b) => a.percentage.compareTo(b.percentage),
                            );
                          break;
                        case 'Below Target':
                          subjects = subjects
                              .where((s) => s.percentage < target)
                              .toList();
                          break;
                      }

                      if (subjects.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('No subjects found')),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final subject = subjects[index];
                          return SubjectListTile(
                            subject: subject,
                            targetPercentage: targetProv.target,
                          );
                        }, childCount: subjects.length),
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
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
        selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
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
      color: Colors.deepPurple.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.1)),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
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
      ..sort(
        (a, b) =>
            a.startTime.padLeft(5, '0').compareTo(b.startTime.padLeft(5, '0')),
      );

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
        periodLabel = 'Periods ${period.period}-${sortedToday[j - 1].period}';
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isSafe
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: isSafe ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSafe
                                ? 'Safe (${percentageIfBunked.toStringAsFixed(1)}%)'
                                : 'Risky (${percentageIfBunked.toStringAsFixed(1)}%)',
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
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
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

  Widget _buildShimmerLoading() {
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily Status Card Placeholder
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Overall Attendance Card Placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Bunk Recommender Card Placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Search and Filter Placeholder
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Subject Header Placeholder
          Container(
            height: 24,
            width: 150,
            margin: const EdgeInsets.only(right: 200, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Subject List Placeholders
          for (int i = 0; i < 5; i++) ...[
            const SizedBox(height: 12),
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ??
                  'We couldn\'t fetch your attendance data. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
