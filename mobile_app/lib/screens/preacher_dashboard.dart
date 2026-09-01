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

  List<dynamic> _folkBoys = [];
  Map<String, List<dynamic>> _allUpdates = {}; // userId -> list of updates
  List<dynamic> _announcements = [];
  List<dynamic> _tripBookings = [];
  List<dynamic> _eventBookings = [];

  // Active View Tab identifier
  String? _activeTab;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileAndData();
  }

  Future<void> _loadProfileAndData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final profileData = await ApiService.get('/users/me');

      final role = (profileData is Map ? profileData['role'] : null) as String?;
      if (role != 'preacher' && role != 'admin') {
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
      final data = await ApiService.get('/users/students');

      if (mounted) {
        setState(() {
          _folkBoys = data is List ? data : [];
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
      final tripData = await ApiService.get('/trips/registrations');
      final eventData = await ApiService.get('/events/registrations');

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

  Future<void> _fetchAllUpdates() async {
    await _fetchTripAndEventBookings();
    if (_folkBoys.isEmpty) return;
    try {
      final updatesData = await ApiService.get('/sadhana/students');
      final List<dynamic> processedUpdates = updatesData is List ? List.from(updatesData) : [];
      
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
        backgroundColor: Color(0xFFFAF8F5),
        body: Center(child: CircularProgressIndicator()),
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
          child: PopScope(
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
                            GestureDetector(
                              onTap: _updateMainProfilePhoto,
                              child: CircleAvatar(
                                radius: 24,
                                backgroundImage: (_profile?['photo_url'] != null && _profile!['photo_url'].toString().trim().isNotEmpty)
                                    ? NetworkImage(_profile!['photo_url'].toString().trim())
                                    : null,
                                backgroundColor: const Color(0xFFEEF2F6),
                                child: (_profile?['photo_url'] == null || _profile!['photo_url'].toString().trim().isEmpty)
                                    ? Text(
                                        (_profile?['name'] ?? 'P')[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3F1200),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hare Krishna, ${_profile?['name'] ?? 'Preacher'}',
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
    }
    return const SizedBox.shrink();
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
