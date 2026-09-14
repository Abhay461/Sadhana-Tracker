import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isAdminVerified = false;

  // Tabs and Preachers list state
  final ImagePicker _picker = ImagePicker();
  int _selectedTab = 0; // 0 = Create Preacher, 1 = Preachers Directory, 2 = Daily Darshan, 3 = Daily Quote, 4 = YouTube Banner
  List<dynamic> _preachers = [];
  Map<String, List<dynamic>> _preacherStudents = {};
  bool _isLoadingPreachersList = false;

  List<dynamic> _publishedDarshans = [];
  List<dynamic> _publishedQuotes = [];
  List<dynamic> _publishedAnnouncements = [];
  bool _isLoadingDarshans = false;
  bool _isLoadingQuotes = false;
  bool _isLoadingAnnouncements = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _fetchPreachersAndStats();
    _fetchPublishedDarshans();
    _fetchPublishedQuotes();
    _fetchPublishedAnnouncements();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Admin Access Denied: no user');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
      return;
    }

    try {
      final profile = await ApiService.get('/users/me');

      if (profile == null || (profile is Map && profile['role'] != 'admin')) {
        debugPrint('Admin Access Denied: insufficient role');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isAdminVerified = true;
        });
      }
    } catch (e) {
      debugPrint('Admin check error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _fetchPublishedDarshans() async {
    setState(() => _isLoadingDarshans = true);
    try {
      final res = await ApiService.get('/daily-darshan/all');
      if (res is List) {
        setState(() => _publishedDarshans = res);
      } else if (res is Map && res.containsKey('imageUrls')) {
        setState(() => _publishedDarshans = [res]);
      }
    } catch (e) {
      debugPrint('Error fetching darshans: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDarshans = false);
    }
  }

  Future<void> _fetchPublishedQuotes() async {
    setState(() => _isLoadingQuotes = true);
    try {
      final res = await ApiService.get('/daily-quotes');
      if (res is List) {
        setState(() => _publishedQuotes = res);
      }
    } catch (e) {
      debugPrint('Error fetching quotes: $e');
    } finally {
      if (mounted) setState(() => _isLoadingQuotes = false);
    }
  }

  Future<void> _fetchPublishedAnnouncements() async {
    setState(() => _isLoadingAnnouncements = true);
    try {
      final res = await ApiService.get('/announcements');
      if (res is List) {
        setState(() => _publishedAnnouncements = res);
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  Future<bool> _showDeleteConfirmDialog(String itemType) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemType'),
        content: Text('Are you sure you want to delete this $itemType? This will permanently delete text from MongoDB and images from Cloudinary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _fetchPreachersAndStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPreachersList = true;
    });
    try {
      final preachersData = await ApiService.get('/admin/preachers');

      final Map<String, List<dynamic>> grouped = {};
      if (preachersData is List) {
        for (final preacher in preachersData) {
          if (preacher is Map) {
            final id = (preacher['_id'] ?? preacher['id'])?.toString();
            if (id != null && preacher['students'] is List) {
              grouped[id] = List<dynamic>.from(preacher['students'] as List);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _preachers = preachersData is List ? preachersData : [];
          _preacherStudents = grouped;
          _isLoadingPreachersList = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching preachers list: $e');
      if (mounted) {
        setState(() {
          _isLoadingPreachersList = false;
        });
      }
    }
  }

  Future<void> _shareCredentialsViaEmail(
    String email,
    String password,
    String code,
  ) async {
    final message = "Hare Krishna!\n\n"
        "Your Preacher account has been created successfully.\n\n"
        "Login Credentials:\n"
        "Email: $email\n"
        "Password: $password\n"
        "Preacher Code: $code\n\n"
        "Please download the Sadhana Tracker app and login using these credentials.";
    
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Sadhana Tracker Preacher Account Credentials',
        'body': message,
      },
    );
    
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        final Uri simpleMailto = Uri(scheme: 'mailto', path: email);
        if (await canLaunchUrl(simpleMailto)) {
          await launchUrl(simpleMailto);
        } else {
          debugPrint('Could not launch email');
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  Future<void> _handleCreatePreacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final whatsapp = _whatsappController.text.trim();
      final password = _passwordController.text.trim();
      
      final created = await ApiService.post('/admin/preachers', {
        'name': name,
        'email': email,
        'password': password,
        'phoneNumber': whatsapp,
      });
      final code = created is Map ? (created['preacherCode'] ?? 'assigned by the server').toString() : 'assigned by the server';

      if (!mounted) return;
      setState(() {
        _successMessage = 'Preacher created successfully! Code: $code.';
        _nameController.clear();
        _emailController.clear();
        _whatsappController.clear();
        _passwordController.clear();
      });

      _fetchPreachersAndStats();
      _shareCredentialsViaEmail(email, password, code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPreacherStudentsDetail(String preacherName, List<dynamic> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Students of $preacherName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F1200),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: students.isEmpty
                    ? const Center(
                        child: Text(
                          'No students registered under this preacher.',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final role = student['role']?.toString() ?? 'folk_boy';
                          final roleDisplay = role.contains('residency') ? 'Residency' : 'Folk Boy';
                          final isPending = role.startsWith('pending_');
                          final statusDisplay = isPending ? ' (Pending)' : '';
                          
                          final rawPhone = student['phoneNumber'] ?? student['whatsapp_number'] ?? 'N/A';
                          final phone = rawPhone.split('|').first.trim();
                          
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(
                                  (student['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF3F1200),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                student['name'] ?? 'No Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF3F1200),
                                ),
                              ),
                              subtitle: Text(
                                '$roleDisplay$statusDisplay\nWhatsApp: $phone',
                                style: const TextStyle(fontSize: 12, height: 1.4),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreachersDirectoryView() {
    if (_isLoadingPreachersList) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F1200)),
          ),
        ),
      );
    }

    if (_preachers.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No preachers found.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _preachers.length,
      itemBuilder: (context, index) {
        final preacher = _preachers[index];
        final preacherId = (preacher['_id'] ?? preacher['id']).toString();
        final students = _preacherStudents[preacherId] ?? [];
        
        final folkCount = students.where((s) => s['role'] == 'folk_boy' || s['role'] == 'pending_folk_boy').length;
        final residencyCount = students.where((s) => s['role'] == 'residency' || s['role'] == 'pending_residency').length;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              child: Text(
                (preacher['name'] ?? 'P')[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF3F1200),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              preacher['name'] ?? 'No Name',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F1200),
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Code: ${preacher['preacherCode'] ?? preacher['preacher_code'] ?? 'N/A'}'),
                Text('Email: ${preacher['email'] ?? 'N/A'}'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Folk: $folkCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Residency: $residencyCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showPreacherStudentsDetail(preacher['name'] ?? 'Preacher', students),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdminVerified) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F1200)),
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
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clean Header
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF3F1200), size: 16),
                            label: const Text(
                              'Back to Dashboard',
                              style: TextStyle(color: Color(0xFF3F1200), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Color(0xFF3F1200), size: 20),
                            tooltip: 'Logout',
                            onPressed: () {
                              try {
                                FirebaseAuth.instance.signOut().catchError((_) {});
                              } catch (_) {}
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Color(0xFF3F1200), size: 32),
                          SizedBox(width: 12),
                          Text(
                            'Admin Portal',
                            style: TextStyle(color: Color(0xFF3F1200), fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create and manage preacher accounts',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Tab Selection Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Create Preacher',
                            style: TextStyle(
                              color: _selectedTab == 0 ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: _selectedTab == 0,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedTab = 0);
                          },
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _selectedTab == 0 ? Colors.transparent : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Preachers Directory',
                            style: TextStyle(
                              color: _selectedTab == 1 ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: _selectedTab == 1,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTab = 1);
                              _fetchPreachersAndStats();
                            }
                          },
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _selectedTab == 1 ? Colors.transparent : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Daily Darshan',
                            style: TextStyle(
                              color: _selectedTab == 2 ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: _selectedTab == 2,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTab = 2);
                            }
                          },
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _selectedTab == 2 ? Colors.transparent : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Daily Quote',
                            style: TextStyle(
                              color: _selectedTab == 3 ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: _selectedTab == 3,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTab = 3);
                            }
                          },
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _selectedTab == 3 ? Colors.transparent : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.video_library, size: 14, color: _selectedTab == 4 ? Colors.white : Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                'YouTube Banner',
                                style: TextStyle(
                                  color: _selectedTab == 4 ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          selected: _selectedTab == 4,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTab = 4);
                            }
                          },
                          selectedColor: const Color(0xFFDC2626),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _selectedTab == 4 ? Colors.transparent : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedTab == 4
                        ? _buildYouTubeBannerPublishView()
                        : _selectedTab == 3
                        ? _buildDailyQuotePublishView()
                        : _selectedTab == 2
                            ? _buildDailyDarshanPublishView()
                            : _selectedTab == 0
                            ? Form(
                                key: _formKey,
                            child: Column(
                              children: [
                                // Success message banner
                                if (_successMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _successMessage!,
                                                style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Email client has been launched with credentials and code.',
                                          style: TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.w600),
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Error message banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Preacher Name
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Preacher Name',
                                    prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Enter preacher name' : null,
                                ),
                                const SizedBox(height: 16),

                                // Email Address
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: const Icon(Icons.mail_outline, color: Colors.grey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter email address';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // WhatsApp Number
                                TextFormField(
                                  controller: _whatsappController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'WhatsApp Number',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12.0),
                                      child: Text('  💬 ', style: TextStyle(fontSize: 16)),
                                    ),
                                    hintText: 'e.g. 9876543210',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Enter WhatsApp number';
                                    final cleanVal = value.trim();
                                    if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(cleanVal)) {
                                      return 'Enter valid 10-digit number or +91 format';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Initial Password
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Initial Password',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter password';
                                    if (value.length < 8) return 'Password must be at least 8 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Create Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleCreatePreacher,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3F1200),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Create Preacher Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildPreachersDirectoryView(),
                  ),
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

  Widget _buildDailyDarshanPublishView() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    List<File> selectedFiles = [];
    bool isUploading = false;

    return StatefulBuilder(
      builder: (context, setPublishState) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.temple_hindu_rounded, color: Color(0xFF0F172A), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Publish Today\'s Darshan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final images = await _picker.pickMultiImage();
                          if (images.isNotEmpty) {
                            setPublishState(() {
                              selectedFiles = images.map((x) => File(x.path)).toList();
                            });
                          }
                        },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(
                    selectedFiles.isEmpty
                        ? 'Choose Darshan Photos'
                        : '${selectedFiles.length} Photos Selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedFiles.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(selectedFiles[idx], width: 80, height: 80, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (isUploading || selectedFiles.isEmpty)
                        ? null
                        : () async {
                            setPublishState(() {
                              isUploading = true;
                            });

                            try {
                              final List<String> uploadedUrls = [];
                              for (var file in selectedFiles) {
                                final url = await CloudinaryService.uploadToCloudinary(file);
                                uploadedUrls.add(url);
                              }

                              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                              await ApiService.post('/daily-darshan', {
                                'date': todayStr,
                                'title': 'Daily Darshan',
                                'description': '',
                                'imageUrls': uploadedUrls,
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Daily Darshan published successfully!')),
                                );
                                setPublishState(() {
                                  selectedFiles.clear();
                                  titleController.clear();
                                  descriptionController.clear();
                                  isUploading = false;
                                });
                                _fetchPublishedDarshans();
                              }
                            } catch (e) {
                              setPublishState(() {
                                isUploading = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to publish Darshan: $e')),
                                );
                              }
                            }
                          },
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish Daily Darshan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Published Daily Darshans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                if (_isLoadingDarshans)
                  const Center(child: CircularProgressIndicator())
                else if (_publishedDarshans.isEmpty)
                  const Text('No Daily Darshans published yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._publishedDarshans.map((d) {
                    final id = (d['_id'] ?? d['id'])?.toString() ?? '';
                    final title = d['title']?.toString() ?? 'Daily Darshan';
                    final date = d['date']?.toString() ?? '';
                    final images = (d['imageUrls'] is List) ? List<String>.from(d['imageUrls']) : [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ListTile(
                        leading: images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(images.first, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)),
                              )
                            : const Icon(Icons.temple_hindu_rounded, color: Colors.orange),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Date: $date • ${images.length} Photos', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () async {
                            final confirm = await _showDeleteConfirmDialog('Daily Darshan');
                            if (!confirm) return;
                            try {
                              await ApiService.delete('/daily-darshan/$id');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Daily Darshan deleted from MongoDB & Cloudinary!')),
                                );
                                _fetchPublishedDarshans();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Delete failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyQuotePublishView() {
    List<File> selectedFiles = [];
    bool isUploading = false;

    return StatefulBuilder(
      builder: (context, setPublishState) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded, color: Color(0xFF0F172A), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Publish Today\'s Quote',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final image = await _picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setPublishState(() {
                              selectedFiles = [File(image.path)];
                            });
                          }
                        },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(
                    selectedFiles.isEmpty
                        ? 'Choose Quote Photo from Gallery'
                        : '1 Photo Selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(selectedFiles.first, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (selectedFiles.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please choose a quote photo from gallery')),
                              );
                              return;
                            }

                            setPublishState(() => isUploading = true);
                            try {
                              List<String> imageUrls = [];
                              for (var file in selectedFiles) {
                                final url = await CloudinaryService.uploadToCloudinary(file);
                                imageUrls.add(url);
                              }

                              final today = DateTime.now().toIso8601String().split('T')[0];
                              await ApiService.post('/daily-quotes', {
                                'date': today,
                                'imageUrls': imageUrls,
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Daily Quote published successfully!')),
                                );
                                setPublishState(() {
                                  selectedFiles.clear();
                                  isUploading = false;
                                });
                                _fetchPublishedQuotes();
                              }
                            } catch (e) {
                              setPublishState(() => isUploading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to publish Quote: $e')),
                                );
                              }
                            }
                          },
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish Daily Quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Published Daily Quotes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                if (_isLoadingQuotes)
                  const Center(child: CircularProgressIndicator())
                else if (_publishedQuotes.isEmpty)
                  const Text('No Daily Quotes published yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._publishedQuotes.map((q) {
                    final id = (q['_id'] ?? q['id'])?.toString() ?? '';
                    final date = q['date']?.toString() ?? '';
                    final images = (q['imageUrls'] is List) ? List<String>.from(q['imageUrls']) : [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ListTile(
                        leading: images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(images.first, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.format_quote)),
                              )
                            : const Icon(Icons.format_quote_rounded, color: Colors.blue),
                        title: Text('Quote ($date)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(images.isNotEmpty ? 'Photo Quote' : 'Text Quote', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () async {
                            final confirm = await _showDeleteConfirmDialog('Daily Quote');
                            if (!confirm) return;
                            try {
                              await ApiService.delete('/daily-quotes/$id');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Daily Quote deleted from MongoDB & Cloudinary!')),
                                );
                                _fetchPublishedQuotes();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Delete failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYouTubeBannerPublishView() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final bannerController = TextEditingController();
    bool isPosting = false;

    return StatefulBuilder(
      builder: (context, setPublishState) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.video_library_rounded, color: Colors.red, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Publish YouTube Video Banner',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'This video banner will appear right below Daily Darshan on Folk Boy Home Page.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Video Title (e.g. Sunday Youth Festival)',
                    prefixIcon: const Icon(Icons.title_rounded, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'YouTube Video Link (e.g. https://youtu.be/...)',
                    prefixIcon: const Icon(Icons.link_rounded, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bannerController,
                  decoration: InputDecoration(
                    labelText: 'Banner Image URL (Optional - Auto thumbnail if empty)',
                    prefixIcon: const Icon(Icons.image_outlined, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isPosting
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final youtubeUrl = urlController.text.trim();
                            String bannerUrl = bannerController.text.trim();

                            if (title.isEmpty || youtubeUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter Video Title and YouTube Link')),
                              );
                              return;
                            }

                            if (bannerUrl.isEmpty) {
                              final regExp = RegExp(
                                r'^.*(?:youtu.be\/|v\/|e\/|u\/\w+\/|embed\/|v=)([^#\&\?]*).*',
                                caseSensitive: false,
                              );
                              final match = regExp.firstMatch(youtubeUrl);
                              if (match != null && match.group(1)!.length == 11) {
                                bannerUrl = 'https://img.youtube.com/vi/${match.group(1)}/hqdefault.jpg';
                              }
                            }

                            setPublishState(() => isPosting = true);

                            try {
                              final contentPayload = '[YOUTUBE] $title | $bannerUrl | $youtubeUrl';
                              final adminUser = FirebaseAuth.instance.currentUser;
                              await ApiService.post('/announcements', {
                                'content': contentPayload,
                                'preacher_id': adminUser?.uid ?? 'admin',
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('YouTube Video Banner published successfully!')),
                                );
                                titleController.clear();
                                urlController.clear();
                                bannerController.clear();
                                setPublishState(() => isPosting = false);
                                _fetchPublishedAnnouncements();
                              }
                            } catch (e) {
                              setPublishState(() => isPosting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to publish Video Banner: $e')),
                                );
                              }
                            }
                          },
                    child: isPosting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish YouTube Video Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Published YouTube Video Banners',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                if (_isLoadingAnnouncements)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Builder(builder: (context) {
                    final youtubeList = _publishedAnnouncements.where((a) => a['content']?.toString().startsWith('[YOUTUBE]') == true || a['category'] == 'youtube' || a['type'] == 'youtube').toList();
                    if (youtubeList.isEmpty) {
                      return const Text('No YouTube Video Banners published yet.', style: TextStyle(color: Colors.grey));
                    }

                    return Column(
                      children: youtubeList.map((item) {
                        final id = (item['_id'] ?? item['id'])?.toString() ?? '';
                        final content = item['content']?.toString() ?? '';
                        final parts = content.replaceFirst('[YOUTUBE] ', '').split(' | ');
                        final title = parts.isNotEmpty ? parts[0] : (item['title'] ?? 'YouTube Video');
                        final banner = parts.length > 1 ? parts[1] : (item['banner_url'] ?? '');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                          child: ListTile(
                            leading: banner.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(banner, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red)),
                                  )
                                : const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 32),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: const Text('YouTube Banner', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () async {
                                final confirm = await _showDeleteConfirmDialog('YouTube Banner');
                                if (!confirm) return;
                                try {
                                  await ApiService.delete('/announcements/$id');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('YouTube Banner deleted from MongoDB & Cloudinary!')),
                                    );
                                    _fetchPublishedAnnouncements();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Delete failed: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
