import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/screens/splash_screen.dart';

void main() {
  setUpAll(() async {
    // Mock the SharedPreferences MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, Object?>{};
        }
        return null;
      },
    );

    // Initialize Supabase with placeholders
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  });

  testWidgets('Splash screen shows loading indicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const Scaffold(body: Text('Login')),
          '/home': (context) => const Scaffold(body: Text('Home')),
        },
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
