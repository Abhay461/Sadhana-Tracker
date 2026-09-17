import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';
import 'dart:convert';
import '../../utils/residency_pdf_helper.dart';

class ApprovalTab extends StatefulWidget {
  final Map<String, List<dynamic>> allUpdates;
  final Future<void> Function() onRefresh;
  final Map<String, dynamic>? preacherProfile;
  final List<dynamic> folkBoys;

  const ApprovalTab({
    super.key,
    required this.allUpdates,
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

  Widget _buildCategoryBadge(String cat) {
    final config = _getCategoryConfig(cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        config.name.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: config.color,
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

  Future<Map<String, String>?> _showAppointmentApprovalDialog(BuildContext context, Map<String, dynamic> u) async {
    final studentName = u['worker_name'] ?? u['student_name'] ?? 'Student';
    final preferredDate = (u['preferredDate'] ?? u['date'] ?? '').toString();
    final preferredTime = (u['preferredTime'] ?? '').toString();
    
    String reqDate = preferredDate;
    String reqTime = preferredTime;
    final desc = (u['description'] ?? '').toString();
    for (var line in desc.split('\n')) {
      if (line.startsWith('Date: ') && reqDate.isEmpty) {
        reqDate = line.replaceAll('Date: ', '').trim();
      } else if (line.startsWith('Time: ') && reqTime.isEmpty) {
        reqTime = line.replaceAll('Time: ', '').trim();
      }
    }
    if (reqDate.isEmpty) reqDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (reqTime.isEmpty) reqTime = '10:00 AM';

    bool isAlternative = false;
    DateTime altDate = DateTime.tryParse(reqDate) ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay altTime = const TimeOfDay(hour: 10, minute: 0);

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedReqDate = DateFormat('dd MMM yyyy').format(DateTime.tryParse(reqDate) ?? altDate);
            final formattedAltDate = DateFormat('dd MMM yyyy').format(altDate);
            final formattedAltTime = altTime.format(context);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Approve Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Student: $studentName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Approval Date & Time:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    
                    // Option 1: Requested Date & Time
                    InkWell(
                      onTap: () => setDialogState(() => isAlternative = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isAlternative ? const Color(0xFFEFF6FF) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: !isAlternative ? const Color(0xFF3B82F6) : Colors.grey[300]!, width: !isAlternative ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(!isAlternative ? Icons.radio_button_checked : Icons.radio_button_off, color: !isAlternative ? const Color(0xFF2563EB) : Colors.grey[400], size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Requested Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('$formattedReqDate at $reqTime', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Option 2: Alternative Date & Time
                    InkWell(
                      onTap: () => setDialogState(() => isAlternative = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAlternative ? const Color(0xFFF0FDFA) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAlternative ? const Color(0xFF0D9488) : Colors.grey[300]!, width: isAlternative ? 1.5 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isAlternative ? Icons.radio_button_checked : Icons.radio_button_off, color: isAlternative ? const Color(0xFF0D9488) : Colors.grey[400], size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text('Alternative Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            if (isAlternative) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.calendar_month, size: 14),
                                      label: Text(formattedAltDate, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: altDate,
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 90)),
                                        );
                                        if (picked != null) {
                                          setDialogState(() => altDate = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.access_time, size: 14),
                                      label: Text(formattedAltTime, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: altTime,
                                        );
                                        if (picked != null) {
                                          setDialogState(() => altTime = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final finalDate = isAlternative ? DateFormat('yyyy-MM-dd').format(altDate) : reqDate;
                    final finalTime = isAlternative ? altTime.format(context) : reqTime;
                    Navigator.pop(dialogCtx, {
                      'approvedDate': finalDate,
                      'approvedTime': finalTime,
                    });
                  },
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingUpdates = [];
    final completedUpdates = [];
    final Set<String> seenPendingIds = {};
    final Set<String> seenCompletedIds = {};

    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        final cat = u['category'];
        final id = (u['_id'] ?? u['id'] ?? u['appointmentId'] ?? '').toString();
        if (cat == 'preacher_appointment' || cat == 'accommodation' || cat == 'residency_admission') {
          final isCompleted = u['is_completed'] == true || u['isCompleted'] == true || (u['work_completed'] != null && u['work_completed'].toString().isNotEmpty && u['work_completed'] != 'PENDING');
          if (!isCompleted) {
            if (id.isEmpty || seenPendingIds.add(id)) {
              pendingUpdates.add(u);
            }
          } else {
            if (id.isEmpty || seenCompletedIds.add(id)) {
              completedUpdates.add(u);
            }
          }
        } else if (cat == 'payment') {
          final workCompleted = u['work_completed'] ?? '';
          if (u['is_completed'] == false && (workCompleted == 'SUBMITTED' || workCompleted == 'WAITING_APPROVAL')) {
            if (id.isEmpty || seenPendingIds.add(id)) {
              pendingUpdates.add(u);
            }
          } else if (u['is_completed'] == true && workCompleted == 'PAID') {
            if (id.isEmpty || seenCompletedIds.add(id)) {
              completedUpdates.add(u);
            }
          }
        }
      }
    }
    pendingUpdates.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    completedUpdates.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.transparent,
            child: const TabBar(
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              indicatorColor: Color(0xFF0F766E),
              labelColor: Color(0xFF0F766E),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'PENDING REQUESTS'),
                Tab(text: 'APPROVAL HISTORY'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingTab(pendingUpdates),
                _buildHistoryTab(completedUpdates),
              ],
            ),
          ),
        ],
      ),
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

  ({Color color, IconData icon, String name}) _getCategoryConfig(String category) {
    switch (category) {
      case 'preacher_appointment':
        return (color: const Color(0xFF1D4ED8), icon: Icons.chat_bubble_outline, name: 'Appointment');
      case 'accommodation':
        return (color: const Color(0xFF9333EA), icon: Icons.hotel_outlined, name: 'Accommodation');
      case 'residency_admission':
        return (color: const Color(0xFF0D9488), icon: Icons.home_outlined, name: 'Residency');
      case 'payment':
        return (color: const Color(0xFFD97706), icon: Icons.currency_rupee, name: 'Payment');
      default:
        return (color: const Color(0xFF475569), icon: Icons.assignment_outlined, name: category.replaceAll('_', ' ').toUpperCase());
    }
  }

  String _formatDateToDdMmYy(String dateStr) {
    final s = dateStr.trim();
    if (s.isEmpty) return '';
    try {
      final parsed = DateTime.parse(s);
      return DateFormat('dd-MM-yy').format(parsed);
    } catch (_) {
      try {
        final parsed = DateFormat('d MMM yyyy').parse(s);
        return DateFormat('dd-MM-yy').format(parsed);
      } catch (_) {
        try {
          final parsed = DateFormat('d MMM').parse(s);
          return DateFormat('dd-MM-yy').format(DateTime(DateTime.now().year, parsed.month, parsed.day));
        } catch (_) {
          try {
            final parts = s.split(' ')[0].split('-');
            if (parts.length == 3 && parts[0].length == 4) {
              final year = parts[0].substring(2);
              return '${parts[2]}-${parts[1]}-$year';
            }
          } catch (_) {}
          return s;
        }
      }
    }
  }

  String _getSingleLineSummary(Map<String, dynamic> u) {
    final cat = u['category'] ?? '';
    final desc = (u['description'] ?? u['work_started'] ?? '').toString();

    if (cat == 'preacher_appointment') {
      final pDateRaw = (u['preferredDate'] ?? u['finalDate'] ?? u['date'] ?? '').toString();
      final pDate = _formatDateToDdMmYy(pDateRaw);
      final pTime = (u['preferredTime'] ?? u['finalTime'] ?? '').toString();
      final parts = <String>[];
      if (pDate.isNotEmpty) parts.add(pDate);
      if (pTime.isNotEmpty) parts.add(pTime);
      
      String actualPurpose = (u['reason'] ?? u['purpose'] ?? '').toString().trim();
      if (actualPurpose.isEmpty && desc.isNotEmpty) {
        final lines = desc.split('\n');
        for (var l in lines) {
          final t = l.trim();
          if (t.startsWith('Purpose:')) {
            actualPurpose = t.substring('Purpose:'.length).trim();
            break;
          }
        }
        if (actualPurpose.isEmpty) {
          final filtered = lines.where((l) {
            final t = l.trim();
            return !t.startsWith('Preacher:') && !t.startsWith('Date:') && !t.startsWith('Time:') && !t.startsWith('Appointment:');
          }).join(' ').trim();
          actualPurpose = filtered;
        }
      }
      
      if (actualPurpose.isNotEmpty) parts.add('Purpose: $actualPurpose');
      
      return parts.isNotEmpty ? parts.join(' • ') : 'Appointment Request';
    }

    if (cat == 'accommodation') {
      final lines = desc.split('\n');
      String arr = '', dep = '';
      for (var l in lines) {
        if (l.startsWith('Arrival: ')) arr = _formatDateToDdMmYy(l.replaceAll('Arrival: ', '').trim());
        if (l.startsWith('Departure: ')) dep = _formatDateToDdMmYy(l.replaceAll('Departure: ', '').trim());
      }
      final parts = <String>[];
      if (arr.isNotEmpty) parts.add('Arr: $arr');
      if (dep.isNotEmpty) parts.add('Dep: $dep');
      if (parts.isNotEmpty) {
        return parts.join('  •  ');
      }
      return desc.replaceAll('\n', ' • ');
    }

    if (cat == 'payment') {
      final wrkStr = (u['work_started'] ?? '').toString();
      final pDesc = u['description'] ?? u['reason'] ?? '';
      return 'Amount: ₹$wrkStr • Purpose: $pDesc'.replaceAll('\n', ' ');
    }

    return desc.isNotEmpty ? desc.replaceAll('\n', ' • ') : 'Request Details';
  }

  void _showFullDetailsBottomSheet(BuildContext context, Map<String, dynamic> u) {
    final cat = u['category'] ?? '';
    final studentName = u['worker_name'] ?? u['name'] ?? 'Disciple';
    final desc = _cleanDescription(u['description'], cat, workStarted: u['work_started']);
    final dateStr = u['created_at'] != null ? DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(u['created_at'])) : '---';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _buildRoleBadge(u['worker_id']?.toString()),
              ],
            ),
            const SizedBox(height: 4),
            Text('Submitted on $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const Divider(height: 24),
            Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
            if (cat == 'residency_admission') ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final data = jsonDecode(u['description'].toString());
                    await ResidencyPdfHelper.generateAndSharePdf(data);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                label: const Text('Download Form PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(Map<String, dynamic> u) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final category = u['category'];
      final updateId = (u['appointmentId'] ?? u['appointment_id'] ?? u['_id'] ?? u['id'])?.toString();

      if (category == 'residency_admission') {
        await ApiService.patch('/sadhana/updates/$updateId', {
          'is_completed': true,
        });
        
        final workerId = u['worker_id'];
        if (workerId != null) {
          try {
            await ApiService.patch('/users/$workerId', {'role': 'residency'});
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

        await ApiService.patch('/accommodations/$updateId/status', {
          'status': 'APPROVED',
          'assignedRoom': roomNum,
        });
      } else if (category == 'payment') {
        await ApiService.patch('/payments/$updateId', {
          'is_completed': true,
          'work_completed': 'PAID',
        });
      } else if (category == 'preacher_appointment') {
        final approvalData = await _showAppointmentApprovalDialog(context, Map<String, dynamic>.from(u));
        if (approvalData == null) return;

        debugPrint('📌 [PREACHER APPROVE APPOINTMENT REQUEST]: ID=$updateId, data=$approvalData');
        final res = await ApiService.patch('/sadhana/updates/$updateId', {
          'status': 'APPROVED',
          'is_completed': true,
          'work_completed': 'APPROVED',
          'approvedDate': approvalData['approvedDate'],
          'approvedTime': approvalData['approvedTime'],
        });
        debugPrint('📌 [PREACHER APPROVE APPOINTMENT RESPONSE]: $res');
      } else {
        await ApiService.patch('/sadhana/updates/$updateId', {'is_completed': true});
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
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Approval failed: ${e.toString().replaceAll('ApiException', '').trim()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> u) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final category = u['category'];
      final updateId = (u['appointmentId'] ?? u['appointment_id'] ?? u['_id'] ?? u['id'])?.toString();
      if (category == 'residency_admission') {
        await ApiService.patch('/sadhana/updates/$updateId', {
          'is_completed': true,
          'work_completed': 'REJECTED',
        });
      } else if (category == 'accommodation') {
        await ApiService.patch('/accommodations/$updateId/status', {
          'status': 'REJECTED',
        });
      } else if (category == 'payment') {
        await ApiService.patch('/payments/$updateId', {
          'is_completed': false,
          'work_completed': 'PENDING',
        });
      } else if (category == 'preacher_appointment') {
        debugPrint('📌 [PREACHER REJECT APPOINTMENT REQUEST]: ID=$updateId');
        final res = await ApiService.patch('/sadhana/updates/$updateId', {
          'status': 'REJECTED',
          'is_completed': true,
          'work_completed': 'REJECTED',
        });
        debugPrint('📌 [PREACHER REJECT APPOINTMENT RESPONSE]: $res');
      } else {
        await ApiService.delete('/sadhana/updates/$updateId');
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
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Rejection failed: ${e.toString().replaceAll('ApiException', '').trim()}'),
          ),
        );
      }
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: pendingUpdates.length,
      itemBuilder: (buildCtx, index) {
        final u = Map<String, dynamic>.from(pendingUpdates[index]);
        final updateDate = u['created_at'] != null
            ? _formatDateToDdMmYy(u['created_at'].toString())
            : '---';
        final cat = u['category'] ?? '';
        final categoryConfig = _getCategoryConfig(cat);
        final summaryText = _getSingleLineSummary(u);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showFullDetailsBottomSheet(context, u),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: categoryConfig.color.withValues(alpha: 0.12),
                    child: Icon(categoryConfig.icon, size: 14, color: categoryConfig.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u['worker_name'] ?? 'Disciple',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildRoleBadge(u['worker_id']?.toString()),
                            const SizedBox(width: 4),
                            _buildCategoryBadge(cat),
                            const SizedBox(width: 4),
                            Text('• $updateDate', style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _handleApprove(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _handleReject(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('REJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: completedUpdates.length,
      itemBuilder: (buildCtx, index) {
        final u = Map<String, dynamic>.from(completedUpdates[index]);
        final updateDate = u['created_at'] != null
            ? _formatDateToDdMmYy(u['created_at'].toString())
            : '---';
            
        final category = u['category'] ?? 'general';
        final categoryConfig = _getCategoryConfig(category);
        final summaryText = _getSingleLineSummary(u);
        final statusText = (u['work_completed'] ?? u['status'] ?? 'COMPLETED').toString();
        final isRejected = statusText == 'REJECTED';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showFullDetailsBottomSheet(context, u),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: categoryConfig.color.withValues(alpha: 0.12),
                    child: Icon(categoryConfig.icon, size: 14, color: categoryConfig.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u['worker_name'] ?? 'Disciple',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildRoleBadge(u['worker_id']?.toString()),
                            const SizedBox(width: 4),
                            _buildCategoryBadge(category),
                            const SizedBox(width: 4),
                            Text('• $updateDate', style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.red[50] : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isRejected ? Colors.redAccent.withValues(alpha: 0.3) : const Color(0xFF99F6E4)),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isRejected ? Colors.redAccent : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  if (category == 'residency_admission') ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0D9488), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                    ),
                  ],
                ],
              ),
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
