import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../utils/notification_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isTakingLong = false;
  Timer? _longTimer;

  @override
  void initState() {
    super.initState();
    // Only show server warning if request takes more than 8 seconds
    _longTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _isTakingLong = true;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRedirect();
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

    // Register user with notification helper
    NotificationHelper.loginUser(user.uid).catchError((_) {});
    FcmService.initialize().catchError((_) {});

    try {
      final response = await ApiService.get('/users/me').timeout(const Duration(seconds: 30));
      final profileData = response is Map ? Map<String, dynamic>.from(response) : null;
      final rawRole = (profileData?['role'] ?? 'folk_boy').toString().toLowerCase();

      _navigateToRole(rawRole, profileData);
    } catch (e) {
      debugPrint('SPLASH API Error: $e');
      ApiService.clearTokenCache();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Server start ho raha hai, kripya thoda wait karein...\n(Free Render server sleep se wake ho raha hai)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
