import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test: basic widget rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Sadhana Tracker')),
        ),
      ),
    );

    expect(find.text('Sadhana Tracker'), findsOneWidget);
  });
}
