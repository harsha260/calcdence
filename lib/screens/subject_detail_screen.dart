import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../constants.dart';
import '../providers/target_provider.dart';
import '../services/notification_service.dart';
import '../models/timetable_entry.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';

/// Subject Detail Screen - Shows detailed stats and calculators
class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  double _target = 75.0; // 0-100
  late final TextEditingController _targetController;

  // Calculator results
  int? _bunkableClasses;
  int? _recoveryClasses;

  @override
  void initState() {
    super.initState();
    _target = context.read<TargetProvider>().target;
    _targetController = TextEditingController(text: _target.toInt().toString());
    _calculateResults();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  void _calculateResults() {
    final subject = widget.subject;
    final targetPct = _target;
    final tt = context.read<TimetableProvider>();
    
    // 1. Bunk Calculator (True Projection)
    // How many upcoming classes can we skip before falling below target?
    int possibleBunks = 0;
    int currentAttendedB = subject.classesAttended;
    int currentConductedB = subject.totalClasses;
    
    // Scan up to 90 days ahead
    for (int day = 1; day <= 90; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final classes = tt.periodsForDate(date).where((e) => e.subjectId == subject.subjectCode).length;
      
      for (int i = 0; i < classes; i++) {
        currentConductedB++;
        if ((currentAttendedB / currentConductedB * 100) >= targetPct) {
          possibleBunks++;
        } else {
          break;
        }
      }
      if ((currentAttendedB / currentConductedB * 100) < targetPct) break;
    }
    _bunkableClasses = possibleBunks;

    // 2. Recovery Calculator (True Projection)
    // How many upcoming classes must we attend to reach target?
    int currentAttendedR = subject.classesAttended;
    int currentConductedR = subject.totalClasses;
    int needed = 0;
    
    if ((currentAttendedR / currentConductedR * 100) < targetPct) {
      for (int day = 1; day <= 90; day++) {
        final date = DateTime.now().add(Duration(days: day));
        final classes = tt.periodsForDate(date).where((e) => e.subjectId == subject.subjectCode).length;
        
        for (int i = 0; i < classes; i++) {
          needed++;
          currentAttendedR++;
          currentConductedR++;
          if ((currentAttendedR / currentConductedR * 100) >= targetPct) break;
        }
        if ((currentAttendedR / currentConductedR * 100) >= targetPct) break;
      }
    }
    _recoveryClasses = needed;
  }

  void _onTargetChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0 && parsed <= 100) {
      setState(() {
        _target = parsed; // _target is already 0-100
        _calculateResults();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final isAboveThreshold = subject.percentage >= _target; // Use _target directly

    return Scaffold(
      appBar: AppBar(
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(subject.subjectName),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject Info Card
            _buildInfoCard(subject, isAboveThreshold),
            const SizedBox(height: 24),

            // Target Setter
            _buildTargetSetter(),
            const SizedBox(height: 24),

            // Calculator Results
            _buildCalculators(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Subject subject, bool isAboveThreshold) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Percentage Circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAboveThreshold
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: isAboveThreshold ? Colors.green : Colors.red,
                  width: 4,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${subject.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isAboveThreshold ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    Text(
                      subject.statusLabel,
                      style: TextStyle(
                        color: isAboveThreshold ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  'Classes Attended',
                  '${subject.classesAttended}',
                  Icons.check_circle,
                  Colors.green,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                _buildStatItem(
                  'Total Classes',
                  '${subject.totalClasses}',
                  Icons.class_,
                  Colors.blue,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                _buildStatItem(
                  'Classes Missed',
                  '${subject.totalClasses - subject.classesAttended}',
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSetter() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Target Percentage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _target, // Use _target (0-100)
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: Colors.deepPurple,
                    onChanged: (value) {
                      setState(() {
                        _target = value;
                        _targetController.text = value.toInt().toString();
                        _calculateResults();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      suffix: const Text('%'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _onTargetChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildQuickTarget(65, 'Safe'),
                _buildQuickTarget(75, 'Target'),
                _buildQuickTarget(85, 'Good'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTarget(int percent, String label) {
    final isSelected = _target.round() == percent;
    return ChoiceChip(
      label: Text('$percent% ($label)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _target = percent.toDouble();
            _targetController.text = percent.toString();
            _calculateResults();
          });
        }
      },
      selectedColor: Colors.deepPurple.withOpacity(0.2),
    );
  }

  Widget _buildCalculators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Calculators',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),

        // Bunk Calculator
        _buildCalculatorCard(
          icon: Icons.free_breakfast,
          title: 'Bunk Calculator',
          subtitle: 'How many classes can you skip?',
          result: _bunkableClasses ?? 0,
          resultLabel: 'classes can be skipped',
          color: _bunkableClasses != null && _bunkableClasses! > 0
              ? Colors.green
              : Colors.orange,
          condition: widget.subject.percentage > _target,
          conditionText: widget.subject.percentage > _target
              ? '✓ You can safely skip $_bunkableClasses classes'
              : '⚠ You need ${_bunkableClasses == 0 ? '0' : 'at least 1'} more class',
        ),
        const SizedBox(height: 12),

        // Recovery Calculator
        _buildCalculatorCard(
          icon: Icons.trending_up,
          title: 'Recovery Calculator',
          subtitle: 'How many classes to recover?',
          result: _recoveryClasses ?? 0,
          resultLabel: 'consecutive classes needed',
          color: _recoveryClasses == 0 ? Colors.green : Colors.red,
          condition: widget.subject.percentage < _target,
          conditionText: widget.subject.percentage < _target
              ? '⚠ Need to attend $_recoveryClasses more class${_recoveryClasses == 1 ? '' : 'es'}'
              : '✓ You\'re above your target!',
        ),
      ],
    );
  }

  Widget _buildCalculatorCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int result,
    required String resultLabel,
    required Color color,
    required bool condition,
    required String conditionText,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    result.toString(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    resultLabel,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              conditionText,
              style: TextStyle(
                color: condition ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
