// lib/screens/userScreen/UserRequestsPage.dart
import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
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
      _snack('Request cancelled');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Completed Requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserRequestHistoryPage()),
            ),
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (_, provider, __) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());

          final requests = provider.userRequests;

          return RefreshIndicator(
            onRefresh: _fetch,
            child: requests.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No active requests',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
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

// ─────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onDelete;

  const _RequestCard({required this.request, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final deadline = request.deadline != null
        ? DateTime.tryParse(request.deadline!)
        : null;

    final statusColor = _statusColor(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(request.serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    request.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Worker: ${request.workerEmail}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              _formatDate(request.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            // ── Deadline countdown ───────────────────
            if (request.status == 'accepted' && deadline != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${DateFormat('MMM d, HH:mm').format(deadline)}',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
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

            const SizedBox(height: 10),

            // ── Actions ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (request.status == 'pending')
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                if (request.status == 'ready_for_delivery' ||
                    request.status == 'completed')
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SafeAreaPage(request: request, isUserBuyer: true),
                      ),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Receive Work'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'ready_for_delivery': return Colors.green;
      case 'completed': return Colors.teal;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }

  String _fmtDuration(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    final days = d.inDays > 0 ? '${d.inDays}d ' : '';
    return '$days${p(d.inHours % 24)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }
}
