import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ResidencyTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final Map<String, dynamic>? preacherProfile;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const ResidencyTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.preacherProfile,
    required this.supabase,
    required this.onRefresh,
  });

  @override
  State<ResidencyTab> createState() => _ResidencyTabState();
}

class _ResidencyTabState extends State<ResidencyTab> {
  final _searchController = TextEditingController();
  String _filter = 'all'; // 'all', 'pending', 'approved'
  String _searchQuery = '';
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approveAdmission(Map<String, dynamic> req) async {
    setState(() => _isActionLoading = true);
    try {
      setState(() {
        req['is_completed'] = true;
      });

      // 1. Insert the signal row for the client to complete it
      await widget.supabase.from('updates').insert({
        'worker_id': req['worker_id'].toString(),
        'worker_name': req['worker_name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'residency_admission_approval_signal',
        'work_started': 'SIGNAL: ${req['id']}',
        'work_completed': '',
        'is_completed': true,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Try updating the disciple's role directly (optional fallback)
      final workerId = req['worker_id'];
      if (workerId != null) {
        try {
          await widget.supabase.from('profiles').update({
            'role': 'residency',
          }).eq('id', workerId);
        } catch (pe) {
          debugPrint('Profile role update failed (falling back to client side auto-promotion): $pe');
        }
      }

      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${req['worker_name'] ?? 'Disciple'} is now admitted to residency!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving residency admission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve admission: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _rejectAdmission(Map<String, dynamic> req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to reject and delete this residency request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      setState(() {
        for (var list in widget.allUpdates.values) {
          list.removeWhere((item) => item['id'] == req['id']);
        }
      });

      // Insert delete signal
      await widget.supabase.from('updates').insert({
        'worker_id': req['worker_id'].toString(),
        'worker_name': req['worker_name'],
        'preacher_name': widget.preacherProfile?['name'] ?? 'Preacher',
        'category': 'residency_admission_delete_signal',
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
          const SnackBar(content: Text('Residency admission request rejected and removed.')),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting admission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showFullEnrollmentDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final personal = data['personal'] ?? {};
        final address = data['address'] ?? {};
        final emergency = data['emergency'] ?? {};
        final academic = List<dynamic>.from(data['academic'] ?? []);
        final training = List<dynamic>.from(data['training'] ?? []);
        final employment = List<dynamic>.from(data['employment'] ?? []);
        final hobbies = data['hobbies_and_activities'] ?? {};
        final spiritual = data['spiritual_assessment'] ?? {};
        final lifestyle = data['lifestyle_assessment'] ?? {};
        final docs = List<dynamic>.from(data['documents_submitted'] ?? []);
        final medical = data['medical_history'] ?? {};
        final debts = data['debts'] ?? {};
        final criminal = data['criminal'] ?? {};
        final selfDecl = data['self_declaration'] ?? {};

        Widget buildSectionTitle(String title) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
            ),
          );
        }

        Widget buildInfoRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    value.isEmpty ? '---' : value,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.assignment_outlined, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              const Text('Enrolment Details', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle('General Information'),
                  buildInfoRow('Program:', data['program'] ?? 'Yoga For Happiness'),
                  buildInfoRow('Residency Name:', data['folk_residency_name'] ?? ''),
                  buildInfoRow('Joining Date:', data['date_of_joining'] ?? ''),
                  buildInfoRow('Referrer:', data['referrer'] ?? ''),

                  buildSectionTitle('Personal Information'),
                  buildInfoRow('Full Name:', personal['full_name'] ?? ''),
                  buildInfoRow('DOB:', personal['dob'] ?? ''),
                  buildInfoRow('Mobile No:', personal['mobile_no'] ?? ''),
                  buildInfoRow('Email ID:', personal['email'] ?? ''),
                  buildInfoRow('Education:', personal['education'] ?? ''),
                  buildInfoRow('Marital Status:', personal['marital_status'] ?? ''),
                  buildInfoRow('Blood Group:', personal['blood_group'] ?? ''),
                  buildInfoRow('Organization/College:', personal['org_or_college'] ?? ''),
                  buildInfoRow('Role/Course:', personal['role_or_course'] ?? ''),

                  buildSectionTitle('Address Details'),
                  buildInfoRow('Present Address:', '${address['present_address']} (Pin: ${address['present_pin']})'),
                  buildInfoRow('Permanent Address:', '${address['permanent_address']} (Pin: ${address['permanent_pin']})'),

                  buildSectionTitle('Emergency Contact Details'),
                  buildInfoRow('Name:', emergency['name'] ?? ''),
                  buildInfoRow('Phone:', emergency['phone'] ?? ''),
                  buildInfoRow('Relation:', emergency['relation'] ?? ''),
                  buildInfoRow('Email:', emergency['email'] ?? ''),
                  buildInfoRow('Address:', emergency['address'] ?? ''),
                  buildInfoRow('Pin:', emergency['pin'] ?? ''),

                  if (academic.isNotEmpty) ...[
                    buildSectionTitle('Academic History'),
                    for (var item in academic)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '• ${item['course']} from ${item['board']} at ${item['institution']} (${item['year']}) - ${item['percentage']}%',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],

                  if (training.isNotEmpty) ...[
                    buildSectionTitle('Training Courses'),
                    for (var item in training)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '• ${item['course']} by ${item['conducted_by']} (${item['duration']}) - Completed: ${item['year']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],

                  if (employment.isNotEmpty) ...[
                    buildSectionTitle('Employment History'),
                    for (var item in employment)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '• ${item['designation']} at ${item['employer']} (${item['period']}) - Salary: ${item['salary']} LPA. Reason: ${item['reason']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],

                  buildSectionTitle('Hobbies & Professional Activities'),
                  buildInfoRow('Hobbies:', hobbies['hobbies'] ?? ''),
                  buildInfoRow('Memberships:', hobbies['professional_memberships'] ?? ''),
                  buildInfoRow('Publications:', hobbies['publications'] ?? ''),
                  buildInfoRow('Honors:', hobbies['honors_and_scholarships'] ?? ''),

                  buildSectionTitle('Spiritual Assessment'),
                  buildInfoRow('Source of VCM:', List<dynamic>.from(spiritual['vcm_source'] ?? []).join(', ') +
                      (spiritual['vcm_source_others']?.toString().isNotEmpty == true ? ' (${spiritual['vcm_source_others']})' : '')),
                  buildInfoRow('First Visit VCM:', spiritual['first_visit_vcm'] ?? ''),
                  buildInfoRow('Since Childhood?', spiritual['visit_since_childhood'] == true ? 'Yes' : (spiritual['visit_since_childhood'] == false ? 'No' : '---')),
                  buildInfoRow('Likes VCM:', List<dynamic>.from(spiritual['vcm_likes'] ?? []).join(', ') +
                      (spiritual['vcm_likes_others']?.toString().isNotEmpty == true ? ' (${spiritual['vcm_likes_others']})' : '')),
                  buildInfoRow('Heard Prabhupada?', spiritual['heard_prabhupada'] == true ? 'Yes' : (spiritual['heard_prabhupada'] == false ? 'No' : '---')),
                  buildInfoRow('First Contact:', spiritual['first_contact_vcm'] ?? ''),
                  buildInfoRow('Programs:', List<dynamic>.from(spiritual['attended_programs'] ?? []).join(', ') +
                      (spiritual['attended_programs_others']?.toString().isNotEmpty == true ? ' (${spiritual['attended_programs_others']})' : '')),
                  buildInfoRow('FOLK ID / Guide:', '${spiritual['folk_id'] ?? ''} / ${spiritual['folk_guide'] ?? ''}'),
                  buildInfoRow('Services rendered:', spiritual['rendered_services'] == true ? 'Yes (${spiritual['rendered_services_details']})' : 'No'),
                  buildInfoRow('Other Courses:', spiritual['other_meditation_course'] == true ? 'Yes (${spiritual['other_meditation_course_details']})' : 'No'),
                  buildInfoRow('Knows 4 Principles?', spiritual['know_four_principles'] == true ? 'Yes' : 'No'),
                  buildInfoRow('Recommended Rounds:', spiritual['recommended_rounds'] ?? ''),
                  buildInfoRow('Daily Chanting:', '${spiritual['chanting_rounds'] ?? ''} rounds (Since ${spiritual['chanting_duration_years'] ?? '0'} yrs ${spiritual['chanting_duration_months'] ?? '0'} months)'),
                  buildInfoRow('1 Mala completion:', spiritual['chanting_one_mala_time'] ?? ''),
                  buildInfoRow('Read books?', spiritual['read_prabhupada_books'] == true ? 'Yes (${spiritual['prabhupada_books_details']})' : 'No'),

                  buildSectionTitle('Lifestyle Assessment'),
                  buildInfoRow('Aim in life:', lifestyle['aim_in_life'] ?? ''),
                  buildInfoRow('Faced Impact Situation?', lifestyle['faced_lasting_impact_situation'] == true ? 'Yes' : 'No'),
                  if (lifestyle['faced_lasting_impact_situation'] == true) ...[
                    buildInfoRow('Situation:', lifestyle['lasting_impact_situation_details'] ?? ''),
                    buildInfoRow('Learning:', lifestyle['learning_from_situation'] ?? ''),
                    buildInfoRow('Handling:', lifestyle['handled_situation'] ?? ''),
                    buildInfoRow('Outcome:', lifestyle['situation_outcome'] ?? ''),
                  ],
                  buildInfoRow('Motivation (KC):', lifestyle['motivation_kc'] ?? ''),
                  buildInfoRow('Motivation (Residency):', lifestyle['motivation_residency'] ?? ''),
                  buildInfoRow('Parents Approved?', lifestyle['parents_approved'] == true ? 'Yes' : (lifestyle['parents_approved'] == false ? 'No' : '---')),
                  buildInfoRow('Participate Morning Schedule?', lifestyle['will_participate_morning_schedule'] == true ? 'Yes' : (lifestyle['will_participate_morning_schedule'] == false ? 'No' : '---')),
                  buildInfoRow('Special Skills:', lifestyle['has_special_skills'] == true ?
                      List<dynamic>.from(lifestyle['special_skills'] ?? []).join(', ') +
                      (lifestyle['special_skills_others']?.toString().isNotEmpty == true ? ' (${lifestyle['special_skills_others']})' : '') : 'No'),
                  buildInfoRow('Watch movies frequency:', lifestyle['watch_movies_frequency'] ?? ''),
                  buildInfoRow('Wake up time:', lifestyle['wakeup_time'] ?? ''),
                  buildInfoRow('Office/College timings:', lifestyle['office_college_timings'] ?? ''),
                  buildInfoRow('Luggage carrying:', lifestyle['luggage_details'] ?? ''),

                  if (docs.isNotEmpty) ...[
                    buildSectionTitle('Documents Submitted'),
                    Text(docs.join(', '), style: const TextStyle(fontSize: 11)),
                  ],

                  buildSectionTitle('Medical Declarations'),
                  for (var key in medical.keys)
                    if (medical[key]?['has_condition'] == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          '• ${key.replaceAll('_', ' ').toUpperCase()}: Yes (${medical[key]?['details']})',
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                      ),

                  buildSectionTitle('Background Declarations'),
                  buildInfoRow('Debts Details:', debts['has_debts'] == true ? debts['details'] : 'No Debts'),
                  buildInfoRow('Criminal Charges:', criminal['has_charges'] == true ? criminal['details'] : 'No Charges'),

                  buildSectionTitle('Self Declaration & Signing'),
                  buildInfoRow('Accepted Rules:', selfDecl['accepted_rules_and_terms'] == true ? 'Yes' : 'No'),
                  buildInfoRow('Signed Place / Date:', '${selfDecl['declaration_place'] ?? ''} / ${selfDecl['declaration_date'] ?? ''}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildFilterButton(String value, String label) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
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
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0284C7) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final residencyLogs = [];
    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        if (u['category'] == 'residency_admission') {
          residencyLogs.add(u);
        }
      }
    }
    residencyLogs.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    final totalCount = residencyLogs.length;
    final pendingCount = residencyLogs.where((u) => u['is_completed'] != true).length;
    final approvedCount = residencyLogs.where((u) => u['is_completed'] == true).length;

    var filteredLogs = residencyLogs;
    if (_filter == 'pending') {
      filteredLogs = filteredLogs.where((u) => u['is_completed'] != true).toList();
    } else if (_filter == 'approved') {
      filteredLogs = filteredLogs.where((u) => u['is_completed'] == true).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredLogs = filteredLogs.where((u) {
        final name = (u['worker_name'] ?? '').toString().toLowerCase();
        final desc = (u['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Residency Admissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PENDING ADMISSIONS',
                        count: pendingCount,
                        icon: Icons.pending_actions_outlined,
                        color: const Color(0xFFF97316),
                        bgColor: const Color(0xFFFFF7ED),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'ADMITTED BOYS',
                        count: approvedCount,
                        icon: Icons.school_outlined,
                        color: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
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
                      Expanded(child: _buildFilterButton('all', 'All ($totalCount)')),
                      Expanded(child: _buildFilterButton('pending', 'Pending ($pendingCount)')),
                      Expanded(child: _buildFilterButton('approved', 'Approved ($approvedCount)')),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search applicant name or details...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () => _searchController.clear(),
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
                      borderSide: const BorderSide(color: Color(0xFF0284C7)),
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
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.school_outlined,
                              size: 56,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No search results found'
                                  : 'No residency admission requests',
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

                          String education = '---';
                          String preferredDateText = '---';
                          String reason = '---';
                          Map<String, dynamic>? jsonDetails;

                          try {
                            jsonDetails = jsonDecode(details.toString());
                          } catch (_) {}

                          if (jsonDetails != null) {
                            education = jsonDetails['personal']?['education'] ?? '---';
                            preferredDateText = jsonDetails['date_of_joining'] ?? '---';
                            try {
                              final parsed = DateTime.parse(preferredDateText);
                              preferredDateText = DateFormat('dd MMM yyyy').format(parsed);
                            } catch (_) {}
                            reason = jsonDetails['folk_residency_name'] ?? '---';
                          } else {
                            final lines = details.toString().split('\n');
                            for (var line in lines) {
                              if (line.startsWith('Education/Profession: ')) {
                                education = line.replaceAll('Education/Profession: ', '');
                              } else if (line.startsWith('Preferred Date: ')) {
                                preferredDateText = line.replaceAll('Preferred Date: ', '');
                                try {
                                  final parsed = DateTime.parse(preferredDateText);
                                  preferredDateText = DateFormat('dd MMM yyyy').format(parsed);
                                } catch (_) {}
                              } else if (line.startsWith('Reason: ')) {
                                reason = line.replaceAll('Reason: ', '');
                              }
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
                                        u['worker_name'] ?? 'Disciple',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCompleted ? const Color(0xFFE0F2FE) : const Color(0xFFFFF4E5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isCompleted ? 'ADMITTED' : 'PENDING',
                                          style: TextStyle(
                                            color: isCompleted ? const Color(0xFF0369A1) : const Color(0xFFB06000),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.school_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Education/Profession: $education',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Preferred Date: $preferredDateText',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    jsonDetails != null ? 'FOLK RESIDENCY:' : 'REASON FOR JOINING:',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                                  ),
                                  if (jsonDetails != null) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0284C7),
                                          side: const BorderSide(color: Color(0xFF0284C7)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showFullEnrollmentDetails(jsonDetails!),
                                        icon: const Icon(Icons.description_outlined, size: 16),
                                        label: const Text('VIEW FULL ENROLMENT FORM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                  if (!isCompleted) ...[
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(color: Colors.redAccent),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _rejectAdmission(u),
                                            icon: const Icon(Icons.close, size: 16),
                                            label: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0284C7),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _approveAdmission(u),
                                            icon: const Icon(Icons.check, size: 16),
                                            label: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                          ),
                                          onPressed: () => _rejectAdmission(u),
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          label: const Text('DELETE RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
