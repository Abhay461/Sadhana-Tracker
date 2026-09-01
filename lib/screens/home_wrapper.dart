import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Register user with OneSignal
    NotificationHelper.loginUser(user.id).catchError((_) {});

    // HYBRID CACHING STRATEGY:
    // If we have a cached role in user_metadata, navigate IMMEDIATELY!
    // This reduces load time to 0ms for returning users.
    final cachedRole = user.userMetadata?['role'] as String?;
    bool navigatedInstantly = false;

    // If the cached role is pending, do not instantly navigate or log out.
    // Instead, let it fall through to check the database for approval status.
    if (cachedRole != null && !cachedRole.startsWith('pending_')) {
      _navigateToRole(cachedRole);
      navigatedInstantly = true;
    }

    try {
      // Fetch fresh role from the database (profiles table)
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        // Profile doesn't exist yet — create one with metadata defaults
        final metadata = user.userMetadata ?? {};
        final assignedRole = metadata['role'] ?? 'folk_boy';
        try {
          await Supabase.instance.client.from('profiles').insert({
            'id': user.id,
            'name': metadata['name'] ?? user.email?.split('@').first ?? 'User',
            'role': assignedRole,
            'preacher_id': metadata['preacher_id'],
            'whatsapp_number': metadata['whatsapp_number'] ?? 'Not provided',
            'email': user.email,
          });
        } catch (insertError) {
          debugPrint('HOME_WRAPPER INSERT ERROR: $insertError');
          if (mounted && !navigatedInstantly) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create profile: $insertError')),
            );
          }
        }

        if (assignedRole.startsWith('pending_')) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your account is pending preacher approval.')),
            );
            Navigator.pushReplacementNamed(context, '/login');
          }
          return;
        }

        if (!navigatedInstantly) {
          if (!mounted) return;
          _navigateToRole(assignedRole);
        }
        return;
      }

      final dbRole = response['role'] as String? ?? 'folk_boy';

      if (dbRole.startsWith('pending_')) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account is pending preacher approval.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // If the cached role is different from database role (e.g. role revoked, promoted, or tampered with),
      // we must sync metadata and update navigation.
      if (cachedRole != dbRole) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'role': dbRole}),
          );
        } catch (_) {
          // Non-critical metadata sync failure
        }

        if (mounted) {
          _navigateToRole(dbRole);
        }
      } else if (!navigatedInstantly) {
        // If we didn't navigate instantly, do it now
        if (mounted) {
          _navigateToRole(dbRole);
        }
      }
    } catch (e) {
      // If we failed to verify but already navigated instantly, let the user stay.
      // Otherwise, show error and redirect to login.
      if (!navigatedInstantly && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile. Please try again.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
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
