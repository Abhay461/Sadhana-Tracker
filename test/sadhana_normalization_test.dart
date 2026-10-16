import 'package:flutter_test/flutter_test.dart';

List<dynamic> normalizeSadhanaItems(List<dynamic> rawList) {
  final List<dynamic> result = [];
  for (var u in rawList) {
    if (u is! Map) continue;
    final itemMap = Map<String, dynamic>.from(u);

    final workerId = (itemMap['worker_id'] ?? itemMap['userId'] ?? '').toString();
    final workerName = (itemMap['worker_name'] ?? itemMap['name'] ?? '').toString();
    final date = (itemMap['dateString'] ?? itemMap['date'] ?? '').toString();

    itemMap['worker_id'] = workerId;
    itemMap['worker_name'] = workerName;
    itemMap['date'] = date;

    final int countBefore = result.length;
    final dynamic rawActs = itemMap['activities'];

    if (rawActs is Map && rawActs.isNotEmpty) {
      final activities = Map<String, dynamic>.from(rawActs);

      if (activities['wakeUpTime'] != null && activities['wakeUpTime'].toString().isNotEmpty) {
        final t = activities['wakeUpTime'].toString();
        result.add({
          'id': itemMap['id'] ?? itemMap['_id'],
          'worker_id': workerId,
          'category': 'folk_sadhna',
          'work_started': 'Morning Wake-Up ($t)',
          'work_completed': t,
        });
      }

      if (activities['sleepTime'] != null && activities['sleepTime'].toString().isNotEmpty) {
        final t = activities['sleepTime'].toString();
        result.add({
          'id': itemMap['id'] ?? itemMap['_id'],
          'worker_id': workerId,
          'category': 'folk_sadhna',
          'work_started': 'Sleep Time ($t)',
          'work_completed': t,
        });
      }

      if (activities['manglaArti'] != null) {
        final m = activities['manglaArti'];
        if (m is Map && m['attended'] == true) {
          final t = (m['time'] ?? '04:30 AM').toString();
          result.add({
            'id': itemMap['id'] ?? itemMap['_id'],
            'worker_id': workerId,
            'category': 'folk_sadhna',
            'work_started': 'Mangla Arti ($t)',
            'work_completed': t,
          });
        }
      }

      if (activities['chanting'] != null) {
        final c = activities['chanting'];
        if (c is Map && c['rounds'] != null) {
          final r = c['rounds'];
          result.add({
            'id': itemMap['id'] ?? itemMap['_id'],
            'worker_id': workerId,
            'category': 'folk_sadhna',
            'work_started': 'Chanting ($r Rounds)',
            'work_completed': '$r Rounds',
          });
        }
      }
    }

    if (result.length == countBefore) {
      result.add(itemMap);
    }
  }
  return result;
}

void main() {
  group('Sadhana Normalization Verification', () {
    test('Decomposes daily entry with activities without adding duplicate parent', () {
      final sampleRaw = [
        // Daily sadhana entry with 4 activities
        {
          '_id': 'sadhana_day_1',
          'worker_id': 'user_1',
          'worker_name': 'Abhay',
          'dateString': '2026-10-16',
          'category': 'folk_sadhna',
          'activities': {
            'wakeUpTime': '05:30 AM',
            'sleepTime': '10:00 PM',
            'manglaArti': {'attended': true, 'time': '04:30 AM'},
            'chanting': {'rounds': 16},
          },
        },
        // Standalone appointment (no activities)
        {
          '_id': 'appt_1',
          'worker_id': 'user_1',
          'worker_name': 'Abhay',
          'category': 'preacher_appointment',
          'work_started': 'Appointment: 2026-10-16 @ 10:00 AM',
          'status': 'PENDING',
        },
        // Standalone accommodation (no activities)
        {
          '_id': 'acc_1',
          'worker_id': 'user_1',
          'worker_name': 'Abhay',
          'category': 'accommodation',
          'work_started': 'Accommodation Booking',
          'description': 'Arrival: 2026-10-16 • Departure: 2026-10-17',
          'status': 'PENDING',
        },
      ];

      final normalized = normalizeSadhanaItems(sampleRaw);

      // Total items should be: 4 (from sadhana) + 1 (appointment) + 1 (accommodation) = 6
      expect(normalized.length, 6);

      // Verify no empty parent container for 'sadhana_day_1'
      final rawParent = normalized.where((e) => e['_id'] == 'sadhana_day_1' && e['work_started'] == null).toList();
      expect(rawParent.isEmpty, isTrue, reason: 'Duplicate empty parent container must not exist');

      // Verify all 4 unpacked activities exist
      final activities = normalized.where((e) => e['category'] == 'folk_sadhna').toList();
      expect(activities.length, 4);

      // Verify standalone records are preserved
      final appt = normalized.firstWhere((e) => e['category'] == 'preacher_appointment');
      expect(appt['_id'], 'appt_1');

      final acc = normalized.firstWhere((e) => e['category'] == 'accommodation');
      expect(acc['_id'], 'acc_1');
    });

    test('Preserves sadhana item if activities map is empty', () {
      final sample = [
        {
          '_id': 'empty_sadhana',
          'worker_id': 'user_2',
          'category': 'folk_sadhna',
          'activities': {},
        }
      ];

      final normalized = normalizeSadhanaItems(sample);
      expect(normalized.length, 1);
      expect(normalized.first['_id'], 'empty_sadhana');
    });
  });
}
