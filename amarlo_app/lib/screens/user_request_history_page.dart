// lib/screens/user_request_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';

class UserRequestHistoryPage extends StatefulWidget {
  const UserRequestHistoryPage({super.key});

  @override
  State<UserRequestHistoryPage> createState() => _UserRequestHistoryPageState();
}

class _UserRequestHistoryPageState extends State<UserRequestHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    await context.read<RequestProvider>().fetchUserCompleted(auth.user!.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Requests')),
      body: Consumer<RequestProvider>(
        builder: (_, provider, __) {
          final list = provider.userCompleted;
          if (list.isEmpty) {
            return const Center(
              child: Text('No completed requests yet',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _HistoryCard(request: list[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────

// lib/screens/worker_request_history_page.dart
class WorkerRequestHistoryPage extends StatefulWidget {
  const WorkerRequestHistoryPage({super.key});

  @override
  State<WorkerRequestHistoryPage> createState() => _WorkerRequestHistoryPageState();
}

class _WorkerRequestHistoryPageState extends State<WorkerRequestHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    await context.read<RequestProvider>().fetchWorkerCompleted(auth.user!.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Jobs')),
      body: Consumer<RequestProvider>(
        builder: (_, provider, __) {
          final list = provider.workerCompleted;
          if (list.isEmpty) {
            return const Center(
              child: Text('No completed jobs yet',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _HistoryCard(request: list[i], isWorker: true),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared card widget
class _HistoryCard extends StatelessWidget {
  final ServiceRequest request;
  final bool isWorker;

  const _HistoryCard({required this.request, this.isWorker = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              isWorker ? 'Client: ${request.userName}' : 'Worker: ${request.workerEmail}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_fmt(request.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (request.deadline != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.flag, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_fmt(request.deadline!),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(String iso) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }
}
