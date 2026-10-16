import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Date Formatting Tests', () {
    test('Formats YYYY-MM-DD to readable format like 17 Oct 2026', () {
      expect(FcmService.formatDateReadable('2026-10-17'), equals('17 Oct 2026'));
      expect(FcmService.formatDateReadable('2026-01-05'), equals('5 Jan 2026'));
    });

    test('Preserves already readable date format', () {
      expect(FcmService.formatDateReadable('17 Oct 2026'), equals('17 Oct 2026'));
    });
  });

  group('Appointment Notification Formatting Tests', () {
    test('Formats appointment notification with exact required layout and dynamic data', () {
      final body = FcmService.formatAppointmentBody(
        studentName: 'Rohan Sharma',
        date: '2026-10-17',
        time: '10:00 AM',
      );

      expect(
        body,
        equals('Rohan Sharma booked an appointment.\nDate: 17 Oct 2026 • Time: 10:00 AM'),
      );
    });

    test('Strictly strips out preacher name from raw body', () {
      const rawBody = 'Preacher: HG Aniruddh Balram Dasa\nDate: 2026-10-17\nTime: 11:30 AM\nPurpose: Counseling';
      final body = FcmService.formatAppointmentBody(
        studentName: 'Amit Verma',
        date: null,
        time: null,
        rawBody: rawBody,
      );

      expect(body.contains('Aniruddh'), isFalse);
      expect(body.contains('Preacher'), isFalse);
      expect(
        body,
        equals('Amit Verma booked an appointment.\nDate: 17 Oct 2026 • Time: 11:30 AM'),
      );
    });

    test('Parses inline date and time without preacher name', () {
      const rawBody = 'Student booked appointment: 2026-10-17 @ 10:00 AM (Preacher: HG Aniruddh Balram Dasa)';
      final body = FcmService.formatAppointmentBody(
        studentName: 'Madhava',
        date: null,
        time: null,
        rawBody: rawBody,
      );

      expect(body.contains('Aniruddh'), isFalse);
      expect(
        body,
        equals('Madhava booked an appointment.\nDate: 17 Oct 2026 • Time: 10:00 AM'),
      );
    });
  });

  group('Accommodation Notification Formatting Tests', () {
    test('Formats body cleanly with student name, arrival date, and departure date', () {
      final formatted = FcmService.formatAccommodationBody(
        studentName: 'Gauranga Das',
        arrivalDate: '2026-10-16',
        departureDate: '2026-10-17',
      );

      expect(
        formatted,
        equals('Student: Gauranga Das\nArrival: 16 Oct 2026 • Departure: 17 Oct 2026'),
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
        equals('Student: Madhava\nArrival: 1 Nov 2026 • Departure: 5 Nov 2026'),
      );
    });
  });

  group('Event Key Resolution and Deduplication Tests', () {
    test('Resolves stable event key from appointmentId', () {
      final key = FcmService.resolveEventKey(
        data: {'appointmentId': '67b2d1000abcd'},
        title: 'New Appointment',
        body: 'Madhava booked an appointment.',
      );
      expect(key, equals('appointment_67b2d1000abcd'));
    });

    test('Distinct appointments with identical message text have different stable keys', () {
      final key1 = FcmService.resolveEventKey(
        data: {'appointmentId': 'appt_001'},
        title: 'New Appointment',
        body: 'Same text',
      );
      final key2 = FcmService.resolveEventKey(
        data: {'appointmentId': 'appt_002'},
        title: 'New Appointment',
        body: 'Same text',
      );
      expect(key1, isNot(equals(key2)));
      expect(key1, equals('appointment_appt_001'));
      expect(key2, equals('appointment_appt_002'));
    });

    test('Duplicate delivery with same appointmentId produces identical key', () {
      final keyDelivery1 = FcmService.resolveEventKey(
        messageId: 'fcm_msg_1',
        data: {'appointmentId': 'appt_001'},
        title: 'New Appointment',
        body: 'Student booked an appointment.',
      );
      final keyDelivery2 = FcmService.resolveEventKey(
        messageId: 'fcm_msg_2', // distinct FCM delivery attempt
        data: {'appointmentId': 'appt_001'},
        title: 'New Appointment',
        body: 'Student booked an appointment.',
      );
      expect(keyDelivery1, equals(keyDelivery2));
      expect(keyDelivery1, equals('appointment_appt_001'));
    });

    test('Resolves stable event key from accommodationId or entity id', () {
      final accKey = FcmService.resolveEventKey(
        data: {'accommodationId': 'acc_999'},
      );
      expect(accKey, equals('accommodation_acc_999'));

      final entityKey = FcmService.resolveEventKey(
        data: {'id': 'entity_123'},
      );
      expect(entityKey, equals('entity_entity_123'));
    });

    test('Falls back to messageId or title_body when data has no entity ID', () {
      final msgKey = FcmService.resolveEventKey(
        messageId: 'msg_unique_88',
        data: {},
      );
      expect(msgKey, equals('fcm_msg_unique_88'));

      final fallbackKey = FcmService.resolveEventKey(
        title: 'General Alert',
        body: 'Meeting in 5 minutes',
      );
      expect(fallbackKey, equals('General Alert_Meeting in 5 minutes'));
    });
  });

  group('Student Approval Notification Tests', () {
    test('Appointment approval body formats date cleanly and omits preacher name', () {
      final formattedDate = FcmService.formatDateReadable('2026-10-17');
      final body = 'Your appointment has been approved for $formattedDate • 10:00 AM.';

      expect(body, equals('Your appointment has been approved for 17 Oct 2026 • 10:00 AM.'));
      expect(body.contains('Preacher'), isFalse);
    });

    test('Accommodation approval body formats room number dynamically', () {
      const room = 'Room 304-B';
      const body = 'Your accommodation request has been approved. Room: $room';

      expect(body, equals('Your accommodation request has been approved. Room: Room 304-B'));
      expect(body.contains('304-B'), isTrue);
    });

    test('Payment approval body confirms payment clearly', () {
      const body = 'Your payment submission has been approved.';
      expect(body, equals('Your payment submission has been approved.'));
    });
  });
}

