import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BlocklistTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const BlocklistTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    required this.supabase,
    required this.onRefresh,
  });

  @override
  State<BlocklistTab> createState() => _BlocklistTabState();
}

class _BlocklistTabState extends State<BlocklistTab> {
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

  Future<void> _toggleBlockAccess(Map<String, dynamic> boy, bool isCurrentlyBlocked) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await widget.supabase.from('updates').insert({
        'worker_id': boy['id'].toString(),
        'worker_name': boy['name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'block_status',
        'work_started': isCurrentlyBlocked ? 'ACTIVE' : 'BLOCKED',
        'description': isCurrentlyBlocked ? 'Access restored' : 'Blocked by Preacher',
        'is_completed': true,
        'date': today,
        'created_at': DateTime.now().toIso8601String(),
      });
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCurrentlyBlocked ? 'Access Restored for ${boy['name']}' : 'Member ${boy['name']} Restricted')),
        );
      }
    } catch (e) {
      debugPrint('Error blocking/unblocking disciple: $e');
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
              final isBlocked = todayUpdateList.any((u) => u['worker_id'] == boy['id'] && u['category'] == 'block_status' && u['work_started'] == 'BLOCKED' && u['date'] == today);

              return Card(
                color: Colors.white,
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
                            Text(boy['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBlocked ? Colors.redAccent : Colors.black)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(color: isBlocked ? Colors.red[50] : Colors.green[50], borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                isBlocked ? 'RESTRICTED' : 'ACTIVE ACCESS',
                                style: TextStyle(color: isBlocked ? Colors.red : Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBlocked ? Colors.green : Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _toggleBlockAccess(boy, isBlocked),
                        child: Text(isBlocked ? 'RESTORE' : 'RESTRICT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }
}
