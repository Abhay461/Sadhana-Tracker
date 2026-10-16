import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accommodation Notification Formatting Tests', () {
    test('Formats body cleanly with student name, arrival date, and departure date', () {
      final formatted = FcmService.formatAccommodationBody(
        studentName: 'Gauranga Das',
        arrivalDate: '2026-10-20',
        departureDate: '2026-10-25',
      );

      expect(
        formatted,
        equals('Student: Gauranga Das\nArrival: 2026-10-20 • Departure: 2026-10-25'),
      );
    });

    test('Parses arrival and departure dates from multiline raw body when fields not in root', () {
      const rawBody = 'Name: Madhava\nAge: 24\nArrival: 2026-11-01\nDeparture: 2026-11-05';
      final formatted = FcmService.formatAccommodationBody(
        studentName: 'Madhava',
        arrivalDate: null,
        departureDate: null,
        rawBody: rawBody,
      );

      expect(
        formatted,
        equals('Student: Madhava\nArrival: 2026-11-01 • Departure: 2026-11-05'),
      );
    });

    test('Parses arrival and departure dates from inline raw body with bullet separators', () {
      const rawBody = 'Madhava requested accommodation: Name: Madhava • Age: 24 • Arrival: 2026-11-10 • Departure: 2026-11-15';
      final formatted = FcmService.formatAccommodationBody(
        studentName: null,
        arrivalDate: null,
        departureDate: null,
        rawBody: rawBody,
      );

      expect(
        formatted,
        equals('Student: Madhava\nArrival: 2026-11-10 • Departure: 2026-11-15'),
      );
    });

    test('Fallback body if dates cannot be parsed', () {
      const rawBody = 'Custom accommodation note without standard dates';
      final formatted = FcmService.formatAccommodationBody(
        studentName: 'Bhakta John',
        arrivalDate: null,
        departureDate: null,
        rawBody: rawBody,
      );

      expect(formatted, equals(rawBody));
    });
  });
}
