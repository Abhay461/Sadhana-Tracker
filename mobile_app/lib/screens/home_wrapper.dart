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
  @override
  void initState() {
    super.initState();
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
      final response = await ApiService.get('/users/me').timeout(const Duration(seconds: 8));
      final role = (response is Map ? response['role'] : null) ?? 'folk_boy';

      if (role.toString().startsWith('pending_')) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account is pending preacher approval.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      if (mounted) {
        _navigateToRole(role.toString());
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
    return const Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading Profile...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
