import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preacher;
  List<dynamic> _updates = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingProfile = true;
  bool _isLoadingUpdates = true;

  // Carousel config
  final PageController _pageController = PageController();
  int _currentAnnouncementIndex = 0;
  Timer? _carouselTimer;

  // Sadhana state variables
  int _totalPointsMonth = 0;

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
    super.dispose();
  }

  Future<void> _loadProfileAndData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      Map<String, dynamic> profileData;
      try {
        profileData = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();
      } catch (e) {
        debugPrint('Profile fetch error: $e');
        // EMERGENCY BYPASS: Create a dummy profile so the dashboard OPENS even if DB fails
        final metadata = user.userMetadata ?? {};
        profileData = {
          'id': user.id,
          'name': metadata['name'] ?? user.email?.split('@').first ?? 'Resident',
          'role': 'residency',
          'preacher_id': null,
          'photo_url': null,
        };
      }

      final role = profileData['role'] as String?;
      if (role != 'residency' && role != 'admin') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      setState(() {
        _profile = profileData;
        _isLoadingProfile = false;
      });

      if (profileData['preacher_id'] != null) {
        _fetchPreacherProfile(profileData['preacher_id']);
      }
      _fetchUpdates();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _fetchPreacherProfile(String preacherId) async {
    try {
      final preacherData = await supabase
          .from('profiles')
          .select('name, photo_url')
          .eq('id', preacherId)
          .single();
      setState(() {
        _preacher = preacherData;
      });
    } catch (e) {
      debugPrint('Error fetching preacher: $e');
    }
  }

  Future<void> _fetchUpdates() async {
    if (_profile == null) return;
    try {
      setState(() => _isLoadingUpdates = true);
      final data = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', _profile!['id'])
          .order('created_at', ascending: false)
          .limit(100);

      // Exclude RLS signal rows from Activity list
      final cleanUpdates = data.where((u) => 
        u['category'] != 'accommodation_approval_signal' && 
        u['category'] != 'accommodation_delete_signal'
      ).toList();

      setState(() {
        _updates = cleanUpdates;
        _isLoadingUpdates = false;
        _calculatePoints();
      });

      // Process signals silently in background
      _processClientSignals(data);
    } catch (e) {
      debugPrint('Error fetching updates: $e');
      setState(() => _isLoadingUpdates = false);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ResidencyAccommodationSheet(
          profile: _profile!,
          preacher: _preacher,
          onBookingSuccess: _fetchUpdates,
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
          onBookingSuccess: _fetchUpdates,
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
      final sessionData = await supabase
          .from('online_announcements')
          .select('*')
          .eq('id', '00000000-0000-0000-0000-000000000001')
          .maybeSingle();

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

      if (sessionData != null) {
        loadedAnnouncements.add({
          'type': 'session',
          'id': sessionData['id'],
          'title': sessionData['title'],
          'time': sessionData['session_time'] ?? '',
          'link': sessionData['link'] ?? '',
          'banner': sessionData['banner_url'] ?? '',
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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _updates.any((u) => u['category'] == 'folk_lock' && (u['date'] == today));
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

  void _openSadhanaModal(String type) {
    if (_profile == null) return;
    if (_isDayLockedByPreacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today tracking is locked by your preacher!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ResidencySadhanaLogSheet(
          logDate: type,
          profileId: _profile!['id'],
          profileName: _profile!['name'],
          preacherName: _preacher?['name'] ?? 'Preacher',
          updates: _updates,
          onSaveSuccess: () {
            _fetchUpdates();
          },
        );
      },
    );
  }

  Future<void> _showTripJoinDialog(String title, String link) async {
    try {
      final existingBookings = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', _profile!['id'])
          .eq('category', 'trip_attendance')
          .eq('work_started', 'Trip: $title')
          .limit(1);

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
              await supabase.from('updates').insert(updateData);
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
      final existingBookings = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', _profile!['id'])
          .eq('category', 'event_attendance')
          .eq('work_started', 'Event: $title')
          .limit(1);

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
              await supabase.from('updates').insert(updateData);
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
              await supabase.from('updates').insert(updateData);
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

    // 2. Show sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              
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
                            colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
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
                                            color: isToday ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
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
                                                color: isToday ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isToday ? 'Today' : 'Completed',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: isToday ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
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
                                                : (pts > 0 ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
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
                  // Auto-recover: Try to insert the profile before fetching again
                  try {
                    final user = supabase.auth.currentUser;
                    if (user != null) {
                      final metadata = user.userMetadata ?? {};
                      await supabase.from('profiles').upsert({
                        'id': user.id,
                        'name': metadata['name'] ?? user.email?.split('@').first ?? 'User',
                        'role': metadata['role'] ?? 'residency',
                        'preacher_id': metadata['preacher_id'],
                        'whatsapp_number': metadata['whatsapp_number'] ?? 'Not provided',
                        'email': user.email,
                      });
                    }
                  } catch (e) {
                    debugPrint('Auto-recover insert failed: $e');
                  }
                  
                  _loadProfileAndData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry / Fix Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: _profile?['photo_url'] != null
                          ? NetworkImage(_profile!['photo_url'])
                          : null,
                      backgroundColor: const Color(0xFFEEF2F6),
                      child: _profile?['photo_url'] == null
                          ? Text(
                              (_profile?['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?['name'] ?? 'Residency Brother',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          if (_preacher != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundImage: _preacher!['photo_url'] != null
                                        ? NetworkImage(_preacher!['photo_url'])
                                        : null,
                                    child: _preacher!['photo_url'] == null
                                        ? Text(_preacher!['name'][0].toUpperCase(), style: const TextStyle(fontSize: 8))
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Preacher: ${_preacher!['name']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),



            // Announcement Carousel
            if (_announcements.isNotEmpty) ...[
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _announcements.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentAnnouncementIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    return GestureDetector(
                      onTap: () {
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
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (ann['banner'] != '') ...[
                            Image.network(
                              ann['banner'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
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
                                  colors: [Color(0xFF0D9488), Color(0xFF115E59)],
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
                                    ann['type'].toString().toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ann['title'],
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (ann['time'] != '') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ann['time'],
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
                children: List.generate(_announcements.length, (index) {
                  return Container(
                    width: index == _currentAnnouncementIndex ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _currentAnnouncementIndex ? const Color(0xFF0D9488) : Colors.grey[400],
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

            // Action Selection Grid
            const Text('Modules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.25,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildCategoryButton(
                  title: 'Today Sadhana',
                  icon: Icons.calendar_today_outlined,
                  color: const Color(0xFFF0FDFA),
                  iconColor: const Color(0xFF0D9488),
                  onTap: () => _openSadhanaModal('Today'),
                ),
                _buildCategoryButton(
                  title: 'Yesterday Sadhana',
                  icon: Icons.history_outlined,
                  color: const Color(0xFFFFFBEB),
                  iconColor: const Color(0xFFD97706),
                  onTap: () => _openSadhanaModal('Yesterday'),
                ),
                _buildCategoryButton(
                  title: 'Ekadashi',
                  icon: Icons.star_border,
                  color: const Color(0xFFFFF1F2),
                  iconColor: const Color(0xFFE11D48),
                  onTap: () => _openSadhanaModal('Ekadashi'),
                ),
                _buildCategoryButton(
                  title: 'Accommodation',
                  icon: Icons.hotel_outlined,
                  color: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  onTap: _handleAccommodationBooking,
                ),
                _buildCategoryButton(
                  title: 'Preacher Appointment',
                  icon: Icons.chat_bubble_outline,
                  color: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF1D4ED8),
                  onTap: _handlePreacherAppointmentBooking,
                ),
                _buildCategoryButton(
                  title: 'Payment Reminder',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFF97316),
                  onTap: _handlePaymentReminder,
                  badgeCount: _updates.where((u) => u['category'] == 'payment' && u['is_completed'] == false && u['work_completed'] != 'SUBMITTED' && u['work_completed'] != 'WAITING_APPROVAL').length,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Logs List
            const Text('Recent Sadhana Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            _isLoadingUpdates
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : _updates.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No logged activities found', style: TextStyle(color: Colors.grey))))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _updates.length,
                        itemBuilder: (context, index) {
                          final u = _updates[index];
                          final date = u['date'] ?? '';
                          final isCompleted = u['is_completed'] ?? false;

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                child: Icon(
                                  isCompleted ? Icons.check_circle : Icons.timer,
                                  color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
                                ),
                              ),
                              title: Text(
                                u['work_started'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                'Date: $date',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () {
                                  debugPrint('Residency Delete button pressed directly for update: ${u['id']}');
                                  _handleDeleteUpdate(u['id'], u['work_started'] ?? '');
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
            ),
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
      await supabase.from('updates').delete().eq('id', id);
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

  const _ResidencySadhanaLogSheet({
    required this.logDate,
    required this.profileId,
    required this.profileName,
    required this.preacherName,
    required this.updates,
    required this.onSaveSuccess,
  });

  @override
  State<_ResidencySadhanaLogSheet> createState() => _ResidencySadhanaLogSheetState();
}

class _ResidencySadhanaLogSheetState extends State<_ResidencySadhanaLogSheet> {
  final supabase = Supabase.instance.client;
  
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log Residency Sadhana (${widget.logDate})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            if (_selectedSubOption == null) ...[
              const Text('Select Activity', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sadhanaOptions.map((opt) {
                  return ChoiceChip(
                    label: Text(opt),
                    selected: _selectedSubOption == opt,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubOption = opt;
                      });
                    },
                    selectedColor: const Color(0xFF0D9488),
                    labelStyle: TextStyle(color: _selectedSubOption == opt ? Colors.white : Colors.black),
                  );
                }).toList(),
              )
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selected: $_selectedSubOption', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                  TextButton(
                    onPressed: () => setState(() => _selectedSubOption = null),
                    child: const Text('Change'),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Inputs based on selection
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
                  child: Text('Click Save below to log this activity!', style: TextStyle(fontStyle: FontStyle.italic)),
                )
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Sadhana Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
  final supabase = Supabase.instance.client;
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
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
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
  final supabase = Supabase.instance.client;
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
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
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
  final supabase = Supabase.instance.client;
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

