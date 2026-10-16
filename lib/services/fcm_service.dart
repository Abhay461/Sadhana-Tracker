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

  // Android notification channel definition
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sadhana_tracker_notifications', // must match AndroidManifest meta-data
    'Sadhana Tracker Notifications',
    description: 'Notifications for accommodation, appointment, and sadhana updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[FCM] Service already initialized — skipping duplicate initialization');
      return;
    }
    _isInitialized = true;

    try {
      // 0. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Create Android notification channel
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

  /// Set up flutter_local_notifications and create the Android channel.
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

    await _localNotifications.initialize(initSettings);

    // Create the notification channel on Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
      debugPrint('[FCM] Android notification channel created: ${_channel.id}');
    }
  }

  /// Formats accommodation request body to clean student name, arrival date, and departure date.
  static String formatAccommodationBody({
    required String? studentName,
    required String? arrivalDate,
    required String? departureDate,
    String? rawBody,
  }) {
    if (studentName != null &&
        studentName.isNotEmpty &&
        arrivalDate != null &&
        arrivalDate.isNotEmpty &&
        departureDate != null &&
        departureDate.isNotEmpty) {
      return 'Student: $studentName\nArrival: $arrivalDate • Departure: $departureDate';
    }

    if (rawBody != null && rawBody.isNotEmpty) {
      final arrMatch = RegExp(r'Arrival:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(rawBody);
      final depMatch = RegExp(r'Departure:\s*([^\n\r•]+)', caseSensitive: false).firstMatch(rawBody);
      if (arrMatch != null && depMatch != null) {
        final sMatch = RegExp(r'^(?:Student:\s*)?([^\n\r•]+?)(?:\s+requested|\n|$)', caseSensitive: false).firstMatch(rawBody);
        final name = studentName ?? sMatch?.group(1)?.trim() ?? 'Student';
        return 'Student: $name\nArrival: ${arrMatch.group(1)!.trim()} • Departure: ${depMatch.group(1)!.trim()}';
      }
      return rawBody;
    }

    return 'Student: ${studentName ?? "Student"}\nNew accommodation booking requested';
  }

  /// Show a visible notification when FCM message arrives in foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: title="${message.notification?.title}", body="${message.notification?.body}", data=${message.data}');

    String title = message.notification?.title ?? message.data['title']?.toString() ?? 'Sadhana Tracker';
    String? body = message.notification?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString();

    final category = message.data['category']?.toString();
    final isAccommodation = category == 'accommodation' ||
        title.toLowerCase().contains('accommodation') ||
        (body != null && body.toLowerCase().contains('accommodation'));

    if (isAccommodation &&
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

    showLocalNotification(
      title: title,
      body: body,
      payload: message.data['category']?.toString(),
    );
  }

  /// Show a visible notification anytime (FCM foreground or WebSocket realtime update).
  /// Automatically deduplicates identical messages within 10 seconds to avoid multi-popups.
  static void showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Purge entries older than 10 seconds
    _recentNotificationDedupe.removeWhere((_, time) => now - time > 10000);

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    final dedupeKey = '${cleanTitle}_$cleanBody';

    if (_recentNotificationDedupe.containsKey(dedupeKey)) {
      debugPrint('[FCM] Suppressed duplicate notification within 10s: "$cleanTitle" - "$cleanBody"');
      return;
    }
    _recentNotificationDedupe[dedupeKey] = now;

    // Use remainder to guarantee 32-bit int compatibility on Android
    final notifId = id ?? (now ~/ 1000).remainder(100000);

    // BigTextStyleInformation for expandable notifications on Android
    final bigTextStyleInformation = BigTextStyleInformation(
      cleanBody,
      contentTitle: cleanTitle,
      summaryText: 'Sadhana Tracker',
      htmlFormatContent: false,
      htmlFormatContentTitle: false,
    );

    _localNotifications.show(
      notifId,
      cleanTitle,
      cleanBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFF3F51B5),
          styleInformation: bigTextStyleInformation,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
    debugPrint('[FCM] Local heads-up notification displayed (id=$notifId): "$cleanTitle" - "$cleanBody"');
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
