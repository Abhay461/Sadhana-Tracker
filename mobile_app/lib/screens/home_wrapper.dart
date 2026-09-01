import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../utils/notification_helper.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  bool _isTakingLong = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isTakingLong = true;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectBasedOnRole();
    });
  }

  void _navigateToRole(String role) {
    if (role == 'preacher') {
      Navigator.pushReplacementNamed(context, '/preacher');
    } else if (role == 'residency') {
      Navigator.pushReplacementNamed(context, '/residency');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin-control-panel');
    } else {
      Navigator.pushReplacementNamed(context, '/folk-boy');
    }
  }

  Future<void> _redirectBasedOnRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Register user with notification helper
    NotificationHelper.loginUser(user.uid).catchError((_) {});
    FcmService.initialize().catchError((_) {});

    try {
      // Sync or fetch user profile from NestJS API
      final response = await ApiService.get('/users/me').timeout(const Duration(seconds: 15));
      final rawRole = (response is Map ? response['role'] : null) ?? 'folk_boy';
      final role = rawRole.toString().replaceAll('pending_', '');

      if (mounted) {
        _navigateToRole(role);
      }
    } catch (e) {
      debugPrint('HOME_WRAPPER API Error: $e');
      if (mounted) {
        _navigateToRole('folk_boy');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading Profile...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isTakingLong) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Server start ho raha hai, kripya thoda wait karein...\n(Free Render server sleep se wake ho raha hai)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
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
