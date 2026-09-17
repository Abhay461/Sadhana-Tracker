import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages reliable local caching of authenticated user sessions (role + profile)
/// mapped strictly to their Firebase UID.
class UserSession {
  static Map<String, dynamic>? _memProfile;
  static String? _memUid;
  static String? _memRole;

  static String? get cachedRole => _memRole;
  static Map<String, dynamic>? get cachedProfile => _memProfile;
  static String? get cachedUid => _memUid;

  static Future<File> _getSessionFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/user_session_v1.json');
  }

  /// Persists verified user profile and role associated with [uid].
  static Future<void> saveSession({
    required String uid,
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    if (uid.isEmpty) return;
    _memUid = uid;
    _memRole = role.toLowerCase().trim();
    _memProfile = profileData;

    try {
      final file = await _getSessionFile();
      final data = {
        'uid': uid,
        'role': _memRole,
        'profile': profileData,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
      debugPrint('🔑 [UserSession] Saved session for UID: $uid | Role: $_memRole');
    } catch (e) {
      debugPrint('⚠️ [UserSession] Save error: $e');
    }
  }

  /// Retrieves cached session for [currentUid] if reliably stored.
  /// Returns null if no session exists or if the stored session belongs to a different UID.
  static Future<Map<String, dynamic>?> getSession(String currentUid) async {
    if (currentUid.isEmpty) return null;

    if (_memUid == currentUid && _memRole != null && _memRole!.isNotEmpty) {
      return {
        'role': _memRole,
        'profile': _memProfile,
      };
    }

    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final storedUid = data['uid'] as String?;
        final storedRole = data['role'] as String?;
        final storedProfile = data['profile'] as Map<String, dynamic>?;

        if (storedUid == currentUid && storedRole != null && storedRole.isNotEmpty) {
          _memUid = storedUid;
          _memRole = storedRole.toLowerCase().trim();
          _memProfile = storedProfile;
          debugPrint('🔑 [UserSession] Restored disk session for UID: $currentUid | Role: $_memRole');
          return {
            'role': _memRole,
            'profile': storedProfile,
          };
        } else if (storedUid != currentUid) {
          debugPrint('⚠️ [UserSession] Stored session UID ($storedUid) does not match current UID ($currentUid). Ignoring.');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [UserSession] Read error: $e');
    }

    return null;
  }

  /// Clears stored user session upon logout.
  static Future<void> clearSession() async {
    _memUid = null;
    _memRole = null;
    _memProfile = null;

    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        await file.delete();
        debugPrint('🔑 [UserSession] Cleared stored session file.');
      }
    } catch (e) {
      debugPrint('⚠️ [UserSession] Clear error: $e');
    }
  }
}
