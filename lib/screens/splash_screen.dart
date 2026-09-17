import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../utils/notification_helper.dart';
import '../utils/user_session.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isTakingLong = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _longTimer;

  @override
  void initState() {
    super.initState();
    _startLongTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRedirect();
    });
  }

  void _startLongTimer() {
    _longTimer?.cancel();
    _longTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_hasError) {
        setState(() {
          _isTakingLong = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _longTimer?.cancel();
    super.dispose();
  }

  void _navigateToRole(String role, Map<String, dynamic>? profileData) {
    if (!mounted) return;
    final cleanRole = role.toLowerCase().replaceAll('pending_', '');
    if (cleanRole == 'preacher' || cleanRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/preacher', arguments: profileData);
    } else {
      Navigator.pushReplacementNamed(context, '/folk-boy', arguments: profileData);
    }
  }

  Future<void> _checkAuthAndRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ApiService.clearTokenCache();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (_hasError) {
      setState(() {
        _hasError = false;
        _isTakingLong = false;
        _errorMessage = '';
      });
      _startLongTimer();
    }

    // Register user with notification helper asynchronously
    NotificationHelper.loginUser(user.uid).catchError((_) {});
    FcmService.initialize().catchError((_) {});

    try {
      // 1. Fast attempt to fetch fresh profile from NestJS API (5 seconds max)
      final response = await ApiService.get('/users/me').timeout(const Duration(seconds: 5));
      if (response is Map) {
        final profileData = Map<String, dynamic>.from(response);
        final rawRole = (profileData['role'] ?? '').toString().toLowerCase();

        if (rawRole.isNotEmpty) {
          // Save session reliably for this UID
          await UserSession.saveSession(
            uid: user.uid,
            role: rawRole,
            profileData: profileData,
          );

          debugPrint('[SPLASH NAV] Successfully retrieved profile for UID ${user.uid} with Role: $rawRole');
          _navigateToRole(rawRole, profileData);
          return;
        }
      }

      throw Exception('Invalid profile payload returned from /users/me');
    } catch (e) {
      final String errStr = e.toString();
      debugPrint('[SPLASH API FAIL] /users/me failed: $errStr');

      // 2. Safe Fallback: Check if we have a verified cached role strictly belonging to this UID
      final cachedSession = await UserSession.getSession(user.uid);
      final cachedRole = cachedSession?['role']?.toString();
      final cachedProfile = cachedSession?['profile'] as Map<String, dynamic>?;

      if (cachedRole != null && cachedRole.isNotEmpty) {
        debugPrint(
            '[SPLASH NAV FALLBACK] /users/me failed ($errStr). Using verified cached role "$cachedRole" for UID ${user.uid}.');
        _navigateToRole(cachedRole, cachedProfile);
        return;
      }

      // 3. No reliable role available -> DO NOT DEFAULT TO folk_boy OR GUESS ROLE. Stays on Error/Retry screen.
      debugPrint(
          '[SPLASH NAV BLOCKED] /users/me failed ($errStr). No reliable cached role found for UID ${user.uid}. Displaying connection error screen.');

      if (mounted) {
        setState(() {
          _hasError = true;
          _isTakingLong = false;
          _errorMessage =
              'Server connectivity issue or slow start.\nCould not verify user account role.';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/logo.jpg',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.temple_hindu, color: Colors.amber, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_hasError) ...[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                  ),
                ),
                if (_isTakingLong) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Server start ho raha hai, kripya thoda wait karein...\n(Free Render server sleep se wake ho raha hai)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ] else ...[
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkAuthAndRedirect,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _handleLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
