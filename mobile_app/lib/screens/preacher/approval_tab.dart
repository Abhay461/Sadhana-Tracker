import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/notification_helper.dart';
import 'dart:convert';
import '../../utils/residency_pdf_helper.dart';

class ApprovalTab extends StatefulWidget {
  final Map<String, List<dynamic>> allUpdates;
  final dynamic supabase;
  final Future<void> Function() onRefresh;
  final Map<String, dynamic>? preacherProfile;
  final List<dynamic> folkBoys;

  const ApprovalTab({
    super.key,
    required this.allUpdates,
    this.supabase,
    required this.onRefresh,
    this.preacherProfile,
    required this.folkBoys,
  });

  @override
  State<ApprovalTab> createState() => _ApprovalTabState();
}

class _ApprovalTabState extends State<ApprovalTab> {
  String _getDiscipleRole(String? workerId) {
    if (workerId == null) return '';
    for (final boy in widget.folkBoys) {
      if (boy is Map && boy['id']?.toString() == workerId) {
        final role = boy['role']?.toString();
        if (role == 'residency') return 'Residency';
        if (role == 'folk_boy') return 'Folk Boy';
        return role ?? '';
      }
    }
    return '';
  }

  Widget _buildRoleBadge(String? workerId) {
    final role = _getDiscipleRole(workerId);
    if (role.isEmpty) return const SizedBox.shrink();
    
    final isResidency = role.toLowerCase() == 'residency';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isResidency ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isResidency ? const Color(0xFFE9D5FF) : const Color(0xFFBFDBFE), width: 0.5),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isResidency ? const Color(0xFF7E22CE) : const Color(0xFF1D4ED8),
        ),
      ),
    );
  }

  String _cleanDescription(dynamic description, String category, {dynamic workStarted}) {
    final desc = description?.toString() ?? '';
    final wrkStr = workStarted?.toString() ?? '';
    if (category == 'preacher_appointment') {
      final lines = desc.split('\n');
      final filtered = lines.where((line) => !line.trim().startsWith('Preacher:')).toList();
      return filtered.join('\n');
    }
    if (category == 'payment') {
      return 'Amount: $wrkStr for "$desc"';
    }
    if (category == 'residency_admission') {
      try {
        final data = jsonDecode(desc);
        final program = data['program'] ?? 'Yoga For Happiness Program';
        final personal = data['personal'] ?? {};
        final name = personal['full_name'] ?? 'N/A';
        final mobile = personal['mobile_no'] ?? 'N/A';
        final email = personal['email'] ?? 'N/A';
        final education = personal['education'] ?? 'N/A';
        final joiningDate = data['date_of_joining'] ?? 'N/A';
        return 'Program: $program\nName: $name\nMobile: $mobile\nEmail: $email\nEducation: $education\nDate of Joining: $joiningDate\n\n(Click "Download Form PDF" below to view complete comprehensive form)';
      } catch (_) {
        return desc.isNotEmpty ? desc : wrkStr;
      }
    }
    return desc.isNotEmpty ? desc : wrkStr;
  }

  @override
  Widget build(BuildContext context) {
    final pendingUpdates = [];
    final completedUpdates = [];

    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        final cat = u['category'];
        if (cat == 'preacher_appointment' || cat == 'accommodation' || cat == 'residency_admission') {
          if (u['is_completed'] == false) {
            pendingUpdates.add(u);
          } else {
            completedUpdates.add(u);
          }
        } else if (cat == 'payment') {
          final workCompleted = u['work_completed'] ?? '';
          if (u['is_completed'] == false && (workCompleted == 'SUBMITTED' || workCompleted == 'WAITING_APPROVAL')) {
            pendingUpdates.add(u);
          } else if (u['is_completed'] == true && workCompleted == 'PAID') {
            completedUpdates.add(u);
          }
        }
      }
    }
    pendingUpdates.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    completedUpdates.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    final pendingAccounts = widget.folkBoys.where((b) {
      final role = b['role'] as String? ?? '';
      return role.startsWith('pending_');
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              indicatorColor: Color(0xFF0F766E),
              labelColor: Color(0xFF0F766E),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'NEW ACCOUNTS'),
                Tab(text: 'PENDING REQUESTS'),
                Tab(text: 'APPROVAL HISTORY'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingAccountsTab(pendingAccounts),
                _buildPendingTab(pendingUpdates),
                _buildHistoryTab(completedUpdates),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAccountsTab(List<dynamic> pendingAccounts) {
    if (pendingAccounts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No pending account approvals.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingAccounts.length,
      itemBuilder: (buildCtx, index) {
        final account = pendingAccounts[index];
        final name = account['name'] ?? 'User';
        final email = account['email'] ?? 'No email';
        final rawRole = account['role'] as String? ?? 'pending_folk_boy';
        final targetRoleDisplay = rawRole.replaceAll('pending_', '').replaceAll('_', ' ').toUpperCase();
        
        // Extract WhatsApp and dates
        final whatsappStr = account['whatsapp_number'] ?? '';
        String phone = whatsappStr;
        String dob = 'N/A';
        String joinDate = 'N/A';
        if (whatsappStr.contains('|')) {
          final parts = whatsappStr.split('|');
          phone = parts[0].trim();
          for (var part in parts) {
            if (part.contains('DOB:')) {
              dob = part.replaceAll('DOB:', '').trim();
            } else if (part.contains('JOIN:')) {
              joinDate = part.replaceAll('JOIN:', '').trim();
            }
          }
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo[50],
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                                ),
                                child: Text(
                                  'PENDING $targetRoleDisplay',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Details Row/Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('WhatsApp', phone, Icons.phone_android),
                    ),
                    Expanded(
                      child: _buildInfoItem('DOB', dob, Icons.cake_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('Joining Date', joinDate, Icons.flag_outlined),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final targetRole = rawRole.replaceFirst('pending_', '');
                            final List<dynamic> response = await widget.supabase
                                .from('profiles')
                                .update({'role': targetRole})
                                .eq('id', account['id'])
                                .select();

                            if (response.isEmpty) {
                              throw Exception('Permission denied: Operation failed. Please check server authorization guards.');
                            }

                            await widget.onRefresh();
                            
                            final preacherName = widget.preacherProfile?['name'] ?? 'Preacher';
                            NotificationHelper.sendSignupApprovalNotification(
                              studentId: account['id'],
                              preacherName: preacherName,
                              newRole: targetRole,
                            ).catchError((_) {});

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Account approved as $targetRoleDisplay!')),
                              );
                            }
                            
                            // Launch WhatsApp with prefilled message
                            await _launchWhatsApp(phone, name, targetRoleDisplay);
                          } catch (e) {
                            debugPrint('Error approving account: $e');
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text('Approval failed: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'APPROVE ENTRY',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Reject Registration'),
                              content: Text('Are you sure you want to reject and delete $name\'s registration request?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Reject & Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;

                          try {
                            await widget.supabase
                                .from('profiles')
                                .delete()
                                .eq('id', account['id']);

                            await widget.onRefresh();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Registration request rejected.')),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error rejecting account: $e');
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text('Rejection failed: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'REJECT',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingTab(List<dynamic> pendingUpdates) {
    if (pendingUpdates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text('All disciple requests verified and approved!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingUpdates.length,
      itemBuilder: (buildCtx, index) {
        final u = pendingUpdates[index];
        final updateDate = u['created_at'] != null
            ? DateFormat('d MMM yyyy').format(DateTime.parse(u['created_at']))
            : '---';

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey[200]!)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal[50],
                      child: Text((u['worker_name'] ?? 'M')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(u['worker_name'] ?? 'Disciple', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              _buildRoleBadge(u['worker_id']?.toString()),
                            ],
                          ),
                          Text('Submitted on $updateDate', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"${_cleanDescription(u['description'], u['category'] ?? '', workStarted: u['work_started'])}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final category = u['category'];
                            if (category == 'residency_admission') {
                              await widget.supabase.from('updates').update({
                                'is_completed': true,
                              }).eq('id', u['id']);
                              
                              final workerId = u['worker_id'];
                              if (workerId != null) {
                                try {
                                  await widget.supabase.from('profiles').update({'role': 'residency'}).eq('id', workerId);
                                } catch (pe) {
                                  debugPrint('Profile role update fallback failed: $pe');
                                }
                              }
                            } else if (category == 'accommodation') {
                              if (!context.mounted) return;
                              final roomController = TextEditingController();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Assign Room'),
                                  content: TextField(
                                    controller: roomController,
                                    decoration: const InputDecoration(hintText: 'Enter room number or details'),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              
                              final roomNum = roomController.text.trim();
                              final roomText = roomNum.isEmpty ? 'Approved' : 'Room $roomNum';

                              await widget.supabase.from('updates').update({
                                'is_completed': true,
                                'work_completed': roomText,
                              }).eq('id', u['id']);
                            } else if (category == 'payment') {
                              await widget.supabase.from('updates').update({
                                'is_completed': true,
                                'work_completed': 'PAID',
                              }).eq('id', u['id']);
                            } else {
                              await widget.supabase.from('updates').update({'is_completed': true}).eq('id', u['id']);
                            }
                            
                            await widget.onRefresh();
                            final workerId = u['worker_id'];
                            if (workerId != null) {
                              NotificationHelper.sendApprovalNotification(
                                studentId: workerId,
                                preacherName: widget.preacherProfile?['name'] ?? 'Preacher',
                                category: u['category'] ?? '',
                                approved: true,
                              ).catchError((_) {});
                            }
                            if (mounted) {
                              messenger.showSnackBar(const SnackBar(content: Text('Request Approved!')));
                            }
                          } catch (e) {
                            debugPrint('Error approving: $e');
                          }
                        },
                        child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final category = u['category'];
                            if (category == 'residency_admission') {
                              await widget.supabase.from('updates').update({
                                'is_completed': true,
                                'work_completed': 'REJECTED',
                              }).eq('id', u['id']);
                            } else if (category == 'accommodation') {
                              await widget.supabase.from('updates').update({
                                'is_completed': true,
                                'work_completed': 'REJECTED',
                              }).eq('id', u['id']);
                            } else if (category == 'payment') {
                              await widget.supabase.from('updates').update({
                                'is_completed': false,
                                'work_completed': 'PENDING',
                              }).eq('id', u['id']);
                            } else {
                              await widget.supabase.from('updates').delete().eq('id', u['id']);
                            }
                            
                            await widget.onRefresh();
                            final workerId = u['worker_id'];
                            if (workerId != null) {
                              NotificationHelper.sendApprovalNotification(
                                studentId: workerId,
                                preacherName: widget.preacherProfile?['name'] ?? 'Preacher',
                                category: u['category'] ?? '',
                                approved: false,
                              ).catchError((_) {});
                            }
                            if (mounted) {
                              messenger.showSnackBar(const SnackBar(content: Text('Request Rejected & Cleared')));
                            }
                          } catch (e) {
                            debugPrint('Error rejecting: $e');
                          }
                        },
                        child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<dynamic> completedUpdates) {
    if (completedUpdates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text('No past approvals found.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedUpdates.length,
      itemBuilder: (buildCtx, index) {
        final u = completedUpdates[index];
        final updateDate = u['created_at'] != null
            ? DateFormat('d MMM yyyy').format(DateTime.parse(u['created_at']))
            : '---';
            
        final category = u['category'] ?? 'general';
        
        Color badgeColor;
        Color textColor;
        String categoryName;
        IconData icon;

        switch (category) {
          case 'preacher_appointment':
            badgeColor = const Color(0xFFEFF6FF);
            textColor = const Color(0xFF1D4ED8);
            categoryName = 'Preacher Appointment';
            icon = Icons.chat_bubble_outline;
            break;
          case 'accommodation':
            badgeColor = const Color(0xFFF3E8FF);
            textColor = const Color(0xFF9333EA);
            categoryName = 'Accommodation';
            icon = Icons.hotel_outlined;
            break;
          case 'residency_admission':
            badgeColor = const Color(0xFFF0FDFA);
            textColor = const Color(0xFF0D9488);
            categoryName = 'Residency Admission';
            icon = Icons.home_outlined;
            break;
          case 'payment':
            badgeColor = const Color(0xFFFEF3C7);
            textColor = const Color(0xFFD97706);
            categoryName = 'Payment';
            icon = Icons.currency_rupee;
            break;
          default:
            badgeColor = const Color(0xFFF1F5F9);
            textColor = const Color(0xFF475569);
            categoryName = category.toString().replaceAll('_', ' ').toUpperCase();
            icon = Icons.assignment_outlined;
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[100]!)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: textColor.withValues(alpha: 0.1),
                          child: Icon(icon, size: 16, color: textColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      updateDate,
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.teal[50],
                      child: Text((u['worker_name'] ?? 'M')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              u['worker_name'] ?? 'Disciple',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(width: 6),
                            _buildRoleBadge(u['worker_id']?.toString()),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _cleanDescription(u['description'], category, workStarted: u['work_started']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (category == 'residency_admission') ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final data = jsonDecode(u['description'].toString());
                        await ResidencyPdfHelper.generateAndSharePdf(data);
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                    label: const Text(
                      'Download Form PDF',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchWhatsApp(String phone, String name, String roleDisplay) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final String message = 'Hare Krishna $name!\n\nYour account registration request for $roleDisplay has been approved . You can now login to the app.';
    final Uri url = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
    final Uri webUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
      try {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (err) {
        debugPrint('Could not launch web WhatsApp: $err');
      }
    }
  }
}
