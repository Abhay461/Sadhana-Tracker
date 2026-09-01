import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // 1. Request Notification Permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted notification permission');
        await registerTokenWithBackend();
      } else {
        debugPrint('FCM: User declined or ungranted notification permission');
      }

      // 2. Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token Refreshed');
        await registerTokenWithBackend(overrideToken: newToken);
      });

      // 3. Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground Message received: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('FCM Initialization error: $e');
    }
  }

  static Future<void> registerTokenWithBackend({String? overrideToken}) async {
    try {
      final token = overrideToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios');
      const appInstanceId = 'INST_APP_001'; // Can be populated via uuid package

      await ApiService.post('/notifications/device-token', {
        'fcmToken': token,
        'platform': platform,
        'appInstanceId': appInstanceId,
        'appVersion': '1.0.0',
      });
      debugPrint('FCM token successfully registered with NestJS backend');
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }

  static Future<void> revokeTokenOnLogout(String fcmToken) async {
    try {
      await ApiService.delete('/notifications/device-token', body: {
        'fcmToken': fcmToken,
      });
      debugPrint('FCM token revoked on backend');
    } catch (e) {
      debugPrint('Failed to revoke FCM token: $e');
    }
  }
}
