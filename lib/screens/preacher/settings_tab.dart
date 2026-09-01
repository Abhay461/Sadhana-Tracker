import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class SettingsTab extends StatefulWidget {
  final Map<String, dynamic>? preacherProfile;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const SettingsTab({
    super.key,
    required this.preacherProfile,
    required this.supabase,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Colors.grey[100]!)),
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
                          child: _settingsPhotoUrl == null ? const Icon(Icons.person, size: 48, color: Colors.grey) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _settingsWhatsappController,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp Number',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                            const Text('YOUR PREACHER CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                            const SizedBox(height: 4),
                            Text(widget.preacherProfile?['preacher_code'] ?? '---', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.black)),
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
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSettingsSaving ? null : _saveSettingsProfile,
                      child: _isSettingsSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
