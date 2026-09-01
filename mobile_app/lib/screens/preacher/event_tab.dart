import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class EventTab extends StatefulWidget {
  final List<dynamic> announcements;
  final List<dynamic> eventBookings;
  final List<dynamic> folkBoys;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const EventTab({
    super.key,
    required this.announcements,
    required this.eventBookings,
    required this.folkBoys,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<EventTab> createState() => _EventTabState();
}

class _EventTabState extends State<EventTab> {
  final _picker = ImagePicker();
  final _eventNameController = TextEditingController();
  final _eventBookingLinkController = TextEditingController();
  final _eventAttendanceSearchController = TextEditingController();

  DateTime _eventDate = DateTime.now();
  TimeOfDay _eventTime = const TimeOfDay(hour: 18, minute: 0);
  String? _eventPosterUrl;
  bool _isEventPosterLoading = false;

  DateTime? _eventAttendanceDateFilter;
  String _eventAttendanceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _eventAttendanceSearchController.addListener(() {
      setState(() {
        _eventAttendanceSearchQuery = _eventAttendanceSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventBookingLinkController.dispose();
    _eventAttendanceSearchController.dispose();
    super.dispose();
  }

  Future<void> _uploadEventPoster() async {
    setState(() => _isEventPosterLoading = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        setState(() {
          _eventPosterUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Error uploading event poster: $e');
    } finally {
      setState(() => _isEventPosterLoading = false);
    }
  }

  Future<void> _postEvent() async {
    final name = _eventNameController.text.trim();
    final link = _eventBookingLinkController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Event Title')),
        );
      }
      return;
    }

    setState(() => _isEventPosterLoading = true);

    final dateStr = DateFormat('d MMM yyyy').format(_eventDate);
    final timeStr = _eventTime.format(context);

    final formattedContent = '[EVENT] $name | $dateStr | $timeStr | ${_eventPosterUrl ?? ''} | $link';

    try {
      await widget.supabase.from('announcements').insert({
        'content': formattedContent,
        'preacher_id': widget.preacherProfile!['id'],
      });
      _eventNameController.clear();
      _eventBookingLinkController.clear();
      setState(() {
        _eventPosterUrl = null;
      });
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Festival / Event Announcement published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error posting event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish Event: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isEventPosterLoading = false);
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await widget.supabase.from('announcements').delete().eq('id', id);
      await widget.onRefresh();
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAnnouncements = widget.announcements.where((a) => (a['content'] ?? '').toString().startsWith('[EVENT]')).toList();
    final eventAttendanceLogs = List.from(widget.eventBookings);

    var filteredEventLogs = eventAttendanceLogs;
    if (_eventAttendanceDateFilter != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_eventAttendanceDateFilter!);
      filteredEventLogs = filteredEventLogs.where((u) => u['date'] == selectedDateStr).toList();
    }
    if (_eventAttendanceSearchQuery.isNotEmpty) {
      final query = _eventAttendanceSearchQuery.toLowerCase();
      filteredEventLogs = filteredEventLogs.where((u) {
        final name = (u['worker_name'] ?? '').toString().toLowerCase();
        final mobile = (u['description'] ?? '').toString().toLowerCase();
        final eventTitle = (u['work_started'] ?? '').toString().toLowerCase();
        return name.contains(query) || mobile.contains(query) || eventTitle.contains(query);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Post New Seva / Youth Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: _isEventPosterLoading ? null : _uploadEventPoster,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        image: _eventPosterUrl != null ? DecorationImage(image: NetworkImage(_eventPosterUrl!), fit: BoxFit.cover) : null,
                      ),
                      child: _eventPosterUrl == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_seat_outlined, color: Colors.indigo),
                                  SizedBox(height: 4),
                                  Text('Select Event Poster Image', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _eventNameController,
                    decoration: InputDecoration(
                      labelText: 'Event Title (e.g. Sri Krishna Janmashtami)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _eventDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _eventDate = date);
                          },
                          child: Text('Date: ${DateFormat('d MMM yyyy').format(_eventDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _eventTime,
                            );
                            if (time != null) setState(() => _eventTime = time);
                          },
                          child: Text('Time: ${_eventTime.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _eventBookingLinkController,
                    decoration: InputDecoration(
                      labelText: 'Passes / Registration Link (Forms, etc.)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isEventPosterLoading ? null : _postEvent,
                      child: _isEventPosterLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('PUBLISH EVENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Active Festivals & Events Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          
          eventAnnouncements.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No active scheduled events.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventAnnouncements.length,
                  itemBuilder: (context, idx) {
                    final e = eventAnnouncements[idx];
                    final contentRaw = (e['content'] ?? '').toString().replaceFirst('[EVENT] ', '');
                    final parts = contentRaw.split(' | ');
                    final evName = parts.isNotEmpty ? parts[0] : 'Event';
                    final evDate = parts.length > 1 ? parts[1] : '';
                    final evTime = parts.length > 2 ? parts[2] : '';
                    final banner = parts.length > 3 ? parts[3] : '';
                    final bookingUrl = parts.length > 4 ? parts[4] : '';

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (banner.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                              child: Image.network(banner, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(evName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('Scheduled: $evDate @ $evTime', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      if (bookingUrl.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text('Booking URL: $bookingUrl', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ]
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteAnnouncement(e['id']),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
          
          const SizedBox(height: 24),
          
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Colors.grey[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Event Booking Attendance Logs', 
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCCFBF1)),
                        ),
                        child: Text(
                          'Total Booked: ${filteredEventLogs.length}',
                          style: const TextStyle(color: Color(0xFF0F766E), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _eventAttendanceSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name or event...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                            suffixIcon: _eventAttendanceSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                    onPressed: () => _eventAttendanceSearchController.clear(),
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
                          foregroundColor: _eventAttendanceDateFilter != null ? const Color(0xFF0D9488) : Colors.grey[700],
                          side: BorderSide(
                            color: _eventAttendanceDateFilter != null ? const Color(0xFF0D9488) : Colors.grey[300]!,
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          _eventAttendanceDateFilter != null 
                              ? DateFormat('dd MMM').format(_eventAttendanceDateFilter!) 
                              : 'Filter Date',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _eventAttendanceDateFilter ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() {
                              _eventAttendanceDateFilter = date;
                            });
                          }
                        },
                      ),
                      if (_eventAttendanceDateFilter != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _eventAttendanceDateFilter = null;
                            });
                          },
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  filteredEventLogs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Column(
                              children: [
                                const Icon(Icons.event_seat_outlined, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _eventAttendanceSearchQuery.isNotEmpty || _eventAttendanceDateFilter != null
                                      ? 'No attendees match filters'
                                      : 'No bookings registered yet',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredEventLogs.length,
                          itemBuilder: (context, index) {
                            final u = filteredEventLogs[index];
                            final name = u['worker_name'] ?? 'Folk Boy / Resident';
                            final mobile = u['description'] ?? 'No mobile';
                            final eventName = (u['work_started'] ?? 'Event').toString().replaceFirst('Event: ', '');
                            
                            String bookTime = '---';
                            if (u['created_at'] != null) {
                              try {
                                final parsed = DateTime.parse(u['created_at']).toLocal();
                                bookTime = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
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
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: role == 'residency' ? const Color(0xFFFAF5FF) : const Color(0xFFF0F9FF),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: role == 'residency' ? const Color(0xFFE9D5FF) : const Color(0xFFBAE6FD),
                                                ),
                                              ),
                                              child: Text(
                                                role == 'residency' ? 'RESIDENCY' : 'FOLK BOY',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: role == 'residency' ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mobile: $mobile',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Event: $eventName',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Booked: $bookTime',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[500])
                                        ),
                                      ],
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
          )
        ],
      ),
    );
  }
}
