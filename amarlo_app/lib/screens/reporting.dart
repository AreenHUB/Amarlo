// lib/screens/reporting.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class AboutAndReportScreen extends StatefulWidget {
  const AboutAndReportScreen({super.key});

  @override
  State<AboutAndReportScreen> createState() => _AboutAndReportScreenState();
}

class _AboutAndReportScreenState extends State<AboutAndReportScreen> {
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _reports = [];
  bool _loadingReports = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    setState(() => _loadingReports = true);
    try {
      final reports = await ApiService.getMyReports();
      if (mounted) setState(() { _reports = reports; _loadingReports = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the problem')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.submitReport(_descCtrl.text.trim());
      _descCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')));
        await _fetchReports();
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── About section ─────────────────────────
            _section('Welcome to Amarlo!'),
            const Text(
              'Amarlo is a marketplace connecting you with skilled workers. '
              'Browse services, post requests, get offers, chat, and transact safely.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),

            _section('How it works'),
            ..._features,
            const SizedBox(height: 20),

            // ── Report form ───────────────────────────
            _section('Report a Problem'),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe your issue...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send),
              label: _submitting ? const Text('Submitting...') : const Text('Submit Report'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 28),

            // ── My reports ────────────────────────────
            _section('My Reports'),
            if (_loadingReports)
              const Center(child: CircularProgressIndicator())
            else if (_reports.isEmpty)
              const Text('No reports submitted yet.', style: TextStyle(color: Colors.grey))
            else
              ..._reports.map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(r['description'] ?? ''),
                      subtitle: Text('Status: ${r['status'] ?? 'Pending'}\n${r['timestamp'] ?? ''}'),
                      leading: Icon(
                        r['status'] == 'Resolved' ? Icons.check_circle : Icons.pending,
                        color: r['status'] == 'Resolved' ? Colors.green : Colors.orange,
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  static const _features = [
    _FeatureTile(Icons.search, 'Find Services', 'Browse and filter services by category, city, and price.'),
    _FeatureTile(Icons.post_add, 'Post Requests', 'Can\'t find what you need? Post a request and get offers.'),
    _FeatureTile(Icons.chat, 'Chat', 'Communicate directly with workers before committing.'),
    _FeatureTile(Icons.lock, 'Safe Area', 'Secure escrow ensures both parties are protected.'),
    _FeatureTile(Icons.star, 'Reviews', 'Rate and review workers after completed jobs.'),
  ];
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureTile(this.icon, this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.brown, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(desc, style: const TextStyle(color: Colors.black54)),
        ])),
      ]),
    );
  }
}
