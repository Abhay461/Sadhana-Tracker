import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/cloudinary_service.dart';

class FestivalTab extends StatefulWidget {
  const FestivalTab({super.key});

  @override
  State<FestivalTab> createState() => _FestivalTabState();
}

class _FestivalTabState extends State<FestivalTab> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  File? _pickedImage;
  bool _isUploading = false;
  bool _isLoading = true;
  List<dynamic> _festivals = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchFestivals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchFestivals() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/festivals/all');
      if (res is List) {
        setState(() {
          _festivals = res;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching festivals: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _saveFestival() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Festival Title')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String imageUrl = '';
      if (_pickedImage != null) {
        imageUrl = await CloudinaryService.uploadToCloudinary(_pickedImage!);
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      await ApiService.post('/festivals', {
        'title': title,
        'imageUrl': imageUrl,
        'dateString': dateStr,
        'isActive': true,
      });

      _titleController.clear();
      setState(() {
        _pickedImage = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Festival added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _fetchFestivals();
    } catch (e) {
      debugPrint('Error saving festival: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFestival(String id) async {
    try {
      await ApiService.delete('/festivals/$id');
      await _fetchFestivals();
    } catch (e) {
      debugPrint('Error deleting festival: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Festival Form Card
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.festival_rounded, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text(
                        'Add Today/Upcoming Festival',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Festival Title *',
                      hintText: 'e.g. Sri Krishna Janmashtami',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(
                            _pickedImage != null ? Icons.check_circle : Icons.image_rounded,
                            color: _pickedImage != null ? Colors.green : null,
                            size: 18,
                          ),
                          label: Text(_pickedImage != null ? 'Image Selected' : 'Add Image'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveFestival,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Publish Festival', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Festival List',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_festivals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text('No festivals created yet.', style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _festivals.length,
              itemBuilder: (context, index) {
                final item = _festivals[index];
                final id = item['_id'] as String? ?? '';
                final title = item['title'] as String? ?? '';
                final dateStr = item['dateString'] as String? ?? '';
                final desc = item['description'] as String? ?? '';
                final imgUrl = item['imageUrl'] as String? ?? '';

                final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

                return Card(
                  color: isToday ? const Color(0xFFFFFBEB) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isToday ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: imgUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.festival_rounded, color: Color(0xFFD97706))),
                            )
                          : const Icon(Icons.festival_rounded, color: Color(0xFFD97706)),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(4)),
                            child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    subtitle: Text('📅 $dateStr ${desc.isNotEmpty ? "• $desc" : ""}', style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _deleteFestival(id),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
