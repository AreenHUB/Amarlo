// lib/screens/userScreen/UserRequestsPage.dart
import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/states.dart';
import '../safe_area_page.dart';
import '../user_request_history_page.dart';

class UserRequestsPage extends StatefulWidget {
  final String userId;
  const UserRequestsPage({super.key, required this.userId});

  @override
  State<UserRequestsPage> createState() => _UserRequestsPageState();
}

class _UserRequestsPageState extends State<UserRequestsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    if (widget.userId.isEmpty) return;
    await context.read<RequestProvider>().fetchUserRequests(widget.userId);
  }

  Future<void> _delete(String requestId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<RequestProvider>().deleteUserRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        automaticallyImplyLeading: false,
        actions: [
          const NotificationIconButton(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Completed Requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserRequestHistoryPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (_, provider, __) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = provider.userRequests;
          if (requests.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('No active requests', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Request a service from Home screen',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _fetch, child: const Text('Refresh')),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: _fetch,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (_, i) => _RequestCard(
                request: requests[i],
                onDelete: () => _delete(requests[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Request Card
// ══════════════════════════════════════════════
class _RequestCard extends StatefulWidget {
  final ServiceRequest request;
  final VoidCallback onDelete;

  const _RequestCard({required this.request, required this.onDelete});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _confirmingDeadline = false;

  ServiceRequest get request => widget.request;

  Future<void> _confirmDeadline(bool accept) async {
    setState(() => _confirmingDeadline = true);
    try {
      await ApiService.confirmDeadline(request.id, accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept
            ? 'Deadline confirmed! Safe Area is now active.'
            : 'Deadline rejected. Worker will propose a new one.'),
        backgroundColor: accept ? Colors.green : Colors.orange,
      ));
      // أعد تحميل الطلبات
      context.read<RequestProvider>().fetchUserRequests(
          context.read<AuthProvider>().user?.id ?? '');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _confirmingDeadline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = request.deadline != null
        ? DateTime.tryParse(request.deadline!)
        : null;
    final statusColor = _statusColor(request.status);

    // ── Safe Area متاح في هذه الحالات ──────────────
    // 1. accepted + safeAreaActive = true  → Worker قبل وبدأ العمل
    // 2. ready_for_delivery                 → Worker رفع الملف وجاهز للاستلام
    // 3. completed                          → منجز، يمكن التحميل
    final canOpenSafeArea =
        (request.status == 'accepted' && request.safeAreaActive) ||
        request.status == 'ready_for_delivery' ||
        request.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────
          Row(children: [
            Expanded(
              child: Text(request.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                request.status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Worker: ${request.workerEmail}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(_formatDate(request.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),

          // ── Deadline proposal awaiting approval ──────
          if (request.hasPendingDeadline &&
              request.proposedDeadline != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange),
                    SizedBox(width: 6),
                    Text('Worker proposed a delivery deadline',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('EEE, MMM d yyyy — HH:mm').format(
                        DateTime.parse(request.proposedDeadline!).toLocal()),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (request.agreedPrice > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Agreed price: \$${request.agreedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _confirmingDeadline
                      ? const Center(
                          child: SizedBox(
                              height: 24, width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _confirmDeadline(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _confirmDeadline(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ]),
                ],
              ),
            ),
          ],

          // ── Safe Area active indicator ────────────
          if (request.safeAreaActive && request.status == 'accepted') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.blue),
                SizedBox(width: 6),
                Text('Safe Area is active — Worker is working on your request',
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
              ]),
            ),
          ],

          // ── Deadline countdown ──────────────────
          if (request.status == 'accepted' && deadline != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text('Deadline: ${DateFormat('MMM d, HH:mm').format(deadline)}',
                  style: const TextStyle(color: Colors.orange, fontSize: 13)),
            ]),
            CountdownTimer(
              endTime: deadline.millisecondsSinceEpoch,
              widgetBuilder: (_, time) {
                if (time == null) {
                  return const Text('⏰ Deadline passed',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                }
                final d = Duration(
                  days: time.days ?? 0, hours: time.hours ?? 0,
                  minutes: time.min ?? 0, seconds: time.sec ?? 0,
                );
                return Text('Time left: ${_fmtDuration(d)}',
                    style: const TextStyle(color: Colors.orange, fontSize: 13));
              },
            ),
          ],

          // ── Ready for delivery banner ─────────────
          if (request.status == 'ready_for_delivery') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green),
                SizedBox(width: 6),
                Text('Work is ready! Open Safe Area to review and pay',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
              ]),
            ),
          ],

          const SizedBox(height: 10),

          // ── Actions ──────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            // Cancel — فقط عند pending
            if (request.status == 'pending')
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                label: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),

            // Safe Area button
            if (canOpenSafeArea)
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SafeAreaPage(request: request, isUserBuyer: true),
                  ),
                ),
                icon: Icon(
                  request.status == 'completed'
                      ? Icons.download_outlined
                      : Icons.shield_outlined,
                  size: 18,
                ),
                label: Text(
                  request.status == 'completed'
                      ? 'Download'
                      : request.status == 'ready_for_delivery'
                          ? 'Review & Pay'
                          : 'Open Safe Area',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: request.status == 'completed'
                      ? AppTheme.success
                      : AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':              return Colors.orange;
      case 'accepted':             return Colors.blue;
      case 'ready_for_delivery':  return Colors.green;
      case 'completed':            return Colors.teal;
      case 'rejected':             return Colors.red;
      default:                     return Colors.grey;
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _fmtDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
}
