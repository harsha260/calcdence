import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// CampX API Service - Handles all API communications with cookie-based session management
class CampXApiService {
  static final CampXApiService _instance = CampXApiService._internal();
  factory CampXApiService() => _instance;
  CampXApiService._internal();

  String? _sessionKey;
  final http.Client _client = http.Client();

  /// Get current session key
  String? get sessionKey => _sessionKey;

  /// Set session key (used after login)
  void setSessionKey(String? key) {
    _sessionKey = key;
  }

  /// Build headers for authenticated requests
  Map<String, String> _buildAuthHeaders() {
    return {
      'x-institution-code': ApiConstants.institutionCode,
      'x-tenant-id': ApiConstants.tenantId,
      'Origin': ApiConstants.origin,
      'Referer': ApiConstants.referer,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Build cookie string for authenticated requests
  String _buildCookieString() {
    final cookies = <String>[
      if (_sessionKey != null) '${ApiConstants.sessionCookieKey}=$_sessionKey',
      '${ApiConstants.tenantCookieKey}=${ApiConstants.institutionCode}',
      '${ApiConstants.institutionCookieKey}=${ApiConstants.institutionCode}',
    ];
    return cookies.join('; ');
  }

  /// Login to CampX and get session cookie
  /// Returns: Map containing success status and session key
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final uri = Uri.parse(ApiConstants.loginUrl);
      
      final body = jsonEncode({
        'loginId': username,
        'password': password,
        'institutionCode': ApiConstants.institutionCode,
        'deviceType': 'mobile',
        'clientName': 'CampX App',
        'os': 'Android',
        'osVersion': '14',
        'loginType': 'USER',
      });

      print('CampX API: Attempting login to ${ApiConstants.loginUrl}');
      
      final response = await _client
          .post(
            uri,
            headers: _buildAuthHeaders(),
            body: body,
          )
          .timeout(AppConstants.connectionTimeout);

      print('CampX API: Response status = ${response.statusCode}');
      print('CampX API: Response headers = ${response.headers}');
      print('CampX API: Response body = ${response.body}');

      // CampX returns 201 Created on successful login (not 200 OK)
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Extract session cookie from response headers
        final setCookieHeader = response.headers['set-cookie'];
        String? sessionKey;
        
        print('CampX API: Set-Cookie header = $setCookieHeader');
        
        if (setCookieHeader != null) {
          // Simple regex to extract campx_session_key value
          final regex = RegExp(r'campx_session_key=([^;,]+)');
          final match = regex.firstMatch(setCookieHeader);
          if (match != null) {
            sessionKey = match.group(1);
            print('CampX API: Found session key from cookie: $sessionKey');
          }
        }

        // Fallback 1: check session.token in JSON body (CampX response format)
        if ((sessionKey == null || sessionKey.isEmpty) && data.containsKey('session')) {
          final session = data['session'];
          if (session is Map && session.containsKey('token')) {
            sessionKey = session['token']?.toString();
            print('CampX API: Found session key from body session.token: $sessionKey');
          }
        }

        // Fallback 2: top-level token/sessionKey/session_key keys
        if ((sessionKey == null || sessionKey.isEmpty)) {
          if (data.containsKey('token') || data.containsKey('sessionKey') || data.containsKey('session_key')) {
            final altKey = data['token'] ?? data['sessionKey'] ?? data['session_key'];
            if (altKey != null && altKey.toString().isNotEmpty) {
              sessionKey = altKey.toString();
              print('CampX API: Found session key from body fallback: $sessionKey');
            }
          }
        }

        if (sessionKey != null && sessionKey.isNotEmpty) {
          _sessionKey = sessionKey;
          return {
            'success': true,
            'sessionKey': sessionKey,
            'message': 'Login successful',
          };
        } else {
          return {
            'success': false,
            'message': 'Session key not found in response. Raw response: ${response.body}',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid username or password',
        };
      } else {
        throw ApiException(
          'Login failed: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during login: $e');
    }
  }

  /// Fetch attendance data for a specific subject
  /// Injects subjectCode into the returned map so Subject.fromJson always has it.
  Future<Map<String, dynamic>> getSubjectAttendance(int subjectCode) async {
    if (_sessionKey == null) {
      throw ApiException('Not authenticated. Please login first.');
    }

    try {
      final uri = Uri.parse('${ApiConstants.attendanceUrl}/$subjectCode');
      
      final headers = _buildAuthHeaders();
      headers['Cookie'] = _buildCookieString();

      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);

      if (response.statusCode == 200) {
        print('ApiService: Successfully fetched attendance for $subjectCode');
        final decoded = jsonDecode(response.body);
        print('ApiService: Raw attendance body: ${response.body}');
        // Always return a mutable Map with the subjectCode injected,
        // because the attendance endpoint response may not include it.
        final data = Map<String, dynamic>.from(
          decoded is Map ? decoded : {'raw': decoded},
        );
        data['subjectCode'] = subjectCode;
        return data;
      } else if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.', statusCode: 401);
      } else {
        throw ApiException(
          'Failed to fetch attendance: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Fetch the subject list for a given semester.
  /// Returns a list of subject maps with at least [id] and [name].
  Future<List<Map<String, dynamic>>> getSubjects({int semNo = 4}) async {
    if (_sessionKey == null) {
      throw ApiException('Not authenticated. Please login first.');
    }

    try {
      final uri = Uri.parse('${ApiConstants.subjectsUrl}?semNo=$semNo');
      final headers = _buildAuthHeaders();
      headers['Cookie'] = _buildCookieString();

      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);

      if (response.statusCode == 200) {
        print('ApiService: Successfully fetched subjects list. Body: ${response.body}');
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (decoded is Map) {
          // Some APIs wrap the list in a 'data' key
          final inner = decoded['data'];
          if (inner is List) {
            return inner
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        throw ApiException('Session expired.', statusCode: 401);
      } else {
        throw ApiException(
          'Failed to fetch subjects: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error fetching subjects: $e');
    }
  }

  /// Fetch the classroom timetable for the current student.
  Future<List<Map<String, dynamic>>> getTimetable() async {
    if (_sessionKey == null) {
      throw ApiException('Not authenticated. Please login first.');
    }

    try {
      final uri = Uri.parse(ApiConstants.timetableUrl);
      final headers = _buildAuthHeaders();
      headers['Cookie'] = _buildCookieString();

      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('ApiService: Timetable raw sample: ${decoded is List ? (decoded.isNotEmpty ? decoded[0] : "Empty List") : decoded}');
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (decoded is Map) {
          final inner = decoded['data'];
          if (inner is List) {
            return inner
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        throw ApiException('Session expired.', statusCode: 401);
      } else {
        throw ApiException(
          'Failed to fetch timetable: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error fetching timetable: $e');
    }
  }

  /// Fetch all subjects attendance (usually requires multiple calls or a list endpoint)
  /// For CampX, we may need to fetch subject list first, then iterate
  Future<List<Map<String, dynamic>>> getAllSubjectsAttendance(
    List<int> subjectCodes,
  ) async {
    final results = <Map<String, dynamic>>[];
    
    for (final code in subjectCodes) {
      try {
        final data = await getSubjectAttendance(code);
        results.add(data);
      } catch (e) {
        // Continue with other subjects if one fails
        results.add({
          'subjectCode': code,
          'error': e.toString(),
        });
      }
    }
    
    return results;
  }

  /// Check if session is valid
  Future<bool> validateSession() async {
    if (_sessionKey == null) return false;
    
    try {
      // Try fetching a known subject to validate
      await getSubjectAttendance(0);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logout and clear session
  void logout() {
    _sessionKey = null;
  }
}
