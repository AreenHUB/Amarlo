// lib/screens/safe_area_session_screen.dart
// C4 — شاشة عرض وإدارة Safe Area Session (Contract)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class SafeAreaSessionScreen extends StatefulWidget {
  final SafeAreaSession session;
  const SafeAreaSessionScreen({super.key, required this.session});

  @override
  State<SafeAreaSessionScreen> createState() => _SafeAreaSessionScreenState();
}

class _SafeAreaSessionScreenState extends State<SafeAreaSessionScreen> {
  late SafeAreaSession _session;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  String get _myEmail =>
      context.read<AuthProvider>().user?.email ?? '';

  bool get _isInitiator => _session.initiatorEmail == _myEmail;

  Future<void> _refresh() async {
    try {
      final updated = await ApiService.getSafeAreaSession(_session.id);
      if (mounted) setState(() => _session = updated);
    } catch (_) {}
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await ApiService.acceptSafeAreaSession(_session.id);
      if (mounted) {
        _snack('Contract accepted! Safe Area is now active.', Colors.green);
        _refresh();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Contract?'),
        content: const Text(
            'The worker will be notified. You can still negotiate via chat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await ApiService.rejectSafeAreaSession(_session.id);
      if (mounted) {
        _snack('Contract rejected.', Colors.orange);
        _refresh();
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Contract Header ─────────────────────
              _ContractHeader(session: _session),
              const SizedBox(height: 20),

              // ── Status Banner ───────────────────────
              _StatusBanner(session: _session),
              const SizedBox(height: 20),

              // ── Contract Body ───────────────────────
              _Section('Work Title', _session.title),
              _Section('Description', _session.description),
              _Section('Deliverables', _session.deliverables),
              _PriceSection(price: _session.price),
              _DeadlineSection(deadline: _session.deadline),
              _Section('Delivery Method',
                  _session.deliveryType == 'online' ? 'Online Delivery' : 'In-Person'),

              // ── Parties ─────────────────────────────
              const SizedBox(height: 8),
              const _Divider('Parties'),
              _PartyRow(
                label: 'Worker (Initiator)',
                email: _session.initiatorEmail,
                username: _session.initiatorUsername,
                icon: Icons.work_outline,
              ),
              _PartyRow(
                label: 'Client (You / Invited)',
                email: _session.participantEmail,
                username: _session.participantUsername,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),

              // ── Invitation expiry ────────────────────
              if (_session.isPending && _session.invitationExpiresAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Invitation expires: ${_session.invitationTimeLeft}',
                      style: const TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Actions ──────────────────────────────
              if (_session.isPending && !_isInitiator)
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(children: [
                        ElevatedButton.icon(
                          onPressed: _accept,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept & Sign Contract'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: Colors.green,
                            textStyle: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _reject,
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          label: const Text('Reject Contract',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ]),

              if (_session.isPending && _isInitiator)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.hourglass_top, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Waiting for client to accept the contract.',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ]),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────

class _ContractHeader extends StatelessWidget {
  final SafeAreaSession session;
  const _ContractHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.description_outlined, color: AppTheme.primary, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Safe Area Contract',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: session.contractRef));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contract ref copied!')));
              },
              child: Row(children: [
                Text(session.contractRef,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 14, color: AppTheme.primary),
              ]),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(
                  DateTime.parse(session.createdAt).toLocal()),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final SafeAreaSession session;
  const _StatusBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (session.status) {
      'active'             => (Colors.green, Icons.shield, 'Active — Contract Signed'),
      'pending_acceptance' => (Colors.orange, Icons.schedule, 'Awaiting Client Signature'),
      'rejected'           => (Colors.red, Icons.cancel, 'Contract Rejected'),
      'expired'            => (Colors.grey, Icons.timer_off, 'Invitation Expired'),
      _                    => (Colors.grey, Icons.info, session.status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String value;
  const _Section(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ]),
      );
}

class _PriceSection extends StatelessWidget {
  final double price;
  const _PriceSection({required this.price});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Agreed Price',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[600],
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('\$${price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: Colors.green)),
        ]),
      );
}

class _DeadlineSection extends StatelessWidget {
  final String deadline;
  const _DeadlineSection({required this.deadline});

  @override
  Widget build(BuildContext context) {
    DateTime? dt;
    try { dt = DateTime.parse(deadline).toLocal(); } catch (_) {}
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Delivery Deadline',
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600],
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          dt != null
              ? DateFormat('EEE, MMM d yyyy — HH:mm').format(dt)
              : deadline,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

class _PartyRow extends StatelessWidget {
  final String label;
  final String email;
  final String username;
  final IconData icon;
  const _PartyRow({
    required this.label, required this.email,
    required this.username, required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(username,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(email,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ]),
      );
}
