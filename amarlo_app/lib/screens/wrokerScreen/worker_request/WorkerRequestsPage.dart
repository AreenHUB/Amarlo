// lib/screens/wrokerScreen/worker_request/WorkerRequestsPage.dart
import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/app_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/http_client.dart';
import '../../safe_area_page.dart';
import '../../worker_request_history_page.dart';

class WorkerRequestsPage extends StatefulWidget {
  const WorkerRequestsPage({super.key});

  @override
  State<WorkerRequestsPage> createState() => _WorkerRequestsPageState();
}

class _WorkerRequestsPageState extends State<WorkerRequestsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    await context.read<RequestProvider>().fetchWorkerRequests(auth.user!.email);
  }

  Future<void> _accept(String requestId) async {
    final deadline = await _pickDeadline();
    if (deadline == null) return;

    try {
      await context.read<RequestProvider>().acceptRequest(requestId, deadline);
      _snack('Request accepted');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _reject(String requestId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await context.read<RequestProvider>().rejectRequest(requestId);
      _snack('Request rejected');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<DateTime?> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null) return null;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _openSafeArea(ServiceRequest req) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SafeAreaPage(request: req, isUserBuyer: false),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WorkerRequestHistoryPage())),
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (_, provider, __) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());

          final pending = provider.workerRequests
              .where((r) => r.status == 'pending')
              .toList();
          final accepted = provider.acceptedRequests;

          return RefreshIndicator(
            onRefresh: _fetch,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Pending ───────────────────────────────
                if (pending.isNotEmpty) ...[
                  const _SectionHeader('New Requests'),
                  ...pending.map((r) => _PendingCard(
                        request: r,
                        onAccept: () => _accept(r.id),
                        onReject: () => _reject(r.id),
                      )),
                  const SizedBox(height: 16),
                ],

                // ── Accepted with deadline ─────────────────
                if (accepted.isNotEmpty) ...[
                  const _SectionHeader('Active (with Deadline)'),
                  ...accepted.map((r) => _AcceptedCard(
                        request: r,
                        onOpenSafeArea: () => _openSafeArea(r),
                      )),
                  const SizedBox(height: 16),
                ],

                // ── Other statuses ─────────────────────────
                ...provider.workerRequests
                    .where((r) =>
                        r.status != 'pending' &&
                        r.status != 'accepted')
                    .map((r) => _StatusCard(
                          request: r,
                          onOpenSafeArea:
                              r.status == 'ready_for_delivery'
                                  ? () => _openSafeArea(r)
                                  : null,
                        )),

                if (provider.workerRequests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No requests yet',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: Colors.brown)),
      );
}

class _PendingCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingCard(
      {required this.request, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.serviceName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('From: ${request.userName}', style: const TextStyle(color: Colors.grey)),
            Text(_formatDate(request.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Accept'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AcceptedCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onOpenSafeArea;

  const _AcceptedCard({required this.request, required this.onOpenSafeArea});

  @override
  Widget build(BuildContext context) {
    final deadline = request.deadline != null
        ? DateTime.tryParse(request.deadline!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.serviceName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('From: ${request.userName}',
                style: const TextStyle(color: Colors.grey)),
            if (deadline != null) ...[
              const SizedBox(height: 6),
              Text(
                'Deadline: ${DateFormat('yyyy-MM-dd HH:mm').format(deadline)}',
                style: const TextStyle(color: Colors.blue),
              ),
              CountdownTimer(
                endTime: deadline.millisecondsSinceEpoch,
                widgetBuilder: (_, time) {
                  if (time == null) return const Text('⏰ Time is up!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                  final d = Duration(
                    days: time.days ?? 0, hours: time.hours ?? 0,
                    minutes: time.min ?? 0, seconds: time.sec ?? 0,
                  );
                  return Text(
                    'Remaining: ${_fmt(d)}',
                    style: const TextStyle(color: Colors.red),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onOpenSafeArea,
              icon: const Icon(Icons.lock_open),
              label: const Text('Open Safe Area'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final days = d.inDays > 0 ? '${d.inDays}d ' : '';
    return '$days${pad(d.inHours % 24)}:${pad(d.inMinutes % 60)}:${pad(d.inSeconds % 60)}';
  }
}

class _StatusCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback? onOpenSafeArea;

  const _StatusCard({required this.request, this.onOpenSafeArea});

  @override
  Widget build(BuildContext context) {
    final color = request.status == 'ready_for_delivery'
        ? Colors.orange
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(request.serviceName),
        subtitle: Text('From: ${request.userName}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(request.status.replaceAll('_', ' '),
                  style: TextStyle(color: color, fontSize: 11)),
            ),
            if (onOpenSafeArea != null)
              TextButton(
                onPressed: onOpenSafeArea,
                child: const Text('Safe Area', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String iso) {
  try {
    return DateFormat('MMM d, HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
