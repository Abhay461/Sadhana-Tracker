import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class SettingsTab extends StatefulWidget {
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const SettingsTab({
    super.key,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _picker = ImagePicker();
  final _settingsNameController = TextEditingController();
  final _settingsWhatsappController = TextEditingController();

  String? _settingsPhotoUrl;
  bool _isSettingsSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preacherProfile != null) {
      _settingsNameController.text = widget.preacherProfile!['name'] ?? '';
      _settingsWhatsappController.text = widget.preacherProfile!['whatsapp_number'] ?? '';
      _settingsPhotoUrl = widget.preacherProfile!['photo_url'];
    }
  }

  @override
  void didUpdateWidget(covariant SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preacherProfile != oldWidget.preacherProfile && widget.preacherProfile != null) {
      _settingsNameController.text = widget.preacherProfile!['name'] ?? '';
      _settingsWhatsappController.text = widget.preacherProfile!['whatsapp_number'] ?? '';
      _settingsPhotoUrl = widget.preacherProfile!['photo_url'];
    }
  }

  @override
  void dispose() {
    _settingsNameController.dispose();
    _settingsWhatsappController.dispose();
    super.dispose();
  }

  Future<void> _updateSettingsPhoto() async {
    setState(() => _isSettingsSaving = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        setState(() {
          _settingsPhotoUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Error selecting settings photo: $e');
    } finally {
      setState(() => _isSettingsSaving = false);
    }
  }

  Future<void> _saveSettingsProfile() async {
    final name = _settingsNameController.text.trim();
    final whatsapp = _settingsWhatsappController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSettingsSaving = true);
    try {
      await widget.supabase.from('profiles').update({
        'name': name,
        'whatsapp_number': whatsapp,
        'photo_url': _settingsPhotoUrl,
      }).eq('id', widget.preacherProfile!['id']);

      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings profile: $e');
    } finally {
      setState(() => _isSettingsSaving = false);
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

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter your suggestions or report issues here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
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
    Clipboard.setData(const ClipboardData(text: 'Check out the Sadhana Tracker App to track your daily sadhana! https://sadhana-tracker.example.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App sharing link copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.grey[100]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  InkWell(
                    onTap: _isSettingsSaving ? null : _updateSettingsPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: _settingsPhotoUrl != null ? NetworkImage(_settingsPhotoUrl!) : null,
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: _settingsPhotoUrl == null
                              ? const Icon(Icons.person, size: 48, color: Colors.grey)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3F1200),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _settingsNameController,
                    decoration: InputDecoration(
                      labelText: 'Preacher Full Name',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _settingsWhatsappController,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp Number',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR PREACHER CODE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.preacherProfile?['preacher_code'] ?? '---',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.copy, size: 12),
                          label: const Text('COPY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          onPressed: () {
                            if (widget.preacherProfile?['preacher_code'] != null) {
                              Clipboard.setData(ClipboardData(text: widget.preacherProfile!['preacher_code']));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preacher Code copied to clipboard!')),
                              );
                            }
                          },
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F1200),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSettingsSaving ? null : _saveSettingsProfile,
                      child: _isSettingsSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
                  const Divider(height: 32, color: Color(0xFFF1F5F9), thickness: 1.5),
                  Column(
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
                      const Divider(indent: 56, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.rate_review_outlined, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Send us your valuable feedback', style: TextStyle(fontSize: 12)),
                        onTap: _showFeedbackDialog,
                      ),
                      const Divider(indent: 56, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.privacy_tip_outlined, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Read our data and privacy terms', style: TextStyle(fontSize: 12)),
                        onTap: _showPrivacyPolicyDialog,
                      ),
                      const Divider(indent: 56, color: Color(0xFFF1F5F9)),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8FAFC),
                          child: Icon(Icons.star_outline_rounded, color: Color(0xFF3F1200)),
                        ),
                        title: const Text('Rate the App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Show your support in the store', style: TextStyle(fontSize: 12)),
                        onTap: _showRateAppDialog,
                      ),
                      const Divider(indent: 56, color: Color(0xFFF1F5F9)),
                      ListTile(
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
                ],
              ),
            ),
          ),
          
          // Swipe to Logout Action
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 220,
              height: 48,
              child: _SwipeToLogoutButton(
                onSwipeCompleted: () async {
                  final navigator = Navigator.of(context);
                  try {
                    await widget.supabase.auth.signOut();
                  } catch (_) {}
                  navigator.pushReplacementNamed('/login');
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
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
