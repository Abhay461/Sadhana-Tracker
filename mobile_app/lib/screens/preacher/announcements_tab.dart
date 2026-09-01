import 'package:flutter/material.dart';

class AnnouncementsTab extends StatefulWidget {
  final List<dynamic> announcements;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const AnnouncementsTab({
    super.key,
    required this.announcements,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final _announcementController = TextEditingController();

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final text = _announcementController.text.trim();
    if (text.isEmpty) return;

    try {
      await widget.supabase.from('announcements').insert({
        'content': text,
        'preacher_id': widget.preacherProfile?['id'],
      });
      _announcementController.clear();
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error posting announcement: $e');
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
    final pureAnnouncements = widget.announcements.where((a) {
      final text = (a['content'] ?? '').toString();
      return !text.startsWith('[TRIP]') && !text.startsWith('[EVENT]') && !text.startsWith('[NOTIF]');
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _announcementController,
                  decoration: InputDecoration(
                    hintText: 'Type announcement content...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _postAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: pureAnnouncements.isEmpty
              ? const Center(child: Text('No announcements posted yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pureAnnouncements.length,
                  itemBuilder: (context, index) {
                    final a = pureAnnouncements[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey[100]!)),
                      elevation: 0,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(Icons.campaign, color: Color(0xFFD97706)),
                        ),
                        title: Text(a['content'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteAnnouncement(a['id']),
                        ),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }
}
