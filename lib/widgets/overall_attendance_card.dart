import 'package:flutter/material.dart';
import '../constants.dart';

class OverallAttendanceCard extends StatelessWidget {
  final double percentage;
  final int attended;
  final int conducted;

  const OverallAttendanceCard({
    super.key,
    required this.percentage,
    required this.attended,
    required this.conducted,
  });

  @override
  Widget build(BuildContext context) {
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
            color: (isAboveThreshold ? Colors.green : Colors.red).withValues(
              alpha: 0.3,
            ),
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
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
