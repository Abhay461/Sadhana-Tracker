import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class TripTab extends StatefulWidget {
  final List<dynamic> announcements;
  final List<dynamic> tripBookings;
  final List<dynamic> folkBoys;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const TripTab({
    super.key,
    required this.announcements,
    required this.tripBookings,
    required this.folkBoys,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<TripTab> createState() => _TripTabState();
}

class _TripTabState extends State<TripTab> {
  final _picker = ImagePicker();
  final _tripDestinationController = TextEditingController();
  final _tripBookingLinkController = TextEditingController();
  final _tripAttendanceSearchController = TextEditingController();

  DateTime _tripStartDate = DateTime.now();
  DateTime _tripEndDate = DateTime.now().add(const Duration(days: 3));
  String? _tripPosterUrl;
  bool _isTripPosterLoading = false;

  DateTime? _tripAttendanceDateFilter;
  String _tripAttendanceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tripAttendanceSearchController.addListener(() {
      setState(() {
        _tripAttendanceSearchQuery = _tripAttendanceSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tripDestinationController.dispose();
    _tripBookingLinkController.dispose();
    _tripAttendanceSearchController.dispose();
    super.dispose();
  }

  Future<void> _uploadTripPoster() async {
    setState(() => _isTripPosterLoading = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final url = await CloudinaryService.uploadToCloudinary(File(pickedFile.path));
        setState(() {
          _tripPosterUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Error uploading trip poster: $e');
    } finally {
      setState(() => _isTripPosterLoading = false);
    }
  }

  Future<void> _postTrip() async {
    final dest = _tripDestinationController.text.trim();
    final link = _tripBookingLinkController.text.trim();
    if (dest.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Yatra Destination')),
        );
      }
      return;
    }

    setState(() => _isTripPosterLoading = true);

    final startStr = DateFormat('d MMM').format(_tripStartDate);
    final endStr = DateFormat('d MMM').format(_tripEndDate);
    final dateRange = '$startStr - $endStr';

    final formattedContent = '[TRIP] $dest | $dateRange | ${_tripPosterUrl ?? ''} | $link';

    try {
      await widget.supabase.from('announcements').insert({
        'content': formattedContent,
        'preacher_id': widget.preacherProfile!['id'],
      });
      _tripDestinationController.clear();
      _tripBookingLinkController.clear();
      setState(() {
        _tripPosterUrl = null;
      });
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yatra / Trip Announcement published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error posting trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish Yatra: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isTripPosterLoading = false);
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
    final tripAnnouncements = widget.announcements.where((a) => (a['content'] ?? '').toString().startsWith('[TRIP]')).toList();
    final tripAttendanceLogs = List.from(widget.tripBookings);

    var filteredTripLogs = tripAttendanceLogs;
    if (_tripAttendanceDateFilter != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_tripAttendanceDateFilter!);
      filteredTripLogs = filteredTripLogs.where((u) => u['date'] == selectedDateStr).toList();
    }
    if (_tripAttendanceSearchQuery.isNotEmpty) {
      final query = _tripAttendanceSearchQuery.toLowerCase();
      filteredTripLogs = filteredTripLogs.where((u) {
        final name = (u['worker_name'] ?? '').toString().toLowerCase();
        final mobile = (u['description'] ?? '').toString().toLowerCase();
        final tripTitle = (u['work_started'] ?? '').toString().toLowerCase();
        return name.contains(query) || mobile.contains(query) || tripTitle.contains(query);
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
                  const Text('Publish New Yatra / Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: _isTripPosterLoading ? null : _uploadTripPoster,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        image: _tripPosterUrl != null ? DecorationImage(image: NetworkImage(_tripPosterUrl!), fit: BoxFit.cover) : null,
                      ),
                      child: _tripPosterUrl == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.landscape, color: Colors.indigo),
                                  SizedBox(height: 4),
                                  Text('Select Trip Poster Image', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _tripDestinationController,
                    decoration: InputDecoration(
                      labelText: 'Yatra Destination (e.g. Vrindavan Dham)',
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
                              initialDate: _tripStartDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _tripStartDate = date);
                          },
                          child: Text('Start: ${DateFormat('d MMM').format(_tripStartDate)}'),
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
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _tripEndDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _tripEndDate = date);
                          },
                          child: Text('End: ${DateFormat('d MMM').format(_tripEndDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _tripBookingLinkController,
                    decoration: InputDecoration(
                      labelText: 'Booking Registration Link (Forms, etc.)',
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
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isTripPosterLoading ? null : _postTrip,
                      child: _isTripPosterLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('PUBLISH YATRA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Scheduled Yatras Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          
          tripAnnouncements.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No active scheduled trips.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tripAnnouncements.length,
                  itemBuilder: (context, idx) {
                    final t = tripAnnouncements[idx];
                    final contentRaw = (t['content'] ?? '').toString().replaceFirst('[TRIP] ', '');
                    final parts = contentRaw.split(' | ');
                    final dest = parts.isNotEmpty ? parts[0] : 'Trip';
                    final dates = parts.length > 1 ? parts[1] : '';
                    final banner = parts.length > 2 ? parts[2] : '';
                    final bookingUrl = parts.length > 3 ? parts[3] : '';

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
                                      Text(dest, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('Scheduled dates: $dates', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      if (bookingUrl.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text('Registration URL: $bookingUrl', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ]
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteAnnouncement(t['id']),
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
                        'Yatra Booking Attendance Logs', 
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Text(
                          'Total Booked: ${filteredTripLogs.length}',
                          style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tripAttendanceSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name or trip...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                            suffixIcon: _tripAttendanceSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                    onPressed: () => _tripAttendanceSearchController.clear(),
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
                          foregroundColor: _tripAttendanceDateFilter != null ? const Color(0xFF2563EB) : Colors.grey[700],
                          side: BorderSide(
                            color: _tripAttendanceDateFilter != null ? const Color(0xFF2563EB) : Colors.grey[300]!,
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          _tripAttendanceDateFilter != null 
                              ? DateFormat('dd MMM').format(_tripAttendanceDateFilter!) 
                              : 'Filter Date',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _tripAttendanceDateFilter ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() {
                              _tripAttendanceDateFilter = date;
                            });
                          }
                        },
                      ),
                      if (_tripAttendanceDateFilter != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _tripAttendanceDateFilter = null;
                            });
                          },
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  filteredTripLogs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Column(
                              children: [
                                const Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _tripAttendanceSearchQuery.isNotEmpty || _tripAttendanceDateFilter != null
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
                          itemCount: filteredTripLogs.length,
                          itemBuilder: (context, index) {
                            final u = filteredTripLogs[index];
                            final name = u['worker_name'] ?? 'Member';
                            final mobile = u['description'] ?? 'No mobile';
                            final tripName = (u['work_started'] ?? 'Trip').toString().replaceFirst('Trip: ', '');
                            
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
                                          'Trip: $tripName',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)
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
