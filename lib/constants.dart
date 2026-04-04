import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Constants for CampX
class ApiConstants {
  // Base URLs
  static String get baseUrl => dotenv.env['CAMPX_API_BASE_URL'] ?? '';
  static String get loginUrl => '$baseUrl/auth-server/auth-v2/login';
  static String get attendanceUrl =>
      '$baseUrl/student-api/student-attendance/subject-attendance-web';
  static String get subjectsUrl => '$baseUrl/student-api/subjects';
  static String get timetableUrl => '$baseUrl/student-api/classroom-timetables';

  // Institution headers
  static const String institutionCode = 'anits';
  static const String tenantId = 'anits';

  // Web origin and referer
  static const String origin = 'https://anits.campx.in';
  static const String referer = 'https://anits.campx.in/';

  // Cookie keys
  static const String sessionCookieKey = 'campx_session_key';
  static const String tenantCookieKey = 'campx_tenant';
  static const String institutionCookieKey = 'campx_institution';

  // Storage keys
  static const String usernameKey = 'campx_username';
  static const String passwordKey = 'campx_password';
  static const String sessionKeyKey = 'campx_session_key';
  static const String semesterKey = 'campx_semester_key';
}

/// App-wide constants
class AppConstants {
  static const String appName = 'Calcdence';
  static const double attendanceThreshold = 75.0;
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// Fallback subject codes to fetch if API fails completely
  static const List<int> fallbackSubjectCodes = [
    1332,
    1337,
    1343,
    1344,
    1345,
    1346,
    1347,
    1348,
    1349,
    1350,
    1438,
    1439,
    1658,
    1749,
    1776,
  ];

  /// Fallback subject names if API is unavailable
  static const Map<int, String> fallbackSubjectNames = {
    1332: 'Entrepreneurship Development & IPR',
    1337: 'Computer Organization & Microprocessors',
    1343: 'Compiler Design',
    1344: 'CO & MP Interfacing Lab',
    1345: 'Design & Analysis of Algorithms',
    1346: 'Database Management Systems',
    1347: 'Numerical Ability & Prof. Communication',
    1348: 'DBMS Lab',
    1349: 'Python Programming Practices',
    1350: 'Artificial Intelligence',
    1438: 'Value Added Course',
    1439: 'Counseling',
    1658: 'Training & Placement',
    1749: 'MID 1 Exam',
    1776: 'MID 2 Exam',
  };

  /// Resolve a display name for a subject code (Fallback)
  static String subjectName(int code) =>
      fallbackSubjectNames[code] ?? 'Subject $code';
}
