import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccommodationTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const AccommodationTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<AccommodationTab> createState() => _AccommodationTabState();
}

class _AccommodationTabState extends State<AccommodationTab> {
  final _accommodationSearchController = TextEditingController();
  
  String _accommodationFilter = 'all'; // 'all', 'pending', 'confirmed'
  String _accommodationSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _accommodationSearchController.addListener(() {
      setState(() {
        _accommodationSearchQuery = _accommodationSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _accommodationSearchController.dispose();
    super.dispose();
  }

  Future<void> _approveBooking(Map<String, dynamic> req, String roomNumber) async {
    try {
      setState(() {
        req['is_completed'] = true;
        req['work_completed'] = 'ROOM: $roomNumber';
      });

      await widget.supabase.from('updates').insert({
        'worker_id': req['worker_id'].toString(),
        'worker_name': req['worker_name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'accommodation_approval_signal',
        'work_started': 'SIGNAL: ${req['id']}',
        'work_completed': 'ROOM: $roomNumber',
        'is_completed': true,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accommodation request approved & room assigned!')),
        );
      }
    } catch (e) {
      debugPrint('Error approving booking: $e');
    }
  }

  Future<void> _rejectBooking(Map<String, dynamic> req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this accommodation record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() {
        for (var list in widget.allUpdates.values) {
          list.removeWhere((item) => item['id'] == req['id']);
        }
      });

      await widget.supabase.from('updates').insert({
        'worker_id': req['worker_id'].toString(),
        'worker_name': req['worker_name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'accommodation_delete_signal',
        'work_started': 'SIGNAL: ${req['id']}',
        'work_completed': '',
        'is_completed': true,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accommodation record deleted.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting booking: $e');
    }
  }

  void _showRoomAssignmentDialog(Map<String, dynamic> req) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Approve & Assign Room', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guest: ${req['worker_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Room Number (e.g. Room 304-B)',
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
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final room = controller.text.trim();
                if (room.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a room number')),
                  );
                  return;
                }
                Navigator.pop(context);
                _approveBooking(req, room);
              },
              child: const Text('Approve & Assign'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSegmentButton(String value, String label, int totalCount, int pendingCount, int confirmedCount) {
    final isSelected = _accommodationFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _accommodationFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF9333EA) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accommodationLogs = [];
    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        if (u['category'] == 'accommodation') {
          accommodationLogs.add(u);
        }
      }
    }
    accommodationLogs.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    final totalCount = accommodationLogs.length;
    final pendingCount = accommodationLogs.where((u) => u['is_completed'] != true).length;
    final confirmedCount = accommodationLogs.where((u) => u['is_completed'] == true).length;

    var filteredLogs = accommodationLogs;
    if (_accommodationFilter == 'pending') {
      filteredLogs = filteredLogs.where((u) => u['is_completed'] != true).toList();
    } else if (_accommodationFilter == 'confirmed') {
      filteredLogs = filteredLogs.where((u) => u['is_completed'] == true).toList();
    }

    if (_accommodationSearchQuery.isNotEmpty) {
      final query = _accommodationSearchQuery.toLowerCase();
      filteredLogs = filteredLogs.where((u) {
        final guestName = (u['worker_name'] ?? '').toString().toLowerCase();
        final roomNumber = (u['work_completed'] ?? '').toString().toLowerCase();
        final description = (u['description'] ?? '').toString().toLowerCase();
        
        String customGuestName = '';
        final lines = description.split('\n');
        for (var line in lines) {
          if (line.startsWith('Name: ')) {
            customGuestName = line.replaceAll('Name: ', '').toLowerCase();
          }
        }

        return guestName.contains(query) || 
               customGuestName.contains(query) || 
               roomNumber.contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Residency Accommodation Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'PENDING',
                    count: pendingCount,
                    icon: Icons.pending_actions_outlined,
                    color: const Color(0xFFF97316),
                    bgColor: const Color(0xFFFFF7ED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'CONFIRMED',
                    count: confirmedCount,
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF9333EA),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildFilterSegmentButton('all', 'All ($totalCount)', totalCount, pendingCount, confirmedCount)),
                  Expanded(child: _buildFilterSegmentButton('pending', 'Pending ($pendingCount)', totalCount, pendingCount, confirmedCount)),
                  Expanded(child: _buildFilterSegmentButton('confirmed', 'Confirmed ($confirmedCount)', totalCount, pendingCount, confirmedCount)),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _accommodationSearchController,
              decoration: InputDecoration(
                hintText: 'Search guest name or room number...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _accommodationSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _accommodationSearchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF9333EA)),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _accommodationSearchQuery.isNotEmpty 
                              ? Icons.search_off 
                              : Icons.hotel_outlined, 
                          size: 56, 
                          color: Colors.grey
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _accommodationSearchQuery.isNotEmpty
                              ? 'No search results found'
                              : 'No accommodation bookings found',
                          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, idx) {
                      final u = filteredLogs[idx];
                      final isCompleted = u['is_completed'] ?? false;
                      final details = u['description'] ?? '';
                      final roomAllocated = u['work_completed'] ?? '';
                      
                      String arrivalText = '---';
                      String departureText = '---';
                      String guestAge = '---';
                      String guestName = u['worker_name'] ?? '';

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
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    guestName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4E5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isCompleted ? 'APPROVED' : 'PENDING',
                                      style: TextStyle(
                                        color: isCompleted ? const Color(0xFF137333) : const Color(0xFFB06000),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.cake_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Age: $guestAge', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('ARRIVAL', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(arrivalText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('DEPARTURE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(departureText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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
                              const Divider(height: 24),
                              if (!isCompleted)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _rejectBooking(u),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF9333EA),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showRoomAssignmentDialog(u),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('APPROVE & ASSIGN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () => _rejectBooking(u),
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('DELETE RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
