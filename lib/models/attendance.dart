import 'subject.dart';

/// Attendance Model - Represents overall attendance data
class Attendance {
  final List<Subject> subjects;
  final double overallPercentage;
  final int totalAttended;
  final int totalConducted;

  Attendance({
    required this.subjects,
    required this.overallPercentage,
    required this.totalAttended,
    required this.totalConducted,
  });

  /// Create from API JSON response (list of subjects)
  factory Attendance.fromJsonList(List<dynamic> jsonList) {
    final subjects = jsonList
        .map((json) => Subject.fromJson(json as Map<String, dynamic>))
        .toList();

    // Calculate overall attendance
    int totalAttended = 0;
    int totalConducted = 0;
    for (final subject in subjects) {
      totalAttended += subject.classesAttended;
      totalConducted += subject.totalClasses;
    }
    final overall = totalConducted > 0 ? (totalAttended / totalConducted * 100) : 0.0;

    return Attendance(
      subjects: subjects,
      overallPercentage: overall,
      totalAttended: totalAttended,
      totalConducted: totalConducted,
    );
  }

  /// Empty attendance
  factory Attendance.empty() => Attendance(
        subjects: [],
        overallPercentage: 0.0,
        totalAttended: 0,
        totalConducted: 0,
      );

  /// Check if overall attendance is above threshold
  bool get isAboveThreshold => overallPercentage >= 75.0;

  /// Get count of subjects above threshold
  int get subjectsAboveThreshold =>
      subjects.where((s) => s.isAboveThreshold).length;

  /// Get count of subjects below threshold
  int get subjectsBelowThreshold =>
      subjects.where((s) => !s.isAboveThreshold).length;

  @override
  String toString() =>
      'Attendance(overall: ${overallPercentage.toStringAsFixed(1)}%, subjects: ${subjects.length})';
}
