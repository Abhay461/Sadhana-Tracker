import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
  
  // Initialize Firebase App
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Validate app constants
  Constants.validate();

  // Initialize notifications in the background
  NotificationHelper.initialize().catchError((e) {
    debugPrint('Notification initialization error: $e');
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
