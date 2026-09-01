import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class NotificationHelper {
  static String? _cachedAppId;
  static String? _cachedRestApiKey;

  /// Fetches OneSignal keys either from Supabase `app_config` table or local Constants.
  static Future<Map<String, String>> _getKeys() async {
    if (_cachedAppId != null && _cachedRestApiKey != null) {
      return {
        'appId': _cachedAppId!,
        'restApiKey': _cachedRestApiKey!,
      };
    }

    String appId = Constants.oneSignalAppId;
    String restApiKey = Constants.oneSignalRestApiKey;

    try {
      final client = Supabase.instance.client;
      // Try to select keys from `app_config` table
      final List<dynamic> response = await client
          .from('app_config')
          .select('key, value');
      
      for (var row in response) {
        final key = row['key']?.toString();
        final value = row['value']?.toString();
        if (key == 'onesignal_app_id' && value != null && value.isNotEmpty) {
          appId = value;
        } else if (key == 'onesignal_rest_api_key' && value != null && value.isNotEmpty) {
          restApiKey = value;
        }
      }
    } catch (e) {
      debugPrint('NotificationHelper: app_config not found or inaccessible, using default Constants. Error: $e');
    }

    _cachedAppId = appId;
    _cachedRestApiKey = restApiKey;

    return {
      'appId': appId,
      'restApiKey': restApiKey,
    };
  }

  /// Initializes the OneSignal SDK.
  static Future<void> initialize() async {
    try {
      final keys = await _getKeys();
      final appId = keys['appId']!;
      
      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID') {
        debugPrint('NotificationHelper: OneSignal App ID is not configured.');
        return;
      }

      // Initialize OneSignal
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      OneSignal.initialize(appId);
      
      // Request permission
      await OneSignal.Notifications.requestPermission(true);
      debugPrint('NotificationHelper: OneSignal initialized successfully.');
    } catch (e) {
      debugPrint('NotificationHelper: Failed to initialize OneSignal: $e');
    }
  }

  /// Log in current user to OneSignal using their Supabase User ID.
  static Future<void> loginUser(String userId) async {
    try {
      final keys = await _getKeys();
      final appId = keys['appId']!;
      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID') return;

      await OneSignal.login(userId);
      debugPrint('NotificationHelper: Associated OneSignal user: $userId');
    } catch (e) {
      debugPrint('NotificationHelper: Error logging in user to OneSignal: $e');
    }
  }

  /// Log out current user from OneSignal.
  static Future<void> logoutUser() async {
    try {
      final keys = await _getKeys();
      final appId = keys['appId']!;
      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID') return;

      await OneSignal.logout();
      debugPrint('NotificationHelper: Disassociated user from OneSignal.');
    } catch (e) {
      debugPrint('NotificationHelper: Error logging out user from OneSignal: $e');
    }
  }

  /// Sends a push notification to specific users.
  static Future<void> sendNotification({
    required List<String> targetUserIds,
    required String title,
    required String body,
  }) async {
    if (targetUserIds.isEmpty) return;

    try {
      final keys = await _getKeys();
      final appId = keys['appId']!;
      final restApiKey = keys['restApiKey']!;

      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID' ||
          restApiKey.isEmpty || restApiKey == 'YOUR_ONESIGNAL_REST_API_KEY') {
        debugPrint('NotificationHelper: OneSignal is not fully configured for sending push notifications.');
        return;
      }

      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $restApiKey',
      };

      final payload = {
        'app_id': appId,
        'headings': {'en': title},
        'contents': {'en': body},
        // Target via external user ID using both legacy and modern formats for maximum compatibility
        'include_external_user_ids': targetUserIds,
        'include_aliases': {
          'external_id': targetUserIds,
        },
        'target_channel': 'push',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('NotificationHelper: Push notification sent successfully to ${targetUserIds.length} users.');
      } else {
        debugPrint('NotificationHelper: Failed to send push notification. Code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('NotificationHelper: Error sending push notification: $e');
    }
  }

  /// Automatically notifies a student's preacher when they log any activity.
  static Future<void> sendUpdateNotification(Map<String, dynamic> update) async {
    final String studentId = update['worker_id'] ?? '';
    final String studentName = update['worker_name'] ?? 'A student';
    final String category = update['category'] ?? '';
    final String description = update['description'] ?? update['work_started'] ?? '';
    
    String? preacherId;
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select('preacher_id').eq('id', studentId).maybeSingle();
      if (profile != null) {
        preacherId = profile['preacher_id']?.toString();
      }
    } catch (e) {
      debugPrint('NotificationHelper error finding preacher: $e');
    }

    if (preacherId == null || preacherId.isEmpty) return;

    String title = 'New Student Activity';
    String body = '$studentName logged $category';

    switch (category) {
      case 'residency_sadhna':
      case 'folk_sadhna':
      case 'sadhna':
        title = 'New Sadhana Log';
        body = '$studentName logged: $description';
        break;
      case 'screen_time':
        title = 'Screen Time Logged';
        body = '$studentName logged screen time: ${update['work_completed'] ?? ""}';
        break;
      case 'trip_attendance':
        title = 'Yatra Registration';
        body = '$studentName registered for: $description';
        break;
      case 'event_attendance':
        title = 'Event Registration';
        body = '$studentName registered for: $description';
        break;
      case 'session_attendance':
        title = 'Session Attendance';
        body = '$studentName joined session: $description';
        break;
      case 'payment':
        title = 'Payment Submitted';
        body = '$studentName submitted payment reminder: $description';
        break;
      case 'accommodation':
        title = 'Accommodation Request';
        body = '$studentName requested accommodation: $description';
        break;
      case 'residency_admission':
        title = 'Residency Admission Request';
        body = '$studentName requested admission: $description';
        break;
      case 'preacher_appointment':
        title = 'Appointment Booked';
        body = '$studentName booked appointment: $description';
        break;
      case 'service':
        title = 'Service Logged';
        body = '$studentName logged service: $description';
        break;
    }

    await sendNotification(
      targetUserIds: [preacherId],
      title: title,
      body: body,
    );
  }

  /// Sends a notification to a student when a preacher approves/rejects an activity.
  static Future<void> sendApprovalNotification({
    required String studentId,
    required String preacherName,
    required String category,
    required bool approved,
  }) async {
    final status = approved ? 'Approved' : 'Rejected';
    String title = '$category $status';
    String body = 'Your $category has been $status by $preacherName.';

    switch (category) {
      case 'payment':
        title = 'Payment $status';
        body = 'Your payment has been $status by $preacherName.';
        break;
      case 'accommodation':
        title = 'Accommodation $status';
        body = 'Your accommodation request has been $status by $preacherName.';
        break;
      case 'residency_admission':
        title = 'Residency Admission $status';
        body = 'Your residency admission has been $status by $preacherName.';
        break;
      case 'preacher_appointment':
        title = 'Appointment $status';
        body = 'Your appointment request has been $status by $preacherName.';
        break;
    }

    await sendNotification(
      targetUserIds: [studentId],
      title: title,
      body: body,
    );
  }

  /// Sends a notification to a student when their signup is approved by a preacher.
  static Future<void> sendSignupApprovalNotification({
    required String studentId,
    required String preacherName,
    required String newRole,
  }) async {
    final roleName = newRole == 'residency' ? 'Resident Student' : 'Folk Boy';
    await sendNotification(
      targetUserIds: [studentId],
      title: 'Account Approved!',
      body: 'Your account has been approved as a $roleName by $preacherName. You can now login.',
    );
  }
}
