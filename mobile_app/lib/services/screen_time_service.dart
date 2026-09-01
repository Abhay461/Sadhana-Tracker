import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class ScreenTimeService {
  static const MethodChannel _screenTimeChannel = MethodChannel(
    'com.example.mobile_app/screen_time',
  );

  /// Checks if the app has usage stats permission on Android.
  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool hasPermission = await _screenTimeChannel.invokeMethod(
        'checkPermission',
      );
      return hasPermission;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Requests the usage stats permission on Android.
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool success = await _screenTimeChannel.invokeMethod(
        'requestPermission',
      );
      return success;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Fetches screen time data from native side.
  /// Returns a Map with keys: totalMs, totalLabel, apps, method, debug
  static Future<Map<String, dynamic>?> getScreenTime() async {
    if (!Platform.isAndroid) return null;
    try {
      final dynamic rawResult = await _screenTimeChannel.invokeMethod(
        'getScreenTime',
      );
      if (rawResult is Map) {
        return Map<String, dynamic>.from(rawResult);
      }
      return null;
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  /// Cleans the application package name to get a user-friendly name.
  static String cleanAppName(String packageName) {
    final Map<String, String> commonApps = {
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.facebook.orca': 'Messenger',
      'com.google.android.youtube': 'YouTube',
      'com.android.chrome': 'Chrome',
      'org.telegram.messenger': 'Telegram',
      'com.microsoft.teams': 'Teams',
      'com.zoom.videomeetings': 'Zoom',
      'com.netflix.mediaclient': 'Netflix',
      'com.amazon.mp3': 'Amazon Music',
      'com.google.android.apps.maps': 'Google Maps',
      'com.google.android.googlequicksearchbox': 'Google Search',
      'com.google.android.apps.photos': 'Google Photos',
      'com.google.android.gm': 'Gmail',
    };

    if (commonApps.containsKey(packageName)) {
      return commonApps[packageName]!;
    }

    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final last = parts.last;
      if (last.toLowerCase() == 'android' && parts.length > 1) {
        final secondLast = parts[parts.length - 2];
        return secondLast[0].toUpperCase() + secondLast.substring(1);
      }
      if (last.length > 1) {
        return last[0].toUpperCase() + last.substring(1);
      }
      return last.toUpperCase();
    }
    return packageName;
  }
}
