import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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

class PreacherDashboard extends StatefulWidget {
  const PreacherDashboard({super.key});

  @override
  State<PreacherDashboard> createState() => _PreacherDashboardState();
}

class _PreacherDashboardState extends State<PreacherDashboard> {
  final supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  bool _isLoadingBoys = true;

  List<dynamic> _folkBoys = [];
  Map<String, List<dynamic>> _allUpdates = {}; // userId -> list of updates
  List<dynamic> _announcements = [];
  List<dynamic> _tripBookings = [];
  List<dynamic> _eventBookings = [];

  // Active View Tab identifier
  String? _activeTab;

  @override
  void initState() {
    super.initState();
    _loadProfileAndData();
  }

  Future<void> _loadProfileAndData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profileData = await supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      final role = profileData['role'] as String?;
      if (role != 'preacher' && role != 'admin') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _profile = profileData;
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
      final data = await supabase
          .from('profiles')
          .select('*')
          .eq('preacher_id', _profile!['id'])
          .order('name');

      if (mounted) {
        setState(() {
          _folkBoys = data;
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
      final tripData = await supabase
          .from('updates')
          .select('*')
          .eq('category', 'trip_attendance')
          .order('created_at', ascending: false);
      
      final eventData = await supabase
          .from('updates')
          .select('*')
          .eq('category', 'event_attendance')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _tripBookings = tripData;
          _eventBookings = eventData;
        });
      }
    } catch (e) {
      debugPrint('Error fetching trip/event bookings: $e');
    }
  }

  Future<void> _fetchAllUpdates() async {
    await _fetchTripAndEventBookings();
    if (_folkBoys.isEmpty) return;
    try {
      final boyIds = _folkBoys.map((b) => b['id']).toList();
      final List<dynamic> updatesData = await supabase
          .from('updates')
          .select('*')
          .inFilter('worker_id', boyIds)
          .order('created_at', ascending: false);

      final List<dynamic> processedUpdates = List.from(updatesData);
      
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
        final workerId = u['worker_id'].toString();
        if (!grouped.containsKey(workerId)) {
          grouped[workerId] = [];
        }
        grouped[workerId]!.add(u);
      }

      if (mounted) {
        setState(() {
          _allUpdates = grouped;
        });
      }
    } catch (e) {
      debugPrint('Error fetching updates: $e');
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final data = await supabase
          .from('announcements')
          .select('*')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _announcements = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    }
  }

  Future<void> _updateMainProfilePhoto() async {
    final user = supabase.auth.currentUser;
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

        await supabase.from('profiles').update({
          'photo_url': url,
        }).eq('id', user.id);

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
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _activeTab == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_activeTab != null) {
          setState(() {
            _activeTab = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            _activeTab == null
                ? 'Preacher Dashboard'
                : _activeTab == 'payment'
                    ? 'Payment Reminder'
                    : _activeTab!.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2, color: Color(0xFF1E293B)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: _activeTab != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
                  onPressed: () {
                    setState(() {
                      _activeTab = null;
                    });
                  },
                )
              : null,
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
        body: _activeTab == null ? _buildMainGrid() : _buildTabContent(),
      ),
    );
  }

  Widget _buildMainGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _updateMainProfilePhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: (_profile?['photo_url'] != null && _profile!['photo_url'].toString().trim().isNotEmpty)
                              ? Image.network(
                                  _profile!['photo_url'].toString().trim(),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('Image loading error: $error');
                                    return Center(
                                      child: Text(
                                        (_profile?['name'] ?? 'P')[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    (_profile?['name'] ?? 'P')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _profile?['name'] ?? 'Preacher Portal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PREACHER',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Preacher Control Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.25,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildGridItem(
                title: 'Management',
                icon: Icons.people_alt_outlined,
                color: const Color(0xFFEEF2F6),
                iconColor: const Color(0xFF4F46E5),
                onTap: () => setState(() => _activeTab = 'management'),
              ),
              _buildGridItem(
                title: 'Online Session',
                icon: Icons.video_camera_back_outlined,
                color: const Color(0xFFE6F4EA),
                iconColor: const Color(0xFF0F9D58),
                onTap: () => setState(() => _activeTab = 'online'),
              ),
              _buildGridItem(
                title: 'Announcements',
                icon: Icons.campaign_outlined,
                color: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                onTap: () => setState(() => _activeTab = 'announcements'),
              ),
              _buildGridItem(
                title: 'Attendance',
                icon: Icons.check_circle_outline_outlined,
                color: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                onTap: () => setState(() => _activeTab = 'attendance'),
              ),
              _buildGridItem(
                title: 'Birthday Wishes',
                icon: Icons.cake_outlined,
                color: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFDB2777),
                onTap: () => setState(() => _activeTab = 'birthday'),
              ),
              _buildGridItem(
                title: 'Plan Trip',
                icon: Icons.alt_route_outlined,
                color: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                onTap: () => setState(() => _activeTab = 'trip'),
              ),
              _buildGridItem(
                title: 'Post Event',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF0D9488),
                onTap: () => setState(() => _activeTab = 'event'),
              ),
              _buildGridItem(
                title: 'Block List',
                icon: Icons.block_outlined,
                color: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
                onTap: () => setState(() => _activeTab = 'blocklist'),
              ),
              _buildGridItem(
                title: 'Accommodation',
                icon: Icons.home_outlined,
                color: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                onTap: () => setState(() => _activeTab = 'accommodation'),
              ),
              _buildGridItem(
                title: 'Approval',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFFCCFBF1),
                iconColor: const Color(0xFF0F766E),
                onTap: () => setState(() => _activeTab = 'approval'),
                badgeCount: _pendingApprovalCount,
              ),
              _buildGridItem(
                title: 'Residency Admission',
                icon: Icons.school_outlined,
                color: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                onTap: () => setState(() => _activeTab = 'residency'),
              ),
              _buildGridItem(
                title: 'Payment Reminder',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                onTap: () => setState(() => _activeTab = 'payment'),
                badgeCount: _pendingPaymentCount,
              ),
              _buildGridItem(
                title: 'Notification',
                icon: Icons.notifications_none_outlined,
                color: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                onTap: () => setState(() => _activeTab = 'notifications'),
              ),
              _buildGridItem(
                title: 'Message',
                icon: Icons.chat_bubble_outline_outlined,
                color: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0369A1),
                onTap: () => setState(() => _activeTab = 'message'),
              ),
              _buildGridItem(
                title: 'Settings',
                icon: Icons.settings_outlined,
                color: const Color(0xFFFFF1F2),
                iconColor: const Color(0xFFF43F5E),
                onTap: () => setState(() => _activeTab = 'settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem({
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
        padding: const EdgeInsets.all(12),
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

  Widget _buildTabContent() {
    final activeFolkBoys = _folkBoys.where((b) => !(b['role'] as String? ?? '').startsWith('pending_')).toList();

    switch (_activeTab) {
      case 'management':
        return ManagementTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'online':
        return OnlineSessionTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'notifications':
        return NotificationsTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'announcements':
        return AnnouncementsTab(
          announcements: _announcements,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'attendance':
        return AttendanceTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
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
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'event':
        return EventTab(
          announcements: _announcements,
          eventBookings: _eventBookings,
          folkBoys: activeFolkBoys,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'blocklist':
        return BlocklistTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'accommodation':
        return AccommodationTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'approval':
        return ApprovalTab(
          allUpdates: _allUpdates,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
          preacherProfile: _profile,
          folkBoys: _folkBoys,
        );
      case 'residency':
        return ResidencyTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          preacherProfile: _profile,
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
      case 'payment':
        return PaymentTab(
          folkBoys: activeFolkBoys,
          allUpdates: _allUpdates,
          supabase: supabase,
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
          supabase: supabase,
          onRefresh: _loadProfileAndData,
        );
    }
    return const SizedBox.shrink();
  }
}
