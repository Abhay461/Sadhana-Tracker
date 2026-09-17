import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/student_sadhana_excel_grid.dart';

class StudentListTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Future<void> Function() onRefresh;

  const StudentListTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
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
  bool _showStudentCard = false;
  bool _showExcelGrid = true;


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

  Map<String, String> _getBoyDetails(Map<String, dynamic> boy) {
    Map<String, dynamic> profileMap = {};
    if (boy['profile'] is Map<String, dynamic>) {
      profileMap = boy['profile'] as Map<String, dynamic>;
    }

    String getString(List<String> keys) {
      for (var k in keys) {
        if (boy[k] != null && boy[k].toString().trim().isNotEmpty && boy[k].toString().trim() != 'N/A') {
          return boy[k].toString().trim();
        }
        if (profileMap[k] != null && profileMap[k].toString().trim().isNotEmpty && profileMap[k].toString().trim() != 'N/A') {
          return profileMap[k].toString().trim();
        }
      }
      return '';
    }

    String name = getString(['name', 'full_name', 'student_name', 'userName', 'displayName']);
    String phone = getString(['whatsapp_number', 'phoneNumber', 'phone', 'whatsapp', 'phone_number', 'mobile', 'contact', 'mobile_number']);
    String email = getString(['email']);

    String rawDob = getString(['dob', 'dateOfBirth', 'date_of_birth']);
    String dob = '';
    if (rawDob.isNotEmpty) {
      try {
        dob = DateFormat('dd/MM/yyyy').format(DateTime.parse(rawDob));
      } catch (_) {
        dob = rawDob;
      }
    }

    String rawJoin = getString(['joiningDate', 'joining_date', 'joinDate', 'join_date']);
    String join = '';
    if (rawJoin.isNotEmpty) {
      try {
        join = DateFormat('dd/MM/yyyy').format(DateTime.parse(rawJoin));
      } catch (_) {
        join = rawJoin;
      }
    }

    String occ = getString(['occupation', 'occ', 'profession', 'work', 'job']);
    String clg = getString(['college', 'clg', 'school', 'institution', 'university']);
    String crs = getString(['courseYear', 'course_year', 'course', 'year', 'branch', 'degree']);
    String city = getString(['city', 'city_name', 'cityName', 'hometown', 'home_town', 'homeTown', 'native_place', 'nativePlace', 'native', 'address', 'location', 'district', 'state', 'place', 'town', 'user_city']);

    if (phone.contains('|')) {
      final parts = phone.split('|');
      phone = parts[0].trim();
      for (var part in parts) {
        final p = part.trim();
        final upperP = p.toUpperCase();

        String extractVal(String str) {
          if (str.contains(':')) return str.substring(str.indexOf(':') + 1).trim();
          if (str.contains('-')) return str.substring(str.indexOf('-') + 1).trim();
          if (str.contains('=')) return str.substring(str.indexOf('=') + 1).trim();
          return str.trim();
        }

        if (upperP.contains('DOB') && (dob.isEmpty || dob == 'N/A')) {
          dob = extractVal(p);
        }
        if (upperP.contains('JOIN') && (join.isEmpty || join == 'N/A')) {
          join = extractVal(p);
        }
        if ((upperP.contains('OCC') || upperP.contains('WORK') || upperP.contains('JOB') || upperP.contains('PROFESSION')) && (occ.isEmpty || occ == 'N/A')) {
          occ = extractVal(p);
        }
        if ((upperP.contains('CLG') || upperP.contains('COLLEGE') || upperP.contains('SCHOOL') || upperP.contains('UNIV')) && (clg.isEmpty || clg == 'N/A')) {
          clg = extractVal(p);
        }
        if ((upperP.contains('CRS') || upperP.contains('COURSE') || upperP.contains('YEAR') || upperP.contains('BRANCH')) && (crs.isEmpty || crs == 'N/A')) {
          crs = extractVal(p);
        }
        if ((upperP.contains('CITY') || upperP.contains('TOWN') || upperP.contains('HOMETOWN') || upperP.contains('NATIVE') || upperP.contains('LOCATION') || upperP.contains('ADDRESS') || upperP.contains('CT:')) && (city.isEmpty || city == 'N/A')) {
          city = extractVal(p);
        }
      }
    }

    if (occ.isEmpty || occ == 'N/A') {
      occ = 'Student';
    }

    return {
      'name': name.isEmpty ? 'Student' : name,
      'phone': (phone.isEmpty || phone == 'N/A') ? 'Not specified' : phone,
      'email': (email.isEmpty || email == 'N/A') ? 'Not specified' : email,
      'dob': (dob.isEmpty || dob == 'N/A') ? 'Not specified' : dob,
      'join': (join.isEmpty || join == 'N/A') ? 'Not specified' : join,
      'occ': occ,
      'clg': (clg.isEmpty || clg == 'N/A') ? 'Not specified' : clg,
      'crs': (crs.isEmpty || crs == 'N/A') ? 'Not specified' : crs,
      'city': (city.isEmpty || city == 'N/A') ? 'Not specified' : city,
    };
  }

  Widget _buildSimpleInfoRow(IconData icon, String label, String value) {
    final bool isNotSpecified = value.isEmpty || value == 'N/A' || value == 'Not specified' || value == '-';
    final String displayValue = isNotSpecified ? 'Not specified' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                color: isNotSpecified ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                fontWeight: isNotSpecified ? FontWeight.w400 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showBoyPersonalDetails(Map<String, dynamic> boy) {
    final details = _getBoyDetails(boy);
    final studentName = details['name'] != 'Not specified' ? details['name']! : (boy['name'] ?? 'Student');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.person_outline, color: Color(0xFF3F1200)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Personal Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleInfoRow(Icons.person_outline, 'Full Name', studentName),
              _buildSimpleInfoRow(Icons.phone_android_outlined, 'WhatsApp / Phone', details['phone']!),
              _buildSimpleInfoRow(Icons.email_outlined, 'Email', details['email']!),
              _buildSimpleInfoRow(Icons.cake_outlined, 'DOB', details['dob']!),
              _buildSimpleInfoRow(Icons.calendar_today_outlined, 'Joined', details['join']!),
              _buildSimpleInfoRow(Icons.work_outline, 'Occupation', details['occ']!),
              _buildSimpleInfoRow(Icons.school_outlined, 'College', details['clg']!),
              _buildSimpleInfoRow(Icons.menu_book_outlined, 'Course & Year', details['crs']!),
              _buildSimpleInfoRow(Icons.location_city_outlined, 'City', details['city']!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F1200))),
          )
        ],
      ),
    );
  }

  List<dynamic> _getAllUpdatesForBoy(Map<String, dynamic> boy) {
    final sId = (boy['id'] ?? boy['_id'] ?? boy['userId'] ?? boy['user_id'] ?? (boy['user'] is Map ? boy['user']['_id'] ?? boy['user']['id'] : null) ?? '').toString();
    final sName = (boy['name'] ?? boy['student_name'] ?? boy['studentName'] ?? boy['userName'] ?? (boy['user'] is Map ? boy['user']['name'] : null) ?? '').toString().trim().toLowerCase();

    final List<dynamic> candidateLogs = [
      ...?widget.allUpdates[sId],
      ...?widget.allUpdates[sName],
      ...?widget.allUpdates[boy['id']?.toString()],
      ...?widget.allUpdates[boy['_id']?.toString()],
      ...?widget.allUpdates[boy['name']?.toString()],
      ...widget.allUpdates.values.expand((x) => x).where((u) {
        if (u is! Map<String, dynamic>) return false;
        final uId = (u['worker_id'] ?? u['workerId'] ?? u['user_id'] ?? u['userId'] ?? u['student_id'] ?? u['studentId'] ?? u['createdBy'] ?? u['created_by'] ?? (u['user'] is Map ? u['user']['_id'] ?? u['user']['id'] : u['user']) ?? '').toString();
        final uName = (u['worker_name'] ?? u['workerName'] ?? u['name'] ?? u['student_name'] ?? u['studentName'] ?? u['userName'] ?? u['user_name'] ?? (u['user'] is Map ? u['user']['name'] : null) ?? '').toString().trim().toLowerCase();

        if (sId.isNotEmpty && uId.isNotEmpty && sId == uId) return true;
        if (sName.isNotEmpty && uName.isNotEmpty) {
          if (sName == uName) return true;
          if (sName.length >= 3 && uName.length >= 3 && (sName.contains(uName) || uName.contains(sName))) return true;
        }
        return false;
      }),
    ];

    final Map<String, dynamic> uniqueLogsMap = {};
    for (var u in candidateLogs) {
      if (u is Map<String, dynamic>) {
        final uIdKey = (u['id'] ?? u['_id'] ?? '${u['date']}_${u['work_started']}_${u['category']}').toString();
        uniqueLogsMap[uIdKey] = u;
      }
    }

    return uniqueLogsMap.values.toList();
  }

  Widget _buildBoyDetailView() {
    final allBoyUpdates = _getAllUpdatesForBoy(_selectedBoy!);
    final details = _getBoyDetails(_selectedBoy!);
    final studentName = details['name'] != 'Not specified' ? details['name']! : (_selectedBoy!['name'] ?? 'Student');

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: _selectedBoy!['photo_url'] != null ? NetworkImage(_selectedBoy!['photo_url']) : null,
                      backgroundColor: const Color(0xFFE2E8F0),
                      child: _selectedBoy!['photo_url'] == null
                          ? Text(
                              (studentName)[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3F1200)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3F1200),
                      side: const BorderSide(color: Color(0xFF3F1200)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    ),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text(
                      'Personal Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                    onPressed: () => _showBoyPersonalDetails(_selectedBoy!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StudentSadhanaExcelGrid(
              studentUpdates: allBoyUpdates,
              studentName: studentName,
            ),
          ),
        ],
      ),
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

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            color: const Color(0xFFF8FAFC),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: _selectedRoleFilter != 'All' ? const Color(0xFF3F1200) : const Color(0xFF64748B),
                    size: 20,
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
                            Icons.all_inclusive_rounded,
                            size: 18,
                            color: _selectedRoleFilter == 'All' ? const Color(0xFF3F1200) : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'All Students',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedRoleFilter == 'All' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'folk_boy',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: _selectedRoleFilter == 'folk_boy' ? const Color(0xFF3F1200) : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Folk Boy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedRoleFilter == 'folk_boy' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'residency',
                      child: Row(
                        children: [
                          Icon(
                            Icons.home_rounded,
                            size: 18,
                            color: _selectedRoleFilter == 'residency' ? const Color(0xFF3F1200) : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Residency',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedRoleFilter == 'residency' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                hintText: 'Search student name or phone...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3F1200), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: filteredBoys.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.person_search_rounded, size: 48, color: Color(0xFFCBD5E1)),
                            SizedBox(height: 12),
                            Text(
                              'No students found',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredBoys.length,
                      itemBuilder: (context, index) {
                        final boy = filteredBoys[index];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedBoy = boy;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: boy['photo_url'] != null ? NetworkImage(boy['photo_url']) : null,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  child: boy['photo_url'] == null
                                      ? Text(
                                          (boy['name'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF3F1200),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    boy['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
