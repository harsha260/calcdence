import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../constants.dart';
import '../providers/target_provider.dart';
import '../providers/timetable_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../providers/attendance_provider.dart';

/// Overall Attendance Detail Screen
/// Shows day-level bunk/attend calculator with per-subject projected percentages.
/// Assumes 7 periods per day (as per the college timetable).
class OverallDetailScreen extends StatefulWidget {
  final int attended;    // total periods attended across all subjects
  final int conducted;   // total periods conducted across all subjects
  final double percentage;
  final List<Subject> subjects;

  const OverallDetailScreen({
    super.key,
    required this.attended,
    required this.conducted,
    required this.percentage,
    required this.subjects,
  });

  @override
  State<OverallDetailScreen> createState() => _OverallDetailScreenState();
}

class _OverallDetailScreenState extends State<OverallDetailScreen> {
  // No longer using fixed averages

  bool _attendMode = true; // true = "I will attend N days", false = "I will skip N days"
  int _days = 1;

  // Estimated number of school days conducted so far
  late final double _totalDays;

  // Removed _getDynamicPeriodsPerDay as we use true iteration

  @override
  void initState() {
    super.initState();
    
    // Initial value setup
    final tt = context.read<TimetableProvider>();
    final avgPpd = (tt.isLoaded && tt.entries.isNotEmpty) 
        ? tt.entries.length / 5.0 
        : 6.0;

    _totalDays = widget.conducted > 0
        ? widget.conducted / avgPpd
        : 1.0;
    
    // Automatically set mode and days based on target
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithTarget();
    });
  }

  void _syncWithTarget() {
    final target = context.read<TargetProvider>().target;
    final isAbove = widget.percentage >= target;
    
    if (isAbove) {
      _attendMode = false;
      _days = _calculateSkipDays(target);
    } else {
      _attendMode = true;
      _days = _calculateRequiredDays(target);
    }
    if (mounted) setState(() {});
  }

  int _calculateRequiredDays(double targetPct) {
    final t = targetPct / 100.0;
    if (t >= 1.0) return 30;

    final tt = context.read<TimetableProvider>();
    int currentAttended = widget.attended;
    int currentConducted = widget.conducted;
    
    for (int day = 1; day <= 60; day++) { // Scan up to 60 days
      final date = DateTime.now().add(Duration(days: day));
      final periods = tt.periodsForDate(date).length;
      if (periods == 0) continue;

      currentAttended += periods;
      currentConducted += periods;
      if ((currentAttended / currentConducted * 100) >= targetPct) return day;
    }
    return 30;
  }

  int _calculateSkipDays(double targetPct) {
    final t = targetPct / 100.0;
    if (t <= 0) return 30;

    final tt = context.read<TimetableProvider>();
    int currentAttended = widget.attended;
    int currentConducted = widget.conducted;
    
    for (int day = 1; day <= 60; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final periods = tt.periodsForDate(date).length;
      if (periods == 0) continue;

      currentConducted += periods;
      if ((currentAttended / currentConducted * 100) < targetPct) return day - 1;
    }
    return 30;
  }

  /// Get exact class counts for the next N days
  Map<int, int> _getUpcomingCounts(int days) {
    final tt = context.read<TimetableProvider>();
    final counts = <int, int>{};
    final now = DateTime.now();
    for (int i = 1; i <= days; i++) {
      final date = now.add(Duration(days: i));
      final periods = tt.periodsForDate(date);
      for (var p in periods) {
        counts[p.subjectId] = (counts[p.subjectId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildCharts(List<Subject> subjects) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    
    // Sort subjects by code for consistent chart
    final sorted = List<Subject>.from(subjects)..sort((a,b) => a.subjectCode.compareTo(b.subjectCode));

    return Column(
      children: [
        const Text(
          'Subject-wise Attendance (%)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 16, top: 16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sorted.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          sorted[index].subjectName.substring(0, math.min(3, sorted[index].subjectName.length)),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: sorted.asMap().entries.map((e) {
                final target = context.read<TargetProvider>().target;
                final isAbove = e.value.percentage >= target;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.percentage,
                      color: isAbove ? Colors.deepPurple : Colors.redAccent,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: context.read<TargetProvider>().target,
                    color: Colors.orange.withValues(alpha: 0.8),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (line) => 'Target ${context.read<TargetProvider>().target.toInt()}%',
                      style: const TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Attendance Projection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 24, top: 16),
          child: LineChart(
            LineChartData(
              maxY: 100,
              minY: math.max(0.0, widget.percentage - 30.0),
              titlesData: const FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, widget.percentage),
                    FlSpot(_days.toDouble(), _projectedOverall()),
                  ],
                  isCurved: false,
                  color: Colors.deepPurple,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.deepPurple.withOpacity(0.1),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: context.read<TargetProvider>().target,
                    color: Colors.orange.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  /// Projected percentage for a subject after _days attend/skip
  double _projected(Subject s) {
    final upcoming = _getUpcomingCounts(_days);
    final count = upcoming[s.subjectCode] ?? 0;
    
    if (_attendMode) {
      final newAtt = s.classesAttended + count;
      final newTot = s.totalClasses + count;
      return newTot > 0 ? (newAtt / newTot * 100) : s.percentage;
    } else {
      final newTot = s.totalClasses + count;
      return newTot > 0 ? (s.classesAttended / newTot * 100) : s.percentage;
    }
  }

  /// Overall projected percentage after _days attend/skip
  double _projectedOverall() {
    final upcoming = _getUpcomingCounts(_days);
    final totalAdded = upcoming.values.fold(0, (a, b) => a + b);
    
    if (_attendMode) {
      final newAtt = widget.attended + totalAdded;
      final newTot = widget.conducted + totalAdded;
      return newTot > 0 ? (newAtt / newTot * 100) : widget.percentage;
    } else {
      final newTot = widget.conducted + totalAdded;
      return newTot > 0 ? (widget.attended / newTot * 100) : widget.percentage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetProv = context.watch<TargetProvider>();
    final target = targetProv.target;
    final isGood = widget.percentage >= target;
    final missed = widget.conducted - widget.attended;
    final projectedPct = _projectedOverall();
    final projectedGood = projectedPct >= target;

    // Sort subjects: worst first so user sees what needs attention
    final sortedSubjects = List<Subject>.from(widget.subjects)
      ..sort((a, b) => a.percentage.compareTo(b.percentage));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall Attendance'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Current Stats card ────────────────────────────────────────
            _buildStatsCard(isGood, missed, theme),
            const SizedBox(height: 20),

            // ── Charts Section ───────────────────────────────────────────
            _buildCharts(widget.subjects),
            const SizedBox(height: 20),

            // ── Day Calculator ───────────────────────────────────────────
            _buildDayCalculator(theme, projectedPct, projectedGood),
            const SizedBox(height: 20),

            // ── Subject Projection Table ─────────────────────────────────
            Text(
              'Subject-wise Projection',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'After ${_attendMode ? "attending" : "skipping"} $_days day${_days == 1 ? "" : "s"}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            _buildProjectionTable(sortedSubjects, theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _statBox(
      String title, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildStatsCard(bool isGood, int missed, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Big circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isGood ? Colors.green : Colors.red).withOpacity(0.1),
                border: Border.all(
                    color: isGood ? Colors.green : Colors.red, width: 4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isGood ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      isGood ? 'Good' : 'Low',
                      style: TextStyle(
                          color: isGood ? Colors.green : Colors.red,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Three stat boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBox('Present', '${widget.attended}', Icons.check_circle,
                    Colors.green),
                _vDivider(),
                _statBox('Conducted', '${widget.conducted}', Icons.class_,
                    Colors.blue),
                _vDivider(),
                _statBox('Missed', '$missed', Icons.cancel, Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Estimated school days
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '≈ ${_totalDays.toStringAsFixed(0)} school days so far',
                style: TextStyle(
                    color: Colors.deepPurple[700], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Target Info Box
            Consumer<TargetProvider>(
              builder: (context, targetProv, _) {
                final target = targetProv.target;
                final isAbove = widget.percentage >= target;
                final days = isAbove ? _calculateSkipDays(target) : _calculateRequiredDays(target);
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAbove ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isAbove ? Colors.green : Colors.orange).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAbove ? Icons.info_outline : Icons.warning_amber_rounded,
                        color: isAbove ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAbove 
                            ? 'You can safely skip $days more days and stay above ${target.toInt()}%.'
                            : 'Attend all classes for $days more days to reach your ${target.toInt()}% target.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isAbove ? Colors.green[800] : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCalculator(
      ThemeData theme, double projectedPct, bool projectedGood) {
    final delta = projectedPct - widget.percentage;
    final deltaStr =
        '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}%';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Attend / Skip
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text('Day Calculator',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // Attend / Skip toggle
            LayoutBuilder(builder: (context, constraints) {
              return ToggleButtons(
                isSelected: [_attendMode, !_attendMode],
                onPressed: (i) =>
                    setState(() => _attendMode = i == 0),
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: _attendMode ? Colors.green : Colors.red,
                constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 16) / 2,
                    minHeight: 38),
                children: const [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.trending_up, size: 18),
                    SizedBox(width: 6),
                    Text('I will Attend'),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.beach_access, size: 18),
                    SizedBox(width: 6),
                    Text('I will Skip'),
                  ]),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Days slider
            Row(
              children: [
                Text('$_days',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    )),
                const SizedBox(width: 6),
                Text(
                  'day${_days == 1 ? "" : "s"}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.deepPurple[300]),
                ),
                const Spacer(),
                // Quick presets
                for (final d in [1, 3, 5, 7, 14])
                  GestureDetector(
                    onTap: () => setState(() => _days = d),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _days == d
                            ? Colors.deepPurple
                            : Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$d',
                        style: TextStyle(
                          color:
                              _days == d ? Colors.white : Colors.deepPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Slider(
              value: _days.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: Colors.deepPurple,
              onChanged: (v) => setState(() => _days = v.round()),
            ),

            const SizedBox(height: 8),
            // Projected overall result
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    (projectedGood ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: projectedGood ? Colors.green : Colors.red,
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall after $_days day${_days == 1 ? "" : "s"}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                      Text(
                        '${projectedPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: projectedGood ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Change', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(
                        deltaStr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: delta >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionTable(List<Subject> subjects, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text('Subject',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(
                  width: 52,
                  child: Text('Now',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 64,
                  child: Text('After',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          ...subjects.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final projPct = _projected(s);
            final delta = projPct - s.percentage;
            final isLast = i == subjects.length - 1;
            final target = context.read<TargetProvider>().target;
            final projGood = projPct >= target;
            final curGood = s.percentage >= target;

            return Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.15))),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Subject name
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            s.subjectName,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${s.classesAttended}/${s.totalClasses}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),

                  // Current %
                  SizedBox(
                    width: 52,
                    child: Center(
                      child: Text(
                        '${s.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: curGood ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Projected %
                  SizedBox(
                    width: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          delta > 0.05
                              ? Icons.arrow_upward
                              : delta < -0.05
                                  ? Icons.arrow_downward
                                  : Icons.remove,
                          size: 13,
                          color: delta > 0.05
                              ? Colors.green
                              : delta < -0.05
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${projPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: projGood ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
