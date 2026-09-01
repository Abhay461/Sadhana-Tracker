import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_wrapper.dart';
import 'screens/folk_boy_dashboard.dart';
import 'screens/preacher_dashboard.dart';
import 'screens/residency_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/reset_password_screen.dart';

import 'utils/notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  // Initialize OneSignal
  await NotificationHelper.initialize();

  // Listen to auth changes globally to sync OneSignal user state
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    final event = data.event;
    if (session != null && (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed)) {
      NotificationHelper.loginUser(session.user.id).catchError((_) {});
    } else if (event == AuthChangeEvent.signedOut) {
      NotificationHelper.logoutUser().catchError((_) {});
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sadhana Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeWrapper(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/folk-boy': (context) => const FolkBoyDashboard(),
        '/residency': (context) => const ResidencyDashboard(),
        '/preacher': (context) => const PreacherDashboard(),
        '/admin-control-panel': (context) => const AdminDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
