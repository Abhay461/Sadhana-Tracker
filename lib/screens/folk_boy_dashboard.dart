import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform, Directory;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'resident_enrollment_form_screen.dart';
import 'student_payment_screen.dart';
import '../utils/notification_helper.dart';

class FolkBoyDashboard extends StatefulWidget {
  const FolkBoyDashboard({super.key});

  @override
  State<FolkBoyDashboard> createState() => _FolkBoyDashboardState();
}

class _FolkBoyDashboardState extends State<FolkBoyDashboard> {
  static const _screenTimeChannel = MethodChannel('com.example.mobile_app/screen_time');
  static const _downloadChannel = MethodChannel('com.example.mobile_app/media_download');
  
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preacher;
  List<dynamic> _updates = [];
  List<Map<String, dynamic>> _announcements = [];
  Map<String, dynamic>? _todayDarshan;
  Map<String, dynamic>? _todayQuote;
  Map<String, dynamic>? _todayFestival;
  bool _isLoadingProfile = true;
  bool _isAutoPromoting = false;
  bool _showPersonalInfoCard = false;

  int _selectedIndex = 0;
  DateTime? _selectedHistoryDate;
  DateTime? _lastBackPressTime;

  String? _photoUrl;
  bool _isSavingProfile = false;
  final ImagePicker _picker = ImagePicker();

  final Map<String, bool> _savingStatus = {};

  final _roundsController = TextEditingController(text: '16');
  final _bookController = TextEditingController();
  final _readingValueController = TextEditingController();
  final String _readingUnit = 'Pages';
  final _serviceNameController = TextEditingController();
  final _serviceMinutesController = TextEditingController();

  TimeOfDay _manglaStartTime = const TimeOfDay(hour: 4, minute: 30);
  final TimeOfDay _onlineStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _onlineEndTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _sbStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _sbEndTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _bgStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _bgEndTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 5, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
  final DateTime _templeVisitDate = DateTime.now();
  String _ekadashiFastingType = 'Water Fasting';

  final PageController _pageController = PageController();
  int _currentAnnouncementIndex = 0;
  Timer? _carouselTimer;

  final PageController _youtubePageController = PageController();
  int _currentYouTubeIndex = 0;
  Timer? _youtubeTimer;

  static const String _razorpayApiKey = 'rzp_test_Tb22VLcoOG6jA0';
  static const String _razorpaySecret = 'PX2qUQCiLui8JEdzuzwzTdbK';
  Razorpay? _razorpay;

  List<Map<String, dynamic>> _dynamicCourses = [];
  bool _isLoadingCourses = true;

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
    _ensureFolkLogoAsset();
    _ensureMalaAsset();
    _loadProfileAndData();
    _fetchAnnouncements();
    _fetchDailyDarshan();
    _fetchDailyQuote();
    _fetchTodayFestival();
    _fetchCourses();
    _initRazorpay();
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await ApiService.get('/courses');
      if (response != null && response is List && response.isNotEmpty) {
        if (mounted) {
          setState(() {
            _dynamicCourses = List<Map<String, dynamic>>.from(response);
            _isLoadingCourses = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching backend courses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
    }
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    _showDonationThankYouDialog(response.paymentId);
  }

  void _showDonationThankYouDialog(String? paymentId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Color(0xFFEA580C),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hare Krishna! 🙏',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Thanks For Donation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your generous contribution supports Vedic wisdom and community programs. May Lord Krishna bless you!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (paymentId != null && paymentId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Payment ID: $paymentId',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: 130,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed/Cancelled: ${response.message ?? "User cancelled"}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _ensureFolkLogoAsset() {
    try {
      final source = File(r'C:\Users\LENOVO\.gemini\antigravity-ide\brain\a1f70f4f-b3fa-4396-93cf-9341234f786e\media__1788678205664.png');
      final target = File(r'd:\work update app\mobile_app\assets\folk_logo.png');
      if (source.existsSync() && (!target.existsSync() || target.lengthSync() != source.lengthSync())) {
        source.copySync(target.path);
      }
    } catch (_) {}
  }

  void _ensureMalaAsset() {
    try {
      final source = File(r'C:\Users\LENOVO\.gemini\antigravity-ide\brain\67ab79e3-d4b0-402f-89e2-f291e8a4076b\media__1789215025049.png');
      final target = File(r'd:\work update app\mobile_app\assets\mala.png');
      if (source.existsSync() && (!target.existsSync() || target.lengthSync() != source.lengthSync())) {
        source.copySync(target.path);
      }
    } catch (_) {}
  }

  Future<void> _fetchDailyDarshan() async {
    try {
      final response = await ApiService.get('/daily-darshan/today');
      if (response != null && response is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _todayDarshan = response;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching daily darshan: $e');
    }
  }

  Future<void> _fetchDailyQuote() async {
    try {
      final response = await ApiService.get('/daily-quotes/today');
      if (response != null && response is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _todayQuote = response;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching daily quote: $e');
    }
  }

  Future<void> _fetchTodayFestival() async {
    try {
      final response = await ApiService.get('/festivals/today');
      if (response != null && response is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _todayFestival = response;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _todayFestival = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching today festival: $e');
      if (mounted) {
        setState(() {
          _todayFestival = null;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _razorpay?.clear();
    } catch (_) {}
    _carouselTimer?.cancel();
    _youtubeTimer?.cancel();
    _pageController.dispose();
    _youtubePageController.dispose();
    _roundsController.dispose();
    _bookController.dispose();
    _readingValueController.dispose();
    _serviceNameController.dispose();
    _serviceMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndData({Map<String, dynamic>? initialProfile}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      Map<String, dynamic> profileData;
      if (initialProfile != null) {
        profileData = Map<String, dynamic>.from(initialProfile);
      } else {
        final response = await ApiService.get('/users/me');
        if (response is! Map) {
          throw StateError('The profile service returned an invalid response.');
        }
        profileData = Map<String, dynamic>.from(response);
      }

      profileData['id'] ??= profileData['_id'];
      profileData['photo_url'] ??= profileData['photoUrl'];
      profileData['preacher_id'] ??= profileData['preacherId'];

      final role = profileData['role'] as String?;
      if (role != 'folk_boy' && role != 'residency') {
        if (mounted) {
          if (role == 'preacher') {
            Navigator.pushReplacementNamed(context, '/preacher');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
        return;
      }

      Map<String, dynamic>? resolvedPreacher;
      if (profileData['preacher'] is Map) {
        resolvedPreacher = Map<String, dynamic>.from(profileData['preacher'] as Map);
      } else if (profileData['preacher_id'] is Map) {
        resolvedPreacher = Map<String, dynamic>.from(profileData['preacher_id'] as Map);
      } else if (profileData['preacherId'] is Map) {
        resolvedPreacher = Map<String, dynamic>.from(profileData['preacherId'] as Map);
      } else {
        final preacherId = (profileData['preacher_id'] ?? profileData['preacherId'] ?? profileData['preacher'])?.toString();
        final preacherName = (profileData['preacher_name'] ?? profileData['preacherName'])?.toString();

        if (preacherId != null && preacherId.isNotEmpty) {
          try {
            final preachersData = await ApiService.get('/users/preachers');
            if (preachersData is List) {
              final match = preachersData.firstWhere(
                (p) => (p['id'] ?? p['_id'])?.toString() == preacherId || p['name'] == preacherName,
                orElse: () => null,
              );
              if (match is Map) {
                resolvedPreacher = Map<String, dynamic>.from(match);
              }
            }
          } catch (err) {
            debugPrint('Error resolving preacher from API: $err');
          }
        }

        if (resolvedPreacher == null && ((preacherId != null && preacherId.isNotEmpty) || (preacherName != null && preacherName.isNotEmpty))) {
          resolvedPreacher = {
            'id': preacherId ?? 'preacher_default',
            'name': (preacherName != null && preacherName.isNotEmpty) ? preacherName : 'Assigned Preacher',
          };
        }
      }

      if (resolvedPreacher != null) {
        profileData['preacher_id'] ??= resolvedPreacher['id'] ?? resolvedPreacher['_id'];
      }

      setState(() {
        _profile = profileData;
        _preacher = resolvedPreacher;
        _photoUrl = profileData['photo_url'];
        _isLoadingProfile = false;
      });

      await _fetchUpdates();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  List<dynamic> _normalizeSadhanaItems(List<dynamic> rawList) {
    List<dynamic> result = [];

    for (var u in rawList) {
      if (u is! Map) continue;

      if (u.containsKey('work_started') || (u.containsKey('category') && u['category'] != 'folk_sadhna')) {
        result.add(u);
        continue;
      }

      final String date = (u['dateString'] ?? u['date'] ?? '').toString();
      if (date.isEmpty) continue;

      final activities = u['activities'];
      if (activities is Map) {
        if (activities.containsKey('wakeUpTime') && activities['wakeUpTime'] != null) {
          final val = activities['wakeUpTime'].toString();
          result.add({
            'id': u['_id'] ?? u['id'],
            'date': date,
            'category': 'folk_sadhna',
            'work_started': 'Morning (Wake-up: $val)',
            'work_completed': val,
            'is_completed': true,
            'points': 5,
          });
        }

        if (activities.containsKey('sleepTime') && activities['sleepTime'] != null) {
          final val = activities['sleepTime'].toString();
          result.add({
            'id': u['_id'] ?? u['id'],
            'date': date,
            'category': 'folk_sadhna',
            'work_started': 'Sleep (Time: $val)',
            'work_completed': val,
            'is_completed': true,
            'points': 5,
          });
        }

        if (activities.containsKey('manglaArti') && activities['manglaArti'] is Map) {
          final m = activities['manglaArti'] as Map;
          if (m['attended'] == true) {
            final time = m['time'] ?? '04:30 AM';
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Mangla Arti ($time)',
              'work_completed': time,
              'is_completed': true,
              'points': 10,
            });
          }
        }

        if (activities.containsKey('chanting') && activities['chanting'] is Map) {
          final c = activities['chanting'] as Map;
          final rounds = c['rounds'];
          if (rounds != null && rounds != 0) {
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Chanting - $rounds rounds',
              'work_completed': '$rounds rounds',
              'is_completed': true,
              'points': 10,
            });
          }
        }

        if (activities.containsKey('onlineSession') && activities['onlineSession'] is Map) {
          final o = activities['onlineSession'] as Map;
          if (o['attended'] == true) {
            final timeSpan = (o['timeSpan'] ?? o['time'] ?? o['duration'] ?? '').toString();
            final cleaned = _cleanDurationOnly(timeSpan);
            final displaySpan = cleaned.isNotEmpty && cleaned.toLowerCase() != 'attended' ? cleaned : 'Attended';
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': displaySpan != 'Attended' ? 'Online Session ($displaySpan)' : 'Online Session',
              'work_completed': displaySpan,
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('bookReading') && activities['bookReading'] is Map) {
          final b = activities['bookReading'] as Map;
          final book = b['bookName'];
          if (book != null && book.toString().isNotEmpty) {
            final pages = b['pagesOrMinutes'] ?? '30 mins';
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Book Reading - $book',
              'work_completed': pages,
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('service') && activities['service'] is Map) {
          final s = activities['service'] as Map;
          final name = s['serviceName'];
          if (name != null && name.toString().isNotEmpty) {
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Service - $name',
              'work_completed': '${s['durationMinutes'] ?? 30} mins',
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('templeVisit') && activities['templeVisit'] is Map) {
          final t = activities['templeVisit'] as Map;
          if (t['visited'] == true) {
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Temple Visit',
              'work_completed': 'Visited',
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('srimadBhagavatamClass') && activities['srimadBhagavatamClass'] is Map) {
          final sb = activities['srimadBhagavatamClass'] as Map;
          if (sb['attended'] == true) {
            final timeSpan = (sb['timeSpan'] ?? sb['time'] ?? sb['duration'] ?? '').toString();
            final cleaned = _cleanDurationOnly(timeSpan);
            final displaySpan = cleaned.isNotEmpty && cleaned.toLowerCase() != 'attended' ? cleaned : 'Attended';
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': displaySpan != 'Attended' ? 'Srimad Bhagavatam Class ($displaySpan)' : 'Srimad Bhagavatam Class',
              'work_completed': displaySpan,
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('bhagavadGitaClass') && activities['bhagavadGitaClass'] is Map) {
          final bg = activities['bhagavadGitaClass'] as Map;
          if (bg['attended'] == true) {
            final timeSpan = (bg['timeSpan'] ?? bg['time'] ?? bg['duration'] ?? '').toString();
            final cleaned = _cleanDurationOnly(timeSpan);
            final displaySpan = cleaned.isNotEmpty && cleaned.toLowerCase() != 'attended' ? cleaned : 'Attended';
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': displaySpan != 'Attended' ? 'Bhagavad Gita Class ($displaySpan)' : 'Bhagavad Gita Class',
              'work_completed': displaySpan,
              'is_completed': true,
              'points': 5,
            });
          }
        }

        if (activities.containsKey('ekadashiFasting') && activities['ekadashiFasting'] is Map) {
          final e = activities['ekadashiFasting'] as Map;
          final type = e['fastingType'];
          if (type != null && type.toString().isNotEmpty && type != 'No Fasting') {
            result.add({
              'id': u['_id'] ?? u['id'],
              'date': date,
              'category': 'folk_sadhna',
              'work_started': 'Ekadashi Fasting ($type)',
              'work_completed': type,
              'is_completed': true,
              'points': 10,
            });
          }
        }
      }
    }

    return result;
  }

  int _fetchUpdatesRequestId = 0;

  Future<void> _fetchUpdates() async {
    if (_profile == null) return;
    final requestId = ++_fetchUpdatesRequestId;
    try {
      List<dynamic> data = [];
      dynamic res;
      try {
        res = await ApiService.get('/sadhana/history');
        debugPrint('📋 [DEBUG] Raw /sadhana/history response type: ${res.runtimeType}');
        if (res is Map) debugPrint('📋 [DEBUG] Response keys: ${res.keys.toList()}');
        if (res is Map && res.containsKey('items')) {
          data = res['items'] as List;
        } else if (res is List) {
          data = res;
        } else if (res is Map) {
          // Maybe response is a single Map with activities
          data = [res];
        }
        debugPrint('📋 [DEBUG] Parsed data count: ${data.length}');
        for (int i = 0; i < data.length && i < 3; i++) {
          debugPrint('📋 [DEBUG] Item $i: ${data[i]}');
        }
      } catch (e) {
        debugPrint('📋 [DEBUG] Error fetching history: $e');
        try {
          res = await ApiService.get('/sadhana/updates');
          if (res is List) data = res;
        } catch (_) {}
      }

      if (requestId != _fetchUpdatesRequestId) {
        debugPrint('📋 [DEBUG] Skipping outdated _fetchUpdates response (req #$requestId != current #$_fetchUpdatesRequestId)');
        return;
      }

      final normalizedData = _normalizeSadhanaItems(data);
      debugPrint('📋 [DEBUG] Normalized items count: ${normalizedData.length}');
      for (int i = 0; i < normalizedData.length && i < 5; i++) {
        debugPrint('📋 [DEBUG] Normalized $i: date=${normalizedData[i]['date']} work=${normalizedData[i]['work_started']}');
      }
      final cleanUpdates = normalizedData.where((u) => 
        u['category'] != 'accommodation_approval_signal' && 
        u['category'] != 'accommodation_delete_signal'
      ).toList();
      debugPrint('📋 [DEBUG] Clean updates count: ${cleanUpdates.length}');

      if (!mounted) return;
      setState(() {
        _updates = cleanUpdates;
      });

      final approvedResidency = cleanUpdates.any((u) =>
        u['category'] == 'residency_admission' && u['is_completed'] == true
      );
      if (approvedResidency && _profile != null && _profile!['role'] == 'folk_boy' && !_isAutoPromoting) {
        try {
          _isAutoPromoting = true;
          await ApiService.patch('/users/me', {'role': 'residency'});
          await _loadProfileAndData();
          return;
        } catch (e) {
          debugPrint('Error auto-promoting to residency: $e');
        } finally {
          _isAutoPromoting = false;
        }
      }

      _autoSyncScreenTime();
    } catch (e) {
      debugPrint('Error fetching updates: $e');
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final data = await ApiService.get('/announcements');
      if (data is List) {
        final List<Map<String, dynamic>> loadedAnnouncements = [];
        for (var ann in data) {
          final content = (ann['content'] ?? '').toString();
          if (content.startsWith('[TRIP]')) {
            final parts = content.replaceFirst('[TRIP] ', '').split(' | ');
            loadedAnnouncements.add({
              'type': 'trip',
              'id': ann['id'] ?? ann['_id'],
              'title': parts.isNotEmpty ? parts[0] : 'Upcoming Trip',
              'time': parts.length > 1 ? parts[1] : '',
              'banner': parts.length > 2 ? parts[2] : '',
              'link': parts.length > 3 ? parts[3] : '',
            });
          } else if (content.startsWith('[EVENT]')) {
            final parts = content.replaceFirst('[EVENT] ', '').split(' | ');
            loadedAnnouncements.add({
              'type': 'event',
              'id': ann['id'] ?? ann['_id'],
              'title': parts.isNotEmpty ? parts[0] : 'Upcoming Event',
              'time': parts.length > 2 ? '${parts[1]} • ${parts[2]}' : (parts.length > 1 ? parts[1] : ''),
              'banner': parts.length > 3 ? parts[3] : '',
              'link': parts.length > 4 ? parts[4] : '',
            });
          } else if (content.startsWith('[YOUTUBE]')) {
            final parts = content.replaceFirst('[YOUTUBE] ', '').split(' | ');
            final youtubeUrl = parts.length > 2 ? parts[2] : (parts.length > 1 ? parts[1] : '');
            String bannerUrl = parts.length > 1 ? parts[1] : '';
            if (bannerUrl.isEmpty || !bannerUrl.startsWith('http')) {
              final videoId = _extractYouTubeId(youtubeUrl);
              if (videoId != null) {
                bannerUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
              }
            }
            loadedAnnouncements.add({
              'type': 'youtube',
              'id': ann['id'] ?? ann['_id'],
              'title': parts.isNotEmpty ? parts[0] : 'YouTube Video',
              'time': '',
              'banner': bannerUrl,
              'link': youtubeUrl,
            });
          } else {
            loadedAnnouncements.add({
              'type': ann['category'] == 'online_session' ? 'session' : 'announcement',
              'id': ann['id'] ?? ann['_id'],
              'title': ann['title'] ?? 'Announcement',
              'time': ann['session_time'] ?? ann['time'] ?? '',
              'link': ann['link'] ?? '',
              'banner': ann['banner_url'] ?? ann['photo_url'] ?? '',
            });
          }
        }
        if (mounted) {
          setState(() {
            _announcements = loadedAnnouncements;
          });
        }
      }
      _startCarouselTimer();
      _startYouTubeTimer();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_announcements.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentAnnouncementIndex + 1) % _announcements.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _startYouTubeTimer() {
    _youtubeTimer?.cancel();
    final youtubeItems = _announcements.where((a) => a['type'] == 'youtube').toList();
    if (youtubeItems.length > 1) {
      _youtubeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_youtubePageController.hasClients) {
          final nextPage = (_currentYouTubeIndex + 1) % youtubeItems.length;
          _youtubePageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  bool get _isDayLockedByPreacher {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _updates.any((u) => u['category'] == 'folk_lock' && (u['date'] == today));
  }

  Map<String, dynamic>? get _pendingManglaArti {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      return _updates.firstWhere((u) =>
          u['date'] == today &&
          u['is_completed'] == false &&
          u['category'] == 'folk_sadhna' &&
          u['work_started'].toString().toLowerCase().contains('mangla arti'));
    } catch (_) {
      return null;
    }
  }

  void _openSadhanaModal(String type) {
    if (_profile == null) return;
    if (_isDayLockedByPreacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today tracking is locked by your preacher!')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _SadhanaLogSheet(
            logDate: 'Today',
            initialOption: type,
            profileId: _profile!['id'] ?? _profile!['_id'],
            profileName: _profile!['name'],
            preacherName: _preacher?['name'] ?? 'Preacher',
            updates: _updates,
            onSaveSuccess: (msg, [Map<String, dynamic>? localData]) {
              if (localData != null) {
                final targetDate = localData['date'];
                final label = localData['work_started'];
                setState(() {
                  _updates.removeWhere((u) => u['date'] == targetDate && u['work_started'] == label);
                  _updates.insert(0, localData);
                });
              }
              _fetchUpdates();
              _showSuccessDialog(msg);
            },
          ),
        );
      },
    );
  }

  String _cleanAppName(String packageName) {
    final Map<String, String> commonApps = {
      'com.google.android.youtube': 'YouTube',
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.android.chrome': 'Chrome',
      'com.facebook.katana': 'Facebook',
      'com.facebook.orca': 'Messenger',
      'com.twitter.android': 'Twitter / X',
      'com.snapchat.android': 'Snapchat',
      'com.spotify.music': 'Spotify',
      'com.tencent.ig': 'PUBG Mobile',
      'com.supercell.clashofclans': 'Clash of Clans',
      'org.telegram.messenger': 'Telegram',
      'com.microsoft.teams': 'Teams',
      'com.zoom.videomeetings': 'Zoom',
      'com.netflix.mediaclient': 'Netflix',
      'com.amazon.mp3': 'Amazon Music',
      'com.google.android.apps.maps': 'Google Maps',
      'com.google.android.googlequicksearchbox': 'Google Search',
      'com.google.android.apps.photos': 'Google Photos',
      'com.google.android.gm': 'Gmail',
    };

    if (commonApps.containsKey(packageName)) {
      return commonApps[packageName]!;
    }

    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final last = parts.last;
      if (last.toLowerCase() == 'android' && parts.length > 1) {
        final secondLast = parts[parts.length - 2];
        return secondLast[0].toUpperCase() + secondLast.substring(1);
      }
      if (last.length > 1) {
        return last[0].toUpperCase() + last.substring(1);
      }
      return last.toUpperCase();
    }
    return packageName;
  }

  Future<void> _handleScreenTimeLog() async {
    if (_profile == null) return;
    bool dialogShown = false;
    if (!Platform.isAndroid) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Feature Unsupported'),
            content: const Text('Screen time tracking is only supported on Android devices.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final bool hasPermission = await _screenTimeChannel.invokeMethod('checkPermission');
      if (!hasPermission) {
        if (mounted) {
          final grant = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'To track screen time, the app needs "Usage Access" permission.\n\n'
                'Please find this app in the list and enable the toggle.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (grant == true) {
            await _screenTimeChannel.invokeMethod('requestPermission');
          }
        }
        return;
      }

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ).then((_) {
        dialogShown = false;
      });

      final dynamic rawResult = await _screenTimeChannel.invokeMethod('getScreenTime');
      final Map<dynamic, dynamic> result = rawResult is Map<dynamic, dynamic>
          ? rawResult
          : <dynamic, dynamic>{};
      
      final String timeLabel = result['totalLabel']?.toString() ?? '0m';
      
      final dynamic rawApps = result['apps'];
      final List<dynamic> apps = rawApps is List ? rawApps : (rawApps is Map ? rawApps.values.toList() : []);
      final dynamic rawDebug = result['debug'];
      final List<dynamic> debugLog = rawDebug is List ? rawDebug : (rawDebug is Map ? rawDebug.values.toList() : []);
      
      final String method = result['method']?.toString() ?? 'none';
      final int totalMs = (result['totalMs'] is int) ? result['totalMs'] as int : 0;

      debugPrint('ScreenTime: total=$timeLabel, method=$method');

      final List<Map<String, dynamic>> topApps = [];
      for (var app in apps) {
        if (app is Map) {
          final String appName = (app['name'] as String?) ?? _cleanAppName(app['package'] as String? ?? '');
          topApps.add({
            'name': appName,
            'duration': app['duration'] as String? ?? '',
          });
        }
      }

      if (!mounted) return;
      if (dialogShown) {
        Navigator.pop(context);
        dialogShown = false;
      }

      if (totalMs == 0) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(child: Text('Screen Time Debug', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Screen time 0 dikhaya raha hai. Neeche debug info hai — please iska screenshot share karo.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: debugLog.map((line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '$line',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final isAlreadyLogged = _updates.any(
        (u) => u['category'] == 'screen_time' && u['date'] == todayDate,
      );

      final List<String> breakdownLines = [];
      for (var app in topApps) {
        breakdownLines.add('• ${app['name']}: ${app['duration']}');
      }
      final String description = 'Total: $timeLabel\n\nApp Breakdown:\n${breakdownLines.join('\n')}';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.phone_android_outlined, color: Color(0xFFDB2777)),
              const SizedBox(width: 10),
              Expanded(
                child: Text("Today's Screen Time", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDB2777),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'App Usage Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (topApps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No app usage data.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: topApps.length > 10 ? 10 : topApps.length,
                      itemBuilder: (context, idx) {
                        final app = topApps[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  app['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                app['duration'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB2777),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _saveScreenTime(timeLabel, todayDate, isAlreadyLogged, description: description);
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } on PlatformException catch (e) {
      if (mounted) {
        if (dialogShown) {
          try { Navigator.pop(context); } catch (_) {}
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen time error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (dialogShown) {
          try { Navigator.pop(context); } catch (_) {}
          dialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve screen time: $e')),
        );
      }
    }
  }

  Future<void> _autoSyncScreenTime() async {
    try {
      if (!Platform.isAndroid || _profile == null) return;

      final bool hasPermission = await _screenTimeChannel.invokeMethod('checkPermission');
      if (!hasPermission) return;

      final dynamic rawResult = await _screenTimeChannel.invokeMethod('getScreenTime');
      final Map<dynamic, dynamic> result = rawResult is Map<dynamic, dynamic> ? rawResult : <dynamic, dynamic>{};
      
      final String timeLabel = result['totalLabel']?.toString() ?? '0m';
      final int totalMs = (result['totalMs'] is int) ? result['totalMs'] as int : 0;
      if (totalMs == 0) return;

      final dynamic rawApps = result['apps'];
      final List<dynamic> apps = rawApps is List ? rawApps : (rawApps is Map ? rawApps.values.toList() : []);

      final List<String> breakdownLines = [];
      for (var app in apps) {
        if (app is Map) {
          final String appName = (app['name'] as String?) ?? _cleanAppName(app['package'] as String? ?? '');
          breakdownLines.add('• $appName: ${app['duration']}');
        }
      }
      final String description = 'Total: $timeLabel\n\nApp Breakdown:\n${breakdownLines.join('\n')}';

      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final isAlreadyLogged = _updates.any(
        (u) => u['category'] == 'screen_time' && u['date'] == todayDate,
      );

      if (isAlreadyLogged) {
        final existingRecord = _updates.firstWhere(
          (u) => u['category'] == 'screen_time' && u['date'] == todayDate
        );
        final id = existingRecord['id'] ?? existingRecord['_id'];
        await ApiService.patch('/sadhana/updates/$id', {
          'work_started': 'Screen Time: $timeLabel',
          'description': description,
          'work_completed': timeLabel,
        });
      } else {
        final updateData = {
          'worker_id': _profile!['id'] ?? _profile!['_id'],
          'worker_name': _profile!['name'],
          'preacher_name': _preacher?['name'] ?? 'Preacher',
          'work_started': 'Screen Time: $timeLabel',
          'description': description,
          'is_completed': true,
          'work_completed': timeLabel,
          'category': 'screen_time',
          'date': todayDate,
          'points': 0,
        };
        await ApiService.post('/sadhana', updateData);
        NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
      }
      
      await _fetchUpdates();
    } catch (e) {
      debugPrint('AutoSyncScreenTime error: $e');
    }
  }

  Future<void> _saveScreenTime(String duration, String date, bool isUpdate, {String? description}) async {
    if (_profile == null) return;
    
    try {
      final desc = description ?? 'Mobile screen time: $duration';
      if (isUpdate) {
        final existingRecord = _updates.firstWhere(
          (u) => u['category'] == 'screen_time' && u['date'] == date
        );
        final id = existingRecord['id'] ?? existingRecord['_id'];
        await ApiService.patch('/sadhana/updates/$id', {
          'work_started': 'Screen Time: $duration',
          'description': desc,
          'work_completed': duration,
        });
      } else {
        final updateData = {
          'worker_id': _profile!['id'] ?? _profile!['_id'],
          'worker_name': _profile!['name'],
          'preacher_name': _preacher?['name'] ?? 'Preacher',
          'work_started': 'Screen Time: $duration',
          'description': desc,
          'is_completed': true,
          'work_completed': duration,
          'category': 'screen_time',
          'date': date,
          'points': 0,
        };
        await ApiService.post('/sadhana', updateData);
        NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
      }
      
      await _fetchUpdates();
    } catch (e) {
      debugPrint('Error saving screen time: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
      }
    }
  }

  Future<void> _showTripJoinDialog(String title, String link) async {
    try {
      dynamic data;
      try {
        data = await ApiService.get('/sadhana/updates');
      } catch (_) {
        try {
          final h = await ApiService.get('/sadhana/history');
          if (h is Map && h.containsKey('items')) data = h['items'];
        } catch (_) {}
      }
      if (data is List) {
        final existingBookings = data.where((u) => u['category'] == 'trip_attendance' && u['work_started'] == 'Trip: $title').toList();

        if (existingBookings.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You are already registered for $title! Opening link...'),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }
          try {
            launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Could not launch trip link: $e');
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking duplicate trip booking: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        return _JoinBookingDialog(
          title: title,
          category: 'trip',
          initialName: _profile?['name'] ?? '',
          initialMobile: _profile?['whatsapp_number'] ?? '',
          onConfirm: (confirmedName, confirmedMobile) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logging trip booking & launching registration...')),
              );
            }
            try {
              final updateData = {
                'worker_id': _profile!['id'] ?? _profile!['_id'],
                'worker_name': confirmedName,
                'preacher_name': _preacher?['name'] ?? 'Preacher',
                'work_started': 'Trip: $title',
                'description': confirmedMobile,
                'is_completed': true,
                'work_completed': link,
                'category': 'trip_attendance',
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'points': 0,
              };
              await ApiService.post('/sadhana', updateData);
              NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
              _fetchUpdates();
            } catch (e) {
              debugPrint('Error logging trip attendance: $e');
            }

            try {
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('Could not launch trip link: $e');
            }
          },
        );
      },
    );
  }

  Future<void> _showEventJoinDialog(String title, String link) async {
    try {
      dynamic data;
      try {
        data = await ApiService.get('/sadhana/updates');
      } catch (_) {
        data = await ApiService.get('/sadhana/history');
      }
      if (data is List) {
        final existingBookings = data.where((u) => u['category'] == 'event_attendance' && u['work_started'] == 'Event: $title').toList();

        if (existingBookings.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You are already registered for $title! Opening link...'),
                backgroundColor: Colors.teal,
              ),
            );
          }
          try {
            if (link.isNotEmpty) {
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('Could not launch event link: $e');
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking duplicate event booking: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        return _JoinBookingDialog(
          title: title,
          category: 'event',
          initialName: _profile?['name'] ?? '',
          initialMobile: _profile?['whatsapp_number'] ?? '',
          onConfirm: (confirmedName, confirmedMobile) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logging event passes booking & launching registration...')),
              );
            }
            try {
              final updateData = {
                'worker_id': _profile!['id'] ?? _profile!['_id'],
                'worker_name': confirmedName,
                'preacher_name': _preacher?['name'] ?? 'Preacher',
                'work_started': 'Event: $title',
                'description': confirmedMobile,
                'is_completed': true,
                'work_completed': link,
                'category': 'event_attendance',
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'points': 0,
              };
              await ApiService.post('/sadhana', updateData);
              NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
              _fetchUpdates();
            } catch (e) {
              debugPrint('Error logging event attendance: $e');
            }

            try {
              if (link.isNotEmpty) {
                launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Could not launch event link: $e');
            }
          },
        );
      },
    );
  }

  void _showSessionJoinDialog(String title, String link) {
    showDialog(
      context: context,
      builder: (_) {
        return _JoinBookingDialog(
          title: title,
          category: 'session',
          initialName: _profile?['name'] ?? '',
          initialMobile: _profile?['whatsapp_number'] ?? '',
          onConfirm: (confirmedName, confirmedMobile) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logging attendance & launching meeting...')),
              );
            }
            try {
              final updateData = {
                'worker_id': _profile!['id'] ?? _profile!['_id'],
                'worker_name': confirmedName,
                'preacher_name': _preacher?['name'] ?? 'Preacher',
                'work_started': 'Session: $title',
                'description': confirmedMobile,
                'is_completed': true,
                'work_completed': link,
                'category': 'session_attendance',
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'points': 0,
              };
              await ApiService.post('/sadhana', updateData);
              NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
              _fetchUpdates();
            } catch (e) {
              debugPrint('Error logging session attendance: $e');
            }

            try {
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('Could not launch session link: $e');
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Folk Boy Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
              onPressed: () {
                try {
                  FirebaseAuth.instance.signOut().catchError((_) {});
                } catch (_) {}
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Profile Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'We could not load your profile data.\nThis might happen if your account is still being set up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _isLoadingProfile = true);
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await ApiService.post('/auth/sync', {
                        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
                        'email': user.email,
                        'photoUrl': user.photoURL,
                      });
                    }
                  } catch (e) {
                    debugPrint('Auto-recover sync failed: $e');
                  }
                  await _loadProfileAndData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry / Fix Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_selectedIndex == 3 && _servicesSubTab != 0) {
          setState(() {
            _servicesSubTab = 0;
          });
          return;
        }

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit app'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFF0F172A),
              ),
            );
          }
          return;
        }

        SystemNavigator.pop();
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
          index: _selectedIndex > 4 ? 0 : _selectedIndex,
          children: [
            _buildHomeTab(),
            _buildEventsTab(),
            _buildCoursesTab(),
            _buildServicesTab(),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11);
                  }
                  return const TextStyle(color: Color(0xFF94A3B8), fontSize: 11);
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Color(0xFF0F172A));
                  }
                  return const IconThemeData(color: Color(0xFF94A3B8));
                }),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 65,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event_rounded),
                    label: 'Events',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_stories_outlined),
                    selectedIcon: Icon(Icons.auto_stories_rounded),
                    label: 'Courses',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore_rounded),
                    label: 'Explore',
                  ),
                  NavigationDestination(
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

  Widget _buildTodayFestivalCard() {
    if (_todayFestival == null) return const SizedBox.shrink();

    final title = _todayFestival!['title'] as String? ?? 'Today\'s Festival';
    final imageUrl = _todayFestival!['imageUrl'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Stack(
                children: [
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: const Color(0xFFFEF3C7),
                      child: const Center(
                        child: Icon(Icons.festival_rounded, size: 48, color: Color(0xFFD97706)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "TODAY'S FESTIVAL",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "TODAY'S FESTIVAL",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileAndData();
        await _fetchAnnouncements();
        await _fetchDailyDarshan();
        await _fetchDailyQuote();
        await _fetchTodayFestival();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayFestivalCard(),
            _buildInlineSadhanaCard(),
            const SizedBox(height: 20),
            _buildDailyDarshanCard(),
            _buildYouTubeVideoBanners(),
            _buildDailyQuoteCard(),
            () {
              final generalAnnouncements = _announcements.where((a) => a['type'] != 'youtube').toList();
              if (generalAnnouncements.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentAnnouncementIndex = index;
                        });
                      },
                      itemCount: generalAnnouncements.length,
                      itemBuilder: (context, index) {
                        final ann = generalAnnouncements[index];
                        final String title = (ann['title'] ?? '').toString();
                        final String time = (ann['time'] ?? '').toString();
                        final String banner = (ann['banner'] ?? '').toString();
                        final String link = (ann['link'] ?? '').toString();
                        final String type = (ann['type'] ?? 'announcement').toString();

                        return GestureDetector(
                          onTap: () {
                            if (link.isNotEmpty) {
                              if (type == 'session') {
                                _showSessionJoinDialog(title, link);
                              } else if (type == 'trip') {
                                _showTripJoinDialog(title, link);
                              } else if (type == 'event') {
                                _showEventJoinDialog(title, link);
                              } else {
                                launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Stack(
                              children: [
                                if (banner.isNotEmpty) ...[
                                  Image.network(
                                    banner,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFF3F1200),
                                      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white38, size: 40)),
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.black12, Colors.black87],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF3F1200), Color(0xFF1B0B00)],
                                      ),
                                    ),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          type.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (time.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          time,
                                          style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(generalAnnouncements.length, (index) {
                      return Container(
                        width: index == _currentAnnouncementIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _currentAnnouncementIndex ? const Color(0xFF0F172A) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }(),

            if (_isDayLockedByPreacher) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'TRACKING LOCKED BY PREACHER FOR TODAY',
                        style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_pendingManglaArti != null) ...[
              _PendingManglaArtiWidget(
                pendingUpdate: _pendingManglaArti!,
                onComplete: () {
                  _fetchUpdates();
                },
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _getSadhanaRecordForActivityAndDate(String activity, String targetDate) {
    try {
      return _updates.firstWhere((u) {
        final uDate = u['date'] as String? ?? '';
        if (uDate != targetDate) return false;
        final category = u['category'] as String? ?? '';
        if (category != 'folk_sadhna') return false;
        final workStarted = (u['work_started'] ?? '').toString();

        if (activity == 'Chanting') return workStarted.startsWith('Chanting');
        if (activity == 'Mangla Arti') return workStarted.contains('Mangla Arti');
        if (activity == 'Online Session') return workStarted.startsWith('Online Session');
        if (activity == 'Book Reading') return workStarted.startsWith('Book Reading');
        if (activity == 'Service') return workStarted.startsWith('Service');
        if (activity == 'Temple Visit') return workStarted.startsWith('Temple Visit');
        if (activity == 'Srimad Bhagavatam Class') return workStarted.startsWith('Srimad Bhagavatam Class');
        if (activity == 'Bhagavad Gita Class') return workStarted.startsWith('Bhagavad Gita Class');
        if (activity == 'Morning') return workStarted.startsWith('Morning');
        if (activity == 'Sleep') return workStarted.startsWith('Sleep');
        if (activity == 'Ekadashi Fasting' || activity == 'Ekadashi') return workStarted.contains('Ekadashi');
        return false;
      });
    } catch (_) {
      return null;
    }
  }

  String _formatTimeSpanWithDuration(TimeOfDay start, TimeOfDay end) {
    final now = DateTime.now();
    final dtStart = DateTime(now.year, now.month, now.day, start.hour, start.minute);
    var dtEnd = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    if (dtEnd.isBefore(dtStart)) {
      dtEnd = dtEnd.add(const Duration(days: 1));
    }
    final durationMins = dtEnd.difference(dtStart).inMinutes;

    if (durationMins > 0) {
      if (durationMins % 60 == 0) {
        final hrs = durationMins ~/ 60;
        return '$hrs hr${hrs > 1 ? "s" : ""}';
      } else if (durationMins >= 60) {
        final hrs = durationMins ~/ 60;
        final mins = durationMins % 60;
        return '$hrs hr $mins mins';
      } else {
        return '$durationMins mins';
      }
    }
    return '0 mins';
  }

  String _cleanDurationOnly(String str) {
    if (str.isEmpty) return str;
    var s = str.trim();
    while (s.contains('(') && s.contains(')')) {
      final firstParen = s.indexOf('(');
      final lastParen = s.lastIndexOf(')');
      if (lastParen > firstParen) {
        final inside = s.substring(firstParen + 1, lastParen).trim();
        if (inside.toLowerCase() == 'attended') break;
        s = inside;
      } else {
        break;
      }
    }
    if (s.contains(' to ') && (s.contains('AM') || s.contains('PM'))) {
      return 'Attended';
    }
    return s;
  }

  String _getSadhanaValueText(String activity, String workStarted, [String workCompleted = '']) {
    final String ws = workStarted;
    final String wc = workCompleted;

    if (activity == 'Chanting') {
      if (ws.contains('-')) return ws.split('-').skip(1).join('-').trim();
      if (wc.isNotEmpty) return wc;
      return 'Completed';
    } else if (activity == 'Book Reading' || activity == 'Service') {
      if (ws.contains('-')) return ws.split('-').skip(1).join('-').trim();
      if (wc.isNotEmpty) return wc;
      return 'Completed';
    } else if (activity == 'Mangla Arti') {
      if (ws.contains('(')) {
        final firstParen = ws.indexOf('(');
        final lastParen = ws.lastIndexOf(')');
        if (lastParen > firstParen) return ws.substring(firstParen + 1, lastParen).trim();
      }
      if (wc.isNotEmpty) return wc;
      return 'Attended';
    } else if (activity == 'Online Session' || activity == 'Srimad Bhagavatam Class' || activity == 'Bhagavad Gita Class') {
      if (wc.isNotEmpty && wc.toLowerCase() != 'attended' && wc.toLowerCase() != 'completed' && wc != 'null') {
        final cleaned = _cleanDurationOnly(wc);
        if (cleaned.isNotEmpty) return cleaned;
      }
      if (ws.isNotEmpty) {
        final cleaned = _cleanDurationOnly(ws);
        if (cleaned.isNotEmpty && cleaned.toLowerCase() != 'attended' && cleaned != ws) return cleaned;
      }
      return 'Attended';
    } else if (activity == 'Morning') {
      if (ws.contains('Wake-up:')) return ws.split('Wake-up:')[1].replaceAll(')', '').trim();
      if (wc.isNotEmpty) return wc;
      return 'Completed';
    } else if (activity == 'Sleep') {
      if (ws.contains('Time:')) return ws.split('Time:')[1].replaceAll(')', '').trim();
      if (wc.isNotEmpty) return wc;
      return 'Completed';
    } else if (activity == 'Ekadashi Fasting' || activity == 'Ekadashi') {
      if (wc.isNotEmpty && wc.toLowerCase() != 'completed' && wc != 'null') {
        if (wc.contains(':')) return wc.split(':')[1].trim();
        return wc;
      }
      if (ws.contains(':')) return ws.split(':')[1].trim();
      if (ws.contains('(') && ws.contains(')')) {
        final firstParen = ws.indexOf('(');
        final lastParen = ws.lastIndexOf(')');
        if (lastParen > firstParen) return ws.substring(firstParen + 1, lastParen).trim();
      }
      return 'Fasting';
    } else if (activity == 'Temple Visit') {
      if (wc.isNotEmpty) return wc;
      return 'Visited';
    }
    return wc.isNotEmpty ? wc : (ws == activity ? 'Completed' : ws);
  }

  Widget _buildHistoryTab() {
    final List<Map<String, String>> standardActivities = [
      {'key': 'Morning', 'label': 'Morning Wake-Up'},
      {'key': 'Mangla Arti', 'label': 'Mangla Arti'},
      {'key': 'Chanting', 'label': 'Chanting'},
      {'key': 'Online Session', 'label': 'Online Session'},
      {'key': 'Book Reading', 'label': 'Book Reading'},
      {'key': 'Service', 'label': 'Service'},
      {'key': 'Temple Visit', 'label': 'Temple Visit'},
      {'key': 'Srimad Bhagavatam Class', 'label': 'Srimad Bhagavatam Class'},
      {'key': 'Bhagavad Gita Class', 'label': 'Bhagavad Gita Class'},
      {'key': 'Ekadashi Fasting', 'label': 'Ekadashi Fasting'},
      {'key': 'Sleep', 'label': 'Sleep Time'},
    ];

    List<String> targetDates = [];
    if (_selectedHistoryDate != null) {
      targetDates = [DateFormat('yyyy-MM-dd').format(_selectedHistoryDate!)];
    } else {
      final Map<String, List<dynamic>> grouped = {};
      for (var u in _updates) {
        final date = u['date'] as String? ?? '';
        if (date.isNotEmpty) grouped.putIfAbsent(date, () => []);
      }
      targetDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      if (targetDates.isEmpty) {
        targetDates = [DateFormat('yyyy-MM-dd').format(DateTime.now())];
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => setState(() => _servicesSubTab = 0),
              ),
              const Text(
                'Sadhana History Sheet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedHistoryDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedHistoryDate = picked;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF3F1200)),
                          const SizedBox(width: 12),
                          Text(
                            _selectedHistoryDate != null
                                ? DateFormat('dd MMM yyyy').format(_selectedHistoryDate!)
                                : 'Filter by Date',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedHistoryDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _selectedHistoryDate = null;
                    });
                  },
                )
              ]
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadProfileAndData();
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: targetDates.length,
              itemBuilder: (context, index) {
                final dateStr = targetDates[index];

                String displayDate = '';
                try {
                  final parsedDate = DateTime.parse(dateStr);
                  displayDate = DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);
                } catch (_) {
                  displayDate = dateStr;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                      child: Text(
                        displayDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F1200),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table Header Row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Center(
                                    child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: Text('Sadhana Activity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Text('Time / Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 32,
                                  child: Center(
                                    child: Text('Action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Data Rows
                          ...standardActivities.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final act = entry.value;
                            final key = act['key']!;
                            final label = act['label']!;
                            final record = _getSadhanaRecordForActivityAndDate(key, dateStr);
                            final isLogged = record != null;
                            final String workStarted = record != null ? (record['work_started'] ?? '') : '';
                            final String workCompleted = record != null ? (record['work_completed'] ?? '') : '';
                            final String valText = isLogged ? _getSadhanaValueText(key, workStarted, workCompleted) : 'Not Logged';
                            final id = record != null ? (record['id'] ?? record['_id']) : null;
                            final isLast = idx == standardActivities.length - 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isLogged
                                    ? const Color(0xFFF0FDF4)
                                    : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                                borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
                                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Center(
                                      child: Icon(
                                        isLogged ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                        size: 16,
                                        color: isLogged ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: isLogged ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                        color: isLogged ? const Color(0xFF065F46) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      valText,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isLogged ? FontWeight.bold : FontWeight.w500,
                                        color: isLogged ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Center(
                                      child: isLogged && id != null
                                          ? InkWell(
                                              onTap: () {
                                                _handleDeleteUpdate(id, workStarted);
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  int _servicesSubTab = 0;

  Widget _buildServicesTab() {
    return _servicesSubTab == 0 ? _buildServicesList() : _buildHistoryTab();
  }

  Widget _buildServicesList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildServiceListItem(
            title: 'Sadhana & Activity History',
            icon: Icons.history_rounded,
            onTap: () => setState(() => _servicesSubTab = 1),
          ),
          _buildServiceListItem(
            title: 'Donate & Support (Seva)',
            icon: Icons.volunteer_activism_outlined,
            onTap: _showDonationDialog,
          ),
          _buildServiceListItem(
            title: 'Accommodation Booking',
            icon: Icons.hotel_outlined,
            onTap: _handleAccommodationBooking,
          ),
          _buildServiceListItem(
            title: 'Residency Admission Form',
            icon: Icons.apartment_outlined,
            onTap: _handleResidencyAdmission,
          ),
          _buildServiceListItem(
            title: 'Preacher Appointment',
            icon: Icons.chat_bubble_outline,
            onTap: _handlePreacherAppointmentBooking,
          ),
          _buildServiceListItem(
            title: 'Payment Details',
            icon: Icons.account_balance_wallet_outlined,
            onTap: _handlePaymentReminder,
            badgeCount: _updates.where((u) => u['category'] == 'payment' && u['is_completed'] == false && u['work_completed'] != 'SUBMITTED' && u['work_completed'] != 'WAITING_APPROVAL').length,
          ),
          _buildServiceListItem(
            title: 'Contact Preacher',
            icon: Icons.message_outlined,
            onTap: _contactPreacher,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final eventList = _announcements.where((a) => a['type'] == 'event' || a['type'] == 'trip').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Events & Yatra',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${eventList.length} Active',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (eventList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'No upcoming events right now',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...eventList.map((ann) {
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((ann['banner'] as String? ?? '').isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          ann['banner'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF3F1200)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ann['type'].toString().toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                ),
                              ),
                              const Spacer(),
                              if ((ann['time'] as String? ?? '').isNotEmpty)
                                Text(
                                  ann['time'],
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ann['title'] ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final link = ann['link'] as String? ?? '';
                                if (link.isNotEmpty) {
                                  launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                                } else {
                                  _showEventJoinDialog(ann['title'] ?? 'Event', link);
                                }
                              },
                              icon: const Icon(Icons.event_available_rounded, size: 18),
                              label: const Text('Register / View Event'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F1200),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBannerTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showCoursePaymentDialog(Map<String, dynamic> crs) {
    _openRazorpayCheckout(crs, 'ALL');
  }

  void _openRazorpayCheckout(Map<String, dynamic> crs, String method) async {
    final priceStr = (crs['price'] as String? ?? '').replaceAll('₹', '').trim();
    final double priceVal = double.tryParse(priceStr) ?? 499;
    final int amountInPaise = (priceVal * 100).round();

    var options = {
      'key': _razorpayApiKey,
      'amount': amountInPaise,
      'name': 'FOLK Vrindavan',
      'description': 'Course: ${crs['title']}',
      'prefill': {
        'contact': _profile?['mobile_number'] ?? _profile?['whatsapp_number'] ?? '',
        'email': _profile?['email'] ?? '',
        'name': _profile?['full_name'] ?? 'Student',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    bool openedNatively = false;
    try {
      if (_razorpay != null) {
        _razorpay!.open(options);
        openedNatively = true;
      }
    } catch (e) {
      debugPrint('Razorpay native open error: $e');
    }

    if (!openedNatively) {
      _openRazorpayWebCheckout(crs, amountInPaise);
    }
  }

  Future<void> _openRazorpayWebCheckout(Map<String, dynamic> crs, int amountInPaise) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: Color(0xFF0B72E7), strokeWidth: 3)),
              SizedBox(height: 18),
              Text('Opening Razorpay...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              SizedBox(height: 6),
              Text('Please wait...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );

    try {
      final credentials = base64Encode(utf8.encode('$_razorpayApiKey:$_razorpaySecret'));
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/payment_links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode({
          'amount': amountInPaise,
          'currency': 'INR',
          'description': 'Course Payment: ${crs['title']}',
          'customer': {
            'name': _profile?['full_name'] ?? 'Student',
            'contact': _profile?['mobile_number'] ?? _profile?['whatsapp_number'] ?? '',
            'email': _profile?['email'] ?? '',
          },
          'notify': {'sms': true, 'email': true},
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final shortUrl = data['short_url'] as String?;

        if (shortUrl != null && shortUrl.isNotEmpty) {
          final uri = Uri.parse(shortUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Razorpay payment page opened. Complete payment there.'),
                backgroundColor: Color(0xFF0B72E7),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment link not available. Try again.'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        debugPrint('Razorpay error: ${response.statusCode} ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment error (${response.statusCode}). Try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Razorpay error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDonationDialog() {
    final List<int> presetAmounts = [108, 501, 1008, 2100, 5001];
    final List<String> sevaCategories = [
      'General Seva',
      'Annadaan (Food Distribution)',
      'Temple Development',
      'Youth Awakening',
      'Mantra Meditation Kits',
    ];

    String selectedCategory = sevaCategories[0];
    int selectedPreset = 1008;
    final customAmountController = TextEditingController(text: '1008');
    final remarksController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Color(0xFFEA580C),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make a Seva Donation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Support Vedic Wisdom & Community Programs',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Seva Category',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: sevaCategories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedCategory = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Choose Amount (₹)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presetAmounts.map((amt) {
                          final bool isSelected = selectedPreset == amt;
                          return ChoiceChip(
                            label: Text(
                              '₹$amt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFEA580C),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (bool selected) {
                              if (selected) {
                                setModalState(() {
                                  selectedPreset = amt;
                                  customAmountController.text = amt.toString();
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: customAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Enter Custom Amount (₹)',
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && presetAmounts.contains(parsed)) {
                            setModalState(() {
                              selectedPreset = parsed;
                            });
                          } else {
                            setModalState(() {
                              selectedPreset = 0;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: remarksController,
                        decoration: InputDecoration(
                          labelText: 'Optional Remarks / Prayer',
                          hintText: 'e.g. For peace, family well-being',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final double? finalAmt = double.tryParse(customAmountController.text.trim());
                            if (finalAmt == null || finalAmt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid donation amount'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            _openRazorpayDonationCheckout(finalAmt, selectedCategory, remarksController.text.trim());
                          },
                          icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'Proceed to Pay via Razorpay',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openRazorpayDonationCheckout(double amount, String sevaCategory, String remarks) async {
    final int amountInPaise = (amount * 100).round();

    var options = {
      'key': _razorpayApiKey,
      'amount': amountInPaise,
      'name': 'FOLK Vrindavan - Seva Donation',
      'description': 'Donation: $sevaCategory${remarks.isNotEmpty ? " ($remarks)" : ""}',
      'prefill': {
        'contact': _profile?['mobile_number'] ?? _profile?['whatsapp_number'] ?? '',
        'email': _profile?['email'] ?? '',
        'name': _profile?['full_name'] ?? _profile?['name'] ?? 'Devotee',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    bool openedNatively = false;
    try {
      if (_razorpay != null) {
        _razorpay!.open(options);
        openedNatively = true;
      }
    } catch (e) {
      debugPrint('Razorpay native open error: $e');
    }

    if (!openedNatively) {
      _openRazorpayWebCheckout({
        'title': 'Donation - $sevaCategory',
      }, amountInPaise);
    }
  }

  Widget _buildCoursesTab() {
    final List<Map<String, dynamic>> courses = [
      {
        'title': 'Discover Yourself (DYS)',
        'subtitle': 'Science of Self, Mind & Meditation',
        'duration': '6 Sessions',
        'category': 'Foundational',
        'price': '₹499',
        'originalPrice': '₹999',
        'icon': Icons.psychology_rounded,
        'color': const Color(0xFF4F46E5),
        'bg': const Color(0xFFEEF2FF),
        'image': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=600&q=80',
        'description': 'Systematic course exploring life purpose, mind control, karma & meditation practices.',
      },
      {
        'title': 'Bhagavad Gita As It Is',
        'subtitle': '18 Chapters In-Depth Study',
        'duration': '12 Weeks',
        'category': 'Vedic Wisdom',
        'price': '₹999',
        'originalPrice': '₹1999',
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'image': 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=600&q=80',
        'description': 'Learn timeless wisdom for daily life, duty, devotion, and inner peace.',
      },
      {
        'title': 'Spiritual Scientist',
        'subtitle': 'Consciousness & Scientific Evidence',
        'duration': '4 Sessions',
        'category': 'Science & Spirituality',
        'price': '₹349',
        'originalPrice': '₹699',
        'icon': Icons.science_rounded,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFECFDF5),
        'image': 'https://images.unsplash.com/photo-1507413245164-6160d8298b31?auto=format&fit=crop&w=600&q=80',
        'description': 'Scientific inquiry into life, origin of species, consciousness, and cosmology.',
      },
      {
        'title': 'Japa Yoga & Habit Building',
        'subtitle': 'Mastering Mantra Meditation',
        'duration': '3 Weeks',
        'category': 'Practicum',
        'price': '₹299',
        'originalPrice': '₹599',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFFDB2777),
        'bg': const Color(0xFFFDF2F8),
        'image': 'https://images.unsplash.com/photo-1609137144813-7d9921338f24?auto=format&fit=crop&w=600&q=80',
        'description': 'Practical guide to morning habits, mantra meditation focus, and spiritual discipline.',
      },
    ];

    final List<Map<String, dynamic>> displayCourses = _dynamicCourses.isNotEmpty
        ? _dynamicCourses
        : courses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF3F1200), Color(0xFF7C2D12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3F1200).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    right: -15,
                    bottom: -15,
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 130,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.stars_rounded, size: 14, color: Color(0xFF92400E)),
                              SizedBox(width: 4),
                              Text(
                                'FOLK ACADEMY BANNER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E), letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Transform Your Life with Vedic Wisdom',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Explore interactive youth workshops, mind management & mantra meditation courses guided by experienced preachers.',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildBannerTag(Icons.workspace_premium_rounded, 'Certificate'),
                            const SizedBox(width: 8),
                            _buildBannerTag(Icons.groups_rounded, 'Live Sessions'),
                            const SizedBox(width: 8),
                            _buildBannerTag(Icons.sell_rounded, 'Paid Courses'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vedic & Youth Growth Courses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayCourses.length} Available',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...displayCourses.map((crs) {
            final Color themeColor = crs['color'] is Color
                ? crs['color'] as Color
                : const Color(0xFF4F46E5);
            final Color bgColor = crs['bg'] is Color
                ? crs['bg'] as Color
                : const Color(0xFFEEF2FF);
            final IconData icon = crs['icon'] is IconData
                ? crs['icon'] as IconData
                : Icons.auto_stories_rounded;
            final String imageUrl = (crs['image'] ?? crs['bannerImage'] ?? 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=600&q=80').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      errorBuilder: (_, __, ___) => Container(color: themeColor),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: themeColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      crs['category'].toString().toUpperCase(),
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: themeColor),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    crs['title'],
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    crs['subtitle'],
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          crs['description'],
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      crs['duration'],
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      crs['originalPrice'] ?? '',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      crs['price'] ?? '',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showCoursePaymentDialog(crs);
                              },
                              icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                              label: Text('Buy Course (${crs['price']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F1200),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    String formatDate(dynamic val) {
      if (val == null) return '';
      String str = val.toString().trim();
      if (str.isEmpty) return '';
      if (str.contains('T')) {
        str = str.split('T')[0];
      }
      return str;
    }

    String rawWhatsapp = _profile?['whatsapp_number'] ?? _profile?['whatsapp'] ?? _profile?['phoneNumber'] ?? '';
    String displayWhatsapp = rawWhatsapp;
    String displayDob = formatDate(_profile?['dob']);
    String displayJoin = formatDate(_profile?['joiningDate'] ?? _profile?['joining_date']);

    String displayOcc = (_profile?['occupation'] ?? '').toString().trim();
    String displayClg = (_profile?['college'] ?? '').toString().trim();
    String displayCrs = (_profile?['courseYear'] ?? '').toString().trim();
    String displayCity = (_profile?['city'] ?? '').toString().trim();

    if (rawWhatsapp.contains('|')) {
      final parts = rawWhatsapp.split('|');
      displayWhatsapp = parts[0].trim();
      for (var part in parts) {
        final p = part.trim();
        if (p.contains('DOB:') && (displayDob.isEmpty || displayDob == 'N/A')) {
          displayDob = formatDate(p.replaceAll('DOB:', '').trim());
        } else if (p.contains('JOIN:') && (displayJoin.isEmpty || displayJoin == 'N/A')) {
          displayJoin = formatDate(p.replaceAll('JOIN:', '').trim());
        } else if (p.contains('OCC:') && (displayOcc.isEmpty || displayOcc == 'N/A')) {
          displayOcc = p.replaceAll('OCC:', '').trim();
        } else if (p.contains('CLG:') && (displayClg.isEmpty || displayClg == 'N/A')) {
          displayClg = p.replaceAll('CLG:', '').trim();
        } else if (p.contains('CRS:') && (displayCrs.isEmpty || displayCrs == 'N/A')) {
          displayCrs = p.replaceAll('CRS:', '').trim();
        } else if (p.contains('CITY:') && (displayCity.isEmpty || displayCity == 'N/A')) {
          displayCity = p.replaceAll('CITY:', '').trim();
        }
      }
    } else {
      displayWhatsapp = rawWhatsapp.trim();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: _isSavingProfile ? null : _updatePhoto,
                  child: CircleAvatar(
                    radius: 36,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    backgroundColor: const Color(0xFFF1F5F9),
                    child: _photoUrl == null
                        ? Text(
                            (_profile?['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3F1200),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _profile?['name'] ?? 'User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _showPersonalInfoCard = !_showPersonalInfoCard;
                  });
                },
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEEF2F6),
                      child: Icon(Icons.person_outline, color: Color(0xFF3F1200)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _showPersonalInfoCard ? 'Tap to hide profile details' : 'Tap to view profile details',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showPersonalInfoCard = !_showPersonalInfoCard;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showPersonalInfoCard ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 16,
                              color: const Color(0xFF3F1200),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showPersonalInfoCard ? 'Hide Details' : 'View Details',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF3F1200), size: 20),
                      tooltip: 'Edit Personal Information',
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),
              ),
              if (_showPersonalInfoCard) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildProfileInfoRow(Icons.person_outline, 'Full Name', _profile?['name'] ?? '')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileInfoRow(Icons.psychology_outlined, 'Preacher', _preacher?['name'] ?? 'Preacher')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildProfileInfoRow(Icons.phone_android_outlined, 'WhatsApp Number', displayWhatsapp.isNotEmpty ? displayWhatsapp : '-')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileInfoRow(Icons.cake_outlined, 'Date of Birth', displayDob.isNotEmpty ? displayDob : '-')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildProfileInfoRow(Icons.calendar_month_outlined, 'Joining Date', displayJoin.isNotEmpty ? displayJoin : '-')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileInfoRow(Icons.email_outlined, 'Email Address', _profile?['email'] ?? '-')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildProfileInfoRow(Icons.work_outline, 'Occupation', displayOcc.isNotEmpty ? displayOcc : '-')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileInfoRow(Icons.location_city_outlined, 'City / Hometown', displayCity.isNotEmpty ? displayCity : '-')),
                  ],
                ),
                if (displayClg.isNotEmpty && displayClg != 'N/A') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildProfileInfoRow(Icons.school_outlined, 'College / University', displayClg)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildProfileInfoRow(Icons.menu_book_outlined, 'Course & Year', displayCrs.isNotEmpty ? displayCrs : '-')),
                    ],
                  ),
                ],
              ],
            ],
          ),

          const SizedBox(height: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF8FAFC),
                  child: Icon(Icons.help_outline_rounded, color: Color(0xFF3F1200)),
                ),
                title: const Text('About the App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('View app version and description', style: TextStyle(fontSize: 12)),
                onTap: _showAboutDialog,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF8FAFC),
                  child: Icon(Icons.rate_review_outlined, color: Color(0xFF3F1200)),
                ),
                title: const Text('Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('sadhanatracker.in@gmail.com', style: TextStyle(fontSize: 12)),
                onTap: _launchFeedbackEmail,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF8FAFC),
                  child: Icon(Icons.privacy_tip_outlined, color: Color(0xFF3F1200)),
                ),
                title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Read our data and privacy terms', style: TextStyle(fontSize: 12)),
                onTap: _showPrivacyPolicyDialog,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF8FAFC),
                  child: Icon(Icons.star_outline_rounded, color: Color(0xFF3F1200)),
                ),
                title: const Text('Rate the App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Show your support in the store', style: TextStyle(fontSize: 12)),
                onTap: _showRateAppDialog,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF8FAFC),
                  child: Icon(Icons.share_outlined, color: Color(0xFF3F1200)),
                ),
                title: const Text('Share App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Invite other students to track sadhana', style: TextStyle(fontSize: 12)),
                onTap: _shareApp,
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: 190,
              height: 48,
              child: _SwipeToLogoutButton(
                onSwipeCompleted: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF3F1200).withValues(alpha: 0.06),
            child: Icon(icon, color: const Color(0xFF3F1200), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not specified',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePhoto() async {
    setState(() => _isSavingProfile = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        await ApiService.patch('/users/me', {'photoUrl': url});
        setState(() {
          _photoUrl = url;
          _profile!['photo_url'] = url;
          _profile!['photoUrl'] = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error selecting photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('About the App', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sadhana Path Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3F1200))),
            SizedBox(height: 8),
            Text('Version: 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'This application is built to help preachers track the daily devotional sadhana practices (chanting, hearing, reading, and attendance) of their students, building a spiritually active community.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    String formatDate(dynamic val) {
      if (val == null) return '';
      String str = val.toString().trim();
      if (str.isEmpty) return '';
      if (str.contains('T')) {
        str = str.split('T')[0];
      }
      return str;
    }

    String rawWhatsapp = _profile?['whatsapp_number'] ?? _profile?['whatsapp'] ?? _profile?['phoneNumber'] ?? '';
    String displayWhatsapp = rawWhatsapp;
    String displayDob = formatDate(_profile?['dob']);
    String displayJoin = formatDate(_profile?['joiningDate'] ?? _profile?['joining_date']);

    String displayOcc = (_profile?['occupation'] ?? '').toString().trim();
    String displayClg = (_profile?['college'] ?? '').toString().trim();
    String displayCrs = (_profile?['courseYear'] ?? '').toString().trim();
    String displayCity = (_profile?['city'] ?? '').toString().trim();

    if (rawWhatsapp.contains('|')) {
      final parts = rawWhatsapp.split('|');
      displayWhatsapp = parts[0].trim();
      for (var part in parts) {
        final p = part.trim();
        if (p.contains('DOB:') && (displayDob.isEmpty || displayDob == 'N/A')) {
          displayDob = formatDate(p.replaceAll('DOB:', '').trim());
        } else if (p.contains('JOIN:') && (displayJoin.isEmpty || displayJoin == 'N/A')) {
          displayJoin = formatDate(p.replaceAll('JOIN:', '').trim());
        } else if (p.contains('OCC:') && (displayOcc.isEmpty || displayOcc == 'N/A')) {
          displayOcc = p.replaceAll('OCC:', '').trim();
        } else if (p.contains('CLG:') && (displayClg.isEmpty || displayClg == 'N/A')) {
          displayClg = p.replaceAll('CLG:', '').trim();
        } else if (p.contains('CRS:') && (displayCrs.isEmpty || displayCrs == 'N/A')) {
          displayCrs = p.replaceAll('CRS:', '').trim();
        } else if (p.contains('CITY:') && (displayCity.isEmpty || displayCity == 'N/A')) {
          displayCity = p.replaceAll('CITY:', '').trim();
        }
      }
    } else {
      displayWhatsapp = rawWhatsapp.trim();
    }

    final nameController = TextEditingController(text: _profile?['name'] ?? '');
    final whatsappController = TextEditingController(text: displayWhatsapp);
    final emailController = TextEditingController(text: _profile?['email'] ?? '');
    final dobController = TextEditingController(text: displayDob);
    final joinController = TextEditingController(text: displayJoin);
    final List<String> occupationOptions = [
      'Student',
      'Working Professional',
      'Business / Self-Employed',
      'Job Seeker / Other',
    ];

    String selectedOcc = displayOcc.isNotEmpty && occupationOptions.contains(displayOcc)
        ? displayOcc
        : 'Student';

    final occupationController = TextEditingController(text: selectedOcc);
    final collegeController = TextEditingController(text: displayClg);
    final courseYearController = TextEditingController(text: displayCrs);
    final cityController = TextEditingController(text: displayCity);

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Number',
                        prefixIcon: Icon(Icons.phone_android_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Occupation / Status',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: occupationOptions.contains(selectedOcc) ? selectedOcc : 'Student',
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                          items: occupationOptions.map((String option) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedOcc = newValue;
                                occupationController.text = newValue;
                                if (newValue != 'Student') {
                                  collegeController.clear();
                                  courseYearController.clear();
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedOcc == 'Student') ...[
                      TextField(
                        controller: collegeController,
                        decoration: const InputDecoration(
                          labelText: 'College / University Name',
                          prefixIcon: Icon(Icons.school_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: courseYearController,
                        decoration: const InputDecoration(
                          labelText: 'Course & Year',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'City / Native Hometown',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dobController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'Tap to select date',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: joinController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Joining Date',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'Tap to select date',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            joinController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F1200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final whatsapp = whatsappController.text.trim();
                          final email = emailController.text.trim();
                          final dob = dobController.text.trim();
                          final join = joinController.text.trim();
                          final occ = occupationController.text.trim();
                          final clg = collegeController.text.trim();
                          final crs = courseYearController.text.trim();
                          final city = cityController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name cannot be empty')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          try {
                            String formattedWhatsapp = whatsapp;
                            List<String> extraParts = [];
                            if (dob.isNotEmpty) extraParts.add('DOB: $dob');
                            if (join.isNotEmpty) extraParts.add('JOIN: $join');
                            if (occ.isNotEmpty) extraParts.add('OCC: $occ');
                            if (clg.isNotEmpty) extraParts.add('CLG: $clg');
                            if (crs.isNotEmpty) extraParts.add('CRS: $crs');
                            if (city.isNotEmpty) extraParts.add('CITY: $city');
                            if (extraParts.isNotEmpty) {
                              formattedWhatsapp = '$whatsapp | ${extraParts.join(' | ')}';
                            }

                            await ApiService.patch('/users/me', {
                              'name': name,
                              'phoneNumber': whatsapp,
                              'whatsapp_number': formattedWhatsapp,
                              'email': email,
                              'dob': dob.isNotEmpty ? dob : null,
                              'joiningDate': join.isNotEmpty ? join : null,
                              'joining_date': join.isNotEmpty ? join : null,
                              'occupation': occ,
                              'college': clg,
                              'courseYear': crs,
                              'city': city,
                            });

                            nav.pop();
                            await _loadProfileAndData();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Personal Information updated successfully!')),
                            );
                          } catch (e) {
                            debugPrint('Error updating profile: $e');
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to update profile: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchFeedbackEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'sadhanatracker.in@gmail.com',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(emailUri);
      }
    } catch (_) {
      _showFeedbackDialog();
    }
  }

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email: sadhanatracker.in@gmail.com',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your suggestions or report issues here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchFeedbackEmail();
            },
            child: const Text('OPEN EMAIL APP', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last updated: July 9, 2026\n\nThis privacy policy governs your use of the mobile application "Sadhana Path Tracker". The Application helps students record daily spiritual activities (sadhana) and share them with their assigned preachers.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text('1. Information We Collect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  '• Account Info: Name, Email, Phone/WhatsApp, Profile Photo.\n'
                  '• Sadhana Data: Daily spiritual activity entries (chanting rounds, reading logs, wake-up/sleep hours, fasts).\n'
                  '• Usage Stats: Screen time usage statistics (optional).',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text('2. Permissions Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  '• Gallery Access: For uploading profile photo.\n'
                  '• Notification Permission: For daily sadhana reminders.\n'
                  '• Usage Stats Access: To log daily device screen time.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text('3. Data Sharing & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  'We do not sell, rent or share your data with commercial third parties. Your data is encrypted and shared only with your explicitly assigned preacher.\n\nUser data is stored securely using cloud database systems (MongoDB & Cloudinary) protected by NestJS security filters.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text('4. Data Deletion Rights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  'You have the right to request deletion of your account and data at any time. For support or deletion, contact us at: sadhanatracker.in@gmail.com',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
          ),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rate the App', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Would you like to support us by rating this app in the app store?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('LATER', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Redirecting to App Store...')),
              );
            },
            child: const Text('RATE NOW', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.sadhanatracker.app';
    const shareMessage = 'Hare Krishna! 🙏 Track your daily sadhana, lectures, and spiritual activities with the Sadhana Tracker App.\n\nDownload now: $playStoreUrl';

    try {
      Share.share(shareMessage, subject: 'Sadhana Tracker App');
    } catch (_) {
      Clipboard.setData(const ClipboardData(text: shareMessage));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App sharing link copied to clipboard!')),
        );
      }
    }
  }

  void _contactPreacher() {
    if (_profile == null) return;
    if (_preacher == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('No Preacher Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('You do not have a preacher assigned to your profile yet. Please contact the administrator.', style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
            ),
          ],
        ),
      );
      return;
    }

    final rawWhatsapp = (_preacher!['phoneNumber'] ?? _preacher!['whatsapp_number'] ?? _preacher!['phone'] ?? '') as String;
    String preacherWhatsapp = '';
    if (rawWhatsapp.contains('|')) {
      preacherWhatsapp = rawWhatsapp.split('|')[0].trim();
    } else {
      preacherWhatsapp = rawWhatsapp.trim();
    }

    final preacherName = _preacher!['name'] ?? 'Preacher';
    final studentName = _profile!['name'] ?? 'Student';
    final preacherPhoto = _preacher!['photoUrl'] ?? _preacher!['photo_url'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: preacherPhoto != null ? NetworkImage(preacherPhoto) : null,
              backgroundColor: const Color(0xFFF1F5F9),
              child: preacherPhoto == null
                  ? Text(
                      preacherName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              preacherName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Send a direct message to your preacher on WhatsApp',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              if (preacherWhatsapp.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preacher WhatsApp number is not available.')),
                );
                return;
              }
              String cleanPhone = preacherWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanPhone.length == 10) {
                cleanPhone = '91$cleanPhone';
              }
              final whatsappUrl = 'https://wa.me/$cleanPhone';
              final uri = Uri.parse(whatsappUrl);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch WhatsApp')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('WhatsApp launch error: $e');
              }
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSadhanaCard() {
    final List<String> activities = [
      'Morning',
      'Mangla Arti',
      'Chanting',
      'Online Session',
      'Book Reading',
      'Service',
      'Temple Visit',
      'Srimad Bhagavatam Class',
      'Bhagavad Gita Class',
      'Ekadashi Fasting',
      'Sleep',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Sadhana',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.0,
          ),
          itemBuilder: (context, index) {
            return _buildSadhanaGridCard(activities[index]);
          },
        ),
      ],
    );
  }

  Widget _buildSadhanaGridCard(String activity) {
    final loggedDetails = _getSadhanaLoggedDetails(activity);
    final isLogged = loggedDetails != null;

    IconData icon;
    const Color themeColor = Color(0xFF3F1200);
    const Color boxBgColor = Color(0xFFFAF5F0);
    const Color borderColor = Color(0xFFE8DCD5);

    switch (activity) {
      case 'Morning':
        icon = Icons.wb_sunny_rounded;
        break;
      case 'Mangla Arti':
        icon = Icons.wb_twilight_rounded;
        break;
      case 'Chanting':
        icon = Icons.trip_origin_rounded;
        break;
      case 'Online Session':
        icon = Icons.devices_rounded;
        break;
      case 'Book Reading':
        icon = Icons.menu_book_rounded;
        break;
      case 'Service':
        icon = Icons.volunteer_activism_rounded;
        break;
      case 'Temple Visit':
        icon = Icons.temple_hindu_rounded;
        break;
      case 'Srimad Bhagavatam Class':
        icon = Icons.library_books_rounded;
        break;
      case 'Bhagavad Gita Class':
        icon = Icons.auto_stories_rounded;
        break;
      case 'Ekadashi Fasting':
      case 'Ekadashi':
        icon = Icons.spa_rounded;
        break;
      case 'Sleep':
        icon = Icons.bedtime_rounded;
        break;
      default:
        icon = Icons.check_circle_outline_rounded;
    }

    final isLocked = _isDayLockedByPreacher;
    final String titleText = activity == 'Morning'
        ? 'Morning Wake-Up'
        : (activity == 'Sleep' ? 'Sleep Time' : activity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Today tracking is locked by your preacher!')),
                );
              }
            : () async {
                if (activity == 'Morning') {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _wakeUpTime,
                    initialEntryMode: TimePickerEntryMode.dialOnly,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(1.0),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() {
                      _wakeUpTime = time;
                    });
                    await _handleInlineSave('Morning');
                  }
                } else if (activity == 'Mangla Arti') {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _manglaStartTime,
                    initialEntryMode: TimePickerEntryMode.dialOnly,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(1.0),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() {
                      _manglaStartTime = time;
                    });
                    await _handleInlineSave('Mangla Arti');
                  }
                } else if (activity == 'Sleep') {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _sleepTime,
                    initialEntryMode: TimePickerEntryMode.dialOnly,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(1.0),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() {
                      _sleepTime = time;
                    });
                    await _handleInlineSave('Sleep');
                  }
                } else {
                  _openSadhanaModal(activity);
                }
              },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isLogged ? const Color(0xFFECFDF5) : boxBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLogged ? const Color(0xFFA7F3D0) : borderColor,
              width: isLogged ? 1.2 : 0.9,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isLogged ? const Color(0xFFA7F3D0) : themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: activity == 'Chanting'
                    ? Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Image.asset(
                          'assets/mala.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.trip_origin_rounded,
                              size: 13,
                              color: isLogged ? const Color(0xFF047857) : themeColor,
                            );
                          },
                        ),
                      )
                    : Icon(
                        icon,
                        size: 13,
                        color: isLogged ? const Color(0xFF047857) : themeColor,
                      ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: isLogged ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isLogged && loggedDetails.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        loggedDetails,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                isLogged ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 16,
                color: isLogged ? const Color(0xFF059669) : themeColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _optimizeCloudinaryUrl(String url) {
    if (url.contains('res.cloudinary.com') && url.contains('/upload/') && !url.contains('f_auto')) {
      return url.replaceFirst('/upload/', '/upload/f_auto,q_auto,w_600,c_limit/');
    }
    return url;
  }

  static final Map<String, File> _cachedImageFiles = {};

  Future<File?> _getOrCacheImageFile(String imageUrl, String title) async {
    if (imageUrl.isEmpty) return null;
    if (_cachedImageFiles.containsKey(imageUrl)) {
      final f = _cachedImageFiles[imageUrl]!;
      if (f.existsSync()) return f;
    }
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = Directory.systemTemp;
        final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        final fileName = 'share_${cleanTitle}_${imageUrl.hashCode}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        _cachedImageFiles[imageUrl] = file;
        return file;
      }
    } catch (e) {
      debugPrint('Error caching image file for share: $e');
    }
    return null;
  }

  void _preloadImageFiles(List<String> imageUrls, String title) {
    for (final url in imageUrls) {
      if (url.isNotEmpty && !_cachedImageFiles.containsKey(url)) {
        _getOrCacheImageFile(url, title);
      }
    }
  }

  Future<void> _shareImage(String imageUrl, String title) async {
    try {
      if (imageUrl.isEmpty) return;

      // 1. Check if image file is already pre-cached in background
      File? imageFile = _cachedImageFiles[imageUrl];
      if (imageFile == null || !imageFile.existsSync()) {
        // Fetch file if not pre-cached yet
        imageFile = await _getOrCacheImageFile(imageUrl, title);
      }

      final shareText = 'Hare Krishna! 🙏 $title\nDownloaded from Sadhana Tracker App';

      if (imageFile != null && imageFile.existsSync()) {
        // Share actual JPEG image file instantly!
        await Share.shareXFiles(
          [XFile(imageFile.path)],
          text: shareText,
        );
      } else {
        // Fallback to text link if download fails
        await Share.share(
          'Hare Krishna! 🙏 $title:\n$imageUrl\n\nTrack your daily sadhana with Sadhana Tracker App!',
          subject: title,
        );
      }
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  Future<void> _downloadImage(BuildContext context, String imageUrl, String title) async {
    if (imageUrl.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final fileName = 'SadhanaTracker_${cleanTitle}_$timestamp.jpg';

        bool savedToGallery = false;
        File? savedFile;

        // 1. Primary: Use Native Android MediaStore (Saves to Gallery & triggers Mobile System Notification)
        if (Platform.isAndroid) {
          try {
            final result = await _downloadChannel.invokeMethod<bool>('saveImageToGallery', {
              'bytes': bytes,
              'fileName': fileName,
            });
            if (result == true) {
              savedToGallery = true;
            }
          } catch (nativeErr) {
            debugPrint('Native MediaStore save error: $nativeErr');
          }
        }

        // 2. Secondary: Fallback to public Download directory
        if (!savedToGallery) {
          final pathsToTry = [
            '/storage/emulated/0/Download',
            '/sdcard/Download',
            '/storage/emulated/0/Downloads',
          ];
          for (final p in pathsToTry) {
            try {
              final d = Directory(p);
              if (!d.existsSync()) {
                d.createSync(recursive: true);
              }
              final f = File('${d.path}/$fileName');
              await f.writeAsBytes(bytes);
              if (f.existsSync()) {
                savedFile = f;
                break;
              }
            } catch (e) {
              debugPrint('Download path error for $p: $e');
            }
          }
        }

        // 3. Fallback to temp dir if needed
        if (!savedToGallery && (savedFile == null || !savedFile.existsSync())) {
          final tempDir = Directory.systemTemp;
          savedFile = File('${tempDir.path}/$fileName');
          await savedFile.writeAsBytes(bytes);
        }
      } else {
        throw Exception('Server code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
  }

  Widget _buildDailyDarshanCard() {
    if (_todayDarshan == null) return const SizedBox.shrink();

    final title = _todayDarshan!['title'] as String? ?? '';
    final List<dynamic> rawUrls = _todayDarshan!['imageUrls'] is List ? _todayDarshan!['imageUrls'] : [];
    final List<String> imageUrls = rawUrls.map((u) => _optimizeCloudinaryUrl(u.toString())).toList();
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    _preloadImageFiles(imageUrls, 'Daily Darshan');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily Darshan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (title.isNotEmpty)
              Text(
                '($title)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _DailyDarshanCarouselWidget(
          imageUrls: imageUrls,
          title: 'Daily Darshan',
          onTapImage: (idx) => _openFullDarshanDialog(imageUrls, idx, title: 'Daily Darshan'),
          onDownload: (idx) => _downloadImage(context, imageUrls[idx], 'Daily Darshan'),
          onShare: (idx) => _shareImage(imageUrls[idx], 'Daily Darshan'),
        ),
      ],
    );
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'^.*(?:youtu.be\/|v\/|e\/|u\/\w+\/|embed\/|v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url.trim());
    return (match != null && match.group(1)!.length == 11) ? match.group(1) : null;
  }

  Widget _buildYouTubeVideoBanners() {
    final youtubeItems = _announcements.where((a) => a['type'] == 'youtube').toList();
    if (youtubeItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Video',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: (MediaQuery.of(context).size.width - 32) * 9 / 16,
          child: PageView.builder(
            controller: _youtubePageController,
            onPageChanged: (index) {
              setState(() {
                _currentYouTubeIndex = index;
              });
            },
            itemCount: youtubeItems.length,
            itemBuilder: (context, index) {
              final item = youtubeItems[index];
              final title = item['title'] as String? ?? 'YouTube Video';
              final banner = item['banner'] as String? ?? '';
              final link = item['link'] as String? ?? '';

              return GestureDetector(
                onTap: () {
                  if (link.isNotEmpty) {
                    launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (banner.isNotEmpty)
                          Image.network(
                            banner,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
                          )
                        else
                          Container(color: const Color(0xFF1E293B)),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black12, Colors.black87],
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 54,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.play_arrow_rounded, color: Colors.red, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'YouTube',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (youtubeItems.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(youtubeItems.length, (index) {
              return Container(
                width: index == _currentYouTubeIndex ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentYouTubeIndex ? Colors.red : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildDailyQuoteCard() {
    if (_todayQuote == null) return const SizedBox.shrink();

    final List<dynamic> rawUrls = _todayQuote!['imageUrls'] is List ? _todayQuote!['imageUrls'] : [];
    final String singleUrl = _todayQuote!['imageUrl'] as String? ?? '';

    List<String> imageUrls = rawUrls.map((u) => _optimizeCloudinaryUrl(u.toString())).toList();
    if (imageUrls.isEmpty && singleUrl.isNotEmpty) {
      imageUrls = [_optimizeCloudinaryUrl(singleUrl)];
    }

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    _preloadImageFiles(imageUrls, 'Daily Quote');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Daily Quotes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _DailyDarshanCarouselWidget(
          imageUrls: imageUrls,
          title: 'Daily Quote',
          onTapImage: (idx) => _openFullDarshanDialog(imageUrls, idx, title: 'Daily Quote'),
          onDownload: (idx) => _downloadImage(context, imageUrls[idx], 'Daily Quote'),
          onShare: (idx) => _shareImage(imageUrls[idx], 'Daily Quote'),
        ),
      ],
    );
  }

  void _openFullDarshanDialog(List<String> urls, int initialIndex, {String title = 'Daily Image'}) {
    showDialog(
      context: context,
      builder: (context) {
        final PageController pageController = PageController(initialPage: initialIndex);
        int currentIdx = initialIndex;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentUrl = urls[currentIdx];
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: urls.length,
                    onPageChanged: (idx) {
                      setDialogState(() {
                        currentIdx = idx;
                      });
                    },
                    itemBuilder: (context, idx) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: _buildSmartImage(
                            _optimizeCloudinaryUrl(urls[idx]),
                            fit: BoxFit.contain,
                            placeholderBgColor: Colors.black,
                            loadingColor: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${currentIdx + 1} / ${urls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                              tooltip: 'Download',
                              onPressed: () => _downloadImage(context, currentUrl, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                              tooltip: 'Share',
                              onPressed: () => _shareImage(currentUrl, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  static Widget _buildSmartImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Color? placeholderBgColor,
    Color? loadingColor,
  }) {
    if (url.startsWith('data:image/') || url.startsWith('data:')) {
      try {
        final base64String = url.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, err, stack) => Container(
            color: placeholderBgColor ?? const Color(0xFFF1F5F9),
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
        );
      } catch (e) {
        return Container(
          color: placeholderBgColor ?? const Color(0xFFF1F5F9),
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        );
      }
    } else {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: placeholderBgColor ?? const Color(0xFFF1F5F9),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(loadingColor ?? const Color(0xFF0F172A)),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, err, stack) => Container(
          color: placeholderBgColor ?? const Color(0xFFF1F5F9),
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      );
    }
  }

  String? _getSadhanaLoggedDetails(String activity) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String targetDate = today;

    try {
      final match = _updates.firstWhere((u) {
        final uDate = u['date'];
        if (uDate != targetDate) return false;
        final category = u['category'] ?? '';
        if (category != 'folk_sadhna') return false;
        final workStarted = u['work_started'].toString();
        if (activity == 'Chanting') {
          return workStarted.startsWith('Chanting');
        }
        if (activity == 'Mangla Arti') {
          return workStarted.contains('Mangla Arti');
        }
        if (activity == 'Online Session') {
          return workStarted.startsWith('Online Session');
        }
        if (activity == 'Book Reading') {
          return workStarted.startsWith('Book Reading');
        }
        if (activity == 'Service') {
          return workStarted.startsWith('Service');
        }
        if (activity == 'Temple Visit') {
          return workStarted.startsWith('Temple Visit');
        }
        if (activity == 'Srimad Bhagavatam Class') {
          return workStarted.startsWith('Srimad Bhagavatam Class');
        }
        if (activity == 'Bhagavad Gita Class') {
          return workStarted.startsWith('Bhagavad Gita Class');
        }
        if (activity == 'Morning') {
          return workStarted.startsWith('Morning');
        }
        if (activity == 'Sleep') {
          return workStarted.startsWith('Sleep');
        }
        if (activity == 'Ekadashi Fasting' || activity == 'Ekadashi') {
          return workStarted.contains('Ekadashi');
        }
        return false;
      });

      final String ws = match['work_started'].toString();
      final String wc = (match['work_completed'] ?? '').toString();
      return _getSadhanaValueText(activity, ws, wc);
    } catch (_) {
      return null;
    }
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleInlineSave(String activity) async {
    if (_profile == null) return;
    if (_isDayLockedByPreacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today tracking is locked by your preacher!')),
      );
      return;
    }

    setState(() => _savingStatus[activity] = true);

    String label = activity;
    int points = 0;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String targetDate = today;

    if (activity == 'Temple Visit') {
      targetDate = DateFormat('yyyy-MM-dd').format(_templeVisitDate);
    }

    if (activity == 'Chanting') {
      final val = int.tryParse(_roundsController.text);
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number of rounds')),
        );
        setState(() => _savingStatus[activity] = false);
        return;
      }
      label = 'Chanting - $val Rounds';
      points = val >= 16 ? 10 : 5;
    } else if (activity == 'Book Reading') {
      if (_bookController.text.isEmpty || _readingValueController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter book name and reading pages/minutes')),
        );
        setState(() => _savingStatus[activity] = false);
        return;
      }
      label = 'Book Reading - ${_bookController.text} (${_readingValueController.text} $_readingUnit)';
      points = 5;
    } else if (activity == 'Service') {
      if (_serviceNameController.text.isEmpty || _serviceMinutesController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter service name and minutes')),
        );
        setState(() => _savingStatus[activity] = false);
        return;
      }
      label = 'Service - ${_serviceNameController.text} (${_serviceMinutesController.text} Mins)';
      points = 5;
    } else if (activity == 'Mangla Arti') {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, _manglaStartTime.hour, _manglaStartTime.minute);
      final timeStr = DateFormat('hh:mm a').format(dt);
      label = 'Mangla Arti ($timeStr)';
      points = 10;
    } else if (activity == 'Online Session') {
      final spanText = _formatTimeSpanWithDuration(_onlineStartTime, _onlineEndTime);
      label = 'Online Session ($spanText)';
      points = 5;
    } else if (activity == 'Srimad Bhagavatam Class') {
      final spanText = _formatTimeSpanWithDuration(_sbStartTime, _sbEndTime);
      label = 'Srimad Bhagavatam Class ($spanText)';
      points = 5;
    } else if (activity == 'Bhagavad Gita Class') {
      final spanText = _formatTimeSpanWithDuration(_bgStartTime, _bgEndTime);
      label = 'Bhagavad Gita Class ($spanText)';
      points = 5;
    } else if (activity == 'Morning') {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, _wakeUpTime.hour, _wakeUpTime.minute);
      final timeStr = DateFormat('hh:mm a').format(dt);
      label = 'Morning (Wake-up: $timeStr)';
      points = 5;
    } else if (activity == 'Sleep') {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, _sleepTime.hour, _sleepTime.minute);
      final timeStr = DateFormat('hh:mm a').format(dt);
      label = 'Sleep (Time: $timeStr)';
      points = 5;
    } else {
      points = 5;
    }

    final isDuplicate = _updates.any((u) {
      final uDate = u['date'];
      if (uDate != targetDate || u['is_completed'] == false) return false;
      final workStarted = u['work_started'].toString();

      if (activity == 'Service' || activity == 'Book Reading') {
        return workStarted.toLowerCase() == label.toLowerCase();
      }
      return workStarted.toLowerCase().startsWith(activity.toLowerCase());
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have already logged $activity for $targetDate!')),
      );
      setState(() => _savingStatus[activity] = false);
      return;
    }

    try {
      String workCompletedVal = DateFormat('hh:mm a').format(DateTime.now());
      if (activity == 'Morning') {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _wakeUpTime.hour, _wakeUpTime.minute);
        workCompletedVal = DateFormat('hh:mm a').format(dt);
      } else if (activity == 'Sleep') {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _sleepTime.hour, _sleepTime.minute);
        workCompletedVal = DateFormat('hh:mm a').format(dt);
      } else if (activity == 'Mangla Arti') {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _manglaStartTime.hour, _manglaStartTime.minute);
        workCompletedVal = DateFormat('hh:mm a').format(dt);
      } else if (activity == 'Online Session') {
        workCompletedVal = _formatTimeSpanWithDuration(_onlineStartTime, _onlineEndTime);
      } else if (activity == 'Srimad Bhagavatam Class') {
        workCompletedVal = _formatTimeSpanWithDuration(_sbStartTime, _sbEndTime);
      } else if (activity == 'Bhagavad Gita Class') {
        workCompletedVal = _formatTimeSpanWithDuration(_bgStartTime, _bgEndTime);
      } else if (activity == 'Ekadashi Fasting' || activity == 'Ekadashi') {
        workCompletedVal = _ekadashiFastingType;
      }

      final updateData = {
        'worker_id': _profile!['id'] ?? _profile!['_id'],
        'worker_name': _profile!['name'],
        'preacher_name': _preacher?['name'] ?? 'Preacher',
        'category': 'folk_sadhna',
        'work_started': label,
        'description': 'Log date: $targetDate\nCategory: $activity',
        'work_completed': workCompletedVal,
        'is_completed': true,
        'date': targetDate,
        'points': points,
      };

      // 1. Instantly update local list and UI - 0 MILLISECONDS DELAY!
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final localItem = {
        '_id': tempId,
        'id': tempId,
        ...updateData,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _updates.insert(0, localItem);
        _savingStatus[activity] = false;
        if (activity == 'Book Reading') {
          _bookController.clear();
          _readingValueController.clear();
        } else if (activity == 'Service') {
          _serviceNameController.clear();
          _serviceMinutesController.clear();
        }
      });

      if (mounted) {
        _showSuccessDialog('$label logged successfully!');
      }

      // 2. Perform network sync asynchronously in the background
      Future(() async {
        try {
          await ApiService.post('/sadhana', updateData);
          await _fetchUpdates();
        } catch (err) {
          debugPrint('🚨 [SADHANA SYNC ERROR LOG]: $err');
          try {
            await ApiService.post('/sadhana', {
              'dateString': targetDate,
              'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
              'activities': {
                if (activity == 'Morning' || activity == 'Morning Wake-Up') 'wakeUpTime': workCompletedVal,
                if (activity == 'Sleep' || activity == 'Sleep Time') 'sleepTime': workCompletedVal,
                if (activity == 'Mangla Arti') 'manglaArti': {'attended': true, 'time': workCompletedVal},
                if (activity == 'Chanting') 'chanting': {'rounds': 16},
                if (activity == 'Online Session') 'onlineSession': {'attended': true, 'timeSpan': workCompletedVal},
                if (activity == 'Book Reading') 'bookReading': {'bookName': _bookController.text.trim().isEmpty ? 'Book' : _bookController.text.trim()},
                if (activity == 'Service') 'service': {'serviceName': _serviceNameController.text.trim().isEmpty ? 'Service' : _serviceNameController.text.trim()},
                if (activity == 'Temple Visit') 'templeVisit': {'visited': true},
                if (activity == 'Srimad Bhagavatam Class') 'srimadBhagavatamClass': {'attended': true, 'timeSpan': workCompletedVal},
                if (activity == 'Bhagavad Gita Class') 'bhagavadGitaClass': {'attended': true, 'timeSpan': workCompletedVal},
                if (activity == 'Ekadashi Fasting') 'ekadashiFasting': {'fastingType': _ekadashiFastingType.isNotEmpty ? _ekadashiFastingType : 'Fasting'},
              },
            });
            await _fetchUpdates();
          } catch (fallbackErr) {
            debugPrint('🚨 [SADHANA FALLBACK SYNC ERROR LOG]: $fallbackErr');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Sadhana Sync Error: ${fallbackErr.toString()}'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        }
        NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});
      });
    } catch (e) {
      debugPrint('🚨 [SADHANA LOG ERROR]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save log: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus[activity] = false);
    }
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

  void _handleAccommodationBooking() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FolkAccommodationSheet(
          profile: _profile!,
          preacher: _preacher,
          onBookingSuccess: () {
            _fetchUpdates();
          },
        );
      },
    );
  }

  void _handlePreacherAppointmentBooking() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PreacherAppointmentSheet(
          profile: _profile!,
          preacher: _preacher,
          onBookingSuccess: () {
            _fetchUpdates();
          },
        );
      },
    );
  }

  void _handleResidencyAdmission() {
    if (_profile == null) return;

    final hasPendingOrApproved = _updates.any((u) => u['category'] == 'residency_admission');
    if (hasPendingOrApproved) {
      final existing = _updates.where((u) => u['category'] == 'residency_admission').toList();
      if (existing.isEmpty) return;
      final firstExisting = existing.first;
      final isApproved = firstExisting['is_completed'] == true;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle_outline : Icons.pending_outlined,
                color: isApproved ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              const Text('Request Status', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            isApproved
                ? 'Your residency admission request has already been approved! You will be redirected shortly.'
                : 'You have already submitted a residency admission request. It is currently pending approval by your preacher.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentEnrollmentFormScreen(
          profile: _profile!,
          preacher: _preacher,
          onSuccess: () {
            _fetchUpdates();
          },
        ),
      ),
    );
  }

  Future<void> _handleDeleteUpdate(dynamic id, String label) async {
    if (_isDayLockedByPreacher) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sadhana tracking is locked by your preacher! You cannot delete records.')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            'Delete Record',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Are you sure you want to delete "$label"?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      setState(() {
        if (label.isNotEmpty) {
          _updates.removeWhere((u) => u['work_started'] == label);
        } else {
          _updates.removeWhere((u) => u['id'] == id || u['_id'] == id);
        }
      });
      final uriLabel = label.isNotEmpty ? '?label=${Uri.encodeComponent(label)}' : '';
      await ApiService.delete('/sadhana/updates/$id$uriLabel');
      _fetchUpdates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting record: $e');
      _fetchUpdates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  void _handlePaymentReminder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentPaymentScreen()),
    ).then((_) {
      _fetchUpdates();
    });
  }
}

class _PendingManglaArtiWidget extends StatefulWidget {
  final Map<String, dynamic> pendingUpdate;
  final VoidCallback onComplete;

  const _PendingManglaArtiWidget({
    required this.pendingUpdate,
    required this.onComplete,
  });

  @override
  State<_PendingManglaArtiWidget> createState() => _PendingManglaArtiWidgetState();
}

class _PendingManglaArtiWidgetState extends State<_PendingManglaArtiWidget> {
  String _endTime = '';
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alarm, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Mangla Arti is Running!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Started At: ${widget.pendingUpdate['work_started'].toString().split(' (').first}',
            style: const TextStyle(fontSize: 13, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: Navigator.of(context, rootNavigator: true).context,
                      initialTime: TimeOfDay.now(),
                      initialEntryMode: TimePickerEntryMode.dialOnly,
                    );
                    if (time != null) {
                      setState(() {
                        _endTime = time.format(context);
                      });
                    }
                  },
                  child: Text(_endTime == '' ? 'Select End Time' : 'End Time: $_endTime'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (_endTime == '' || _isSaving)
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        try {
                          final currentLabel = widget.pendingUpdate['work_started'] ?? '';
                          final updatedLabel = '$currentLabel to $_endTime)';

                          await ApiService.patch('/sadhana/updates/${widget.pendingUpdate['id'] ?? widget.pendingUpdate['_id']}', {
                            'is_completed': true,
                            'work_completed': _endTime,
                            'work_started': updatedLabel,
                            'description': updatedLabel,
                          });

                          widget.onComplete();
                        } catch (e) {
                          debugPrint('Error completing Mangla Arti: $e');
                        } finally {
                          setState(() => _isSaving = false);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Complete'),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _SadhanaLogSheet extends StatefulWidget {
  final String logDate;
  final String profileId;
  final String profileName;
  final String preacherName;
  final List<dynamic> updates;
  final Function(String msg, [Map<String, dynamic>? localData]) onSaveSuccess;
  final String? initialOption;

  const _SadhanaLogSheet({
    super.key,
    required this.logDate,
    this.initialOption,
    required this.profileId,
    required this.profileName,
    required this.preacherName,
    required this.updates,
    required this.onSaveSuccess,
  });

  @override
  State<_SadhanaLogSheet> createState() => _SadhanaLogSheetState();
}

class _SadhanaLogSheetState extends State<_SadhanaLogSheet> {
  String? _selectedSubOption;
  bool _isLoading = false;

  int _rounds = 16;
  final _roundsController = TextEditingController(text: '16');
  final _bookController = TextEditingController();
  final _readingValueController = TextEditingController();
  String _readingUnit = 'Pages';
  final _serviceNameController = TextEditingController();
  final _serviceMinutesController = TextEditingController();
  
  String _ekadashiFastingType = 'Ekadashi Prasadam (No Grains)';
  final _ekadashiNotesController = TextEditingController();
  
  TimeOfDay _startTime = const TimeOfDay(hour: 4, minute: 30);
  TimeOfDay _classStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _classEndTime = const TimeOfDay(hour: 9, minute: 0);
  late DateTime _templeVisitDate;

  late final List<String> _sadhanaOptions;

  @override
  void initState() {
    super.initState();
    _selectedSubOption = widget.initialOption;
    if (widget.logDate == 'Yesterday') {
      _templeVisitDate = DateTime.now().subtract(const Duration(days: 1));
    } else {
      _templeVisitDate = DateTime.now();
    }
    _sadhanaOptions = [
      'Mangla Arti',
      'Chanting',
      'Online Session',
      'Book Reading',
      'Service',
      'Temple Visit',
      'Srimad Bhagavatam Class',
      'Bhagavad Gita Class',
      'Ekadashi Fasting',
    ];
  }

  @override
  void dispose() {
    _roundsController.dispose();
    _bookController.dispose();
    _readingValueController.dispose();
    _serviceNameController.dispose();
    _serviceMinutesController.dispose();
    _ekadashiNotesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_selectedSubOption == null) return;

    setState(() => _isLoading = true);

    String label = _selectedSubOption!;
    int points = 0;
    String? photoUrl;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String targetDate = today;

    if (widget.logDate == 'Yesterday') {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      targetDate = DateFormat('yyyy-MM-dd').format(yesterday);
    }

    if (_selectedSubOption == 'Temple Visit') {
      targetDate = DateFormat('yyyy-MM-dd').format(_templeVisitDate);
    }

    if (_selectedSubOption == 'Chanting') {
      final val = int.tryParse(_roundsController.text);
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number of rounds')),
        );
        setState(() => _isLoading = false);
        return;
      }
      _rounds = val;
      label = 'Chanting - $_rounds Rounds';
      points = _rounds >= 16 ? 10 : 5;
    } else if (_selectedSubOption == 'Book Reading') {
      if (_bookController.text.isEmpty || _readingValueController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter book name and reading pages/minutes')));
        setState(() => _isLoading = false);
        return;
      }
      label = 'Book Reading - ${_bookController.text} (${_readingValueController.text} $_readingUnit)';
      points = 5;
    } else if (_selectedSubOption == 'Service') {
      if (_serviceNameController.text.isEmpty || _serviceMinutesController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter service name and minutes')));
        setState(() => _isLoading = false);
        return;
      }
      label = 'Service - ${_serviceNameController.text} (${_serviceMinutesController.text} Mins)';
      points = 5;
    } else if (_selectedSubOption == 'Mangla Arti') {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
      final timeStr = DateFormat('hh:mm a').format(dt);
      label = 'Mangla Arti ($timeStr)';
      points = 10;
    } else if (_selectedSubOption == 'Online Session' ||
               _selectedSubOption == 'Srimad Bhagavatam Class' ||
               _selectedSubOption == 'Bhagavad Gita Class') {
      final now = DateTime.now();
      final dtStart = DateTime(now.year, now.month, now.day, _classStartTime.hour, _classStartTime.minute);
      var dtEnd = DateTime(now.year, now.month, now.day, _classEndTime.hour, _classEndTime.minute);
      if (dtEnd.isBefore(dtStart)) {
        dtEnd = dtEnd.add(const Duration(days: 1));
      }
      final startStr = DateFormat('hh:mm a').format(dtStart);
      final endStr = DateFormat('hh:mm a').format(dtEnd);
      final durationMins = dtEnd.difference(dtStart).inMinutes;

      String durationText = '';
      if (durationMins > 0) {
        if (durationMins % 60 == 0) {
          final hrs = durationMins ~/ 60;
          durationText = '$hrs hr${hrs > 1 ? "s" : ""}';
        } else if (durationMins >= 60) {
          final hrs = durationMins ~/ 60;
          final mins = durationMins % 60;
          durationText = '$hrs hr $mins mins';
        } else {
          durationText = '$durationMins mins';
        }
      }

      final spanText = durationText.isNotEmpty ? '$startStr to $endStr ($durationText)' : '$startStr to $endStr';
      label = '$_selectedSubOption ($spanText)';
      points = 5;
    } else if (_selectedSubOption == 'Ekadashi Fasting') {
      final notes = _ekadashiNotesController.text.trim();
      label = 'Ekadashi Fasting: $_ekadashiFastingType${notes.isNotEmpty ? " ($notes)" : ""}';
      points = _ekadashiFastingType == 'No Fasting' ? 0 : 10;
    } else {
      points = 5;
    }

    final isDuplicate = widget.updates.any((u) {
      final uDate = u['date'];
      if (uDate != targetDate || u['is_completed'] == false) return false;
      final workStarted = u['work_started'].toString();
      
      if (_selectedSubOption == 'Service' || _selectedSubOption == 'Book Reading') {
        return workStarted.toLowerCase() == label.toLowerCase();
      }
      return workStarted.toLowerCase().startsWith(_selectedSubOption!.toLowerCase());
    });

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This activity is already logged for this date!')));
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final isMangla = _selectedSubOption == 'Mangla Arti';
      String workCompletedVal = DateFormat('hh:mm a').format(DateTime.now());
      if (isMangla) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
        workCompletedVal = DateFormat('hh:mm a').format(dt);
      } else if (_selectedSubOption == 'Online Session' ||
                 _selectedSubOption == 'Srimad Bhagavatam Class' ||
                 _selectedSubOption == 'Bhagavad Gita Class') {
        final now = DateTime.now();
        final dtStart = DateTime(now.year, now.month, now.day, _classStartTime.hour, _classStartTime.minute);
        var dtEnd = DateTime(now.year, now.month, now.day, _classEndTime.hour, _classEndTime.minute);
        if (dtEnd.isBefore(dtStart)) {
          dtEnd = dtEnd.add(const Duration(days: 1));
        }
        final startStr = DateFormat('hh:mm a').format(dtStart);
        final endStr = DateFormat('hh:mm a').format(dtEnd);
        final durationMins = dtEnd.difference(dtStart).inMinutes;

        String durationText = '';
        if (durationMins > 0) {
          if (durationMins % 60 == 0) {
            final hrs = durationMins ~/ 60;
            durationText = '$hrs hr${hrs > 1 ? "s" : ""}';
          } else if (durationMins >= 60) {
            final hrs = durationMins ~/ 60;
            final mins = durationMins % 60;
            durationText = '$hrs hr $mins mins';
          } else {
            durationText = '$durationMins mins';
          }
        }

        workCompletedVal = durationText.isNotEmpty ? '$startStr to $endStr ($durationText)' : '$startStr to $endStr';
      } else if (_selectedSubOption == 'Ekadashi Fasting') {
        workCompletedVal = _ekadashiFastingType;
      }

      final updateData = {
        'worker_id': widget.profileId,
        'worker_name': widget.profileName,
        'preacher_name': widget.preacherName,
        'work_started': label,
        'description': label,
        'is_completed': true,
        'work_completed': workCompletedVal,
        'category': 'folk_sadhna',
        'date': targetDate,
        'points': points,
        'photo_url': photoUrl,
      };
      await ApiService.post('/sadhana', updateData);
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) Navigator.pop(context);
      widget.onSaveSuccess('$label logged successfully!', updateData);
    } catch (e) {
      debugPrint('🚨 [SADHANA SHEET ERROR LOG]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to log sadhana: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedSubOption ?? 'Sadhana',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            if (_selectedSubOption == null) ...[
              const Text('Select Activity', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sadhanaOptions.map((opt) {
                  return ChoiceChip(
                    label: Text(opt, style: TextStyle(fontSize: 12, color: _selectedSubOption == opt ? Colors.white : Colors.black87)),
                    selected: _selectedSubOption == opt,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubOption = opt;
                      });
                    },
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
              )
            ] else ...[
              if (_selectedSubOption == 'Chanting') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rounds Completed:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _roundsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              hintText: 'Enter rounds, e.g. 16',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null) {
                                _rounds = parsed;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Quick Select:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [8, 16, 20, 24, 32].map((r) {
                        return ActionChip(
                          label: Text('$r Rounds'),
                          onPressed: () {
                            setState(() {
                              _roundsController.text = r.toString();
                              _rounds = r;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ] else if (_selectedSubOption == 'Book Reading') ...[
                TextField(
                  controller: _bookController,
                  decoration: const InputDecoration(labelText: 'Book Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _readingValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pages/Mins read', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _readingUnit,
                      items: ['Pages', 'Minutes'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _readingUnit = val);
                      },
                    )
                  ],
                ),
              ] else if (_selectedSubOption == 'Service') ...[
                TextField(
                  controller: _serviceNameController,
                  decoration: const InputDecoration(labelText: 'Service Done (e.g. Cooking, Cleaning)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes Invested', border: OutlineInputBorder()),
                ),
              ] else if (_selectedSubOption == 'Mangla Arti') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: Navigator.of(context, rootNavigator: true).context,
                          initialTime: _startTime,
                          initialEntryMode: TimePickerEntryMode.dialOnly,
                        );
                        if (time != null) setState(() => _startTime = time);
                      },
                      child: Text(_startTime.format(context)),
                    )
                  ],
                ),
              ] else if (_selectedSubOption == 'Online Session' ||
                         _selectedSubOption == 'Srimad Bhagavatam Class' ||
                         _selectedSubOption == 'Bhagavad Gita Class') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(_classStartTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: Navigator.of(context, rootNavigator: true).context,
                              initialTime: _classStartTime,
                              initialEntryMode: TimePickerEntryMode.dialOnly,
                            );
                            if (time != null) {
                              setState(() {
                                _classStartTime = time;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('End Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(_classEndTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: Navigator.of(context, rootNavigator: true).context,
                              initialTime: _classEndTime,
                              initialEntryMode: TimePickerEntryMode.dialOnly,
                            );
                            if (time != null) {
                              setState(() {
                                _classEndTime = time;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ] else if (_selectedSubOption == 'Temple Visit') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Visit Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('dd MMM yyyy').format(_templeVisitDate)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _templeVisitDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _templeVisitDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ] else if (_selectedSubOption == 'Ekadashi Fasting') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fasting Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _ekadashiFastingType,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Water Fasting', child: Text('Water Fasting')),
                        DropdownMenuItem(value: 'Fruit Fasting', child: Text('Fruit Fasting')),
                        DropdownMenuItem(value: 'Ekadashi Prasadam (No Grains)', child: Text('Ekadashi Prasadam (No Grains)')),
                        DropdownMenuItem(value: 'No Fasting', child: Text('No Fasting / Unable to Fast')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _ekadashiFastingType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Fasting Details / Notes (Optional):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ekadashiNotesController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Broke fast next day at Paran time',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Click Save below!', style: TextStyle(fontStyle: FontStyle.italic)),
                )
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _FolkAccommodationSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? preacher;
  final VoidCallback onBookingSuccess;

  const _FolkAccommodationSheet({
    required this.profile,
    this.preacher,
    required this.onBookingSuccess,
  });

  @override
  State<_FolkAccommodationSheet> createState() => _FolkAccommodationSheetState();
}

class _FolkAccommodationSheetState extends State<_FolkAccommodationSheet> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  final _ageController = TextEditingController();
  late TabController _tabController;
  
  DateTime? _arrivalDate;
  DateTime? _departureDate;
  bool _isLoading = false;
  
  List<dynamic> _bookings = [];
  bool _isLoadingBookings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.profile['name'] ?? '');
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    try {
      setState(() => _isLoadingBookings = true);
      List<dynamic> bookingsList = [];

      try {
        final accRes = await ApiService.get('/accommodations/my');
        if (accRes is List && accRes.isNotEmpty) {
          bookingsList = accRes.map((item) {
            final details = item['requestDetails']?.toString() ?? '';
            final assignedRoom = item['assignedRoom']?.toString() ?? '';
            final status = item['status']?.toString() ?? 'PENDING';
            return {
              '_id': item['_id'],
              'category': 'accommodation',
              'description': details,
              'is_completed': status == 'APPROVED',
              'work_completed': assignedRoom.isNotEmpty
                  ? 'ROOM: $assignedRoom'
                  : status,
              'created_at': item['createdAt'] ?? DateTime.now().toIso8601String(),
            };
          }).toList();
        }
      } catch (e) {
        debugPrint('Error fetching /accommodations/my: $e');
      }

      if (bookingsList.isEmpty) {
        dynamic res;
        try {
          res = await ApiService.get('/sadhana/history');
        } catch (_) {
          try {
            res = await ApiService.get('/sadhana/updates');
          } catch (_) {}
        }

        List<dynamic> updatesList = [];
        if (res is Map && res.containsKey('items')) {
          updatesList = res['items'] is List ? res['items'] : [];
        } else if (res is List) {
          updatesList = res;
        }

        bookingsList = updatesList.where((u) => u is Map && u['category'] == 'accommodation').toList();
      }

      if (mounted) {
        setState(() {
          _bookings = bookingsList;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) setState(() => _isLoadingBookings = false);
    }
  }

  Future<void> _selectArrivalDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _arrivalDate = picked;
        if (_departureDate != null && _departureDate!.isBefore(picked)) {
          _departureDate = null;
        }
      });
    }
  }

  Future<void> _selectDepartureDate() async {
    if (_arrivalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Arrival Date first!')),
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _arrivalDate!.add(const Duration(days: 1)),
      firstDate: _arrivalDate!,
      lastDate: _arrivalDate!.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_arrivalDate == null || _departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Arrival & Departure Dates.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final age = _ageController.text.trim();
      final arrivalStr = DateFormat('yyyy-MM-dd').format(_arrivalDate!);
      final departureStr = DateFormat('yyyy-MM-dd').format(_departureDate!);

      final requestDetails = 'Name: $name\nAge: $age\nArrival: $arrivalStr\nDeparture: $departureStr';

      final updateData = {
        'worker_id': widget.profile['id'] ?? widget.profile['_id'],
        'worker_name': widget.profile['name'],
        'preacher_name': widget.preacher?['name'] ?? 'Preacher',
        'category': 'accommodation',
        'work_started': 'Accommodation Booking',
        'description': requestDetails,
        'work_completed': '',
        'is_completed': false,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
      };

      final tempItem = {
        ...updateData,
        '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      };

      // 1. Post to NestJS /accommodations endpoint (Populates MongoDB accommodations collection)
      try {
        await ApiService.post('/accommodations', {
          'requestDetails': requestDetails,
        });
      } catch (accError) {
        debugPrint('Error saving to /accommodations endpoint: $accError');
      }

      // 2. Post to /sadhana for real-time activity feed fallback
      await ApiService.post('/sadhana', updateData).catchError((_) {});
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        setState(() {
          _bookings.insert(0, tempItem);
          _arrivalDate = null;
          _departureDate = null;
          _ageController.clear();
        });

        _tabController.animateTo(1);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accommodation booking requested successfully!')),
        );
        widget.onBookingSuccess();
        _fetchBookings();
      }
    } catch (e) {
      debugPrint('Error booking accommodation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Accommodation Booking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'New Booking'),
                Tab(text: 'My Bookings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestTab(),
                _buildBookingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab() {
    if (_isLoadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No accommodation bookings yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bookings.length,
      itemBuilder: (context, idx) {
        final b = _bookings[idx];
        final isCompleted = b['is_completed'] ?? false;
        final details = b['description'] ?? '';
        final roomAllocated = b['work_completed'] ?? '';
        
        String arrivalText = '---';
        String departureText = '---';
        String guestAge = '---';
        String guestName = b['worker_name'] ?? '';

        final lines = details.toString().split('\n');
        for (var line in lines) {
          if (line.startsWith('Arrival: ')) {
            arrivalText = line.replaceAll('Arrival: ', '');
            try {
              final parsed = DateTime.parse(arrivalText);
              arrivalText = DateFormat('dd MMM yyyy').format(parsed);
            } catch (_) {}
          } else if (line.startsWith('Departure: ')) {
            departureText = line.replaceAll('Departure: ', '');
            try {
              final parsed = DateTime.parse(departureText);
              departureText = DateFormat('dd MMM yyyy').format(parsed);
            } catch (_) {}
          } else if (line.startsWith('Age: ')) {
            guestAge = line.replaceAll('Age: ', '');
          } else if (line.startsWith('Name: ')) {
            guestName = line.replaceAll('Name: ', '');
          }
        }

        final status = isCompleted
            ? 'APPROVED'
            : (b['status']?.toString().toUpperCase() ?? 'PENDING');
        final isApproved = status == 'APPROVED';
        final isRejected = status == 'REJECTED';

        Color statusBg = const Color(0xFFFEF3C7);
        Color statusFg = const Color(0xFFD97706);
        if (isApproved) {
          statusBg = const Color(0xFFDCFCE7);
          statusFg = const Color(0xFF15803D);
        } else if (isRejected) {
          statusBg = const Color(0xFFFEE2E2);
          statusFg = const Color(0xFFB91C1C);
        }

        final titleName = guestName.isNotEmpty ? guestName : (widget.profile['name'] ?? 'Booking');
        final ageLabel = (guestAge.isNotEmpty && guestAge != '---') ? ' • Age: $guestAge' : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$titleName$ageLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusFg,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    '$arrivalText  ➔  $departureText',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              if (isApproved && roomAllocated.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room_rounded, color: Color(0xFF0F172A), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Room: ${roomAllocated.toString().replaceAll('ROOM: ', '')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter guest name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter age';
                if (int.tryParse(val) == null) return 'Please enter a valid age';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectArrivalDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ARRIVAL DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _arrivalDate == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy').format(_arrivalDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _arrivalDate == null ? Colors.grey : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectDepartureDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEPARTURE DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _departureDate == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy').format(_departureDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _departureDate == null ? Colors.grey : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _submitBooking,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Submit Request',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreacherAppointmentSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? preacher;
  final VoidCallback onBookingSuccess;

  const _PreacherAppointmentSheet({
    required this.profile,
    this.preacher,
    required this.onBookingSuccess,
  });

  @override
  State<_PreacherAppointmentSheet> createState() => _PreacherAppointmentSheetState();
}

class _PreacherAppointmentSheetState extends State<_PreacherAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  
  final _purposeController = TextEditingController();
  
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  bool _isLoading = false;
  
  List<dynamic> _appointments = [];
  bool _isLoadingAppointments = true;
  List<dynamic> _availablePreachers = [];
  Map<String, dynamic>? _selectedPreacherFromList;

  Map<String, dynamic>? get _effectivePreacher {
    if (widget.preacher != null) return widget.preacher;
    if (_selectedPreacherFromList != null) return _selectedPreacherFromList;
    final preacherId = (widget.profile['preacher_id'] ?? widget.profile['preacherId'] ?? widget.profile['preacher'])?.toString();
    final preacherName = (widget.profile['preacher_name'] ?? widget.profile['preacherName'])?.toString();
    if (preacherName != null && preacherName.isNotEmpty) {
      return {'id': preacherId ?? 'preacher_1', 'name': preacherName};
    }
    if (preacherId != null && preacherId.isNotEmpty) {
      return {'id': preacherId, 'name': 'Assigned Preacher'};
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _fetchPreachersList();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreachersList() async {
    try {
      final data = await ApiService.get('/users/preachers');
      if (data is List && mounted) {
        setState(() {
          _availablePreachers = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching preachers list: $e');
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoadingAppointments = true);
      List<dynamic> res = [];
      dynamic data;
      try {
        data = await ApiService.get('/sadhana/history');
      } catch (_) {
        try {
          data = await ApiService.get('/sadhana/updates');
        } catch (_) {}
      }
      if (data is Map && data.containsKey('items')) {
        data = data['items'];
      }
      if (data is List) {
        res = data.where((u) => u is Map && u['category'] == 'preacher_appointment').toList();
      }

      if (mounted) {
        setState(() {
          _appointments = res;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _appointmentDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _appointmentTime = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    final activePreacher = _effectivePreacher;
    if (activePreacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preacher to book an appointment.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_appointmentDate == null || _appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Date and Time.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_appointmentDate!);
      final timeStr = _appointmentTime!.format(context);
      final bookingStr = 'Appointment: $dateStr @ $timeStr';
      final purpose = _purposeController.text.trim();

      final updateData = {
        'worker_id': widget.profile['id'] ?? widget.profile['_id'],
        'worker_name': widget.profile['name'],
        'preacher_name': activePreacher['name'] ?? 'Preacher',
        'category': 'preacher_appointment',
        'work_started': bookingStr,
        'description': 'Preacher: ${activePreacher['name']}\nDate: $dateStr\nTime: $timeStr\nPurpose: $purpose',
        'work_completed': '',
        'is_completed': false,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
      };

      await ApiService.post('/sadhana', updateData);
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment request submitted successfully!')),
        );
        widget.onBookingSuccess();
        _fetchAppointments();
        _purposeController.clear();
        setState(() {
          _appointmentDate = null;
          _appointmentTime = null;
        });
      }
    } catch (e) {
      debugPrint('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preacher Appointment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                padding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Book New'),
                  Tab(text: 'My Appointments'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildRequestTab(),
                  _buildAppointmentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_isLoadingAppointments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No appointment requests yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _appointments.length,
      itemBuilder: (context, idx) {
        final appt = _appointments[idx];
        final isCompleted = appt['is_completed'] ?? false;
        final details = appt['description'] ?? '';
        
        String dateText = '---';
        String timeText = '---';
        String purposeText = '---';
        String preacherName = appt['preacher_name'] ?? 'Preacher';

        final lines = details.toString().split('\n');
        for (var line in lines) {
          if (line.startsWith('Date: ')) {
            dateText = line.replaceAll('Date: ', '');
            try {
              final parsed = DateTime.parse(dateText);
              dateText = DateFormat('dd MMM yyyy').format(parsed);
            } catch (_) {}
          } else if (line.startsWith('Time: ')) {
            timeText = line.replaceAll('Time: ', '');
          } else if (line.startsWith('Purpose: ')) {
            purposeText = line.replaceAll('Purpose: ', '');
          } else if (line.startsWith('Preacher: ')) {
            preacherName = line.replaceAll('Preacher: ', '');
          }
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[100]!),
          ),
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isCompleted ? 'APPROVED / BOOKED' : 'PENDING APPROVAL',
                        style: TextStyle(
                          color: isCompleted ? const Color(0xFF137333) : const Color(0xFFB06000),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Icon(Icons.check_circle, color: Colors.green[600], size: 24)
                    else
                      Icon(Icons.pending_actions, color: Colors.orange[600], size: 24),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Preacher: $preacherName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DATE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(dateText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TIME', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(timeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.help_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PURPOSE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            purposeText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestTab() {
    final activePreacher = _effectivePreacher;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (activePreacher != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: activePreacher['photo_url'] != null
                        ? NetworkImage(activePreacher['photo_url'])
                        : null,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: activePreacher['photo_url'] == null
                        ? Text((activePreacher['name'] ?? 'P')[0].toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BOOKING WITH PREACHER',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activePreacher['name'] ?? 'Preacher',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('SELECT YOUR PREACHER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  isExpanded: true,
                  hint: const Text('Choose your preacher...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  value: _selectedPreacherFromList,
                  items: _availablePreachers.map((p) {
                    final itemMap = Map<String, dynamic>.from(p as Map);
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: itemMap,
                      child: Text(itemMap['name'] ?? 'Preacher', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPreacherFromList = val;
                    });
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 10),
          
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 12),
                      Text(
                        _appointmentDate == null
                            ? 'Select Appointment Date'
                            : DateFormat('dd MMM yyyy').format(_appointmentDate!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _appointmentDate == null ? FontWeight.normal : FontWeight.bold,
                          color: _appointmentDate == null ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: _selectTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 12),
                      Text(
                        _appointmentTime == null
                            ? 'Select Appointment Time'
                            : _appointmentTime!.format(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _appointmentTime == null ? FontWeight.normal : FontWeight.bold,
                          color: _appointmentTime == null ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _purposeController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Purpose / Topic of Discussion',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              alignLabelWithHint: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the purpose of this appointment';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _submitBooking,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text(
                      'Submit Appointment Request',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinBookingDialog extends StatefulWidget {
  final String title;
  final String category;
  final String initialName;
  final String initialMobile;
  final Function(String name, String mobile) onConfirm;

  const _JoinBookingDialog({
    required this.title,
    required this.category,
    required this.initialName,
    required this.initialMobile,
    required this.onConfirm,
  });

  @override
  State<_JoinBookingDialog> createState() => _JoinBookingDialogState();
}

class _JoinBookingDialogState extends State<_JoinBookingDialog> {
  late final TextEditingController nameController;
  late final TextEditingController mobileController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    final rawMobile = widget.initialMobile;
    final cleanMobile = rawMobile.split(' | ').first.trim();
    mobileController = TextEditingController(text: cleanMobile);
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel = 'Yatra / Trip';
    IconData icon = Icons.directions_bus_outlined;
    Color buttonColor = const Color(0xFF2563EB);
    String confirmLabel = 'Book & Open';
    String descText = 'Confirm details to book your trip and open registration link:';

    if (widget.category == 'event') {
      typeLabel = 'Event Passes';
      icon = Icons.confirmation_number_outlined;
      buttonColor = const Color(0xFF0D9488);
      confirmLabel = 'Book Event';
      descText = 'Confirm details to book event entry passes and get pass link:';
    } else if (widget.category == 'session') {
      typeLabel = 'Online Session';
      icon = Icons.video_camera_front_outlined;
      buttonColor = const Color(0xFF0F9D58);
      confirmLabel = 'Join Session';
      descText = 'Confirm details to register attendance and launch meeting:';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(icon, color: buttonColor),
          const SizedBox(width: 10),
          Expanded(child: Text('Book $typeLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(descText, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: mobileController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'WhatsApp / Mobile Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final name = nameController.text.trim();
            final mobile = mobileController.text.trim();
            if (name.isEmpty || mobile.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter both name and mobile number')),
              );
              return;
            }
            Navigator.pop(context);
            widget.onConfirm(name, mobile);
          },
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _SwipeToLogoutButton extends StatefulWidget {
  final VoidCallback onSwipeCompleted;

  const _SwipeToLogoutButton({required this.onSwipeCompleted});

  @override
  State<_SwipeToLogoutButton> createState() => _SwipeToLogoutButtonState();
}

class _SwipeToLogoutButtonState extends State<_SwipeToLogoutButton> {
  double _dragPosition = 0.0;
  bool _isFinished = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final double buttonSize = 40.0;
        final double maxDrag = trackWidth - buttonSize - 4;

        return Container(
          width: trackWidth,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFEE2E2), width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                left: 38,
                right: 8,
                child: Center(
                  child: Opacity(
                    opacity: (1.0 - (_dragPosition / maxDrag)).clamp(0.2, 1.0),
                    child: Text(
                      _isFinished ? 'LOGGING OUT...' : 'SWIPE TO LOGOUT',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                left: _dragPosition + 2,
                top: 1,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    if (_isFinished) return;
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isFinished) return;
                    setState(() {
                      _isDragging = false;
                    });
                    if (_dragPosition >= maxDrag * 0.85) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isFinished = true;
                      });
                      widget.onSwipeCompleted();
                    } else {
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: buttonSize,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33EF4444),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        _dateTimeStr = DateFormat('EEEE, d MMM   hh:mm a').format(DateTime.now());
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

class _DailyDarshanCarouselWidget extends StatefulWidget {
  final List<String> imageUrls;
  final String? title;
  final Function(int index) onTapImage;
  final Function(int index)? onDownload;
  final Function(int index)? onShare;

  const _DailyDarshanCarouselWidget({
    required this.imageUrls,
    this.title,
    required this.onTapImage,
    this.onDownload,
    this.onShare,
  });

  @override
  State<_DailyDarshanCarouselWidget> createState() => _DailyDarshanCarouselWidgetState();
}

class _DailyDarshanCarouselWidgetState extends State<_DailyDarshanCarouselWidget> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
    _precacheImages();
  }

  @override
  void didUpdateWidget(_DailyDarshanCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls) {
      _startTimer();
      _precacheImages();
    }
  }

  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in widget.imageUrls) {
        if (url.startsWith('data:')) {
          try {
            final base64String = url.split(',').last;
            final bytes = base64Decode(base64String);
            precacheImage(MemoryImage(bytes), context).catchError((_) {});
          } catch (_) {}
        } else {
          precacheImage(NetworkImage(url), context).catchError((_) {});
        }
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentIndex + 1) % widget.imageUrls.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth * (5.0 / 4.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (_currentIndex != index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    }
                  },
                  itemCount: widget.imageUrls.length,
                  itemBuilder: (context, idx) {
                    final url = widget.imageUrls[idx];
                    return GestureDetector(
                      onTap: () => widget.onTapImage(idx),
                      child: _FolkBoyDashboardState._buildSmartImage(
                        url,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
                if (widget.onDownload != null || widget.onShare != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onDownload != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onDownload!(_currentIndex),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38, width: 1),
                              ),
                              child: const Icon(
                                Icons.file_download_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        if (widget.onShare != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onShare!(_currentIndex),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38, width: 1),
                              ),
                              child: const Icon(
                                Icons.share_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.imageUrls.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.imageUrls.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: index == _currentIndex ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _currentIndex ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
