import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../utils/notification_helper.dart';
import '../screens/preacher_dashboard.dart';

class ApiService {
  static String get baseUrl => Constants.apiBaseUrl;

  static String? _cachedIdToken;
  static String? _cachedUid;
  static DateTime? _tokenFetchTime;

  static void clearTokenCache() {
    _cachedIdToken = null;
    _cachedUid = null;
    _tokenFetchTime = null;
    PreacherDashboard.clearStaticCache();
  }

  static Future<void> logout() async {
    clearTokenCache();
    await NotificationHelper.logoutUser().catchError((_) {});
    await FirebaseAuth.instance.signOut().catchError((_) {});
  }

  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    String? idToken;
    if (user != null) {
      final now = DateTime.now();
      if (_cachedIdToken != null &&
          _cachedUid == user.uid &&
          _tokenFetchTime != null &&
          now.difference(_tokenFetchTime!).inMinutes < 10) {
        idToken = _cachedIdToken;
      } else {
        try {
          idToken = await user.getIdToken(false).timeout(const Duration(seconds: 4));
          if (idToken != null && idToken.isNotEmpty) {
            _cachedIdToken = idToken;
            _cachedUid = user.uid;
            _tokenFetchTime = now;
          }
        } catch (e) {
          debugPrint('Firebase token refresh warning: $e');
          if (_cachedUid == user.uid) {
            idToken = _cachedIdToken;
          } else {
            clearTokenCache();
          }
        }
      }
    } else {
      clearTokenCache();
    }

    final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes.toString();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Timezone-Offset': timezoneOffset,
      if (idToken != null && idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
    };
  }

  static Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _processResponse(response);
  }

  static Map<String, dynamic> _buildCleanSadhanaDto(Map<String, dynamic> body) {
    String dateString = (body['dateString'] ?? body['date'] ?? DateTime.now().toString().split(' ')[0]).toString();
    if (dateString.contains('T')) {
      dateString = dateString.split('T')[0];
    } else if (dateString.contains(' ')) {
      dateString = dateString.split(' ')[0];
    }

    Map<String, dynamic> activities = {};
    if (body['activities'] is Map<String, dynamic>) {
      activities = Map<String, dynamic>.from(body['activities']);
    } else if (body['activities'] is Map) {
      activities = Map<String, dynamic>.from(body['activities'] as Map);
    }

    String workStarted = (body['work_started'] ?? body['workStarted'] ?? '').toString();
    String workCompleted = (body['work_completed'] ?? body['workCompleted'] ?? '').toString();
    String description = (body['description'] ?? '').toString();
    String category = (body['category'] ?? '').toString();
    String lower = '$workStarted $description $category'.toLowerCase();

    if (lower.contains('wake-up') || lower.contains('wakeup') || lower.contains('wake up') || lower.contains('morning')) {
      String t = workCompleted;
      if (t.isEmpty) {
        final match = RegExp(r'wake-up:\s*([^)]+)', caseSensitive: false).firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['wakeUpTime'] = t.isNotEmpty ? t : '05:30 AM';
    } else if (lower.contains('sleep')) {
      String t = workCompleted;
      if (t.isEmpty) {
        final match = RegExp(r'time:\s*([^)]+)', caseSensitive: false).firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['sleepTime'] = t.isNotEmpty ? t : '10:00 PM';
    } else if (lower.contains('mangla')) {
      String t = workCompleted;
      if (t.isEmpty) {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['manglaArti'] = {'attended': true, 'time': t.isNotEmpty ? t : '04:30 AM'};
    } else if (lower.contains('chanting')) {
      RegExp reg = RegExp(r'(\d+)\s*round');
      Match? match = reg.firstMatch(lower);
      int rounds = match != null ? int.parse(match.group(1)!) : 16;
      activities['chanting'] = {'rounds': rounds};
    } else if (lower.contains('online')) {
      String t = workCompleted;
      if (t.isEmpty || t.toLowerCase() == 'attended') {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['onlineSession'] = {'attended': true, if (t.isNotEmpty && t.toLowerCase() != 'attended') 'timeSpan': t};
    } else if (lower.contains('book') || lower.contains('reading')) {
      String bookName = workStarted.replaceFirst(RegExp(r'^Book Reading\s*-\s*', caseSensitive: false), '').trim();
      if (bookName.isEmpty) bookName = 'Bhagavad Gita';
      activities['bookReading'] = {'bookName': bookName, 'pagesOrMinutes': workCompleted.isNotEmpty ? workCompleted : '30 mins'};
    } else if (lower.contains('service')) {
      String serviceName = workStarted.replaceFirst(RegExp(r'^Service\s*-\s*', caseSensitive: false), '').trim();
      if (serviceName.isEmpty) serviceName = 'Temple Service';
      activities['service'] = {'serviceName': serviceName, 'durationMinutes': 30};
    } else if (lower.contains('temple')) {
      activities['templeVisit'] = {'visited': true};
    } else if (lower.contains('bhagavatam')) {
      String t = workCompleted;
      if (t.isEmpty || t.toLowerCase() == 'attended') {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['srimadBhagavatamClass'] = {'attended': true, if (t.isNotEmpty && t.toLowerCase() != 'attended') 'timeSpan': t};
    } else if (lower.contains('gita')) {
      String t = workCompleted;
      if (t.isEmpty || t.toLowerCase() == 'attended') {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(workStarted);
        if (match != null) t = match.group(1)!.trim();
      }
      activities['bhagavadGitaClass'] = {'attended': true, if (t.isNotEmpty && t.toLowerCase() != 'attended') 'timeSpan': t};
    } else if (lower.contains('ekadashi')) {
      String f = workCompleted;
      if (f.isEmpty || f.toLowerCase() == 'fasting') {
        if (workStarted.contains(':')) {
          f = workStarted.split(':')[1].trim();
        } else {
          final match = RegExp(r'\(([^)]+)\)').firstMatch(workStarted);
          if (match != null) f = match.group(1)!.trim();
        }
      }
      activities['ekadashiFasting'] = {'fastingType': f.isNotEmpty ? f : 'Fasting'};
    }

    final cleanMap = <String, dynamic>{
      'dateString': dateString,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };

    if (activities.isNotEmpty) {
      cleanMap['activities'] = activities;
    }

    return cleanMap;
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body, {String? idempotencyKey}) async {
    final headers = await _getHeaders();
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
    }

    String targetEndpoint = endpoint;
    Map<String, dynamic> targetBody;

    if (endpoint == '/sadhana' && (body['category'] == null || body['category'] == 'folk_sadhna')) {
      targetEndpoint = '/sadhana';
      targetBody = _buildCleanSadhanaDto(body);
    } else {
      targetEndpoint = endpoint;
      targetBody = Map<String, dynamic>.from(body);
    }

    final response = await http.post(
      Uri.parse('$baseUrl$targetEndpoint'),
      headers: headers,
      body: jsonEncode(targetBody),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _processResponse(response);
    }

    if (response.statusCode == 404 && targetEndpoint != '/sadhana') {
      final fbResponse = await http.post(
        Uri.parse('$baseUrl/sadhana'),
        headers: headers,
        body: jsonEncode(_buildCleanSadhanaDto(body)),
      );
      if (fbResponse.statusCode >= 200 && fbResponse.statusCode < 300) {
        return _processResponse(fbResponse);
      }
    }

    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = '$baseUrl$endpoint';
    debugPrint('📌 [PATCH REQUEST URL]: $url');
    debugPrint('📌 [PATCH REQUEST BODY]: ${jsonEncode(body)}');
    final response = await http.patch(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
    debugPrint('📌 [PATCH RESPONSE STATUS]: ${response.statusCode}');
    debugPrint('📌 [PATCH RESPONSE BODY]: ${response.body}');
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 404) {
      final id = endpoint.split('/').last;
      return {'success': true, 'id': id};
    }
    return _processResponse(response);
  }

  static dynamic _processResponse(http.Response response) {
    debugPrint('API [${response.statusCode}] -> ${response.request?.url}');
    if (response.statusCode >= 400) {
      debugPrint('🚨 [API ERROR LOG] Status: ${response.statusCode} | URL: ${response.request?.url}');
      debugPrint('🚨 [API ERROR RESPONSE BODY]: ${response.body}');
    }
    
    final bodyStr = response.body;
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(bodyStr);
    } catch (_) {
      jsonBody = bodyStr;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (jsonBody is Map && jsonBody.containsKey('data')) {
        return jsonBody['data'];
      }
      if (jsonBody is Map && jsonBody.containsKey('items')) {
        return jsonBody['items'];
      }
      return jsonBody;
    }

    if (response.statusCode == 401) {
      clearTokenCache();
      FirebaseAuth.instance.signOut().catchError((_) {});
    }

    final message = jsonBody is Map ? (jsonBody['message'] ?? 'API Request Failed') : 'HTTP ${response.statusCode} Error';
    throw ApiException(response.statusCode, message.toString(), jsonBody);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic errorDetails;

  ApiException(this.statusCode, this.message, [this.errorDetails]);

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}
