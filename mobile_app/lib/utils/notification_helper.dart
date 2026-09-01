import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/api_service.dart';
import 'constants.dart';

class NotificationHelper {
  static String? _cachedAppId;

  /// Fetches OneSignal keys from Constants.
  static Future<Map<String, String>> _getKeys() async {
    if (_cachedAppId != null) {
      return {
        'appId': _cachedAppId!,
      };
    }

    String appId = Constants.oneSignalAppId;

    _cachedAppId = appId;

    return {
      'appId': appId,
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
      await OneSignal.Notifications.requestPermission(true).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('NotificationHelper: OneSignal permission request timed out (normal on emulators).');
          return false;
        },
      );
      debugPrint('NotificationHelper: OneSignal initialized successfully.');
    } catch (e) {
      debugPrint('NotificationHelper: Failed to initialize OneSignal: $e');
    }
  }

  /// Log in current user to OneSignal using their User ID.
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
    String? sendAfter,
  }) async {
    if (targetUserIds.isEmpty) return;

    try {
      final keys = await _getKeys();
      final appId = keys['appId']!;
      if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID') {
        debugPrint('NotificationHelper: OneSignal is not configured.');
        return;
      }

      if (sendAfter != null) {
        debugPrint('NotificationHelper: scheduled notifications must be created by a server-side scheduler.');
        return;
      }

      await ApiService.post('/notifications/send', {
        'targetUserIds': targetUserIds,
        'title': title,
        'body': body,
      });
      debugPrint('NotificationHelper: push notification requested for ${targetUserIds.length} users.');
    } catch (e) {
      debugPrint('NotificationHelper: Error sending push notification: $e');
    }
  }

  /// Automatically notifies a student's preacher when they log any activity.
  static Future<void> sendUpdateNotification(Map<String, dynamic> update) async {
    final String studentName = update['worker_name'] ?? 'A student';
    final String category = update['category'] ?? '';
    final String description = update['description'] ?? update['work_started'] ?? '';
    
    String? preacherId = (update['preacher_id'] ?? update['preacherId'])?.toString();
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

  /// Sends a notification to all active disciples when a new online session is created.
  static Future<void> sendNewSessionNotification({
    required List<String> targetUserIds,
    required String preacherName,
    required String sessionTitle,
    required String date,
    required String time,
  }) async {
    await sendNotification(
      targetUserIds: targetUserIds,
      title: 'New Session Scheduled',
      body: 'Preacher $preacherName has scheduled a new session: "$sessionTitle" on $date at $time.',
    );
  }

  /// Schedules a reminder notification to be sent 2 minutes before the session starts.
  static Future<void> sendScheduledSessionReminder({
    required List<String> targetUserIds,
    required String sessionTitle,
    required DateTime sessionDateTime,
  }) async {
    final reminderTime = sessionDateTime.subtract(const Duration(minutes: 2));
    if (reminderTime.isBefore(DateTime.now())) {
      // If the session starts in less than 2 minutes, don't schedule a reminder
      return;
    }

    // Convert to UTC ISO-8601 string as expected by OneSignal
    final sendAfterStr = reminderTime.toUtc().toIso8601String();

    await sendNotification(
      targetUserIds: targetUserIds,
      title: 'Session Starting Soon',
      body: 'The session "$sessionTitle" is starting in 2 minutes. Get ready to join!',
      sendAfter: sendAfterStr,
    );
  }
}
