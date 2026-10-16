import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationHelper {
  /// Pure Firebase FCM handles all notifications.
  static Future<void> initialize() async {
    debugPrint('ℹ️ [NotificationHelper] Firebase FCM handles all push notifications.');
  }

  /// Optional stub kept for compatibility.
  static Future<void> loginUser(String userId) async {}

  /// Optional stub kept for compatibility.
  static Future<void> logoutUser() async {}

  /// Sends a push notification to specific users via the backend FCM service.
  /// The backend looks up FCM device tokens by userId and delivers via Firebase Admin.
  static Future<void> sendNotification({
    required List<String> targetUserIds,
    required String title,
    required String body,
    Map<String, String>? dataPayload,
    String? sendAfter,
  }) async {
    if (targetUserIds.isEmpty) return;

    if (sendAfter != null) {
      debugPrint('[FCM] Scheduled notifications must be created by a server-side scheduler.');
      return;
    }

    try {
      debugPrint('[FCM] Sending notification → targets: $targetUserIds, title: "$title"');
      final payload = <String, dynamic>{
        'targetUserIds': targetUserIds,
        'title': title,
        'body': body,
      };
      if (dataPayload != null && dataPayload.isNotEmpty) {
        payload['dataPayload'] = dataPayload;
      }
      final response = await ApiService.post('/notifications/send', payload);
      debugPrint('[FCM] Notification send SUCCESS → response: $response');
    } catch (e) {
      debugPrint('[FCM] Notification send FAILED → error: $e');
    }
  }


  /// Automatically notifies a student's preacher when they log any activity.
  static Future<void> sendUpdateNotification(Map<String, dynamic> update) async {
    final String studentName = update['worker_name'] ?? 'A student';
    final String category = update['category'] ?? '';
    final String description = update['description'] ?? update['work_started'] ?? '';
    
    String? preacherId = (update['preacher_id'] ?? update['preacherId'])?.toString();
    if (preacherId == null || preacherId.isEmpty) {
      debugPrint('[FCM] sendUpdateNotification: No preacherId found in update — skipping');
      return;
    }
    debugPrint('[FCM] sendUpdateNotification: category=$category, preacherId=$preacherId, student=$studentName');

    String title = 'New Student Activity';
    String body = '$studentName logged $category';
    Map<String, String>? dataPayload;

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
        title = 'New Accommodation Request';
        String arrival = '';
        String departure = '';
        final arrMatch = RegExp(r'Arrival:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(description);
        if (arrMatch != null) arrival = arrMatch.group(1)?.trim() ?? '';
        final depMatch = RegExp(r'Departure:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(description);
        if (depMatch != null) departure = depMatch.group(1)?.trim() ?? '';

        if (arrival.isNotEmpty && departure.isNotEmpty) {
          body = 'Student: $studentName\nArrival: $arrival • Departure: $departure';
        } else {
          final cleanAcc = description.replaceAll('\n', ' • ').trim();
          body = cleanAcc.isNotEmpty
              ? 'Student: $studentName\nDetails: $cleanAcc'
              : '$studentName requested accommodation';
        }
        dataPayload = {
          'category': 'accommodation',
          'studentName': studentName,
          'arrivalDate': arrival,
          'departureDate': departure,
        };
        break;
      case 'residency_admission':
        title = 'Residency Admission Request';
        body = '$studentName requested admission: $description';
        break;
      case 'preacher_appointment':
        title = 'Appointment Booked';
        final cleanAppt = description.replaceAll('\n', ' • ');
        body = '$studentName booked appointment: $cleanAppt';
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
      dataPayload: dataPayload,
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

    // Convert to UTC ISO-8601 string
    final sendAfterStr = reminderTime.toUtc().toIso8601String();

    await sendNotification(
      targetUserIds: targetUserIds,
      title: 'Session Starting Soon',
      body: 'The session "$sessionTitle" is starting in 2 minutes. Get ready to join!',
      sendAfter: sendAfterStr,
    );
  }
}
