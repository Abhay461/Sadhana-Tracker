import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ManagementTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final Future<void> Function() onRefresh;

  const ManagementTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    required this.onRefresh,
  });

  @override
  State<ManagementTab> createState() => _ManagementTabState();
}

class _ManagementTabState extends State<ManagementTab> {
  final _managementSearchController = TextEditingController();
  final _pointsController = TextEditingController();
  final _pointsReasonController = TextEditingController();
  
  String _managementSearchTerm = '';
  String _selectedRoleFilter = 'All'; // 'All', 'folk_boy', 'residency'
  Map<String, dynamic>? _selectedBoy;
  final Set<String> _expandedScreenTimeIds = {};

  @override
  void initState() {
    super.initState();
    _managementSearchController.addListener(() {
      setState(() {
        _managementSearchTerm = _managementSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _managementSearchController.dispose();
    _pointsController.dispose();
    _pointsReasonController.dispose();
    super.dispose();
  }



  void _showBoyScreenTimeDetails(Map<String, dynamic> boy) {
    final boyId = boy['id'].toString();
    final boyUpdates = widget.allUpdates[boyId] ?? [];
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayMatches = boyUpdates.where((u) => u['category'] == 'screen_time' && u['date'] == today);
    var screenTimeUpdate = todayMatches.isNotEmpty ? todayMatches.first : null;
    
    if (screenTimeUpdate == null) {
      final screenTimeUpdates = boyUpdates.where((u) => u['category'] == 'screen_time').toList();
      if (screenTimeUpdates.isNotEmpty) {
        screenTimeUpdate = screenTimeUpdates.first;
      }
    }
    
    if (screenTimeUpdate == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('No Screen Time Logged', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('${boy['name']} has not logged or synced any screen time yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
      return;
    }

    final String total = screenTimeUpdate['work_completed'] ?? '0m';
    final String date = screenTimeUpdate['date'] ?? '';
    final String breakdown = screenTimeUpdate['description'] ?? 'No details available.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.phone_android_outlined, color: Color(0xFFDB2777)),
            const SizedBox(width: 10),
            Expanded(
              child: Text("${boy['name']}'s Screen Time", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    total,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDB2777),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Last Synced: $date',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Detailed App Breakdown:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCE7F3)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      breakdown,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF9D174D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDB2777),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showPointAdjustmentSheet(Map<String, dynamic> boy) {
    _pointsController.clear();
    _pointsReasonController.clear();
    String chosenCategory = 'service';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adjust Points',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          Text(
                            'For ${boy['name']}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.indigo[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use positive numbers to reward points, and negative numbers to deduct points.',
                            style: TextStyle(color: Colors.indigo[900], fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'POINT SHIFT',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _pointsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'e.g. 10 or -5',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CATEGORY',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: chosenCategory,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'service', child: Text('Service', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: 'sadhna', child: Text('Sadhna', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: 'behavior', child: Text('Behavior', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSheetState(() {
                                        chosenCategory = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'JUSTIFICATION',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pointsReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Why are you adjusting these metrics?',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('APPLY ADJUSTMENTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
                      onPressed: () async {
                        final ptsStr = _pointsController.text.trim();
                        final rsn = _pointsReasonController.text.trim();
                        if (ptsStr.isEmpty || rsn.isEmpty) return;

                        final ptsVal = int.tryParse(ptsStr);
                        if (ptsVal == null) return;

                        final sign = ptsVal >= 0 ? '+' : '';
                        final desc = 'Manual Adjustment: $rsn ($sign$ptsVal Point)';
                        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

                        try {
                          await ApiService.post('/sadhana', {
                            'worker_id': (boy['id'] ?? boy['_id']).toString(),
                            'worker_name': boy['name'],
                            'category': chosenCategory,
                            'work_started': desc,
                            'description': desc,
                            'is_completed': true,
                            'points': ptsVal,
                            'date': today,
                          });

                          await widget.onRefresh();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Point adjustments applied for ${boy['name']}!')),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error adjusting points: $e');
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBoyDetailView() {
    final boyId = _selectedBoy!['id'].toString();
    final boyUpdates = (widget.allUpdates[boyId] ?? [])
        .where((u) => u['category'] != 'screen_time')
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: _selectedBoy!['photo_url'] != null ? NetworkImage(_selectedBoy!['photo_url']) : null,
                    child: _selectedBoy!['photo_url'] == null ? Text(_selectedBoy!['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedBoy!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          (() {
                            final raw = _selectedBoy!['whatsapp_number'] ?? 'No whatsapp';
                            return raw.split(' | ').first.trim();
                          })(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        (() {
                          final raw = _selectedBoy!['whatsapp_number'] ?? '';
                          String dob = '';
                          String join = '';
                          if (raw.contains('| DOB:')) {
                            dob = raw.split('| DOB:')[1].split('|').first.trim();
                          }
                          if (raw.contains('| JOIN:')) {
                            join = raw.split('| JOIN:')[1].split('|').first.trim();
                          }
                          if (dob.isEmpty && join.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dob.isNotEmpty && dob != 'N/A')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.cake, size: 10, color: Colors.pinkAccent),
                                        const SizedBox(width: 4),
                                        Text('DOB: $dob', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                if (join.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 10, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text('Joined: $join', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey)),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        })(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDB2777),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.smartphone_outlined, size: 14),
                    label: const Text('SCREEN TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    onPressed: () => _showBoyScreenTimeDetails(_selectedBoy!),
                  ),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedBoy = null;
                      });
                    },
                    child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  )
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSadhanaCardWidget(
                sadhanaLogs: boyUpdates,
                studentName: _selectedBoy!['name'],
              ),
              if (boyUpdates.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12, top: 4),
                  child: Text(
                    'All Student Logs & Activity Feed',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                  ),
                ),
                ...boyUpdates.map((u) {
                  final date = u['date'] ?? '';
                  final isCompleted = u['is_completed'] ?? false;
                  final isScreenTime = u['category'] == 'screen_time';
                  final updateId = u['id']?.toString() ?? '';
                  final isExpanded = _expandedScreenTimeIds.contains(updateId);

                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isScreenTime
                            ? const Color(0xFFFCE7F3)
                            : (isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7)),
                        child: Icon(
                          isScreenTime
                              ? Icons.smartphone_outlined
                              : (isCompleted ? Icons.check_circle : Icons.timer),
                          color: isScreenTime
                              ? const Color(0xFFDB2777)
                              : (isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706)),
                        ),
                      ),
                      title: Text(u['work_started'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isScreenTime
                                ? 'Date: $date • Screen Time Log'
                                : 'Date: $date • Points: ${u['points'] ?? 0}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          if (isScreenTime && u['description'] != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedScreenTimeIds.remove(updateId);
                                  } else {
                                    _expandedScreenTimeIds.add(updateId);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: const Color(0xFFDB2777),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isExpanded ? 'Hide Screen Time Details' : 'Show Screen Time Details',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDB2777),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF2F8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFCE7F3)),
                                ),
                                child: Text(
                                  u['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: Color(0xFF9D174D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ]
                        ],
                      ),
                      trailing: u['photo_url'] != null
                          ? IconButton(
                              icon: const Icon(Icons.image_outlined, color: Colors.indigo),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(u['photo_url']),
                                    ),
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ],
          ),
        )
      ],
    );
  }



  DateTime? _selectedSadhanaDate;

  Widget _buildSadhanaCardWidget({
    required List<dynamic> sadhanaLogs,
    String? studentName,
  }) {
    final curDate = _selectedSadhanaDate ?? DateTime.now();
    final formattedDateTitle = DateFormat('EEEE, d MMMM yyyy').format(curDate);
    final targetDateStr = DateFormat('yyyy-MM-dd').format(curDate);
    final targetDateAlt = DateFormat('dd/MM/yyyy').format(curDate);

    final standardActivities = [
      {'key': 'morning wake-up', 'title': 'Morning Wake-Up'},
      {'key': 'mangla arti', 'title': 'Mangla Arti'},
      {'key': 'chanting', 'title': 'Chanting'},
      {'key': 'online session', 'title': 'Online Session'},
      {'key': 'book reading', 'title': 'Book Reading'},
      {'key': 'service', 'title': 'Service'},
      {'key': 'temple visit', 'title': 'Temple Visit'},
      {'key': 'srimad bhagavatam class', 'title': 'SB Class'},
      {'key': 'bhagavad gita class', 'title': 'BG Class'},
      {'key': 'sleep time', 'title': 'Sleep Time'},
    ];

    String? getMatchedKey(Map<String, dynamic> u) {
      final act = (u['work_started'] ?? u['activity'] ?? u['title'] ?? '').toString().toLowerCase();
      final desc = (u['description'] ?? '').toString().toLowerCase();
      final combined = '$act $desc';

      if (combined.contains('morning') || combined.contains('wake')) return 'morning wake-up';
      if (combined.contains('mangla')) return 'mangla arti';
      if (combined.contains('chanting') || combined.contains('japa')) return 'chanting';
      if (combined.contains('online') || combined.contains('session')) return 'online session';
      if (combined.contains('book') || combined.contains('reading')) return 'book reading';
      if (combined.contains('service')) return 'service';
      if (combined.contains('temple')) return 'temple visit';
      if (combined.contains('srimad') || combined.contains('bhagavatam')) return 'srimad bhagavatam class';
      if (combined.contains('gita') || combined.contains('bhagavad gita')) return 'bhagavad gita class';
      if (combined.contains('ekadashi')) return 'ekadashi fasting';
      if (combined.contains('sleep')) return 'sleep time';

      for (var std in standardActivities) {
        final k = std['key']!;
        if (combined.contains(k)) return k;
      }
      return null;
    }

    String getDetailText(Map<String, dynamic> u) {
      final workComp = (u['work_completed'] ?? u['detail'] ?? '').toString().trim();
      if (workComp.isNotEmpty && workComp != 'null') return workComp;
      final workStart = (u['work_started'] ?? '').toString().trim();
      if (workStart.contains('(') && workStart.contains(')')) {
        final inside = workStart.substring(workStart.indexOf('(') + 1, workStart.lastIndexOf(')')).trim();
        if (inside.isNotEmpty) return inside;
      }
      return 'Filled';
    }

    Map<String, String> extractActivitiesFromLog(Map<String, dynamic> u) {
      final Map<String, String> result = {};

      final dynamic rawActivities = u['activities'];
      if (rawActivities is Map) {
        final acts = Map<String, dynamic>.from(rawActivities);

        if (acts['wakeUpTime'] != null && acts['wakeUpTime'].toString().isNotEmpty) {
          result['morning wake-up'] = acts['wakeUpTime'].toString();
        }
        if (acts['sleepTime'] != null && acts['sleepTime'].toString().isNotEmpty) {
          result['sleep time'] = acts['sleepTime'].toString();
        }
        if (acts['manglaArti'] != null) {
          final m = acts['manglaArti'];
          if (m is Map && (m['attended'] == true || m['time'] != null)) {
            result['mangla arti'] = (m['time'] ?? 'Attended').toString();
          } else if (m == true) {
            result['mangla arti'] = 'Attended';
          }
        }
        if (acts['chanting'] != null) {
          final c = acts['chanting'];
          if (c is Map && c['rounds'] != null) {
            result['chanting'] = '${c['rounds']} Rounds';
          } else if (c is num) {
            result['chanting'] = '$c Rounds';
          }
        }
        if (acts['onlineSession'] != null) {
          final o = acts['onlineSession'];
          if (o is Map && (o['attended'] == true || o['timeSpan'] != null)) {
            result['online session'] = (o['timeSpan'] ?? 'Attended').toString();
          } else if (o == true) {
            result['online session'] = 'Attended';
          }
        }
        if (acts['bookReading'] != null) {
          final b = acts['bookReading'];
          if (b is Map) {
            final name = (b['bookName'] ?? '').toString();
            final detail = (b['pagesOrMinutes'] ?? b['duration'] ?? '').toString();
            final combined = [name, detail].where((s) => s.isNotEmpty).join(' - ');
            result['book reading'] = combined.isNotEmpty ? combined : 'Completed';
          } else if (b is String && b.isNotEmpty) {
            result['book reading'] = b;
          }
        }
        if (acts['service'] != null) {
          final s = acts['service'];
          if (s is Map) {
            final name = (s['serviceName'] ?? '').toString();
            final dur = (s['durationMinutes'] ?? s['duration'] ?? '').toString();
            final durStr = dur.isNotEmpty ? '$dur mins' : '';
            final combined = [name, durStr].where((x) => x.isNotEmpty).join(' - ');
            result['service'] = combined.isNotEmpty ? combined : 'Completed';
          } else if (s is String && s.isNotEmpty) {
            result['service'] = s;
          }
        }
        if (acts['templeVisit'] != null) {
          final t = acts['templeVisit'];
          if (t is Map && t['visited'] == true) {
            result['temple visit'] = 'Visited';
          } else if (t == true) {
            result['temple visit'] = 'Visited';
          }
        }
        if (acts['srimadBhagavatamClass'] != null) {
          final sb = acts['srimadBhagavatamClass'];
          if (sb is Map && (sb['attended'] == true || sb['timeSpan'] != null)) {
            result['srimad bhagavatam class'] = (sb['timeSpan'] ?? 'Attended').toString();
          } else if (sb == true) {
            result['srimad bhagavatam class'] = 'Attended';
          }
        }
        if (acts['bhagavadGitaClass'] != null) {
          final bg = acts['bhagavadGitaClass'];
          if (bg is Map && (bg['attended'] == true || bg['timeSpan'] != null)) {
            result['bhagavad gita class'] = (bg['timeSpan'] ?? 'Attended').toString();
          } else if (bg == true) {
            result['bhagavad gita class'] = 'Attended';
          }
        }
        if (acts['ekadashiFasting'] != null) {
          final e = acts['ekadashiFasting'];
          if (e is Map && e['fastingType'] != null) {
            result['ekadashi fasting'] = e['fastingType'].toString();
          } else if (e is String && e.isNotEmpty) {
            result['ekadashi fasting'] = e;
          }
        }
      }

      final key = getMatchedKey(u);
      if (key != null) {
        result[key] = getDetailText(u);
      } else {
        final act = (u['work_started'] ?? u['activity'] ?? u['title'] ?? '').toString().trim().toLowerCase();
        if (act.isNotEmpty) {
          result[act] = getDetailText(u);
        }
      }

      return result;
    }

    bool isSameStudent(Map<String, dynamic> student, Map<String, dynamic> u) {
      final sId = (student['id'] ?? student['_id'] ?? student['userId'] ?? student['user_id'] ?? (student['user'] is Map ? student['user']['_id'] ?? student['user']['id'] : null) ?? '').toString();
      final sName = (student['name'] ?? student['student_name'] ?? student['studentName'] ?? student['userName'] ?? (student['user'] is Map ? student['user']['name'] : null) ?? '').toString().trim().toLowerCase();

      final uId = (u['worker_id'] ?? u['workerId'] ?? u['user_id'] ?? u['userId'] ?? u['student_id'] ?? u['studentId'] ?? u['createdBy'] ?? u['created_by'] ?? (u['user'] is Map ? u['user']['_id'] ?? u['user']['id'] : u['user']) ?? '').toString();
      final uName = (u['worker_name'] ?? u['workerName'] ?? u['name'] ?? u['student_name'] ?? u['studentName'] ?? u['userName'] ?? u['user_name'] ?? (u['user'] is Map ? u['user']['name'] : null) ?? '').toString().trim().toLowerCase();

      if (sId.isNotEmpty && uId.isNotEmpty && sId == uId) return true;
      if (sName.isNotEmpty && uName.isNotEmpty) {
        if (sName == uName) return true;
        if (sName.length >= 3 && uName.length >= 3 && (sName.contains(uName) || uName.contains(sName))) return true;
      }
      return false;
    }

    bool matchesLogDate(Map<String, dynamic> u) {
      final d = (u['dateString'] ?? u['date'] ?? u['created_at'] ?? u['createdAt'] ?? u['timestamp'] ?? '').toString().trim();
      if (d.isEmpty) return false;

      final targetDashAlt = DateFormat('dd-MM-yyyy').format(curDate);
      if (d.contains(targetDateStr) || d.contains(targetDateAlt) || d.contains(targetDashAlt)) {
        return true;
      }

      try {
        final parsed = DateTime.tryParse(d);
        if (parsed != null) {
          final local = parsed.toLocal();
          if (local.year == curDate.year && local.month == curDate.month && local.day == curDate.day) {
            return true;
          }
        }
      } catch (_) {}

      return false;
    }

    // IF A SPECIFIC STUDENT IS SELECTED -> SHOW SINGLE STUDENT DETAIL TABLE
    if (studentName != null) {
      final dateFilteredLogs = sadhanaLogs.where((u) => matchesLogDate(u)).toList();

      final Map<String, Map<String, dynamic>> filledLogsMap = {};
      for (var u in dateFilteredLogs) {
        final key = getMatchedKey(u);
        if (key != null) {
          filledLogsMap[key] = u;
        } else {
          final act = (u['work_started'] ?? u['activity'] ?? u['title'] ?? '').toString().trim().toLowerCase();
          if (act.isNotEmpty) filledLogsMap[act] = u;
        }
      }

      final List<Map<String, dynamic>> tableRows = [];

      for (var actItem in standardActivities) {
        final stdAct = actItem['title']!;
        final key = actItem['key']!;
        final log = filledLogsMap[key];
        if (log != null) {
          final detail = getDetailText(log);
          final isComp = log['is_completed'] ?? true;
          tableRows.add({
            'id': log['id'],
            'activity': stdAct,
            'detail': detail.isNotEmpty ? detail : 'Filled',
            'isCompleted': isComp,
            'raw': log,
          });
        } else {
          tableRows.add({
            'activity': stdAct,
            'detail': 'Not Logged',
            'isCompleted': false,
            'raw': null,
          });
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    formattedDateTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3F1200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: curDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedSadhanaDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: _selectedSadhanaDate != null ? const Color(0xFF2563EB) : const Color(0xFF3F1200),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedSadhanaDate != null
                                  ? DateFormat('dd MMM yyyy').format(_selectedSadhanaDate!)
                                  : 'Filter Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _selectedSadhanaDate != null ? const Color(0xFF2563EB) : const Color(0xFF3F1200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedSadhanaDate != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSadhanaDate = null;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Sadhana Activity', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Time / Detail', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      SizedBox(
                        width: 36,
                        child: Center(child: Text('Action', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tableRows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final row = tableRows[index];
                    final isCompleted = row['isCompleted'] == true;
                    final activity = row['activity'] ?? '';
                    final detail = row['detail'] ?? '-';
                    final rawData = row['raw'];

                    return Container(
                      color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              color: isCompleted ? const Color(0xFF16A34A) : Colors.grey[400],
                              size: 17,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              activity,
                              style: TextStyle(
                                fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                                color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              detail,
                              style: TextStyle(
                                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 11,
                                color: isCompleted ? const Color(0xFF166534) : Colors.grey[500],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Center(
                              child: rawData != null
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        if (rawData['id'] != null) {
                                          try {
                                            await ApiService.delete('/sadhana/updates/${rawData['id']}');
                                            await widget.onRefresh();
                                          } catch (e) {
                                            debugPrint('Error deleting sadhana entry: $e');
                                          }
                                        }
                                      },
                                    )
                                  : const SizedBox.shrink(),
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
        ],
      );
    }

    // MAIN DASHBOARD MATRIX TABLE (MULTIPLE STUDENTS SIDE-BY-SIDE)
    final List<Map<String, dynamic>> studentsToDisplay = [];
    if (widget.folkBoys.isNotEmpty) {
      for (var b in widget.folkBoys) {
        if (b is Map<String, dynamic>) {
          studentsToDisplay.add(b);
        } else if (b is Map) {
          studentsToDisplay.add(Map<String, dynamic>.from(b));
        }
      }
    } else {
      final Map<String, String> uniqueNames = {};
      for (var u in sadhanaLogs) {
        final id = (u['worker_id'] ?? '').toString();
        final name = (u['worker_name'] ?? 'Student').toString();
        if (id.isNotEmpty) uniqueNames[id] = name;
      }
      for (var entry in uniqueNames.entries) {
        studentsToDisplay.add({'id': entry.key, 'name': entry.value});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  formattedDateTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F1200),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: curDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedSadhanaDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: _selectedSadhanaDate != null ? const Color(0xFF2563EB) : const Color(0xFF3F1200),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedSadhanaDate != null
                                ? DateFormat('dd MMM yyyy').format(_selectedSadhanaDate!)
                                : 'Filter Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _selectedSadhanaDate != null ? const Color(0xFF2563EB) : const Color(0xFF3F1200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedSadhanaDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSadhanaDate = null;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. FROZEN LEFT COLUMN ('Name') - STAYS FIXED HORIZONTALLY
              Container(
                width: 100,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    // Frozen Top-Left Header Cell ('Name')
                    Container(
                      height: 36,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                      ),
                      child: const Text(
                        'Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                      ),
                    ),
                    // Student Name Rows
                    ...studentsToDisplay.asMap().entries.map((entry) {
                      final index = entry.key;
                      final student = entry.value;
                      final studentName = (student['name'] ?? 'Student').toString();
                      final isEven = index % 2 == 0;

                      return Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedBoy = student;
                            });
                          },
                          child: Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // 2. HORIZONTALLY SCROLLABLE ACTIVITIES MATRIX
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Frozen Top Activity Headers Row
                      Container(
                        height: 36,
                        color: const Color(0xFFF8FAFC),
                        child: Row(
                          children: standardActivities.map((act) {
                            return Container(
                              width: 105,
                              height: 36,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  right: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                ),
                              ),
                              child: Text(
                                act['title']!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Student Activity Rows
                      ...studentsToDisplay.asMap().entries.map((entry) {
                        final index = entry.key;
                        final student = entry.value;
                        final studentId = (student['id'] ?? student['_id'] ?? student['userId'] ?? student['user_id'] ?? (student['user'] is Map ? student['user']['_id'] ?? student['user']['id'] : null) ?? '').toString();
                        final studentNameStr = (student['name'] ?? student['student_name'] ?? student['studentName'] ?? student['userName'] ?? (student['user'] is Map ? student['user']['name'] : null) ?? '').toString().trim().toLowerCase();

                        final List<dynamic> candidateLogs = [
                          ...?(widget.allUpdates[studentId]),
                          ...?(widget.allUpdates[studentNameStr]),
                          ...sadhanaLogs.where((u) => isSameStudent(student, u)),
                          ...widget.allUpdates.values.expand((x) => x).where((u) => isSameStudent(student, u)),
                        ];

                        final Map<String, dynamic> uniqueBoyLogsMap = {};
                        for (var u in candidateLogs) {
                          final uIdKey = (u['id'] ?? u['_id'] ?? '${u['date']}_${u['work_started']}').toString();
                          uniqueBoyLogsMap[uIdKey] = u;
                        }

                        final boyLogs = uniqueBoyLogsMap.values.where((u) => matchesLogDate(u)).toList();

                        final Map<String, String> filledMap = {};
                        for (var u in boyLogs) {
                          final extracted = extractActivitiesFromLog(u);
                          filledMap.addAll(extracted);
                        }

                        final Map<String, String> renderedBadges = {};
                        for (var act in standardActivities) {
                          final key = act['key']!;
                          if (filledMap.containsKey(key)) {
                            renderedBadges[act['title']!] = filledMap[key]!;
                          }
                        }

                        debugPrint('=== DEBUG PREACHER DASHBOARD MATRIX MATCH ===');
                        debugPrint('Student: ${student['name'] ?? studentNameStr} (ID: $studentId)');
                        debugPrint('  → Matched Sadhana Records (${boyLogs.length}): $boyLogs');
                        debugPrint('  → Extracted Activities: $filledMap');
                        debugPrint('  → Rendered Green Badges: $renderedBadges');

                        final isEven = index % 2 == 0;
                        final rowColor = isEven ? Colors.white : const Color(0xFFFAFAFA);

                        return SizedBox(
                          height: 42,
                          child: Row(
                            children: standardActivities.map((act) {
                              final key = act['key']!;
                              final detail = filledMap[key];

                              return Container(
                                width: 105,
                                height: 42,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rowColor,
                                  border: const Border(
                                    right: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                                  ),
                                ),
                                child: detail != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          detail,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            color: Color(0xFF15803D),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : const Text(
                                        '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedBoy != null) {
      return _buildBoyDetailView();
    }

    final allTasks = widget.allUpdates.values
        .expand((list) => list)
        .where((u) => u['category'] != 'screen_time')
        .toList();

    allTasks.sort((a, b) {
      final aTime = a['created_at'] ?? '';
      final bTime = b['created_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    final filteredTasks = allTasks.where((task) {
      final workerName = (task['worker_name'] ?? '').toString().toLowerCase();
      final workStarted = (task['work_started'] ?? '').toString().toLowerCase();
      final description = (task['description'] ?? '').toString().toLowerCase();
      final category = (task['category'] ?? '').toString().toLowerCase();
      final matchesSearch = workerName.contains(_managementSearchTerm.toLowerCase()) ||
                            workStarted.contains(_managementSearchTerm.toLowerCase()) ||
                            description.contains(_managementSearchTerm.toLowerCase()) ||
                            category.contains(_managementSearchTerm.toLowerCase());

      bool matchesRole = true;
      if (_selectedRoleFilter != 'All') {
        final matches = widget.folkBoys.where((b) => b['id'].toString() == task['worker_id'].toString());
        final boy = matches.isNotEmpty ? matches.first : null;
        if (boy == null) {
          matchesRole = false;
        } else {
          matchesRole = (boy['role'] ?? '') == _selectedRoleFilter;
        }
      }

      return matchesSearch && matchesRole;
    }).toList();

    final sadhanaTasks = allTasks.where((u) {
      final cat = (u['category'] ?? '').toString().toLowerCase();
      return cat.contains('sadhana') || cat.contains('sadhna');
    }).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSadhanaCardWidget(sadhanaLogs: sadhanaTasks),
              if (filteredTasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
                  child: Text(
                    'Student Activity Feed',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                  ),
                ),
                ...filteredTasks.map((task) {
                  final isCompleted = task['is_completed'] ?? false;
                  final boyId = task['worker_id']?.toString();
                  final matches = widget.folkBoys.where((b) => b['id'].toString() == boyId);
                  final boy = matches.isNotEmpty ? matches.first : null;
                  final photoUrl = boy?['photo_url'];

                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: boy != null
                                ? () {
                                    setState(() {
                                      _selectedBoy = boy;
                                    });
                                  }
                                : null,
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null
                                  ? Text(
                                      (task['worker_name'] ?? 'S')[0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: boy != null
                                            ? () {
                                                setState(() {
                                                  _selectedBoy = boy;
                                                });
                                              }
                                            : null,
                                        child: Text(
                                          task['worker_name'] ?? 'Student',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      task['date'] ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task['work_started'] ?? 'No title',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                if (task['description'] != null &&
                                    (task['description'] as String).trim().isNotEmpty &&
                                    task['description'] != task['work_started']) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task['description'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3F1200).withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (task['category'] ?? 'Task').toString().toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3F1200),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isCompleted ? 'COMPLETED' : 'PENDING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (task['photo_url'] != null)
                            IconButton(
                              icon: const Icon(Icons.image_outlined, color: Color(0xFF3F1200)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(task['photo_url']),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
