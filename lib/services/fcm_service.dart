import 'dart:io';
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

  static Future<void> initialize() async {
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
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted notification permission');
        await registerTokenWithBackend();
      } else {
        debugPrint('[FCM] User declined notification permission');
      }

      // 3. Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed → re-registering');
        await registerTokenWithBackend(overrideToken: newToken);
      });

      // 4. Foreground Message Handler → show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      debugPrint('[FCM] Service initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Set up flutter_local_notifications and create the Android channel.
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);

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

  /// Show a visible notification when FCM message arrives in foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: title="${message.notification?.title}", body="${message.notification?.body}", data=${message.data}');

    final notification = message.notification;
    if (notification == null) {
      debugPrint('[FCM] Data-only message (no notification payload) — skipping display');
      return;
    }

    // Show the notification as a visible Android notification
    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Sadhana Tracker',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
    );
    debugPrint('[FCM] Foreground notification displayed: "${notification.title}"');
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

  static Future<void> revokeTokenOnLogout(String fcmToken) async {
    try {
      await ApiService.delete('/notifications/device-token', body: {
        'fcmToken': fcmToken,
      });
      debugPrint('[FCM] Token revoked on backend');
    } catch (e) {
      debugPrint('[FCM] Token revocation FAILED: $e');
    }
  }
}
