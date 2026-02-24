import '../constants.dart';

/// Subject Model - Represents a subject with attendance data
class Subject {
  final int subjectCode;
  final String subjectName;
  final int classesAttended; // P
  final int totalClasses; // T
  final double percentage;
  final String subjectType; // Theory, Practical, etc.

  Subject({
    required this.subjectCode,
    required this.subjectName,
    required this.classesAttended,
    required this.totalClasses,
    required this.percentage,
    this.subjectType = 'Theory',
  });

  /// Create from API JSON response
  factory Subject.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    double _toDouble(dynamic val) {
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final code = _toInt(json['subjectCode'] ?? json['subject_code']);

    // Prefer our hardcoded name; fall back to API name or code
    final resolvedName = json['subjectName']?.toString() ??
        json['subject_name']?.toString() ??
        AppConstants.subjectNames[code] ??
        'Subject $code';

    final attended = _toInt(json['attended'] ?? json['present'] ?? json['subject_attended_count']);
    final total = _toInt(json['total'] ?? json['totalClasses'] ?? json['subject_total_count']);
    
    // Calculate percentage if not provided or 0.0
    double percentage = _toDouble(json['percentage']);
    if (percentage == 0.0 && total > 0) {
      percentage = (attended / total) * 100;
    }

    final type = (json['subjectType']?['type'] ?? json['type'] ?? 'Theory').toString();

    return Subject(
      subjectCode: code,
      subjectName: resolvedName,
      classesAttended: attended,
      totalClasses: total,
      percentage: percentage,
      subjectType: type,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'classesAttended': classesAttended,
        'totalClasses': totalClasses,
        'percentage': percentage,
      };

  /// Check if attendance is above threshold (75%)
  bool get isAboveThreshold => percentage >= 75.0;

  /// Get status color indicator
  String get statusLabel => isAboveThreshold ? 'Good' : 'Low';

  @override
  String toString() =>
      'Subject($subjectName: $classesAttended/$totalClasses = ${percentage.toStringAsFixed(1)}%)';
}
