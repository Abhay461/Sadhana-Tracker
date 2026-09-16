import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';

// Import modular tab widgets
import 'preacher/management_tab.dart';
import 'preacher/online_session_tab.dart';
import 'preacher/notifications_tab.dart';
import 'preacher/announcements_tab.dart';
import 'preacher/attendance_tab.dart';
import 'preacher/birthday_tab.dart';
import 'preacher/trip_tab.dart';
import 'preacher/event_tab.dart';
import 'preacher/blocklist_tab.dart';
import 'preacher/accommodation_tab.dart';
import 'preacher/approval_tab.dart';
import 'preacher/payment_tab.dart';
import 'preacher/message_tab.dart';
import 'preacher/settings_tab.dart';
import 'preacher/residency_tab.dart';
import 'preacher/student_list_tab.dart';
import 'preacher/festival_tab.dart';

class PreacherDashboard extends StatefulWidget {
  const PreacherDashboard({super.key});

  @override
  State<PreacherDashboard> createState() => _PreacherDashboardState();
}

class _PreacherDashboardState extends State<PreacherDashboard> {
  final _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  bool _isLoadingBoys = true;

  bool get _isAdmin {
    if (_profile == null) return false;
    final role = (_profile!['role'] as String? ?? '').toLowerCase();
    final isAdminFlag = _profile!['isAdmin'] == true || _profile!['is_admin'] == true;
    final email = (_profile!['email'] as String? ?? '').toLowerCase();
    final isSuperAdminEmail = email == 'sadhanatracker.in@gmail.com' || email.contains('admin');
    return role == 'admin' || isAdminFlag || isSuperAdminEmail;
  }

  List<dynamic> _folkBoys = [];
  Map<String, List<dynamic>> _allUpdates = {}; // userId -> list of updates
  List<dynamic> _announcements = [];
  List<dynamic> _tripBookings = [];
  List<dynamic> _eventBookings = [];

  // Active View Tab identifier
  String? _activeTab;
  int _selectedIndex = 0;
  bool _initializedFromArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      _initializedFromArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _loadProfileAndData(initialProfile: args);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfileAndData();
  }

  Future<void> _loadProfileAndData({Map<String, dynamic>? initialProfile}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      dynamic profileData;
      if (initialProfile != null) {
        profileData = initialProfile;
      } else {
        profileData = await ApiService.get('/users/me');
      }

      final role = ((profileData is Map ? profileData['role'] : null) as String? ?? '').toLowerCase();
      if (role != 'preacher' && role != 'admin') {
        debugPrint('PreacherDashboard: User role is "$role" (not preacher/admin). Redirecting to home...');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _profile = profileData is Map ? Map<String, dynamic>.from(profileData) : null;
          _isLoadingProfile = false;
        });
      }

      await _fetchFolkBoys();
      await _fetchAnnouncements();
    } catch (e) {
      debugPrint('Error loading preacher profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _fetchFolkBoys() async {
    if (_profile == null) return;
    try {
      if (mounted) setState(() => _isLoadingBoys = true);
      final data = await ApiService.get('/preacher/students');

      debugPrint('=== DEBUG PREACHER DASHBOARD: /preacher/students ===');
      debugPrint('Runtime type of students response: ${data.runtimeType}');
      if (data is Map) {
        debugPrint('Map keys in students response: ${data.keys.toList()}');
      }

      List<dynamic> extractedStudents = [];
      if (data is List) {
        extractedStudents = List.from(data);
      } else if (data is Map) {
        for (var k in ['students', 'data', 'items', 'users', 'boys', 'records', 'results']) {
          if (data[k] is List) {
            extractedStudents = List.from(data[k]);
            break;
          }
        }
      }

      debugPrint('Fetched _folkBoys count: ${extractedStudents.length}');
      for (var b in extractedStudents) {
        debugPrint('  Student record: $b');
      }

      if (mounted) {
        setState(() {
          _folkBoys = extractedStudents;
          _isLoadingBoys = false;
        });
      }

      await _fetchAllUpdates();
    } catch (e) {
      debugPrint('Error fetching folk boys: $e');
      if (mounted) setState(() => _isLoadingBoys = false);
    }
  }

  Future<void> _fetchTripAndEventBookings() async {
    try {
      final tripData = await ApiService.get('/trips');
      final eventData = await ApiService.get('/events');

      if (mounted) {
        setState(() {
          _tripBookings = tripData is List ? tripData : [];
          _eventBookings = eventData is List ? eventData : [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching trip/event bookings: $e');
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final s = timeStr.trim().toUpperCase();
    if (s.isEmpty) return null;

    try {
      bool isPM = s.contains('PM');
      bool isAM = s.contains('AM');
      final clean = s.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0].trim());
        int minute = int.parse(parts[1].trim());
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  String _formatDurationText(String rawStr, {String defaultText = 'Attended'}) {
    final s = rawStr.trim();
    if (s.isEmpty) return defaultText;

    final lower = s.toLowerCase();
    if (lower == 'attended' || lower == 'visited' || lower == 'completed' || lower == 'filled') {
      return 'Attended';
    }

    if (lower.contains('hour') || lower.contains('hr')) {
      final numMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)', caseSensitive: false).firstMatch(s);
      if (numMatch != null) {
        final valStr = numMatch.group(1)!;
        final val = double.tryParse(valStr);
        if (val != null) {
          if (val == 1.0) return '1 hr';
          if (val == val.toInt().toDouble()) return '${val.toInt()} hrs';
          return '$valStr hrs';
        }
      }
      return s.replaceAll(RegExp(r'hours?', caseSensitive: false), 'hrs');
    }

    if (lower.contains('minute') || lower.contains('min')) {
      final numMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?)', caseSensitive: false).firstMatch(s);
      if (numMatch != null) {
        final mins = int.tryParse(numMatch.group(1)!);
        if (mins != null) {
          if (mins % 60 == 0) {
            final hrs = mins ~/ 60;
            return '$hrs hr${hrs > 1 ? 's' : ''}';
          }
          return '$mins mins';
        }
      }
      return s;
    }

    final numVal = int.tryParse(s);
    if (numVal != null) {
      if (numVal % 60 == 0) {
        final hrs = numVal ~/ 60;
        return '$hrs hr${hrs > 1 ? 's' : ''}';
      }
      return '$numVal mins';
    }

    if (s.contains('-')) {
      final parts = s.split('-');
      if (parts.length == 2) {
        final start = _parseTimeOfDay(parts[0].trim());
        final end = _parseTimeOfDay(parts[1].trim());
        if (start != null && end != null) {
          int startMin = start.hour * 60 + start.minute;
          int endMin = end.hour * 60 + end.minute;
          if (endMin < startMin) endMin += 24 * 60;
          final diff = endMin - startMin;
          if (diff > 0) {
            if (diff % 60 == 0) {
              final hrs = diff ~/ 60;
              return '$hrs hr${hrs > 1 ? 's' : ''}';
            } else if (diff > 60) {
              final hrs = (diff / 60).toStringAsFixed(1);
              return '$hrs hrs';
            } else {
              return '$diff mins';
            }
          }
        }
      }
    }

    final singleTime = _parseTimeOfDay(s);
    if (singleTime != null) {
      return '1 hr';
    }

    return s;
  }

  List<dynamic> _normalizeSadhanaItems(List<dynamic> rawList) {
    final List<dynamic> result = [];
    for (var u in rawList) {
      if (u is! Map) continue;
      final itemMap = Map<String, dynamic>.from(u);

      final workerId = (itemMap['worker_id'] ??
              itemMap['workerId'] ??
              itemMap['user_id'] ??
              itemMap['userId'] ??
              itemMap['student_id'] ??
              itemMap['studentId'] ??
              itemMap['createdBy'] ??
              itemMap['created_by'] ??
              (itemMap['user'] is Map ? itemMap['user']['_id'] ?? itemMap['user']['id'] : itemMap['user']) ??
              '')
          .toString();

      final workerName = (itemMap['worker_name'] ??
              itemMap['workerName'] ??
              itemMap['name'] ??
              itemMap['student_name'] ??
              itemMap['studentName'] ??
              itemMap['userName'] ??
              itemMap['user_name'] ??
              (itemMap['user'] is Map ? itemMap['user']['name'] : null) ??
              '')
          .toString();

      final date = (itemMap['dateString'] ?? itemMap['date'] ?? itemMap['created_at'] ?? itemMap['createdAt'] ?? '').toString();

      itemMap['worker_id'] = workerId;
      itemMap['worker_name'] = workerName;
      itemMap['date'] = date;
      result.add(itemMap);

      final dynamic rawActs = itemMap['activities'];
      if (rawActs is Map) {
        final activities = Map<String, dynamic>.from(rawActs);

        if (activities['wakeUpTime'] != null && activities['wakeUpTime'].toString().isNotEmpty) {
          final t = activities['wakeUpTime'].toString();
          result.add({
            'id': itemMap['id'] ?? itemMap['_id'],
            'worker_id': workerId,
            'worker_name': workerName,
            'date': date,
            'category': 'folk_sadhna',
            'work_started': 'Morning Wake-Up ($t)',
            'work_completed': t,
            'is_completed': true,
            'activities': rawActs,
          });
        }

        if (activities['sleepTime'] != null && activities['sleepTime'].toString().isNotEmpty) {
          final t = activities['sleepTime'].toString();
          result.add({
            'id': itemMap['id'] ?? itemMap['_id'],
            'worker_id': workerId,
            'worker_name': workerName,
            'date': date,
            'category': 'folk_sadhna',
            'work_started': 'Sleep Time ($t)',
            'work_completed': t,
            'is_completed': true,
            'activities': rawActs,
          });
        }

        if (activities['manglaArti'] != null) {
          final m = activities['manglaArti'];
          if (m is Map && (m['attended'] == true || m['time'] != null)) {
            final t = (m['time'] ?? 'Attended').toString();
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Mangla Arti ($t)',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (m == true) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Mangla Arti (Attended)',
              'work_completed': 'Attended',
              'is_completed': true,
              'activities': rawActs,
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
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Chanting ($r Rounds)',
              'work_completed': '$r Rounds',
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (c is num) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Chanting ($c Rounds)',
              'work_completed': '$c Rounds',
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['onlineSession'] != null) {
          final o = activities['onlineSession'];
          if (o is Map && (o['attended'] == true || o['timeSpan'] != null || o['duration'] != null || o['time'] != null)) {
            final rawT = (o['durationMinutes'] ?? o['duration'] ?? o['timeSpan'] ?? o['time'] ?? 'Attended').toString();
            final t = _formatDurationText(rawT, defaultText: 'Attended');
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Online Session ($t)',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (o == true) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Online Session (Attended)',
              'work_completed': 'Attended',
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['bookReading'] != null) {
          final b = activities['bookReading'];
          if (b is Map) {
            final name = (b['bookName'] ?? '').toString();
            final detail = (b['pagesOrMinutes'] ?? b['duration'] ?? '').toString();
            final combined = [name, detail].where((s) => s.isNotEmpty).join(' - ');
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Book Reading: ${combined.isNotEmpty ? combined : "Completed"}',
              'work_completed': combined.isNotEmpty ? combined : 'Completed',
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (b is String && b.isNotEmpty) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Book Reading: $b',
              'work_completed': b,
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['service'] != null) {
          final s = activities['service'];
          if (s is Map) {
            final dur = (s['durationMinutes'] ?? s['duration'] ?? s['timeSpan'] ?? s['time'] ?? '').toString();
            final name = (s['serviceName'] ?? s['name'] ?? '').toString();
            final t = dur.isNotEmpty ? _formatDurationText(dur) : (name.isNotEmpty ? name : 'Completed');
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Service: $t',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (s is String && s.isNotEmpty) {
            final t = _formatDurationText(s);
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Service: $t',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['templeVisit'] != null) {
          final t = activities['templeVisit'];
          if ((t is Map && t['visited'] == true) || t == true) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Temple Visit',
              'work_completed': 'Visited',
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['srimadBhagavatamClass'] != null) {
          final sb = activities['srimadBhagavatamClass'];
          if (sb is Map && (sb['attended'] == true || sb['timeSpan'] != null || sb['duration'] != null || sb['time'] != null)) {
            final rawT = (sb['durationMinutes'] ?? sb['duration'] ?? sb['timeSpan'] ?? sb['time'] ?? 'Attended').toString();
            final t = _formatDurationText(rawT, defaultText: 'Attended');
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Srimad Bhagavatam Class ($t)',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (sb == true) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Srimad Bhagavatam Class (Attended)',
              'work_completed': 'Attended',
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['bhagavadGitaClass'] != null) {
          final bg = activities['bhagavadGitaClass'];
          if (bg is Map && (bg['attended'] == true || bg['timeSpan'] != null || bg['duration'] != null || bg['time'] != null)) {
            final rawT = (bg['durationMinutes'] ?? bg['duration'] ?? bg['timeSpan'] ?? bg['time'] ?? 'Attended').toString();
            final t = _formatDurationText(rawT, defaultText: 'Attended');
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Bhagavad Gita Class ($t)',
              'work_completed': t,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (bg == true) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Bhagavad Gita Class (Attended)',
              'work_completed': 'Attended',
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }

        if (activities['ekadashiFasting'] != null) {
          final e = activities['ekadashiFasting'];
          if (e is Map && e['fastingType'] != null) {
            final f = e['fastingType'].toString();
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Ekadashi Fasting ($f)',
              'work_completed': f,
              'is_completed': true,
              'activities': rawActs,
            });
          } else if (e is String && e.isNotEmpty) {
            result.add({
              'id': itemMap['id'] ?? itemMap['_id'],
              'worker_id': workerId,
              'worker_name': workerName,
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Ekadashi Fasting ($e)',
              'work_completed': e,
              'is_completed': true,
              'activities': rawActs,
            });
          }
        }
      }
    }
    return result;
  }

  Future<void> _fetchAllUpdates() async {
    await _fetchTripAndEventBookings();
    try {
      dynamic updatesData = await ApiService.get('/sadhana/updates');

      debugPrint('=== DEBUG PREACHER DASHBOARD: /sadhana/updates RESPONSE ===');
      debugPrint('Runtime type of updatesData: ${updatesData.runtimeType}');
      if (updatesData is Map) {
        debugPrint('Map keys in updatesData: ${updatesData.keys.toList()}');
      }

      List<dynamic> extractList(dynamic data) {
        if (data is List) return List.from(data);
        if (data is Map) {
          for (var key in ['items', 'updates', 'data', 'records', 'results', 'sadhana', 'history', 'logs', 'sadhanaUpdates']) {
            final val = data[key];
            if (val is List) return List.from(val);
            if (val is Map) {
              final nested = extractList(val);
              if (nested.isNotEmpty) return nested;
            }
          }
        }
        return [];
      }

      List<dynamic> rawUpdates = extractList(updatesData);
      debugPrint('Total raw updates extracted: ${rawUpdates.length}');
      if (rawUpdates.isNotEmpty) {
        debugPrint('Sample raw update record #0: ${rawUpdates.first}');
      }

      final List<dynamic> processedUpdates = _normalizeSadhanaItems(rawUpdates);
      debugPrint('Total processed updates count: ${processedUpdates.length}');

      // Process signals in-memory
      final approvalSignals = processedUpdates.where((u) => u['category'] == 'accommodation_approval_signal').toList();
      final deleteSignals = processedUpdates.where((u) => u['category'] == 'accommodation_delete_signal').toList();
      final residencyApprovalSignals = processedUpdates.where((u) => u['category'] == 'residency_admission_approval_signal').toList();
      final residencyDeleteSignals = processedUpdates.where((u) => u['category'] == 'residency_admission_delete_signal').toList();

      for (var signal in approvalSignals) {
        final String signalStr = signal['work_started'] ?? '';
        if (signalStr.startsWith('SIGNAL: ')) {
          final targetIdStr = signalStr.replaceAll('SIGNAL: ', '');
          final targetId = int.tryParse(targetIdStr);
          final room = signal['work_completed'] ?? '';
          if (targetId != null) {
            for (var u in processedUpdates) {
              if (u['id'] == targetId && u['category'] == 'accommodation') {
                u['is_completed'] = true;
                u['work_completed'] = room;
              }
            }
          }
        }
      }

      for (var signal in residencyApprovalSignals) {
        final String signalStr = signal['work_started'] ?? '';
        if (signalStr.startsWith('SIGNAL: ')) {
          final targetIdStr = signalStr.replaceAll('SIGNAL: ', '');
          final targetId = int.tryParse(targetIdStr);
          if (targetId != null) {
            for (var u in processedUpdates) {
              if (u['id'] == targetId && u['category'] == 'residency_admission') {
                u['is_completed'] = true;
              }
            }
          }
        }
      }

      final List<int> idsToDelete = [];
      for (var signal in deleteSignals) {
        final String signalStr = signal['work_started'] ?? '';
        if (signalStr.startsWith('SIGNAL: ')) {
          final targetIdStr = signalStr.replaceAll('SIGNAL: ', '');
          final targetId = int.tryParse(targetIdStr);
          if (targetId != null) {
            idsToDelete.add(targetId);
          }
        }
      }

      for (var signal in residencyDeleteSignals) {
        final String signalStr = signal['work_started'] ?? '';
        if (signalStr.startsWith('SIGNAL: ')) {
          final targetIdStr = signalStr.replaceAll('SIGNAL: ', '');
          final targetId = int.tryParse(targetIdStr);
          if (targetId != null) {
            idsToDelete.add(targetId);
          }
        }
      }

      if (idsToDelete.isNotEmpty) {
        processedUpdates.removeWhere((u) => idsToDelete.contains(u['id']));
      }

      processedUpdates.removeWhere((u) => 
        u['category'] == 'accommodation_approval_signal' || 
        u['category'] == 'accommodation_delete_signal' ||
        u['category'] == 'residency_admission_approval_signal' ||
        u['category'] == 'residency_admission_delete_signal'
      );

      final Map<String, List<dynamic>> grouped = {};
      for (var u in processedUpdates) {
        final workerId = (u['worker_id'] ?? u['workerId'] ?? u['user_id'] ?? u['userId'] ?? u['student_id'] ?? u['studentId'] ?? u['createdBy'] ?? u['created_by'] ?? (u['user'] is Map ? u['user']['_id'] ?? u['user']['id'] : u['user']) ?? '').toString();
        final workerName = (u['worker_name'] ?? u['workerName'] ?? u['name'] ?? u['student_name'] ?? u['studentName'] ?? u['userName'] ?? u['user_name'] ?? (u['user'] is Map ? u['user']['name'] : null) ?? '').toString().trim().toLowerCase();

        void addGroup(String k) {
          if (k.isEmpty) return;
          if (!grouped.containsKey(k)) grouped[k] = [];
          grouped[k]!.add(u);
        }

        addGroup(workerId);
        addGroup(workerName);
        if (u['user'] is Map) {
          final uObjId = (u['user']['_id'] ?? u['user']['id'] ?? '').toString();
          final uObjName = (u['user']['name'] ?? '').toString().trim().toLowerCase();
          addGroup(uObjId);
          addGroup(uObjName);
        }
      }

      if (mounted) {
        setState(() {
          _allUpdates = grouped;
        });
      }
    } catch (e) {
      debugPrint('Error fetching all updates: $e');
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final data = await ApiService.get('/announcements');
      if (mounted) {
        setState(() {
          _announcements = data is List ? data : [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    }
  }

  Future<void> _updateMainProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _profile == null) return;

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading photo... Please wait.')),
          );
        }
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        
        setState(() {
          _profile = Map<String, dynamic>.from(_profile!)..['photo_url'] = url;
        });

        await ApiService.patch('/users/me', {
          'photoUrl': url,
        });

        await _loadProfileAndData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating main profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update photo. Please try again.')),
        );
      }
    }
  }

  int get _pendingApprovalCount {
    final pendingAccounts = _folkBoys.where((b) {
      final role = b['role'] as String? ?? '';
      return role.startsWith('pending_');
    }).length;

    int pendingUpdatesCount = 0;
    for (var list in _allUpdates.values) {
      for (var u in list) {
        final cat = u['category'];
        if (cat == 'preacher_appointment' || cat == 'accommodation' || cat == 'residency_admission') {
          if (u['is_completed'] == false) {
            pendingUpdatesCount++;
          }
        } else if (cat == 'payment') {
          final workCompleted = u['work_completed'] ?? '';
          if (u['is_completed'] == false && (workCompleted == 'SUBMITTED' || workCompleted == 'WAITING_APPROVAL')) {
            pendingUpdatesCount++;
          }
        }
      }
    }
    return pendingAccounts + pendingUpdatesCount;
  }

  int get _pendingPaymentCount {
    int count = 0;
    for (var list in _allUpdates.values) {
      for (var u in list) {
        if (u['category'] == 'payment') {
          final workCompleted = u['work_completed'] ?? '';
          if (u['is_completed'] == false && (workCompleted == 'SUBMITTED' || workCompleted == 'WAITING_APPROVAL')) {
            count++;
          }
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
            canPop: _selectedIndex == 0 && _activeTab == null,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_activeTab != null) {
                setState(() {
                  _activeTab = null;
                });
              } else if (_selectedIndex != 0) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 95,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFBAE6FD),
                        Color(0xFFE0F2FE),
                        Color(0xFFF8FAFC),
                      ],
                    ),
                  ),
                ),
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
                centerTitle: true,
                title: _buildHeaderLogo(),
              ),
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildHomeTabContent(),
                  _buildApprovalsTabContent(),
                  _buildServicesTabContent(),
                  _buildSettingsTabContent(),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      indicatorColor: const Color(0xFF3F1200).withValues(alpha: 0.12),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const TextStyle(color: Color(0xFF3F1200), fontWeight: FontWeight.bold, fontSize: 12);
                        }
                        return TextStyle(color: const Color(0xFF3F1200).withValues(alpha: 0.6), fontSize: 12);
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const IconThemeData(color: Color(0xFF3F1200));
                        }
                        return IconThemeData(color: const Color(0xFF3F1200).withValues(alpha: 0.6));
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                          _activeTab = null;
                        });
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      height: 65,
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.fact_check_outlined),
                              if (_pendingApprovalCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                    child: Center(
                                      child: Text(
                                        '$_pendingApprovalCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          selectedIcon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.fact_check_rounded),
                              if (_pendingApprovalCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                    child: Center(
                                      child: Text(
                                        '$_pendingApprovalCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          label: 'Approvals',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.grid_view_outlined),
                          selectedIcon: Icon(Icons.grid_view_rounded),
                          label: 'Services',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

  Widget _buildHomeTabContent() {
    final activeFolkBoys = _folkBoys.where((b) => !(b['role'] as String? ?? '').startsWith('pending_')).toList();
    return ManagementTab(
      folkBoys: activeFolkBoys,
      allUpdates: _allUpdates,
      preacherProfile: _profile,
      onRefresh: _loadProfileAndData,
    );
  }

  Widget _buildApprovalsTabContent() {
    return ApprovalTab(
      allUpdates: _allUpdates,
      onRefresh: _loadProfileAndData,
      preacherProfile: _profile,
      folkBoys: _folkBoys,
    );
  }

  Widget _buildSettingsTabContent() {
    return SettingsTab(
      preacherProfile: _profile,

      onRefresh: _loadProfileAndData,
    );
  }

  Widget _buildServicesTabContent() {
    if (_activeTab == null) {
      return _buildServicesGrid();
    } else {
      return Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
                  onPressed: () {
                    setState(() {
                      _activeTab = null;
                    });
                  },
                ),
                Text(
                  _activeTab == 'payment'
                      ? 'Payment Reminder'
                      : _activeTab == 'online'
                          ? 'Online Session'
                          : _activeTab == 'blocklist'
                              ? 'Block List'
                              : _activeTab == 'residency'
                                  ? 'Residency Admission'
                                  : _activeTab == 'notifications'
                                      ? 'Notification'
                                      : _activeTab == 'student_list'
                                          ? 'Student List'
                                          : _activeTab == 'festival'
                                              ? 'Festival Management'
                                              : _activeTab![0].toUpperCase() + _activeTab!.substring(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildTabContent()),
        ],
      );
    }
  }

  Widget _buildServicesGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services Control Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildServiceListItem(
                title: 'Online Session',
                icon: Icons.video_camera_back_outlined,
                onTap: () => setState(() => _activeTab = 'online'),
              ),
              _buildServiceListItem(
                title: 'Announcements',
                icon: Icons.campaign_outlined,
                onTap: () => setState(() => _activeTab = 'announcements'),
              ),
              _buildServiceListItem(
                title: 'Attendance',
                icon: Icons.check_circle_outline_outlined,
                onTap: () => setState(() => _activeTab = 'attendance'),
              ),
              _buildServiceListItem(
                title: 'Birthday Wishes',
                icon: Icons.cake_outlined,
                onTap: () => setState(() => _activeTab = 'birthday'),
              ),
              _buildServiceListItem(
                title: 'Plan Trip',
                icon: Icons.alt_route_outlined,
                onTap: () => setState(() => _activeTab = 'trip'),
              ),
              _buildServiceListItem(
                title: 'Post Event',
                icon: Icons.calendar_month_outlined,
                onTap: () => setState(() => _activeTab = 'event'),
              ),
              _buildServiceListItem(
                title: 'Block List',
                icon: Icons.block_outlined,
                onTap: () => setState(() => _activeTab = 'blocklist'),
              ),
              _buildServiceListItem(
                title: 'Accommodation',
                icon: Icons.home_outlined,
                onTap: () => setState(() => _activeTab = 'accommodation'),
              ),
              _buildServiceListItem(
                title: 'Residency Admission',
                icon: Icons.school_outlined,
                onTap: () => setState(() => _activeTab = 'residency'),
              ),
              _buildServiceListItem(
                title: 'Payment Reminder',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => setState(() => _activeTab = 'payment'),
                badgeCount: _pendingPaymentCount,
              ),
              _buildServiceListItem(
                title: 'Notification',
                icon: Icons.notifications_none_outlined,
                onTap: () => setState(() => _activeTab = 'notifications'),
              ),
              _buildServiceListItem(
                title: 'Message',
                icon: Icons.chat_bubble_outline_outlined,
                onTap: () => setState(() => _activeTab = 'message'),
              ),
              _buildServiceListItem(
                title: 'Student List',
                icon: Icons.people_outline_rounded,
                onTap: () => setState(() => _activeTab = 'student_list'),
              ),
              if (_isAdmin)
                _buildServiceListItem(
                  title: 'Festival Management (Admin Only)',
                  icon: Icons.festival_outlined,
                  onTap: () => setState(() => _activeTab = 'festival'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceListItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3F1200).withValues(alpha: 0.08),
          child: Icon(icon, color: const Color(0xFF3F1200), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final activeFolkBoys = _folkBoys.where((b) => !(b['role'] as String? ?? '').startsWith('pending_')).toList();

    switch (_activeTab) {
      case 'management':
        return ManagementTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
    
          onRefresh: _loadProfileAndData,
        );
      case 'online':
        return OnlineSessionTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'notifications':
        return NotificationsTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'announcements':
        return AnnouncementsTab(
          announcements: _announcements,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'attendance':
        return AttendanceTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'birthday':
        return BirthdayTab(
          folkBoys: activeFolkBoys,
        );
      case 'trip':
        return TripTab(
          announcements: _announcements,
          tripBookings: _tripBookings,
          folkBoys: activeFolkBoys,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'event':
        return EventTab(
          announcements: _announcements,
          eventBookings: _eventBookings,
          folkBoys: activeFolkBoys,
          preacherProfile: _profile,
          onRefresh: _loadProfileAndData,
        );
      case 'blocklist':
        return BlocklistTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
    
          onRefresh: _loadProfileAndData,
        );
      case 'accommodation':
        return AccommodationTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
    
          onRefresh: _loadProfileAndData,
        );
      case 'approval':
        return ApprovalTab(
          allUpdates: _allUpdates,
    
          onRefresh: _loadProfileAndData,
          preacherProfile: _profile,
          folkBoys: _folkBoys,
        );
      case 'residency':
        return ResidencyTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
    
          onRefresh: _loadProfileAndData,
        );
      case 'payment':
        return PaymentTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
    
          onRefresh: _loadProfileAndData,
        );
      case 'message':
        return MessageTab(
          folkBoys: activeFolkBoys,
          isLoadingBoys: _isLoadingBoys,
        );
      case 'settings':
        return SettingsTab(
          preacherProfile: _profile,
    
          onRefresh: _loadProfileAndData,
        );
      case 'student_list':
        return StudentListTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
    
          onRefresh: _loadProfileAndData,
        );
      case 'festival':
        if (!_isAdmin) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '🔒 Access Restricted: Festival Management is available for Admin accounts only.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 15),
              ),
            ),
          );
        }
        return const FestivalTab();
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeaderLogo() {
    return Image.asset(
      'assets/folk_logo.png',
      height: 82,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/logo.jpg',
        height: 82,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _LiveDateTimeWidget extends StatefulWidget {
  final Color? color;
  const _LiveDateTimeWidget({this.color});

  @override
  State<_LiveDateTimeWidget> createState() => _LiveDateTimeWidgetState();
}

class _LiveDateTimeWidgetState extends State<_LiveDateTimeWidget> {
  late Timer _timer;
  late String _dateTimeStr;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _dateTimeStr = DateFormat('EEEE, d MMM • hh:mm a').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _dateTimeStr,
      style: TextStyle(
        fontSize: 12,
        color: widget.color ?? const Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
