import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Top-level background message handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.notification?.title ?? message.data.toString()}');
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android notification channel definitions:
  // 1. _channel: Plays sound and shows heads-up notification banner
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sadhana_tracker_notifications', // must match AndroidManifest meta-data
    'Sadhana Tracker Notifications',
    description: 'Notifications for accommodation, appointment, and sadhana updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // 2. _trayChannel: Preserves notification in drop-down tray silently without intrusive screen popup
  static const AndroidNotificationChannel _trayChannel = AndroidNotificationChannel(
    'sadhana_tracker_tray',
    'Sadhana Tracker Tray Notifications',
    description: 'Notifications displayed silently in the notification shade without popping up',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
    showBadge: true,
  );

  static bool _isInitialized = false;

  /// IDs of notifications already clicked by the user
  static final Set<int> _tappedNotificationIds = {};

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[FCM] Service already initialized — skipping duplicate initialization');
      return;
    }
    _isInitialized = true;

    try {
      // 0. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Create Android notification channels
      await _setupLocalNotifications();

      // 2. Request Notification Permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] User granted notification permission');
        await registerTokenWithBackend();
      } else {
        debugPrint('[FCM] Notification permission status: ${settings.authorizationStatus}');
        // On Android, attempt registration regardless so the device is registered
        if (!kIsWeb && Platform.isAndroid) {
          await registerTokenWithBackend();
        }
      }

      // 3. Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed → re-registering');
        await registerTokenWithBackend(overrideToken: newToken);
      });

      // 4. Foreground Message Handler → show local notification with BigTextStyle
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Notification tap handler when app is running in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened app from background: title="${message.notification?.title}", data=${message.data}');
      });

      // 6. Check if app was launched from a terminated state notification
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('[FCM] App launched from terminated state notification: title="${message.notification?.title}", data=${message.data}');
        }
      });

      debugPrint('[FCM] Service initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Deduplication cache: key -> timestamp (milliseconds). Prevents duplicate heads-up notifications.
  static final Map<String, int> _recentNotificationDedupe = {};

  /// Set up flutter_local_notifications and create the Android channels.
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.id != null) {
          _tappedNotificationIds.add(details.id!);
        }
        debugPrint('[FCM] Notification tapped: id=${details.id}, payload=${details.payload}');
      },
    );

    // Create the notification channels on Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
      await androidPlugin.createNotificationChannel(_trayChannel);
      debugPrint('[FCM] Android notification channels created: ${_channel.id}, ${_trayChannel.id}');
    }
  }

  /// Formats YYYY-MM-DD or standard dates to readable format (e.g. 17 Oct 2026).
  static String formatDateReadable(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    final trimmed = dateStr.trim();
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(trimmed);
    if (match != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final year = match.group(1);
      final monthIdx = int.parse(match.group(2)!) - 1;
      final day = int.parse(match.group(3)!);
      if (monthIdx >= 0 && monthIdx < 12) {
        return '$day ${months[monthIdx]} $year';
      }
    }
    return trimmed;
  }

  /// Formats appointment notification body cleanly according to specification:
  /// Line 1: "[Student Name] booked an appointment."
  /// Line 2: "Date: [Date] • Time: [Time]"
  /// Strictly removes any preacher name mentions.
  static String formatAppointmentBody({
    required String? studentName,
    required String? date,
    required String? time,
    String? rawBody,
  }) {
    String sName = (studentName != null && studentName.trim().isNotEmpty) ? studentName.trim() : '';
    String finalDate = date?.trim() ?? '';
    String finalTime = time?.trim() ?? '';

    if (rawBody != null && rawBody.isNotEmpty) {
      // Remove any "Preacher: ..." text
      final sanitized = rawBody.replaceAll(RegExp(r'Preacher:\s*([^\n\r•]+)[•\n\r]*', caseSensitive: false), '').trim();
      
      if (sName.isEmpty) {
        final sMatch = RegExp(r'^(?:Student:\s*)?([^\n\r•]+?)(?:\s+booked|\s+requested|\n|$)', caseSensitive: false).firstMatch(sanitized);
        if (sMatch != null) sName = sMatch.group(1)!.trim();
      }
      if (finalDate.isEmpty) {
        final dateMatch = RegExp(r'Date:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(sanitized);
        if (dateMatch != null) finalDate = dateMatch.group(1)!.trim();
      }
      if (finalTime.isEmpty) {
        final timeMatch = RegExp(r'Time:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(sanitized);
        if (timeMatch != null) finalTime = timeMatch.group(1)!.trim();
      }
      if (finalDate.isEmpty || finalTime.isEmpty) {
        final atMatch = RegExp(r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}\s+[A-Za-z]+\s+\d{4})\s*@\s*([0-9:APMapm\s]+)').firstMatch(sanitized);
        if (atMatch != null) {
          if (finalDate.isEmpty) finalDate = atMatch.group(1)!.trim();
          if (finalTime.isEmpty) finalTime = atMatch.group(2)!.trim();
        }
      }
    }

    if (sName.isEmpty) sName = 'Student';
    final formattedDate = formatDateReadable(finalDate);
    final formattedTime = finalTime.isNotEmpty ? finalTime : '10:00 AM';

    if (formattedDate.isNotEmpty) {
      return '$sName booked an appointment.\nDate: $formattedDate • Time: $formattedTime';
    }
    return '$sName booked an appointment.';
  }

  /// Formats accommodation request body to clean student name, arrival date, and departure date.
  static String formatAccommodationBody({
    required String? studentName,
    required String? arrivalDate,
    required String? departureDate,
    String? rawBody,
  }) {
    String sName = (studentName != null && studentName.trim().isNotEmpty) ? studentName.trim() : '';
    String arr = arrivalDate?.trim() ?? '';
    String dep = departureDate?.trim() ?? '';

    if (rawBody != null && rawBody.isNotEmpty) {
      if (sName.isEmpty) {
        final sMatch = RegExp(r'^(?:Student:\s*)?([^\n\r•]+?)(?:\s+requested|\n|$)', caseSensitive: false).firstMatch(rawBody);
        if (sMatch != null) sName = sMatch.group(1)!.trim();
      }
      if (arr.isEmpty) {
        final arrMatch = RegExp(r'Arrival:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(rawBody);
        if (arrMatch != null) arr = arrMatch.group(1)!.trim();
      }
      if (dep.isEmpty) {
        final depMatch = RegExp(r'Departure:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(rawBody);
        if (depMatch != null) dep = depMatch.group(1)!.trim();
      }
    }

    if (sName.isEmpty) sName = 'Student';
    final formattedArrival = formatDateReadable(arr);
    final formattedDeparture = formatDateReadable(dep);

    if (formattedArrival.isNotEmpty && formattedDeparture.isNotEmpty) {
      return 'Student: $sName\nArrival: $formattedArrival • Departure: $formattedDeparture';
    }
    return 'Student: $sName\nNew accommodation request';
  }

  /// Resolves a stable event key from message metadata, payload ID, or stable event ID.
  static String resolveEventKey({
    String? messageId,
    Map<String, dynamic>? data,
    String? title,
    String? body,
  }) {
    if (data != null) {
      final apptId = data['appointmentId']?.toString();
      if (apptId != null && apptId.isNotEmpty) {
        return 'appointment_$apptId';
      }
      final accId = data['accommodationId']?.toString();
      if (accId != null && accId.isNotEmpty) {
        return 'accommodation_$accId';
      }
      final entityId = data['id']?.toString() ?? data['_id']?.toString() ?? data['eventId']?.toString();
      if (entityId != null && entityId.isNotEmpty) {
        return 'entity_$entityId';
      }
    }
    if (messageId != null && messageId.isNotEmpty) {
      return 'fcm_$messageId';
    }
    return '${title?.trim() ?? ""}_${body?.trim() ?? ""}';
  }

  /// Show a visible notification when FCM message arrives in foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: title="${message.notification?.title}", body="${message.notification?.body}", data=${message.data}');

    String title = message.notification?.title ?? message.data['title']?.toString() ?? 'Sadhana Tracker';
    String? body = message.notification?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString();

    final category = message.data['category']?.toString();
    final isAppointment = category == 'preacher_appointment' ||
        category == 'appointment' ||
        title.toLowerCase().contains('appointment') ||
        (body != null && body.toLowerCase().contains('appointment'));

    final isAccommodation = category == 'accommodation' ||
        title.toLowerCase().contains('accommodation') ||
        (body != null && body.toLowerCase().contains('accommodation'));

    if (isAppointment &&
        !title.toLowerCase().contains('approved') &&
        !title.toLowerCase().contains('rejected')) {
      title = 'New Appointment';
      body = formatAppointmentBody(
        studentName: message.data['studentName']?.toString() ??
            message.data['student_name']?.toString() ??
            message.data['worker_name']?.toString(),
        date: message.data['date']?.toString() ?? message.data['preferredDate']?.toString(),
        time: message.data['time']?.toString() ?? message.data['preferredTime']?.toString(),
        rawBody: body,
      );
    } else if (isAccommodation &&
        !title.toLowerCase().contains('approved') &&
        !title.toLowerCase().contains('rejected')) {
      title = 'New Accommodation Request';
      body = formatAccommodationBody(
        studentName: message.data['studentName']?.toString(),
        arrivalDate: message.data['arrivalDate']?.toString(),
        departureDate: message.data['departureDate']?.toString(),
        rawBody: body,
      );
    }

    if (body == null || body.trim().isEmpty) {
      debugPrint('[FCM] Message has no body or displayable text — skipping display');
      return;
    }

    final eventKey = resolveEventKey(
      messageId: message.messageId,
      data: message.data,
      title: title,
      body: body,
    );

    showLocalNotification(
      title: title,
      body: body,
      eventKey: eventKey,
      payload: message.data['category']?.toString(),
    );
  }

  /// Show a visible notification anytime (FCM foreground or WebSocket realtime update).
  /// Automatically deduplicates using stable event ID (e.g. appointmentId, accommodationId)
  /// within 60 seconds to avoid multi-popups while allowing distinct events.
  static void showLocalNotification({
    required String title,
    required String body,
    String? eventKey,
    String? payload,
    int? id,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Purge entries older than 60 seconds
    _recentNotificationDedupe.removeWhere((_, time) => now - time > 60000);

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    final dedupeKey = (eventKey != null && eventKey.isNotEmpty)
        ? eventKey
        : '${cleanTitle}_$cleanBody';

    if (_recentNotificationDedupe.containsKey(dedupeKey)) {
      debugPrint('[FCM] Suppressed duplicate notification for event key: "$dedupeKey"');
      return;
    }
    _recentNotificationDedupe[dedupeKey] = now;

    // Use stable ID derived from eventKey if available, otherwise timestamp
    final notifId = id ?? (eventKey != null ? eventKey.hashCode.abs().remainder(100000) : (now ~/ 1000).remainder(100000));

    // BigTextStyleInformation without summaryText to prevent duplicate app name in header
    final bigTextStyleInformation = BigTextStyleInformation(
      cleanBody,
      contentTitle: cleanTitle,
      htmlFormatContent: false,
      htmlFormatContentTitle: false,
    );

    // 1. Show initial heads-up banner with sound & vibration
    _localNotifications.show(
      notifId,
      cleanTitle,
      cleanBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFF3F51B5),
          styleInformation: bigTextStyleInformation,
          playSound: true,
          enableVibration: true,
          tag: eventKey,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
    debugPrint('[FCM] Local heads-up notification displayed (id=$notifId, tag=$eventKey): "$cleanTitle" - "$cleanBody"');

    // 2. Auto-dismiss heads-up banner from screen after 2.2 seconds:
    // Dismisses the intrusive floating banner from the user's screen,
    // while seamlessly preserving the notification in the Android drop-down tray.
    Future.delayed(const Duration(milliseconds: 2200), () async {
      try {
        if (_tappedNotificationIds.contains(notifId)) {
          // User already interacted with notification
          return;
        }

        // Remove the floating banner from the screen
        await _localNotifications.cancel(notifId, tag: eventKey);

        // Immediately re-post silently in the notification shade/tray
        await _localNotifications.show(
          notifId,
          cleanTitle,
          cleanBody,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _trayChannel.id,
              _trayChannel.name,
              channelDescription: _trayChannel.description,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/launcher_icon',
              color: const Color(0xFF3F51B5),
              styleInformation: bigTextStyleInformation,
              playSound: false,
              enableVibration: false,
              onlyAlertOnce: true,
              tag: eventKey,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: true,
              presentSound: false,
            ),
          ),
          payload: payload,
        );
        debugPrint('[FCM] Heads-up banner auto-dismissed from screen; preserved in tray (id=$notifId, tag=$eventKey)');
      } catch (e) {
        debugPrint('[FCM] Error auto-collapsing heads-up notification: $e');
      }
    });
  }

  static Future<void> registerTokenWithBackend({String? overrideToken}) async {
    try {
      final token = overrideToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token is null or empty — cannot register');
        return;
      }

      debugPrint('[FCM] Registering token with backend (token=${token.substring(0, 20)}...)');

      final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios');
      const appInstanceId = 'INST_APP_001'; // Can be populated via uuid package

      await ApiService.post('/notifications/device-token', {
        'fcmToken': token,
        'platform': platform,
        'appInstanceId': appInstanceId,
        'appVersion': '1.0.0',
      }).timeout(const Duration(seconds: 30));
      debugPrint('[FCM] Token registered successfully with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration FAILED: $e');
    }
  }

  static Future<void> revokeTokenOnLogout({String? token}) async {
    try {
      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[FCM] No token to revoke on logout');
        return;
      }
      await ApiService.delete('/notifications/device-token', body: {
        'fcmToken': fcmToken,
      });
      debugPrint('[FCM] Token revoked on backend');
    } catch (e) {
      debugPrint('[FCM] Token revocation FAILED: $e');
    }
  }
}
