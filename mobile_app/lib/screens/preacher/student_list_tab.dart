import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentListTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final dynamic supabase;
  final Future<void> Function() onRefresh;

  const StudentListTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    this.supabase,
    required this.onRefresh,
  });

  @override
  State<StudentListTab> createState() => _StudentListTabState();
}

class _StudentListTabState extends State<StudentListTab> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _selectedRoleFilter = 'All'; // 'All', 'folk_boy', 'residency'
  Map<String, dynamic>? _selectedBoy;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                      style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF9D174D), fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDB2777))),
          )
        ],
      ),
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
                    child: _selectedBoy!['photo_url'] == null
                        ? Text(_selectedBoy!['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))
                        : null,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedBoy = null;
                      });
                    },
                    child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF3F1200))),
                  )
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: boyUpdates.isEmpty
              ? const Center(child: Text('No logged activities for this student.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: boyUpdates.length,
                  itemBuilder: (context, index) {
                    final u = boyUpdates[index];
                    final date = u['date'] ?? '';
                    final isCompleted = u['is_completed'] ?? false;

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
                          backgroundColor: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                          child: Icon(
                            isCompleted ? Icons.check_circle : Icons.timer,
                            color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                        ),
                        title: Text(u['work_started'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          'Date: $date • Points: ${u['points'] ?? 0}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    if (_selectedBoy != null) {
      return _buildBoyDetailView();
    }

    final filteredBoys = widget.folkBoys.where((boy) {
      final name = (boy['name'] ?? '').toString().toLowerCase();
      final whatsapp = (boy['whatsapp_number'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchTerm.toLowerCase()) || whatsapp.contains(_searchTerm.toLowerCase());

      bool matchesRole = true;
      if (_selectedRoleFilter != 'All') {
        matchesRole = (boy['role'] ?? '') == _selectedRoleFilter;
      }

      return matchesSearch && matchesRole;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3F1200),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    tooltip: 'Filter by Role',
                    onSelected: (String value) {
                      setState(() {
                        _selectedRoleFilter = value;
                      });
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'All',
                        child: Row(
                          children: [
                            Icon(
                              Icons.all_inclusive,
                              color: _selectedRoleFilter == 'All' ? const Color(0xFF3F1200) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All',
                              style: TextStyle(
                                  fontWeight: _selectedRoleFilter == 'All' ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'folk_boy',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: _selectedRoleFilter == 'folk_boy' ? const Color(0xFF3F1200) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Folk Boy',
                              style: TextStyle(
                                  fontWeight: _selectedRoleFilter == 'folk_boy' ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'residency',
                        child: Row(
                          children: [
                            Icon(
                              Icons.home,
                              color: _selectedRoleFilter == 'residency' ? const Color(0xFF3F1200) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Residency',
                              style: TextStyle(
                                  fontWeight: _selectedRoleFilter == 'residency' ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  hintText: 'Search student name or phone...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filteredBoys.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBoys.length,
                    itemBuilder: (context, index) {
                      final boy = filteredBoys[index];
                      final role = boy['role'] ?? 'folk_boy';
                      final isResidency = role == 'residency';

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedBoy = boy;
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: boy['photo_url'] != null ? NetworkImage(boy['photo_url']) : null,
                            backgroundColor: const Color(0xFFEEF2F6),
                            child: boy['photo_url'] == null
                                ? Text(
                                    (boy['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200)),
                                  )
                                : null,
                          ),
                          title: Text(
                            boy['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isResidency ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isResidency ? 'Residency' : 'Folk Boy',
                                    style: TextStyle(
                                      color: isResidency ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
