import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/notification_helper.dart';

class PaymentTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final Map<String, List<dynamic>> allUpdates;
  final SupabaseClient supabase;
  final Future<void> Function() onRefresh;

  const PaymentTab({
    super.key,
    required this.folkBoys,
    required this.allUpdates,
    required this.supabase,
    required this.onRefresh,
  });

  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> {
  final _paymentAmountController = TextEditingController();
  final _paymentPurposeController = TextEditingController();
  
  String? _selectedPaymentBoyId;
  bool _isPaymentSaving = false;
  bool _markAsPaidImmediately = false;

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _paymentPurposeController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final amt = _paymentAmountController.text.trim();
    final purpose = _paymentPurposeController.text.trim();
    if (_selectedPaymentBoyId == null || amt.isEmpty || purpose.isEmpty) return;

    final boy = widget.folkBoys.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b?['id'].toString() == _selectedPaymentBoyId,
      orElse: () => null,
    );
    if (boy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected person not found. Please try again.')),
        );
      }
      return;
    }

    final wasImmediatelyPaid = _markAsPaidImmediately;
    setState(() => _isPaymentSaving = true);
    try {
      await widget.supabase.from('updates').insert({
        'worker_id': boy['id'].toString(),
        'worker_name': boy['name'],
        'category': 'payment',
        'work_started': '₹$amt',
        'description': purpose,
        'is_completed': wasImmediatelyPaid,
        'work_completed': wasImmediatelyPaid ? 'PAID' : 'PENDING',
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'created_at': DateTime.now().toIso8601String(),
      });
      _paymentAmountController.clear();
      _paymentPurposeController.clear();
      setState(() {
        _markAsPaidImmediately = false;
      });
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasImmediatelyPaid 
                  ? 'Contribution logged successfully!' 
                  : 'Payment request sent successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error logging payment: $e');
    } finally {
      setState(() => _isPaymentSaving = false);
    }
  }

  Future<void> _approvePayment(dynamic payment) async {
    setState(() => _isPaymentSaving = true);
    try {
      await widget.supabase.from('updates').update({
        'is_completed': true,
        'work_completed': 'PAID',
      }).eq('id', payment['id']);

      final studentId = payment['worker_id'];
      if (studentId != null) {
        NotificationHelper.sendApprovalNotification(
          studentId: studentId,
          preacherName: payment['preacher_name'] ?? 'Preacher',
          category: 'payment',
          approved: true,
        ).catchError((_) {});
      }

      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPaymentSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentLogs = [];
    for (var list in widget.allUpdates.values) {
      for (var u in list) {
        if (u['category'] == 'payment') {
          paymentLogs.add(u);
        }
      }
    }
    paymentLogs.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Contribution / Donation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentBoyId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      labelText: 'Select Contributing Folk Boy / Resident',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: widget.folkBoys.map((boy) {
                      return DropdownMenuItem<String>(
                        value: boy['id'].toString(),
                        child: Text(boy['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPaymentBoyId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Contribution Amount (₹)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paymentPurposeController,
                    decoration: InputDecoration(
                      labelText: 'Purpose (e.g. Vrindavan Trip Fee, Donation)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _markAsPaidImmediately,
                        onChanged: (val) {
                          setState(() {
                            _markAsPaidImmediately = val ?? false;
                          });
                        },
                        activeColor: const Color(0xFFEA580C),
                      ),
                      const Expanded(
                        child: Text(
                          'Mark as Paid Immediately (No approval needed)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isPaymentSaving ? null : _recordPayment,
                      child: _isPaymentSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE PAYMENT RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Circle Financial History Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          paymentLogs.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No payment history logged.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paymentLogs.length,
                  itemBuilder: (context, idx) {
                    final u = paymentLogs[idx];
                    final paymentDate = u['created_at'] != null
                        ? DateFormat('d MMM yyyy').format(DateTime.parse(u['created_at']))
                        : '---';

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey[200]!)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange[50],
                          child: const Icon(Icons.currency_rupee, color: Colors.orange),
                        ),
                        title: Text(u['worker_name'] ?? 'Disciple', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          (u['is_completed'] == true)
                              ? 'Paid ${u['work_started']} for "${u['description']}" on $paymentDate'
                              : (u['work_completed'] == 'SUBMITTED' || u['work_completed'] == 'WAITING_APPROVAL')
                                  ? 'Paid by student (Pending Preacher Approval) • ${u['work_started']} for "${u['description']}"'
                                  : 'Requested ${u['work_started']} for "${u['description']}" on $paymentDate',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        trailing: (u['is_completed'] == true)
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PAID',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : (u['work_completed'] == 'SUBMITTED' || u['work_completed'] == 'WAITING_APPROVAL')
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => _approvePayment(u),
                                    child: const Text(
                                      'APPROVE',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PENDING',
                                      style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                      ),
                    );
                  },
                )
        ],
      ),
    );
  }
}
