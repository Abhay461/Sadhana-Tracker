import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const NotificationsTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {

  // Compile all Folk Boy / Resident logs and format them as activity feed notifications
  List<Map<String, dynamic>> _compileNotificationFeed() {
    final List<Map<String, dynamic>> feed = [];

    widget.allUpdates.forEach((boyId, updates) {
      final folkBoy = widget.folkBoys.firstWhere(
        (b) => b['id'].toString() == boyId,
        orElse: () => <String, dynamic>{'name': 'Folk Boy', 'photo_url': null},
      );

      for (var u in updates) {
        final category = u['category'] ?? '';
        final date = u['date'] ?? '';
        final points = (u['points'] as num?)?.toInt() ?? 0;
        final details = u['work_started'] ?? u['description'] ?? '';
        final rawCreatedAt = u['created_at'] ?? '';

        String title = '';
        IconData icon = Icons.notifications_active_outlined;
        Color color = const Color(0xFF4F46E5);
        Color bgColor = const Color(0xFFEEF2F6);

        switch (category) {
          case 'screen_time':
            title = '${folkBoy['name']} synchronized Screen Time of ${u['work_completed'] ?? "0m"}';
            icon = Icons.smartphone_outlined;
            color = const Color(0xFFEC4899);
            bgColor = const Color(0xFFFDF2F8);
            break;
          case 'trip_attendance':
            title = '${folkBoy['name']} registered for Yatra: ${details.toString().replaceAll("Trip: ", "")}';
            icon = Icons.directions_bus_outlined;
            color = const Color(0xFF0284C7);
            bgColor = const Color(0xFFE0F2FE);
            break;
          case 'event_attendance':
            title = '${folkBoy['name']} registered for Event: ${details.toString().replaceAll("Event: ", "")}';
            icon = Icons.confirmation_num_outlined;
            color = const Color(0xFF0D9488);
            bgColor = const Color(0xFFECFDF5);
            break;
          case 'session_attendance':
            title = '${folkBoy['name']} joined Online Session: ${details.toString().replaceAll("Session: ", "")}';
            icon = Icons.video_camera_front_outlined;
            color = const Color(0xFF0F9D58);
            bgColor = const Color(0xFFE6F4EA);
            break;
          case 'payment':
            title = '${folkBoy['name']} recorded Contribution / Donation';
            icon = Icons.account_balance_wallet_outlined;
            color = const Color(0xFFEA580C);
            bgColor = const Color(0xFFFFEDD5);
            break;
          case 'accommodation':
            final room = u['work_completed'] ?? '';
            if (u['is_completed'] == true && room.isNotEmpty) {
              title = '${folkBoy['name']} assigned accommodation room: ${room.toString().replaceAll("ROOM: ", "")}';
            } else {
              title = '${folkBoy['name']} requested residency accommodation';
            }
            icon = Icons.hotel_outlined;
            color = const Color(0xFF9333EA);
            bgColor = const Color(0xFFF3E8FF);
            break;
          case 'residency_admission':
            if (u['is_completed'] == true) {
              title = '${folkBoy['name']} has been admitted to Residency!';
            } else {
              title = '${folkBoy['name']} requested residency admission';
            }
            icon = Icons.school_outlined;
            color = const Color(0xFF0284C7);
            bgColor = const Color(0xFFE0F2FE);
            break;
          case 'service':
          case 'sadhna':
          case 'behavior':
            final sign = points >= 0 ? '+' : '';
            title = 'Points Shift ($sign$points): ${folkBoy['name']} for ${category.toUpperCase()}';
            icon = Icons.stars_rounded;
            color = const Color(0xFFD97706);
            bgColor = const Color(0xFFFEF3C7);
            break;
          default:
            title = '${folkBoy['name']} logged: $details';
            icon = Icons.check_circle_outline_outlined;
            color = const Color(0xFF64748B);
            bgColor = const Color(0xFFF1F5F9);
        }

        feed.add({
          'title': title,
          'category': category,
          'date': date,
          'rawCreatedAt': rawCreatedAt,
          'points': points,
          'folkBoyName': folkBoy['name'] ?? 'Folk Boy',
          'photoUrl': folkBoy['photo_url'],
          'icon': icon,
          'color': color,
          'bgColor': bgColor,
          'description': u['description'] ?? '',
        });
      }
    });

    // Sort feed descending based on created_at or date
    feed.sort((a, b) {
      final aTime = a['rawCreatedAt'] != '' ? a['rawCreatedAt'] : a['date'];
      final bTime = b['rawCreatedAt'] != '' ? b['rawCreatedAt'] : b['date'];
      return bTime.compareTo(aTime);
    });

    return feed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16, left: 4),
                child: Text(
                  'Folk Boy Alerts & Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              _buildActivityFeed(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityFeed() {
    final feed = _compileNotificationFeed();

    if (feed.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No Folk Boy alerts logged yet.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feed.length,
      itemBuilder: (context, idx) {
        final notif = feed[idx];
        final points = notif['points'];
        final isPlus = points >= 0;

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[100]!),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folk Boy circular avatar
                CircleAvatar(
                  radius: 18,
                  backgroundImage: notif['photoUrl'] != null 
                      ? NetworkImage(notif['photoUrl']) 
                      : null,
                  child: notif['photoUrl'] == null 
                      ? Text(notif['folkBoyName'][0].toUpperCase(), style: const TextStyle(fontSize: 12)) 
                      : null,
                ),
                const SizedBox(width: 12),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['title'],
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: notif['bgColor'],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(notif['icon'], size: 10, color: notif['color']),
                                const SizedBox(width: 4),
                                Text(
                                  notif['category'].toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: notif['color'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateLabel(notif['date']),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (notif['category'] == 'screen_time' && notif['description'] != '') ...[
                        const SizedBox(height: 8),
                        Text(
                          notif['description'].toString().split('\n\n').first,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Points Badge (if points changed)
                if (points != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPlus ? const Color(0xFFE6F4EA) : const Color(0xFFFFEAEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isPlus ? "+" : ""}$points Pts',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isPlus ? const Color(0xFF137333) : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }



  String _formatDateLabel(String dateString) {
    try {
      final parsed = DateTime.parse(dateString);
      return DateFormat('d MMM yyyy').format(parsed);
    } catch (_) {
      return dateString;
    }
  }
}
