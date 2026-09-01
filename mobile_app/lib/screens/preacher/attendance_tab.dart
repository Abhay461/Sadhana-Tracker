import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const AttendanceTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  List<dynamic> _getTodayUpdates() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<dynamic> list = [];
    for (var boyUpdates in widget.allUpdates.values) {
      for (var u in boyUpdates) {
        if (u['date'] == today) {
          list.add(u);
        }
      }
    }
    return list;
  }

  Future<void> _markAttendance(Map<String, dynamic> boy) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await widget.supabase.from('updates').insert({
        'worker_id': boy['id'].toString(),
        'worker_name': boy['name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'attendance',
        'work_started': 'Present',
        'description': 'Marked Present by Preacher',
        'is_completed': true,
        'date': today,
        'created_at': DateTime.now().toIso8601String(),
      });
      await widget.onRefresh();
    } catch (e) {
      debugPrint('Error marking attendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayUpdateList = _getTodayUpdates();

    return widget.folkBoys.isEmpty
        ? const Center(child: Text('No circle members found.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.folkBoys.length,
            itemBuilder: (context, index) {
              final boy = widget.folkBoys[index];
              final isPresent = todayUpdateList.any((u) => u['worker_id'] == boy['id'] && u['category'] == 'attendance' && u['date'] == today);

              return Card(
                color: isPresent ? const Color(0xFFE6F4EA) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: boy['photo_url'] != null ? NetworkImage(boy['photo_url']) : null,
                        child: boy['photo_url'] == null ? Text(boy['name'][0].toUpperCase()) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(boy['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text((boy['role'] ?? 'Member').toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                      ),
                      isPresent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF0F9D58), borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                children: [
                                  Icon(Icons.check, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('PRESENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _markAttendance(boy),
                              child: const Text('MARK PRESENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            )
                    ],
                  ),
                ),
              );
            },
          );
  }
}
