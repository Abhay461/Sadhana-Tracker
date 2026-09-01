import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


class ManagementTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const ManagementTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    required this.supabase,
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

  // Toggle folk lock day targets
  Future<void> _toggleLock(String boyId, String boyName, bool currentlyLocked) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      if (currentlyLocked) {
        await widget.supabase
            .from('updates')
            .delete()
            .eq('worker_id', boyId)
            .eq('category', 'folk_lock')
            .eq('date', today);
      } else {
        await widget.supabase.from('updates').insert({
          'worker_id': boyId,
          'worker_name': boyName,
          'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
          'work_started': 'Sadhana Locked',
          'description': 'Sadhana Tracking Locked',
          'is_completed': true,
          'category': 'folk_lock',
          'date': today,
        });
      }
      await widget.onRefresh();
    } catch (e) {
      debugPrint('Error toggling lock: $e');
    }
  }

  void _showBoyScreenTimeDetails(Map<String, dynamic> boy) {
    final boyId = boy['id'].toString();
    final boyUpdates = widget.allUpdates[boyId] ?? [];
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var screenTimeUpdate = boyUpdates.firstWhere(
      (u) => u['category'] == 'screen_time' && u['date'] == today,
      orElse: () => null,
    );
    
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
                          await widget.supabase.from('updates').insert({
                            'worker_id': boy['id'].toString(),
                            'worker_name': boy['name'],
                            'category': chosenCategory,
                            'work_started': desc,
                            'description': desc,
                            'is_completed': true,
                            'points': ptsVal,
                            'date': today,
                            'created_at': DateTime.now().toIso8601String(),
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
          child: boyUpdates.isEmpty
              ? const Center(child: Text('No logged activities for this Folk Boy / Resident.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: boyUpdates.length,
                  itemBuilder: (context, index) {
                    final u = boyUpdates[index];
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
                  },
                ),
        )
      ],
    );
  }

  Widget _buildChoiceChip(String label, String value) {
    final isSelected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? Colors.white : Colors.black)),
      selected: isSelected,
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRoleFilter = value;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedBoy != null) {
      return _buildBoyDetailView();
    }

    final filteredList = widget.folkBoys.where((boy) {
      final nameMatches = (boy['name'] ?? '').toString().toLowerCase().contains(_managementSearchTerm.toLowerCase());
      if (_selectedRoleFilter == 'All') {
        return nameMatches;
      } else {
        return nameMatches && (boy['role'] ?? '') == _selectedRoleFilter;
      }
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _managementSearchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search Folk Boy or Resident...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Filter Circle: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChoiceChip('All', 'All'),
                          const SizedBox(width: 8),
                          _buildChoiceChip('Folk Boy', 'folk_boy'),
                          const SizedBox(width: 8),
                          _buildChoiceChip('Residency', 'residency'),
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredList.isEmpty
              ? const Center(child: Text('No matching Folk Boys or Residents found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final boy = filteredList[index];
                    final boyId = boy['id'].toString();
                    final boyUpdates = widget.allUpdates[boyId] ?? [];
                    
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final isLocked = boyUpdates.any((u) => u['category'] == 'folk_lock' && u['date'] == today);

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage: boy['photo_url'] != null ? NetworkImage(boy['photo_url']) : null,
                          child: boy['photo_url'] == null ? Text(boy['name'][0].toUpperCase()) : null,
                        ),
                        title: Text(boy['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${boyUpdates.length} logged activities', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isLocked ? Icons.lock : Icons.lock_open,
                                color: isLocked ? Colors.redAccent : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => _toggleLock(boyId, boy['name'], isLocked),
                            ),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedBoy = boy;
                          });
                        },
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }
}
