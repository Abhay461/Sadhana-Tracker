import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class OnlineSessionTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const OnlineSessionTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    required this.supabase,
    required this.onRefresh,
  });

  @override
  State<OnlineSessionTab> createState() => _OnlineSessionTabState();
}

class _OnlineSessionTabState extends State<OnlineSessionTab> {
  final _picker = ImagePicker();
  final _sessionTitleController = TextEditingController();
  final _sessionLinkController = TextEditingController();
  final _attendanceSearchController = TextEditingController();

  bool _isSessionLoading = false;
  String? _sessionPosterUrl;
  DateTime _sessionDate = DateTime.now();
  TimeOfDay _sessionTime = const TimeOfDay(hour: 18, minute: 0);

  DateTime? _attendanceDateFilter;
  String _attendanceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchOnlineSession();
    _attendanceSearchController.addListener(() {
      setState(() {
        _attendanceSearchQuery = _attendanceSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _sessionTitleController.dispose();
    _sessionLinkController.dispose();
    _attendanceSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnlineSession() async {
    try {
      final sessionData = await widget.supabase
          .from('online_announcements')
          .select('*')
          .eq('id', '00000000-0000-0000-0000-000000000001')
          .maybeSingle();

      if (sessionData != null && mounted) {
        setState(() {
          _sessionTitleController.text = sessionData['title'] ?? '';
          _sessionLinkController.text = sessionData['link'] ?? '';
          _sessionPosterUrl = sessionData['banner_url'];
          
          final timeStr = sessionData['session_time'] as String?;
          if (timeStr != null && timeStr.contains(' @ ')) {
            final parts = timeStr.split(' @ ');
            try {
              _sessionDate = DateTime.parse(parts[0]);
              final timeParts = parts[1].split(':');
              _sessionTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching session in tab: $e');
    }
  }

  Future<void> _uploadPoster() async {
    setState(() => _isSessionLoading = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        setState(() {
          _sessionPosterUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Error uploading poster: $e');
    } finally {
      setState(() => _isSessionLoading = false);
    }
  }

  Future<void> _saveOnlineSession() async {
    setState(() => _isSessionLoading = true);
    try {
      final time24 = '${_sessionTime.hour.toString().padLeft(2, '0')}:${_sessionTime.minute.toString().padLeft(2, '0')}';
      final formattedDate = DateFormat('yyyy-MM-dd').format(_sessionDate);
      final finalTimeStr = '$formattedDate @ $time24';

      await widget.supabase.from('online_announcements').upsert({
        'id': '00000000-0000-0000-0000-000000000001',
        'title': _sessionTitleController.text.trim(),
        'link': _sessionLinkController.text.trim(),
        'banner_url': _sessionPosterUrl,
        'session_time': finalTimeStr,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Online Session updated successfully!')),
        );
      }
      await widget.onRefresh();
    } catch (e) {
      debugPrint('Error saving session: $e');
    } finally {
      setState(() => _isSessionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceLogs = [];
    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        if (u['category'] == 'session_attendance') {
          attendanceLogs.add(u);
        }
      }
    }
    attendanceLogs.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    var filteredLogs = attendanceLogs;
    if (_attendanceDateFilter != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_attendanceDateFilter!);
      filteredLogs = filteredLogs.where((u) => u['date'] == selectedDateStr).toList();
    }
    if (_attendanceSearchQuery.isNotEmpty) {
      final query = _attendanceSearchQuery.toLowerCase();
      filteredLogs = filteredLogs.where((u) {
        final name = (u['worker_name'] ?? '').toString().toLowerCase();
        final mobile = (u['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || mobile.contains(query);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Colors.grey[100]!)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manage Online session details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _isSessionLoading ? null : _uploadPoster,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                        image: _sessionPosterUrl != null
                            ? DecorationImage(image: NetworkImage(_sessionPosterUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _sessionPosterUrl == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.indigo),
                                  SizedBox(height: 8),
                                  Text('Upload Session Poster', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _sessionTitleController,
                    decoration: InputDecoration(
                      labelText: 'Session Title',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _sessionLinkController,
                    decoration: InputDecoration(
                      labelText: 'Meeting Link (Zoom / GMeet)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(_sessionDate)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _sessionDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (date != null) setState(() => _sessionDate = date);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(_sessionTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _sessionTime,
                            );
                            if (time != null) setState(() => _sessionTime = time);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSessionLoading ? null : _saveOnlineSession,
                      child: _isSessionLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE SESSION DETAILS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Colors.grey[100]!)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Session Attendance Logs', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Total Joined: ${filteredLogs.length}',
                          style: const TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _attendanceSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search attendee name...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                            suffixIcon: _attendanceSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                    onPressed: () => _attendanceSearchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          foregroundColor: _attendanceDateFilter != null ? const Color(0xFF0F9D58) : Colors.grey[700],
                          side: BorderSide(
                            color: _attendanceDateFilter != null ? const Color(0xFF0F9D58) : Colors.grey[300]!,
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          _attendanceDateFilter != null 
                              ? DateFormat('dd MMM').format(_attendanceDateFilter!) 
                              : 'Filter Date',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _attendanceDateFilter ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() {
                              _attendanceDateFilter = date;
                            });
                          }
                        },
                      ),
                      if (_attendanceDateFilter != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _attendanceDateFilter = null;
                            });
                          },
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  filteredLogs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _attendanceSearchQuery.isNotEmpty || _attendanceDateFilter != null
                                      ? 'No attendees match filters'
                                      : 'No Folk Boys / Residents have joined yet',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final u = filteredLogs[index];
                            final name = u['worker_name'] ?? 'Member';
                            final mobile = u['description'] ?? 'No mobile';
                            
                            String joinTime = '---';
                            if (u['created_at'] != null) {
                              try {
                                final parsed = DateTime.parse(u['created_at']).toLocal();
                                joinTime = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
                              } catch (_) {}
                            }

                            Map<String, dynamic>? memberProfile;
                            for (var b in widget.folkBoys) {
                              if (b['id'].toString() == u['worker_id'].toString()) {
                                memberProfile = b;
                                break;
                              }
                            }
                            final role = memberProfile != null ? memberProfile['role'] : 'folk_boy';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: role == 'residency' ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: role == 'residency' ? const Color(0xFF9333EA) : const Color(0xFF0284C7)
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name, 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mobile: $mobile',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Joined: $joinTime',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold)
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: role == 'residency' ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      role == 'residency' ? 'RESIDENCY' : 'FOLK BOY',
                                      style: TextStyle(
                                        color: role == 'residency' ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
