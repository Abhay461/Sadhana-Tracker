import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class ApiService {
  static String get baseUrl => Constants.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    String? idToken;
    if (user != null) {
      idToken = await user.getIdToken();
    }

    final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes.toString();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Timezone-Offset': timezoneOffset,
      if (idToken != null) 'Authorization': 'Bearer $idToken',
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

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body, {String? idempotencyKey}) async {
    final headers = await _getHeaders();
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
    }
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  static dynamic _processResponse(http.Response response) {
    debugPrint('API [${response.statusCode}] -> ${response.request?.url}');
    
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
      return jsonBody;
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
