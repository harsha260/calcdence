import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../screens/subject_detail_screen.dart';

class SubjectListTile extends StatelessWidget {
  final Subject subject;
  final double targetPercentage;

  const SubjectListTile({
    super.key,
    required this.subject,
    required this.targetPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final isAboveThreshold = subject.percentage >= targetPercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
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
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAboveThreshold ? 'Safe' : 'Low',
                      style: TextStyle(
                        color: isAboveThreshold ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
