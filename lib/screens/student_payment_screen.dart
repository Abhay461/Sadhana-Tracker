import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/notification_helper.dart';

class StudentPaymentScreen extends StatefulWidget {
  const StudentPaymentScreen({super.key});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('updates')
          .select('*')
          .eq('worker_id', user.id)
          .eq('category', 'payment')
          .order('created_at', ascending: false);

      setState(() {
        _payments = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching student payments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPaid(dynamic payment) async {
    setState(() => _isLoading = true);
    try {
      await supabase.from('updates').update({
        'is_completed': false,
        'work_completed': 'SUBMITTED',
      }).eq('id', payment['id']);

      final user = supabase.auth.currentUser;
      final updateData = {
        'worker_id': user?.id,
        'worker_name': payment['worker_name'] ?? 'Student',
        'category': 'payment',
        'work_started': payment['work_started'] ?? '₹0',
        'description': 'Student marked payment as PAID: ${payment['description'] ?? ""}',
      };
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked as PAID. Waiting for Preacher approval!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _fetchPayments();
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _payments.where((p) => p['is_completed'] == false).toList();
    final completed = _payments.where((p) => p['is_completed'] == true).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Payments & Contributions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPayments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient summary banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Dues & History',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Pending Requests: ${pending.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed Payments: ${completed.length}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pending Section
                    Row(
                      children: [
                        const Icon(Icons.pending_actions, color: Color(0xFFEA580C), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pending Requests (${pending.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pending.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        color: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'All payments cleared!',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No pending payment requests from Preacher.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...pending.map((p) => _buildPaymentCard(p, isPending: true)),

                    const SizedBox(height: 24),

                    // Completed Section
                    Row(
                      children: [
                        const Icon(Icons.history_outlined, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Payment History (${completed.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (completed.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        color: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Center(
                            child: Text(
                              'No payment history found.',
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    else
                      ...completed.map((p) => _buildPaymentCard(p, isPending: false)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentCard(dynamic p, {required bool isPending}) {
    final dateStr = p['created_at'] != null
        ? DateFormat('d MMM yyyy, hh:mm a').format(DateTime.parse(p['created_at']))
        : '---';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p['description'] ?? 'Contribution/Donation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  p['work_started'] ?? '₹0',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isPending ? const Color(0xFFEA580C) : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: $dateStr',
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isPending)
              (p['work_completed'] == 'SUBMITTED' || p['work_completed'] == 'WAITING_APPROVAL')
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'WAITING FOR PREACHER APPROVAL',
                            style: TextStyle(
                              color: Colors.amber[800],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => _showConfirmationDialog(p),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'MARK AS PAID',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'PAID',
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(dynamic payment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Confirm Payment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you have paid ${payment['work_started']} for "${payment['description']}"? This will send a notification confirmation to your preacher.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _markAsPaid(payment);
              },
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
