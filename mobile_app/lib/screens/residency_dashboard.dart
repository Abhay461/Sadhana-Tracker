import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'student_payment_screen.dart';
import '../utils/notification_helper.dart';

class ResidencyDashboard extends StatefulWidget {
  const ResidencyDashboard({super.key});

  @override
  State<ResidencyDashboard> createState() => _ResidencyDashboardState();
}

class _ResidencyDashboardState extends State<ResidencyDashboard> {
  final dynamic supabase = null;
  int _selectedIndex = 0;
  DateTime? _selectedHistoryDate;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preacher;
  List<dynamic> _updates = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingProfile = true;
  String? _photoUrl;
  bool _isSavingProfile = false;
  final ImagePicker _picker = ImagePicker();

  // Carousel config
  final PageController _pageController = PageController();
  int _currentAnnouncementIndex = 0;
  Timer? _carouselTimer;

  // Sadhana state variables
  int _totalPointsMonth = 0;

  // Inline Sadhana state variables
  String _selectedSadhanaDate = 'Today';
  final Map<String, bool> _savingStatus = {};
  
  final _roundsController = TextEditingController(text: '16');
  final _bookController = TextEditingController();
  final _readingValueController = TextEditingController();
  final String _readingUnit = 'Pages';
  final _serviceNameController = TextEditingController();
  final _serviceMinutesController = TextEditingController();
  final String _ekadashiFastingType = 'Ekadashi Prasadam (No Grains)';
  final _ekadashiNotesController = TextEditingController();

  final TimeOfDay _manglaStartTime = const TimeOfDay(hour: 4, minute: 30);
  final TimeOfDay _onlineStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _onlineEndTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _sbStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _sbEndTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _bgStartTime = const TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _bgEndTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 5, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
  final DateTime _templeVisitDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadProfileAndData();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _roundsController.dispose();
    _bookController.dispose();
    _readingValueController.dispose();
    _serviceNameController.dispose();
    _serviceMinutesController.dispose();
    _ekadashiNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final response = await ApiService.get('/users/me');
      if (response is! Map) {
        throw StateError('The profile service returned an invalid response.');
      }

      final profileData = Map<String, dynamic>.from(response);
      profileData['id'] ??= profileData['_id'];
      profileData['photo_url'] ??= profileData['photoUrl'];
      profileData['preacher_id'] ??= profileData['preacherId'];

      final role = profileData['role'] as String?;
      if (role != 'residency' && role != 'admin') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _profile = profileData;
          _photoUrl = profileData['photo_url'];
          _isLoadingProfile = false;
        });
      }

      if (profileData['preacher_id'] != null) {
        final preacher = profileData['preacher_id'];
        if (preacher is Map<String, dynamic>) {
          _preacher = preacher;
        }
      }
      await _fetchUpdates();
    } catch (e) {
      debugPrint('Error loading residency profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _fetchUpdates() async {
    if (_profile == null) return;
    try {
      final data = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', _profile!['id'])
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 8));

      // Exclude RLS signal rows from Activity list
      final cleanUpdates = data.where((u) => 
        u['category'] != 'accommodation_approval_signal' && 
        u['category'] != 'accommodation_delete_signal'
      ).toList();

      setState(() {
        _updates = cleanUpdates;
        _calculatePoints();
      });

      // Process signals silently in background
      _processClientSignals(data);
    } catch (e) {
      debugPrint('Error fetching updates: $e');
    }
  }

  Future<void> _processClientSignals(List<dynamic> rawUpdates) async {
    bool didChange = false;
    for (var u in rawUpdates) {
      final category = u['category'];
      final signalId = u['id'];
      
      if (category == 'accommodation_approval_signal') {
        final String signal = u['work_started'] ?? '';
        if (signal.startsWith('SIGNAL: ')) {
          final targetIdStr = signal.replaceAll('SIGNAL: ', '');
          final targetId = targetIdStr;
          final room = u['work_completed'] ?? '';
          
          if (targetId.isNotEmpty) {
            try {
              await supabase.from('updates').update({
                'is_completed': true,
                'work_completed': room,
              }).eq('id', targetId);
              await supabase.from('updates').delete().eq('id', signalId);
              didChange = true;
            } catch (e) {
              debugPrint('Error executing client approval signal: $e');
            }
          }
        }
      } else if (category == 'accommodation_delete_signal') {
        final String signal = u['work_started'] ?? '';
        if (signal.startsWith('SIGNAL: ')) {
          final targetIdStr = signal.replaceAll('SIGNAL: ', '');
          final targetId = targetIdStr;
          
          if (targetId.isNotEmpty) {
            try {
              await supabase.from('updates').delete().eq('id', targetId);
              await supabase.from('updates').delete().eq('id', signalId);
              didChange = true;
            } catch (e) {
              debugPrint('Error executing client delete signal: $e');
            }
          }
        }
      }
    }
    if (didChange && mounted) {
      _fetchUpdates();
    }
  }

  void _handleAccommodationBooking() {
    if (_profile == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: _ResidencyAccommodationSheet(
            profile: _profile!,
            preacher: _preacher,
            onBookingSuccess: _fetchUpdates,
          ),
        );
      },
    );
  }

  void _handlePreacherAppointmentBooking() {
    if (_profile == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: _PreacherAppointmentSheet(
            profile: _profile!,
            preacher: _preacher,
            onBookingSuccess: _fetchUpdates,
          ),
        );
      },
    );
  }

  void _calculatePoints() {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    int pointsMonth = 0;

    for (var u in _updates) {
      final dateStr = u['date'] as String?;
      if (dateStr == null || u['is_completed'] != true) continue;

      final pts = u['points'] as int? ?? 0;

      try {
        final parsedDate = DateTime.parse(dateStr);
        if (parsedDate.month == currentMonth && parsedDate.year == currentYear) {
          pointsMonth += pts;
        }
      } catch (_) {}
    }

    setState(() {
      _totalPointsMonth = pointsMonth;
    });
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final sessionsData = await supabase
          .from('online_announcements')
          .select('*')
          .order('updated_at', ascending: false);

      final tripsData = await supabase
          .from('announcements')
          .select('*')
          .like('content', '[TRIP]%')
          .order('created_at', ascending: false);

      final eventsData = await supabase
          .from('announcements')
          .select('*')
          .like('content', '[EVENT]%')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedAnnouncements = [];

      for (var session in sessionsData) {
        final dateStr = session['description'] as String? ?? '';
        final timeStr = session['session_time'] as String? ?? '';
        final combinedTime = dateStr.isNotEmpty && timeStr.isNotEmpty
            ? '$dateStr @ $timeStr'
            : (dateStr.isNotEmpty ? dateStr : timeStr);

        loadedAnnouncements.add({
          'type': 'session',
          'id': session['id'],
          'title': session['title'],
          'time': combinedTime,
          'link': session['link'] ?? '',
          'banner': session['banner_url'] ?? '',
        });
      }

      for (var trip in tripsData) {
        final parts = trip['content'].toString().replaceFirst('[TRIP] ', '').split(' | ');
        loadedAnnouncements.add({
          'type': 'trip',
          'id': trip['id'],
          'title': parts.isNotEmpty ? parts[0] : 'Upcoming Trip',
          'time': parts.length > 1 ? parts[1] : '',
          'banner': parts.length > 2 ? parts[2] : '',
          'link': parts.length > 3 ? parts[3] : '',
        });
      }

      for (var event in eventsData) {
        final parts = event['content'].toString().replaceFirst('[EVENT] ', '').split(' | ');
        loadedAnnouncements.add({
          'type': 'event',
          'id': event['id'],
          'title': parts.isNotEmpty ? parts[0] : 'Upcoming Event',
          'time': parts.length > 2 ? '${parts[1]} • ${parts[2]}' : (parts.length > 1 ? parts[1] : ''),
          'banner': parts.length > 3 ? parts[3] : '',
          'link': parts.length > 4 ? parts[4] : '',
        });
      }

      setState(() {
        _announcements = loadedAnnouncements;
      });

      _startCarouselTimer();
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

  bool get _isDayLockedByPreacher {
    return false;
  }

  Map<String, dynamic>? get _pendingManglaArti {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      return _updates.firstWhere((u) =>
          u['date'] == today &&
          u['is_completed'] == false &&
          u['category'] == 'residency_sadhna' &&
          u['work_started'].toString().toLowerCase().contains('mangla arti'));
    } catch (_) {
      return null;
    }
  }


  Future<void> _showTripJoinDialog(String title, String link) async {
    try {
      final existingBookings = _updates.where((u) => u['category'] == 'trip_attendance' && u['work_started'] == 'Trip: $title').toList();

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
                'worker_id': _profile!['id'],
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
      final existingBookings = _updates.where((u) => u['category'] == 'event_attendance' && u['work_started'] == 'Event: $title').toList();

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
          launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Could not launch event link: $e');
        }
        return; 
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
                'worker_id': _profile!['id'],
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
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
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
                'worker_id': _profile!['id'],
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

  void openProgressBottomSheetDisabled() {
    final List<Map<String, dynamic>> last7Days = [];
    final today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final dayName = DateFormat('E').format(day); // e.g. Mon
      final dateLabel = DateFormat('MMM d').format(day); // e.g. May 25
      
      // Calculate total points for this dateStr
      int pts = 0;
      for (var u in _updates) {
        if (u['date'] == dateStr && u['is_completed'] == true) {
          pts += (u['points'] as int? ?? 0);
        }
      }
      last7Days.add({
        'day': dayName,
        'date': dateLabel,
        'points': pts,
        'isToday': i == 0,
      });
    }

    // 2. Show dialog
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sadhana Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Weekly & Monthly Overview',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Body in a scrollable view to prevent overflow
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly Summary Stats Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3F1200), Color(0xFF5C1B00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3F1200).withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MONTHLY TOTAL',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$_totalPointsMonth Pts',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Keep tracking daily to achieve your spiritual goals!',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.insights_outlined,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Section: Weekly Trend
                      const Text(
                        'Last 7 Days Trend',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: last7Days.map((dayData) {
                            final int pts = dayData['points'];
                            final double percent = (pts / 14.0).clamp(0.0, 1.0);
                            final isToday = dayData['isToday'] as bool;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  // Date label
                                  SizedBox(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dayData['day'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: isToday ? const Color(0xFF3F1200) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          dayData['date'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Progress Bar
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isToday ? const Color(0xFF3F1200).withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isToday ? 'Today' : 'Completed',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: isToday ? const Color(0xFF3F1200) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$pts / 14 pts',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: pts >= 14 ? const Color(0xFF059669) : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 6,
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            pts >= 14
                                                ? const Color(0xFF059669)
                                                : (pts > 0 ? const Color(0xFF3F1200) : const Color(0xFFCBD5E1)),
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
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
          title: const Text('Residency Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () {
                try {
                  supabase.auth.signOut().catchError((_) {});
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
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Failed to load profile. Please try logging in again.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  try {
                    supabase.auth.signOut().catchError((_) {});
                  } catch (_) {}
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('LOG OUT'),
              ),
            ],
          ),
        ),
      );
    }


    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF8F5),
            appBar: _selectedIndex == 0
                ? AppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: const Color(0xFF3F1200),
                    elevation: 0.5,
                    toolbarHeight: 80,
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Colors.white,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                    ),
                    centerTitle: false,
                    title: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: _profile?['photo_url'] != null
                                ? NetworkImage(_profile!['photo_url'])
                                : null,
                            backgroundColor: const Color(0xFFEEF2F6),
                            child: _profile?['photo_url'] == null
                                ? Text(
                                    (_profile?['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3F1200),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hare Krishna, ${_profile?['name'] ?? 'User'}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const _LiveDateTimeWidget(color: Colors.white70),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildHistoryTab(),
          _buildServicesTab(),
          _buildProfileTab(),
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
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Services',
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
),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileAndData();
        await _fetchAnnouncements();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Announcement Carousel
            if (_announcements.isNotEmpty) ...[
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentAnnouncementIndex = index;
                    });
                  },
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          if (ann['image_url'] != null && ann['image_url'].toString().isNotEmpty) ...[
                            Image.network(
                              ann['image_url'],
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: ann['type'] == 'session'
                                            ? const Color(0xFFEF4444)
                                            : (ann['type'] == 'trip' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ann['type'].toString().toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ann['title'],
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (ann['time'] != '') ...[
                                            Builder(
                                              builder: (context) {
                                                final timeStr = ann['time'] as String? ?? '';
                                                String displayDate = timeStr;
                                                String displayTime = '';
                                                if (timeStr.contains(' @ ')) {
                                                  final parts = timeStr.split(' @ ');
                                                  displayDate = parts[0];
                                                  displayTime = parts[1];
                                                  try {
                                                    final parsed = DateFormat('yyyy-MM-dd').parse(displayDate);
                                                    displayDate = DateFormat('dd MMM yyyy').format(parsed);
                                                  } catch (_) {}
                                                } else if (timeStr.contains(' | ')) {
                                                  final parts = timeStr.split(' | ');
                                                  displayDate = parts[0];
                                                  displayTime = parts.length > 1 ? parts[1] : '';
                                                }

                                                if (displayTime.isNotEmpty) {
                                                  try {
                                                    final parts = displayTime.split(':');
                                                    if (parts.length >= 2) {
                                                      final hour = int.parse(parts[0]);
                                                      final minute = int.parse(parts[1]);
                                                      final dummyDate = DateTime(2026, 1, 1, hour, minute);
                                                      displayTime = DateFormat('hh:mm a').format(dummyDate);
                                                    }
                                                  } catch (_) {}
                                                }

                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 12),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            displayDate,
                                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (displayTime.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.access_time_outlined, color: Colors.white70, size: 12),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              displayTime,
                                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              }
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final link = ann['link'] as String? ?? '';
                                        if (link.isNotEmpty) {
                                          if (ann['type'] == 'session') {
                                            _showSessionJoinDialog(ann['title'], link);
                                          } else if (ann['type'] == 'trip') {
                                            _showTripJoinDialog(ann['title'], link);
                                          } else if (ann['type'] == 'event') {
                                            _showEventJoinDialog(ann['title'], link);
                                          } else {
                                            try {
                                              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                                            } catch (e) {
                                              debugPrint('Could not launch $link: $e');
                                            }
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: ann['type'] == 'session'
                                            ? const Color(0xFFEF4444)
                                            : (ann['type'] == 'trip' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      icon: Icon(
                                        ann['type'] == 'session'
                                            ? Icons.videocam_outlined
                                            : (ann['type'] == 'trip' ? Icons.directions_bus_outlined : Icons.event_available_outlined),
                                        size: 14,
                                      ),
                                      label: Text(
                                        ann['type'] == 'session'
                                            ? 'JOIN'
                                            : (ann['type'] == 'trip' ? 'BOOK' : 'JOIN'),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_announcements.length, (index) {
                  return Container(
                    width: index == _currentAnnouncementIndex ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _currentAnnouncementIndex ? const Color(0xFF3F1200) : Colors.grey[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
            ],

            // Pending Mangla Arti Banner
            if (_pendingManglaArti != null) ...[
              _PendingResidencyManglaArtiWidget(
                pendingUpdate: _pendingManglaArti!,
                onComplete: () {
                  _fetchUpdates();
                },
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons / Categories
            _buildInlineSadhanaCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final filteredUpdates = _updates.where((u) {
      if (_selectedHistoryDate == null) return true;
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedHistoryDate!);
      final itemDate = u['date'] as String? ?? '';
      return itemDate == selectedDateStr;
    }).toList();

    // Group updates by date
    final Map<String, List<dynamic>> groupedUpdates = {};
    for (var u in filteredUpdates) {
      final date = u['date'] as String? ?? 'No Date';
      groupedUpdates.putIfAbsent(date, () => []).add(u);
    }

    // Sort dates in descending order
    final sortedDates = groupedUpdates.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Date Filter Row
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
        // History List
        Expanded(
          child: filteredUpdates.isEmpty
              ? const Center(child: Text('No records found for this date', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadProfileAndData();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final dateStr = sortedDates[index];
                      final items = groupedUpdates[dateStr]!;

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
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                            child: Text(
                              displayDate,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3F1200),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...items.map((u) {
                            final isCompleted = u['is_completed'] ?? false;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  leading: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCompleted ? Icons.check_rounded : Icons.access_time_rounded,
                                      color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    u['work_started'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      debugPrint('Residency Delete button pressed directly for update: ${u['id']}');
                                      _handleDeleteUpdate(u['id'], u['work_started'] ?? '');
                                    },
                                  ),
                                ),
                                const Divider(height: 1, indent: 60, color: Color(0xFFF1F5F9)),
                              ],
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resident Services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildServiceListItem(
                title: 'Accommodation',
                icon: Icons.hotel_outlined,
                onTap: _handleAccommodationBooking,
              ),
              _buildServiceListItem(
                title: 'Preacher Appointment',
                icon: Icons.chat_bubble_outline,
                onTap: _handlePreacherAppointmentBooking,
              ),
              _buildServiceListItem(
                title: 'Payment Reminder',
                icon: Icons.account_balance_wallet_outlined,
                onTap: _handlePaymentReminder,
              ),
              _buildServiceListItem(
                title: 'Messages',
                icon: Icons.message_outlined,
                onTap: _contactPreacher,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _contactPreacher() {
    if (_profile == null) return;
    if (_profile!['preacher_id'] == null || _preacher == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('No Preacher Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('You do not have a preacher assigned to your profile yet. Please contact the administrator.', style: TextStyle(fontSize: 14)),
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

    final rawWhatsapp = _preacher!['whatsapp_number'] as String? ?? '';
    String preacherWhatsapp = '';
    if (rawWhatsapp.contains('|')) {
      preacherWhatsapp = rawWhatsapp.split('|')[0].trim();
    } else {
      preacherWhatsapp = rawWhatsapp.trim();
    }

    final preacherName = _preacher!['name'] ?? 'Preacher';
    final studentName = _profile!['name'] ?? 'Resident';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Message Preacher', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: _preacher!['photo_url'] != null ? NetworkImage(_preacher!['photo_url']) : null,
              backgroundColor: const Color(0xFFF1F5F9),
              child: _preacher!['photo_url'] == null
                  ? Text(
                      preacherName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              preacherName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3F1200)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'For approvals, questions, or guidance, you can send a message to your preacher directly on WhatsApp.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
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
              final message = 'Hare Krishna, Preacher! I am $studentName. I have a query/request regarding...';
              final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final rawWhatsapp = _profile?['whatsapp_number'] as String? ?? '';
    String displayWhatsapp = '';
    String displayDob = _profile?['dob'] ?? '';
    String displayJoin = _profile?['joining_date'] ?? '';

    if (rawWhatsapp.contains('|')) {
      final parts = rawWhatsapp.split('|');
      displayWhatsapp = parts[0].trim();
      for (var part in parts) {
        if (part.contains('DOB:')) {
          displayDob = part.replaceAll('DOB:', '').trim();
        } else if (part.contains('JOIN:')) {
          displayJoin = part.replaceAll('JOIN:', '').trim();
        }
      }
    } else {
      displayWhatsapp = rawWhatsapp.trim();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // 1. Profile photo header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _isSavingProfile ? null : _updatePhoto,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: _photoUrl == null
                              ? Text(
                                  (_profile?['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3F1200),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile?['name'] ?? 'Residency Portal',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'RESIDENCY',
                              style: TextStyle(color: Color(0xFF3F1200), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1.5),

                // 2. Personal Information Fields
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                const Text(
                                  'Your residency profile details',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildProfileInfoRow(Icons.person_outline, 'Full Name', _profile?['name'] ?? ''),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildProfileInfoRow(Icons.psychology_outlined, 'Preacher', _preacher?['name'] ?? 'Preacher'),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildProfileInfoRow(Icons.phone_android_outlined, 'WhatsApp Number', displayWhatsapp),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildProfileInfoRow(Icons.cake_outlined, 'Date of Birth', displayDob),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildProfileInfoRow(Icons.calendar_month_outlined, 'Joining Date', displayJoin),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildProfileInfoRow(Icons.email_outlined, 'Email Address', _profile?['email'] ?? ''),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1.5),

                // 3. About & App Settings
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.help_outline_rounded, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('About the App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('View app version and description', style: TextStyle(fontSize: 12)),
                        onTap: _showAboutDialog,
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.rate_review_outlined, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Send us your valuable feedback', style: TextStyle(fontSize: 12)),
                        onTap: _showFeedbackDialog,
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.policy_outlined, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Read our data and privacy policies', style: TextStyle(fontSize: 12)),
                        onTap: _showPrivacyPolicyDialog,
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.star_outline_rounded, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Rate the App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Express your love on app store', style: TextStyle(fontSize: 12)),
                        onTap: _showRateAppDialog,
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.share_outlined, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Share The App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Invite others to download this app', style: TextStyle(fontSize: 12)),
                        onTap: _shareApp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Logout Action
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 220,
              height: 48,
              child: _SwipeToLogoutButton(
                onSwipeCompleted: () {
                  try {
                    FirebaseAuth.instance.signOut().catchError((_) {});
                  } catch (_) {}
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF3F1200).withValues(alpha: 0.06),
            child: Icon(icon, color: const Color(0xFF3F1200), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isNotEmpty ? value : 'Not specified',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
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
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your feedback helps us make the app better.', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your comments or suggestions here...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              final feedback = controller.text.trim();
              if (feedback.isNotEmpty) {
                try {
                  await ApiService.post('/feedback', {
                    'content': feedback,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                } catch (_) {}
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you! Your feedback has been submitted successfully.')),
                  );
                }
              }
            },
            child: const Text('SUBMIT', style: TextStyle(color: Color(0xFF3F1200), fontWeight: FontWeight.bold)),
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
                  'You have the right to request deletion of your account and data at any time. For support or deletion, contact us at: abhaykumarsalempur8521@gmail.com',
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
    int selectedStars = 5;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Rate The App', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enjoying Sadhana Path Tracker? Give us a rating!', style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= selectedStars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setStateDialog(() {
                        selectedStars = starIndex;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Thank you! You rated the app $selectedStars stars.')),
                );
              },
              child: const Text('SUBMIT', style: TextStyle(color: Color(0xFF3F1200), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _shareApp() {
    const downloadUrl = 'https://sadhanapathtracker.page.link/download';
    Clipboard.setData(const ClipboardData(text: 'Hare Krishna! Download the Sadhana Path Tracker app: $downloadUrl'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App download link copied to clipboard!')),
    );
  }



  String? _getSadhanaLoggedDetails(String activity) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String targetDate = today;
    if (_selectedSadhanaDate == 'Yesterday') {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      targetDate = DateFormat('yyyy-MM-dd').format(yesterday);
    } else if (_selectedSadhanaDate == 'Ekadashi') {
      targetDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    try {
      final match = _updates.firstWhere((u) {
        final uDate = u['date'];
        if (uDate != targetDate) return false;
        final category = u['category'] ?? '';
        if (category != 'residency_sadhna') return false;
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
        if (activity == 'Ekadashi Fasting') {
          return workStarted.startsWith('Ekadashi Fasting');
        }
        if (activity == 'Morning') {
          return workStarted.startsWith('Morning');
        }
        if (activity == 'Sleep') {
          return workStarted.startsWith('Sleep');
        }
        return false;
      });

      final String ws = match['work_started'].toString();
      if (activity == 'Chanting') {
        if (ws.contains('-')) {
          return ws.split('-').skip(1).join('-').trim();
        }
      } else if (activity == 'Book Reading') {
        if (ws.contains('-')) {
          return ws.split('-').skip(1).join('-').trim();
        }
      } else if (activity == 'Service') {
        if (ws.contains('-')) {
          return ws.split('-').skip(1).join('-').trim();
        }
      } else if (activity == 'Mangla Arti') {
        if (ws.contains('(')) {
          return ws.substring(ws.indexOf('(') + 1, ws.indexOf(')')).trim();
        }
      } else if (activity == 'Online Session' ||
                 activity == 'Srimad Bhagavatam Class' ||
                 activity == 'Bhagavad Gita Class') {
        if (ws.contains('(')) {
          return ws.substring(ws.indexOf('(') + 1, ws.indexOf(')')).trim();
        }
      } else if (activity == 'Ekadashi Fasting') {
        if (ws.contains(':')) {
          return ws.split(':').skip(1).join(':').trim();
        }
      } else if (activity == 'Morning') {
        if (ws.contains('Wake-up:')) {
          return ws.split('Wake-up:')[1].replaceAll(')', '').trim();
        }
      } else if (activity == 'Sleep') {
        if (ws.contains('Time:')) {
          return ws.split('Time:')[1].replaceAll(')', '').trim();
        }
      } else if (activity == 'Temple Visit') {
        return 'Logged';
      }
      return ws;
    } catch (_) {
      return null;
    }
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

    if (_selectedSadhanaDate == 'Yesterday') {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      targetDate = DateFormat('yyyy-MM-dd').format(yesterday);
    } else if (_selectedSadhanaDate == 'Ekadashi') {
      targetDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

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
      final timeStr = '${_manglaStartTime.hour.toString().padLeft(2, '0')}:${_manglaStartTime.minute.toString().padLeft(2, '0')}';
      label = 'Mangla Arti ($timeStr)';
      points = 10;
    } else if (activity == 'Online Session') {
      final startStr = '${_onlineStartTime.hour.toString().padLeft(2, '0')}:${_onlineStartTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${_onlineEndTime.hour.toString().padLeft(2, '0')}:${_onlineEndTime.minute.toString().padLeft(2, '0')}';
      label = 'Online Session ($startStr to $endStr)';
      points = 5;
    } else if (activity == 'Srimad Bhagavatam Class') {
      final startStr = '${_sbStartTime.hour.toString().padLeft(2, '0')}:${_sbStartTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${_sbEndTime.hour.toString().padLeft(2, '0')}:${_sbEndTime.minute.toString().padLeft(2, '0')}';
      label = 'Srimad Bhagavatam Class ($startStr to $endStr)';
      points = 5;
    } else if (activity == 'Bhagavad Gita Class') {
      final startStr = '${_bgStartTime.hour.toString().padLeft(2, '0')}:${_bgStartTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${_bgEndTime.hour.toString().padLeft(2, '0')}:${_bgEndTime.minute.toString().padLeft(2, '0')}';
      label = 'Bhagavad Gita Class ($startStr to $endStr)';
      points = 5;
    } else if (activity == 'Ekadashi Fasting') {
      final notes = _ekadashiNotesController.text.trim();
      label = 'Ekadashi Fasting: $_ekadashiFastingType${notes.isNotEmpty ? " ($notes)" : ""}';
      points = _ekadashiFastingType == 'No Fasting' ? 0 : 10;
    } else if (activity == 'Morning') {
      final timeStr = _wakeUpTime.format(context);
      label = 'Morning (Wake-up: $timeStr)';
      points = 5;
    } else if (activity == 'Sleep') {
      final timeStr = _sleepTime.format(context);
      label = 'Sleep (Time: $timeStr)';
      points = 5;
    } else {
      points = 5;
    }

    // Duplicate check
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
      final isMangla = activity == 'Mangla Arti';
      final updateData = {
        'worker_id': _profile!['id'],
        'worker_name': _profile!['name'],
        'preacher_name': _preacher?['name'] ?? 'Preacher',
        'category': 'residency_sadhna',
        'work_started': label,
        'description': 'Log date: $targetDate\\nCategory: $activity',
        'work_completed': isMangla ? null : DateFormat('hh:mm a').format(DateTime.now()),
        'is_completed': isMangla ? false : true,
        'date': targetDate,
        'points': points,
      };

      await ApiService.post('/sadhana', updateData);
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label logged successfully!')),
        );
        _fetchUpdates();
        setState(() {
          if (activity == 'Book Reading') {
            _bookController.clear();
            _readingValueController.clear();
          } else if (activity == 'Service') {
            _serviceNameController.clear();
            _serviceMinutesController.clear();
          } else if (activity == 'Ekadashi Fasting') {
            _ekadashiNotesController.clear();
          }
        });
      }
    } catch (e) {
      debugPrint('Error saving sadhana: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save log: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus[activity] = false);
    }
  }

  Widget _buildRealisticIcon(String activity, IconData icon, bool isLogged) {
    final Color iconColor = isLogged ? const Color(0xFF3F1200) : const Color(0xFF7A6B63);
    final Color borderColor = isLogged 
        ? const Color(0xFF3F1200).withValues(alpha: 0.25)
        : const Color(0xFFD6C8C0);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLogged
              ? [
                  const Color(0xFFFFF5F0),
                  const Color(0xFFFBE4D8),
                ]
              : [
                  const Color(0xFFFAFAFA),
                  const Color(0xFFECE6E2),
                ],
        ),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          if (isLogged)
            BoxShadow(
              color: const Color(0xFF3F1200).withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Center(
        child: activity == 'Chanting'
            ? Padding(
                padding: const EdgeInsets.all(3.0),
                child: Image.asset(
                  'assets/mala.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              )
            : activity == 'Morning'
                ? Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Image.asset(
                      'assets/wakeup.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  )
            : activity == 'Mangla Arti'
                ? Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Image.asset(
                      'assets/mangla_arti.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  )
                : activity == 'Service'
                    ? Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Image.asset(
                          'assets/service.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      )
                    : activity == 'Temple Visit'
                        ? Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: Image.asset(
                              'assets/temple_visit.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.contain,
                            ),
                          )
                        : activity == 'Book Reading'
                            ? Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Image.asset(
                                  'assets/book_reading.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              )
                        : activity == 'Online Session'
                            ? Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Image.asset(
                                  'assets/online_session.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              )
                        : activity == 'Sleep'
                            ? Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Image.asset(
                                  'assets/sleep.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              )
                        : (activity == 'Srimad Bhagavatam Class' || activity == 'Bhagavad Gita Class')
                            ? Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Image.asset(
                                  'assets/scripture_class.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(
                                icon,
                                color: iconColor,
                                size: 26,
                              ),
      ),
    );
  }

  Widget _buildSadhanaTile(String activity) {
    final loggedDetails = _getSadhanaLoggedDetails(activity);
    final isLogged = loggedDetails != null;
    
    IconData icon;
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
        icon = Icons.restaurant_rounded;
        break;
      case 'Sleep':
        icon = Icons.bedtime_rounded;
        break;
      default:
        icon = Icons.check_circle_outline_rounded;
    }

    final isLocked = _isDayLockedByPreacher;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isLogged ? const Color(0xFF3F1200).withValues(alpha: 0.02) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLogged ? const Color(0xFF3F1200).withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
          width: isLogged ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _buildRealisticIcon(activity, icon, isLogged),
        title: Text(
          activity == 'Morning' ? 'Morning Wake-Up' : (activity == 'Sleep' ? 'Sleep Time' : activity),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isLogged ? const Color(0xFF3F1200) : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          isLogged ? loggedDetails : 'Not logged yet • Tap to log',
          style: TextStyle(
            fontSize: 12,
            color: isLogged ? const Color(0xFF3F1200).withValues(alpha: 0.7) : const Color(0xFF64748B),
          ),
        ),
        trailing: isLogged
            ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
            : Icon(Icons.add_circle_outline_rounded, color: const Color(0xFF3F1200).withValues(alpha: 0.4), size: 24),
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
                  );
                  if (time != null) {
                    setState(() {
                      _wakeUpTime = time;
                    });
                    await _handleInlineSave('Morning');
                  }
                } else if (activity == 'Sleep') {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _sleepTime,
                  );
                  if (time != null) {
                    setState(() {
                      _sleepTime = time;
                    });
                    await _handleInlineSave('Sleep');
                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        clipBehavior: Clip.antiAlias,
                        child: _ResidencySadhanaLogSheet(
                          logDate: _selectedSadhanaDate,
                          profileId: _profile!['id'],
                          profileName: _profile!['name'] ?? '',
                          preacherName: _preacher?['name'] ?? 'Preacher',
                          updates: _updates,
                          initialActivity: activity,
                          onSaveSuccess: () {
                            _fetchUpdates();
                          },
                        ),
                      );
                    },
                  );
                }
              },
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
      if (_selectedSadhanaDate == 'Ekadashi') 'Ekadashi Fasting',
      'Sleep',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Sadhana',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Row(
              children: ['Today', 'Yesterday', 'Ekadashi'].map((type) {
                final isSelected = _selectedSadhanaDate == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(
                      type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF3F1200),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          _selectedSadhanaDate = type;
                        });
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF3F1200) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...activities.map((activity) => _buildSadhanaTile(activity)),
      ],
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
          title: const Text('Confirm Delete'),
          content: Text('Do you want to delete "$label" record?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ApiService.delete('/sadhana/$id');
      _fetchUpdates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting record: $e');
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

class _ResidencySadhanaLogSheet extends StatefulWidget {
  final String logDate;
  final String profileId;
  final String profileName;
  final String preacherName;
  final List<dynamic> updates;
  final VoidCallback onSaveSuccess;
  final String? initialActivity;

  const _ResidencySadhanaLogSheet({
    required this.logDate,
    required this.profileId,
    required this.profileName,
    required this.preacherName,
    required this.updates,
    required this.onSaveSuccess,
    this.initialActivity,
  });

  @override
  State<_ResidencySadhanaLogSheet> createState() => _ResidencySadhanaLogSheetState();
}

class _ResidencySadhanaLogSheetState extends State<_ResidencySadhanaLogSheet> {
  final dynamic supabase = null;
  
  String? _selectedSubOption;
  bool _isLoading = false;

  // Logging values
  int _rounds = 16;
  final _roundsController = TextEditingController(text: '16');
  final _bookController = TextEditingController();
  final _readingValueController = TextEditingController();
  String _readingUnit = 'Pages';
  final _serviceNameController = TextEditingController();
  final _serviceMinutesController = TextEditingController();
  
  // Ekadashi Logging values
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
    _selectedSubOption = widget.initialActivity;
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
      if (widget.logDate == 'Ekadashi') 'Ekadashi Fasting',
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
    } else if (_selectedSubOption == 'Book Reading') {
      if (_bookController.text.isEmpty || _readingValueController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter book name and reading pages/minutes')));
        setState(() => _isLoading = false);
        return;
      }
      label = 'Book Reading - ${_bookController.text} (${_readingValueController.text} $_readingUnit)';
    } else if (_selectedSubOption == 'Service') {
      if (_serviceNameController.text.isEmpty || _serviceMinutesController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter service name and minutes')));
        setState(() => _isLoading = false);
        return;
      }
      label = 'Service - ${_serviceNameController.text} (${_serviceMinutesController.text} Mins)';
    } else if (_selectedSubOption == 'Mangla Arti') {
      final timeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      label = 'Mangla Arti ($timeStr)';
    } else if (_selectedSubOption == 'Online Session' ||
               _selectedSubOption == 'Srimad Bhagavatam Class' ||
               _selectedSubOption == 'Bhagavad Gita Class') {
      final startStr = '${_classStartTime.hour.toString().padLeft(2, '0')}:${_classStartTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${_classEndTime.hour.toString().padLeft(2, '0')}:${_classEndTime.minute.toString().padLeft(2, '0')}';
      label = '$_selectedSubOption ($startStr to $endStr)';
    } else if (_selectedSubOption == 'Ekadashi Fasting') {
      final notes = _ekadashiNotesController.text.trim();
      label = 'Ekadashi Fasting: $_ekadashiFastingType${notes.isNotEmpty ? " ($notes)" : ""}';
    }

    // Duplicate check
    final isDuplicate = widget.updates.any((u) {
      final uDate = u['date'];
      if (uDate != targetDate || u['is_completed'] == false) return false;
      final workStarted = u['work_started'].toString();
      
      if (_selectedSubOption == 'Service' || _selectedSubOption == 'Book Reading') {
        // For Service and Book Reading, only duplicate if the exact label matches
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
      final updateData = {
        'worker_id': widget.profileId,
        'worker_name': widget.profileName,
        'preacher_name': widget.preacherName,
        'work_started': label,
        'description': label,
        'is_completed': isMangla ? false : true,
        'work_completed': isMangla ? null : DateFormat('hh:mm a').format(DateTime.now()),
        'category': 'residency_sadhna',
        'date': targetDate,
        'points': points,
        'photo_url': photoUrl,
      };
      await supabase.from('updates').insert(updateData);
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      widget.onSaveSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error inserting update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save record: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String labelText, {String? hintText, Widget? prefixIcon}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3F1200), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine friendly title for this activity
    String displayTitle = _selectedSubOption ?? 'Log Sadhana';
    if (displayTitle == 'Morning') {
      displayTitle = 'Morning Wake-Up';
    } else if (displayTitle == 'Sleep') {
      displayTitle = 'Sleep Time';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // Header: Title and Date Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Devotional Progress • ${widget.logDate}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                if (widget.initialActivity == null && _selectedSubOption != null)
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF3F1200)),
                    label: const Text('Change', style: TextStyle(color: Color(0xFF3F1200), fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _selectedSubOption = null),
                  )
              ],
            ),
            const Divider(height: 24),

            if (_selectedSubOption == null) ...[
              const Text('Select Activity to Log', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sadhanaOptions.map((opt) {
                  return ChoiceChip(
                    label: Text(opt),
                    selected: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSubOption = opt;
                        });
                      }
                    },
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Specific Activity Inputs
              if (_selectedSubOption == 'Chanting') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _roundsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _buildInputDecoration('Rounds Completed', hintText: 'e.g. 16', prefixIcon: const Icon(Icons.trip_origin, color: Color(0xFF3F1200))),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) {
                          _rounds = parsed;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Quick Select:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [8, 16, 20, 24, 32].map((r) {
                        final isSelected = _rounds == r;
                        return ActionChip(
                          label: Text('$r Rounds'),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF3F1200),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          backgroundColor: isSelected ? const Color(0xFF3F1200) : Colors.white,
                          side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Column(
                  children: [
                    TextField(
                      controller: _bookController,
                      decoration: _buildInputDecoration('Book Name', hintText: 'e.g. Bhagavad Gita As It Is', prefixIcon: const Icon(Icons.book_outlined, color: Color(0xFF3F1200))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _readingValueController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration('Read Amount', hintText: 'e.g. 10', prefixIcon: const Icon(Icons.chrome_reader_mode_outlined, color: Color(0xFF3F1200))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _readingUnit,
                              style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14),
                              items: ['Pages', 'Minutes'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _readingUnit = val);
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ] else if (_selectedSubOption == 'Service') ...[
                Column(
                  children: [
                    TextField(
                      controller: _serviceNameController,
                      decoration: _buildInputDecoration('Service Done', hintText: 'e.g. Cooking, Cleaning, Deity Worship', prefixIcon: const Icon(Icons.volunteer_activism_outlined, color: Color(0xFF3F1200))),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _serviceMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Minutes Invested', hintText: 'e.g. 60', prefixIcon: const Icon(Icons.access_time, color: Color(0xFF3F1200))),
                    ),
                  ],
                ),
              ] else if (_selectedSubOption == 'Mangla Arti') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_filled_rounded, size: 18),
                      label: Text(_startTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3F1200),
                        side: const BorderSide(color: Color(0xFF3F1200), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: Navigator.of(context, rootNavigator: true).context,
                          initialTime: _startTime,
                          initialEntryMode: TimePickerEntryMode.dialOnly,
                        );
                        if (time != null) setState(() => _startTime = time);
                      },
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
                        const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15)),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(_classStartTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3F1200),
                            side: const BorderSide(color: Color(0xFF3F1200), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('End Time:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15)),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_filled_rounded, size: 18),
                          label: Text(_classEndTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3F1200),
                            side: const BorderSide(color: Color(0xFF3F1200), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Visit Date:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(DateFormat('dd MMM yyyy').format(_templeVisitDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3F1200),
                        side: const BorderSide(color: Color(0xFF3F1200), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
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
              ] else if (_selectedSubOption == 'Ekadashi Fasting') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _ekadashiFastingType,
                      decoration: _buildInputDecoration('Fasting Type', prefixIcon: const Icon(Icons.restaurant, color: Color(0xFF3F1200))),
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ekadashiNotesController,
                      decoration: _buildInputDecoration('Fasting Details / Notes (Optional)', hintText: 'e.g. Broke fast next day at Paran time', prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFF3F1200))),
                    ),
                  ],
                ),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Click Save below to log this activity!', style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  ),
                )
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F1200),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: const Color(0xFF3F1200).withValues(alpha: 0.25),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE SADHANA RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _ResidencyAccommodationSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? preacher;
  final VoidCallback onBookingSuccess;

  const _ResidencyAccommodationSheet({
    required this.profile,
    this.preacher,
    required this.onBookingSuccess,
  });

  @override
  State<_ResidencyAccommodationSheet> createState() => _ResidencyAccommodationSheetState();
}

class _ResidencyAccommodationSheetState extends State<_ResidencyAccommodationSheet> {
  final dynamic supabase = null;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  final _ageController = TextEditingController();
  
  DateTime? _arrivalDate;
  DateTime? _departureDate;
  bool _isLoading = false;
  
  List<dynamic> _bookings = [];
  bool _isLoadingBookings = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['name'] ?? '');
    _fetchBookings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    try {
      setState(() => _isLoadingBookings = true);
      final res = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', widget.profile['id'])
          .order('created_at', ascending: false)
          .limit(70);

      final bookings = res.where((u) => u['category'] == 'accommodation').toList();

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoadingBookings = false;
        });
      }

      _processBackgroundSignals(res);
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) setState(() => _isLoadingBookings = false);
    }
  }

  Future<void> _processBackgroundSignals(List<dynamic> raw) async {
    bool didChange = false;
    for (var u in raw) {
      final category = u['category'];
      final signalId = u['id'];
      
      if (category == 'accommodation_approval_signal') {
        final String signal = u['work_started'] ?? '';
        if (signal.startsWith('SIGNAL: ')) {
          final targetIdStr = signal.replaceAll('SIGNAL: ', '');
          final targetId = targetIdStr;
          final room = u['work_completed'] ?? '';
          
          if (targetId.isNotEmpty) {
            try {
              await supabase.from('updates').update({
                'is_completed': true,
                'work_completed': room,
              }).eq('id', targetId);
              await supabase.from('updates').delete().eq('id', signalId);
              didChange = true;
            } catch (e) {
              debugPrint('Approval signal error: $e');
            }
          }
        }
      } else if (category == 'accommodation_delete_signal') {
        final String signal = u['work_started'] ?? '';
        if (signal.startsWith('SIGNAL: ')) {
          final targetIdStr = signal.replaceAll('SIGNAL: ', '');
          final targetId = targetIdStr;
          
          if (targetId.isNotEmpty) {
            try {
              await supabase.from('updates').delete().eq('id', targetId);
              await supabase.from('updates').delete().eq('id', signalId);
              didChange = true;
            } catch (e) {
              debugPrint('Delete signal error: $e');
            }
          }
        }
      }
    }
    if (didChange && mounted) {
      _fetchBookings();
      widget.onBookingSuccess();
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

      final updateData = {
        'worker_id': widget.profile['id'],
        'worker_name': widget.profile['name'],
        'preacher_name': widget.preacher?['name'] ?? 'Preacher',
        'category': 'accommodation',
        'work_started': 'Accommodation Booking',
        'description': 'Name: $name\nAge: $age\nArrival: $arrivalStr\nDeparture: $departureStr',
        'work_completed': '',
        'is_completed': false,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
      };
      await supabase.from('updates').insert(updateData);
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accommodation booking requested successfully!')),
        );
        widget.onBookingSuccess();
        _fetchBookings();
        _ageController.clear();
        setState(() {
          _arrivalDate = null;
          _departureDate = null;
        });
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
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Residency Accommodation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: const Color(0xFF9333EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'MY BOOKINGS'),
                  Tab(text: 'BOOK NEW'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBookingsTab(),
                  _buildRequestTab(),
                ],
              ),
            ),
          ],
        ),
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
            Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No accommodation bookings yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
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
                        isCompleted ? 'APPROVED' : 'PENDING APPROVAL',
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
                      guestName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Age: $guestAge',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.login, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ARRIVAL', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(arrivalText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.logout, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DEPARTURE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(departureText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isCompleted && roomAllocated.isNotEmpty) ...[
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room, color: Color(0xFF9333EA)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ROOM ASSIGNED',
                                style: TextStyle(fontSize: 9, color: Color(0xFF7E22CE), fontWeight: FontWeight.bold),
                              ),
                              Text(
                                roomAllocated.toString().replaceAll('ROOM: ', ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF5B21B6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
                labelText: 'Guest Full Name',
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter guest name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Guest Age',
                prefixIcon: const Icon(Icons.cake),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter age';
                if (int.tryParse(val) == null) return 'Please enter a valid age';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectArrivalDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ARRIVAL DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            _arrivalDate == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy').format(_arrivalDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _arrivalDate == null ? Colors.grey : const Color(0xFF1E293B),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEPARTURE DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            _departureDate == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy').format(_departureDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _departureDate == null ? Colors.grey : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: const Color(0xFF9333EA).withValues(alpha: 0.3),
                ),
                onPressed: _isLoading ? null : _submitBooking,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SUBMIT BOOKING REQUEST',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
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
  final dynamic supabase = null;
  final _formKey = GlobalKey<FormState>();
  
  final _purposeController = TextEditingController();
  
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  bool _isLoading = false;
  
  List<dynamic> _appointments = [];
  bool _isLoadingAppointments = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoadingAppointments = true);
      final res = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', widget.profile['id'])
          .eq('category', 'preacher_appointment')
          .order('created_at', ascending: false);

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
    );
    if (picked != null) {
      setState(() {
        _appointmentTime = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (widget.preacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book. No preacher is assigned to your profile!')),
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

      // Check for duplicate booking
      final existing = await supabase
          .from('updates')
          .select('id')
          .eq('worker_id', widget.profile['id'])
          .eq('category', 'preacher_appointment')
          .eq('work_started', bookingStr)
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You have already requested/booked an appointment for this time: $dateStr @ $timeStr')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final updateData = {
        'worker_id': widget.profile['id'],
        'worker_name': widget.profile['name'],
        'preacher_name': widget.preacher!['name'],
        'category': 'preacher_appointment',
        'work_started': bookingStr,
        'description': 'Preacher: ${widget.preacher!['name']}\nDate: $dateStr\nTime: $timeStr\nPurpose: $purpose',
        'work_completed': '',
        'is_completed': false,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
      };
      await supabase.from('updates').insert(updateData);
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
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Preacher Appointment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'MY APPOINTMENTS'),
                  Tab(text: 'BOOK NEW'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAppointmentsTab(),
                  _buildRequestTab(),
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
    if (widget.preacher == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'No Assigned Preacher',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'You cannot book appointments because you do not have an assigned preacher. Please contact administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: widget.preacher!['photo_url'] != null
                      ? NetworkImage(widget.preacher!['photo_url'])
                      : null,
                  child: widget.preacher!['photo_url'] == null
                      ? Text(widget.preacher!['name'][0].toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BOOKING WITH ASSIGNED PREACHER',
                        style: TextStyle(fontSize: 9, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.preacher!['name'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 12),
                      Text(
                        _appointmentDate == null
                            ? 'Select Appointment Date'
                            : DateFormat('dd MMM yyyy').format(_appointmentDate!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _appointmentDate == null ? FontWeight.normal : FontWeight.bold,
                          color: _appointmentDate == null ? Colors.grey[600] : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          InkWell(
            onTap: _selectTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 12),
                      Text(
                        _appointmentTime == null
                            ? 'Select Appointment Time'
                            : _appointmentTime!.format(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _appointmentTime == null ? FontWeight.normal : FontWeight.bold,
                          color: _appointmentTime == null ? Colors.grey[600] : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _purposeController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Purpose / Topic of Discussion',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              fillColor: Colors.white,
              filled: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter the purpose of this appointment';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _submitBooking,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('SUBMIT APPOINTMENT REQUEST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _JoinBookingDialog extends StatefulWidget {
  final String title;
  final String category; // 'trip', 'event', or 'session'
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

class _PendingResidencyManglaArtiWidget extends StatefulWidget {
  final Map<String, dynamic> pendingUpdate;
  final VoidCallback onComplete;

  const _PendingResidencyManglaArtiWidget({
    required this.pendingUpdate,
    required this.onComplete,
  });

  @override
  State<_PendingResidencyManglaArtiWidget> createState() => _PendingResidencyManglaArtiWidgetState();
}

class _PendingResidencyManglaArtiWidgetState extends State<_PendingResidencyManglaArtiWidget> {
  final dynamic supabase = null;
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

                          await supabase.from('updates').update({
                            'is_completed': true,
                            'work_completed': _endTime,
                            'work_started': updatedLabel,
                            'description': updatedLabel,
                          }).eq('id', widget.pendingUpdate['id']);

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
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragPosition / maxDrag)).clamp(0.2, 1.0),
                  child: Text(
                    _isFinished ? 'LOGGING OUT...' : 'SWIPE TO LOGOUT',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
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
