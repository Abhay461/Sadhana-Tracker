import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import '../services/realtime_service.dart';
import '../utils/user_session.dart';

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

  static void clearStaticCache() {
    _PreacherDashboardState.clearStaticCache();
  }

  @override
  State<PreacherDashboard> createState() => _PreacherDashboardState();
}

class _PreacherDashboardState extends State<PreacherDashboard> with WidgetsBindingObserver {
  final _picker = ImagePicker();

  // Static in-memory cache for instant UI restoration (<1 sec) across screen re-opens
  static String? _staticCacheUid;
  static Map<String, dynamic>? _staticProfile;
  static List<dynamic>? _staticFolkBoys;
  static Map<String, List<dynamic>>? _staticAllUpdates;
  static List<dynamic>? _staticAnnouncements;
  static List<dynamic>? _staticTripBookings;
  static List<dynamic>? _staticEventBookings;

  static void clearStaticCache() {
    _staticCacheUid = null;
    _staticProfile = null;
    _staticFolkBoys = null;
    _staticAllUpdates = null;
    _staticAnnouncements = null;
    _staticTripBookings = null;
    _staticEventBookings = null;
  }

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

  // ── Real-time refresh: WebSocket event stream + FCM foreground + lifecycle ──
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  StreamSubscription? _fcmForegroundSub;
  bool _isSilentRefreshing = false;

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
    WidgetsBinding.instance.addObserver(this);

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_staticCacheUid != null && _staticCacheUid != currentUid) {
      clearStaticCache();
    }
    _staticCacheUid = currentUid;

    // Populate immediately from static cache if available for 0ms delay
    if (_staticProfile != null) {
      _profile = _staticProfile;
      _isLoadingProfile = false;
    }
    if (_staticFolkBoys != null && _staticFolkBoys!.isNotEmpty) {
      _folkBoys = List.from(_staticFolkBoys!);
      _isLoadingBoys = false;
    }
    if (_staticAllUpdates != null && _staticAllUpdates!.isNotEmpty) {
      _allUpdates = Map.from(_staticAllUpdates!);
    }
    if (_staticAnnouncements != null) {
      _announcements = List.from(_staticAnnouncements!);
    }
    if (_staticTripBookings != null) {
      _tripBookings = List.from(_staticTripBookings!);
    }
    if (_staticEventBookings != null) {
      _eventBookings = List.from(_staticEventBookings!);
    }

    _loadProfileAndData();
    _startRealtimeRefresh();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _fcmForegroundSub?.cancel();
    RealtimeService.instance.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Lifecycle: auto-refresh when app comes back to foreground ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [PREACHER] App resumed → refreshing data');
      _silentRefresh();
    }
  }

  // ── Real-time refresh setup ──
  void _startRealtimeRefresh() {
    // 1. Connect to WebSocket Realtime Service (Event-driven)
    RealtimeService.instance.connect();
    _realtimeSub?.cancel();
    _realtimeSub = RealtimeService.instance.eventStream.listen(_handleRealtimeEvent);

    // 2. FCM foreground message listener
    _fcmForegroundSub?.cancel();
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [PREACHER] FCM foreground message: ${message.notification?.title ?? message.data.toString()}');
      _silentRefresh();
    });
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;
    debugPrint('[REALTIME] Event received: ${event.type}:${event.action}');
    switch (event.type) {
      case 'sadhana_update':
      case 'accommodation_update':
      case 'appointment_update':
      case 'payment_update':
        _fetchAllUpdates();
        break;
      case 'student_update':
        _fetchFolkBoys();
        break;
      case 'trip_update':
      case 'event_update':
        _fetchTripAndEventBookings();
        break;
      case 'announcement_update':
        _fetchAnnouncements();
        break;
      default:
        _silentRefresh();
        break;
    }
  }

  /// Silently re-fetch updates + accommodations without showing a loading spinner.
  Future<void> _silentRefresh() async {
    if (_isSilentRefreshing || !mounted) return;
    _isSilentRefreshing = true;
    debugPrint('🔄 [PREACHER] Silent refresh started');
    try {
      await _fetchAllUpdates();
    } catch (e) {
      debugPrint('🔄 [PREACHER] Silent refresh error: $e');
    } finally {
      _isSilentRefreshing = false;
    }
  }

  Future<void> _loadProfileAndData({Map<String, dynamic>? initialProfile}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_staticCacheUid != null && _staticCacheUid != user.uid) {
      clearStaticCache();
    }
    _staticCacheUid = user.uid;

    if (initialProfile != null) {
      _profile = initialProfile;
      _staticProfile = initialProfile;
      _isLoadingProfile = false;
    } else if (_staticProfile != null) {
      _profile = _staticProfile;
      _isLoadingProfile = false;
    }

    if (_staticFolkBoys != null && _staticFolkBoys!.isNotEmpty) {
      _folkBoys = List.from(_staticFolkBoys!);
      _isLoadingBoys = false;
    }
    if (_staticAllUpdates != null && _staticAllUpdates!.isNotEmpty) {
      _allUpdates = Map.from(_staticAllUpdates!);
    }

    try {
      // Fire parallel requests concurrently to avoid waterfall latency
      await Future.wait([
        if (_profile == null)
          ApiService.get('/users/me').then((profileData) {
            if (profileData is Map && mounted) {
              final map = Map<String, dynamic>.from(profileData);
              final role = (map['role'] as String? ?? '').toLowerCase();
              if (role != 'preacher' && role != 'admin') {
                Navigator.pushReplacementNamed(context, '/home');
                return;
              }
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null && uid.isNotEmpty) {
                UserSession.saveSession(
                  uid: uid,
                  role: role,
                  profileData: map,
                );
              }
              setState(() {
                _profile = map;
                _staticProfile = map;
                _isLoadingProfile = false;
              });
            }
          }).catchError((e) {
            debugPrint('Error loading preacher profile: $e');
            if (mounted) setState(() => _isLoadingProfile = false);
          }),
        _fetchFolkBoys(),
        _fetchAllUpdates(),
        _fetchAnnouncements(),
        _fetchTripAndEventBookings(),
      ]);
    } catch (e) {
      debugPrint('Error loading preacher profile and data: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingBoys = false;
        });
      }
    }
  }

  Future<void> _fetchFolkBoys() async {
    try {
      if (_folkBoys.isEmpty && mounted) {
        setState(() => _isLoadingBoys = true);
      }

      final user = FirebaseAuth.instance.currentUser;
      final fbUid = user?.uid ?? 'NULL';
      final fbEmail = user?.email ?? 'NULL';
      final detectedRole = (_profile?['role'] ?? 'UNKNOWN').toString();
      final cachedUid = ApiService.cachedUid ?? 'NONE';
      final freshRequested = ApiService.wasFreshTokenRequested;

      debugPrint('📌 [DEBUG /preacher/students CALL]:');
      debugPrint('   1. Firebase UID: $fbUid');
      debugPrint('   2. Firebase Email: $fbEmail');
      debugPrint('   3. Detected Role: $detectedRole');
      debugPrint('   4. Cached Token UID: $cachedUid');
      debugPrint('   5. Fresh Token Requested: $freshRequested');

      final data = await ApiService.get('/preacher/students');

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

      if (mounted) {
        setState(() {
          _folkBoys = extractedStudents;
          _staticFolkBoys = extractedStudents;
          _isLoadingBoys = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching folk boys: $e');
      if (mounted) setState(() => _isLoadingBoys = false);
    }
  }

  Future<void> _fetchTripAndEventBookings() async {
    try {
      final results = await Future.wait([
        ApiService.get('/trips').catchError((e) => []),
        ApiService.get('/events').catchError((e) => []),
      ]);
      final tripData = results[0];
      final eventData = results[1];

      if (mounted) {
        setState(() {
          _tripBookings = tripData is List ? tripData : [];
          _eventBookings = eventData is List ? eventData : [];
          _staticTripBookings = _tripBookings;
          _staticEventBookings = _eventBookings;
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
    try {
      final fetchResults = await Future.wait([
        ApiService.get('/sadhana/updates').catchError((e) => []),
        ApiService.get('/accommodations/queue').catchError((e) => []),
      ]);
      dynamic updatesData = fetchResults[0];
      dynamic accQueueData = fetchResults[1];

      debugPrint('=== DEBUG PREACHER DASHBOARD: /sadhana/updates RESPONSE ===');
      debugPrint('Runtime type of updatesData: ${updatesData.runtimeType}');

      List<dynamic> extractList(dynamic data) {
        if (data is List) return List.from(data);
        if (data is Map) {
          for (var key in ['items', 'updates', 'data', 'records', 'results', 'sadhana', 'history', 'logs', 'sadhanaUpdates', 'accommodations']) {
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

      void mergeAccommodations(dynamic accData) {
        for (var acc in extractList(accData)) {
          if (acc is Map) {
            final reqDetails = (acc['requestDetails'] ?? acc['description'] ?? '').toString();
            final userObj = acc['user'] ?? acc['student'] ?? acc['worker'];
            final wId = userObj is Map ? (userObj['_id'] ?? userObj['id']) : (acc['worker_id'] ?? acc['userId'] ?? acc['studentId']);
            final wName = userObj is Map ? userObj['name'] : (acc['worker_name'] ?? acc['userName'] ?? acc['studentName'] ?? 'Student');
            final status = (acc['status'] ?? '').toString().toUpperCase();
            final isDone = status == 'APPROVED' || acc['is_completed'] == true;
            final room = acc['assignedRoom'] ?? acc['work_completed'] ?? '';
            rawUpdates.add({
              '_id': acc['_id'] ?? acc['id'],
              'id': acc['id'] ?? acc['_id'],
              'worker_id': wId,
              'worker_name': wName,
              'category': 'accommodation',
              'work_started': 'Accommodation Booking',
              'description': reqDetails,
              'work_completed': isDone ? (room.toString().isNotEmpty ? 'ROOM: $room' : 'Approved') : (status.isNotEmpty ? status : 'PENDING'),
              'is_completed': isDone,
              'created_at': acc['createdAt'] ?? acc['created_at'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
      }

      mergeAccommodations(accQueueData);

      debugPrint('Total raw updates extracted: ${rawUpdates.length}');
      if (rawUpdates.isNotEmpty) {
        debugPrint('Sample raw update record #0: ${rawUpdates.first}');
      }

      final Set<String> seenRawIds = {};
      final List<dynamic> uniqueRawUpdates = [];
      for (var item in rawUpdates) {
        if (item is Map) {
          final itemId = (item['_id'] ?? item['id'] ?? item['appointmentId'] ?? '').toString();
          if (itemId.isNotEmpty) {
            if (seenRawIds.contains(itemId)) continue;
            seenRawIds.add(itemId);
          }
        }
        uniqueRawUpdates.add(item);
      }

      final List<dynamic> processedUpdates = _normalizeSadhanaItems(uniqueRawUpdates);
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
          _staticAllUpdates = grouped;
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
          _staticAnnouncements = _announcements;
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
    final Set<String> seenPendingIds = {};
    for (var list in _allUpdates.values) {
      for (var u in list) {
        final cat = u['category'];
        final id = (u['_id'] ?? u['id'] ?? u['appointmentId'] ?? '').toString();
        if (cat == 'preacher_appointment' || cat == 'accommodation' || cat == 'residency_admission') {
          final isDone = u['is_completed'] == true || u['work_completed'] == 'APPROVED' || u['status'] == 'APPROVED';
          if (!isDone) {
            if (id.isEmpty || seenPendingIds.add(id)) {
              pendingUpdatesCount++;
            }
          }
        } else if (cat == 'payment') {
          final workCompleted = u['work_completed'] ?? '';
          if (u['is_completed'] == false && (workCompleted == 'SUBMITTED' || workCompleted == 'WAITING_APPROVAL')) {
            if (id.isEmpty || seenPendingIds.add(id)) {
              pendingUpdatesCount++;
            }
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
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: 'Explore',
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
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
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
            'Explore Control Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildServiceListItem(
                title: 'Student List',
                icon: Icons.people_outline_rounded,
                onTap: () => setState(() => _activeTab = 'student_list'),
              ),
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
