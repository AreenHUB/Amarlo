import 'package:url_launcher/url_launcher.dart';
// lib/screens/safe_area_page.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../core/constants.dart';

class SafeAreaPage extends StatefulWidget {
  final ServiceRequest request;
  final bool isUserBuyer;

  const SafeAreaPage({super.key, required this.request, required this.isUserBuyer});

  @override
  State<SafeAreaPage> createState() => _SafeAreaPageState();
}

class _SafeAreaPageState extends State<SafeAreaPage> {
  bool _paymentSent = false;
  bool _dealConfirmed = false;
  int _paymentAmount = 0;
  final _amountCtrl = TextEditingController();

  // Review
  double _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _reviewSubmitted = false;

  bool _loading = true;
  String? _confirmMessage;

  @override
  void initState() {
    super.initState();
    _checkPayment();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    try {
      final status = await ApiService.getPaymentStatus(widget.request.id);
      if (mounted) {
        setState(() {
          _paymentSent = status['payment_received'] ?? false;
          _paymentAmount = status['amount'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Worker actions ───────────────────────────────────

  Future<void> _uploadWork() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    try {
      await ApiService.uploadWork(widget.request.id, file);
      _snack('Work uploaded successfully!');
      setState(() {});
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  // ── User actions ─────────────────────────────────────

  Future<void> _sendPayment() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    try {
      await ApiService.sendPayment(widget.request.id, amount);
      setState(() { _paymentSent = true; _paymentAmount = amount; });
      _snack('Payment sent!');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _confirmDeal() async {
    try {
      final result = await ApiService.confirmDeal(widget.request.id);
      final msg = result['message'] as String? ?? '';
      setState(() {
        _confirmMessage = msg;
        if (msg.contains('completed')) _dealConfirmed = true;
      });
      _snack(msg);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) { _snack('Select a rating first'); return; }
    try {
      await ApiService.addReview(
          widget.request.workerEmail, _rating.toInt(), _reviewCtrl.text);
      setState(() => _reviewSubmitted = true);
      _snack('Review submitted!');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Preview URL ──────────────────────────────────────
  String get _previewUrl =>
      '${AppConstants.safeAreaPreviewUrl(widget.request.id)}?token=${context.read<AuthProvider>().token ?? ''}';

  String get _downloadUrl =>
      AppConstants.safeAreaDownloadUrl(widget.request.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Safe Area · ${widget.request.serviceName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: widget.isUserBuyer ? _buildBuyerView() : _buildWorkerView(),
            ),
    );
  }

  // ══════════════════════════════════════════════
  //  BUYER VIEW
  // ══════════════════════════════════════════════
  Widget _buildBuyerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status banner
        _StatusBanner(
          paymentSent: _paymentSent,
          dealConfirmed: _dealConfirmed,
        ),
        const SizedBox(height: 16),

        // Preview (watermarked until confirmed)
        const Text('Work Preview',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (!_dealConfirmed)
          const Text('Watermarked preview — confirm deal to download original',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _previewUrl,
            placeholder: (_, __) => Container(
              height: 220,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('No file uploaded yet or file is not an image'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Payment section
        if (!_paymentSent) ...[
          const Text('Send Payment',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (\$)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _sendPayment,
            icon: const Icon(Icons.payment),
            label: const Text('Send Payment'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
        ] else ...[
          // Payment sent — show confirm button
          _InfoCard(
            icon: Icons.check_circle,
            color: Colors.green,
            title: 'Payment Sent',
            subtitle: '\$$_paymentAmount held in escrow',
          ),
          const SizedBox(height: 12),

          if (!_dealConfirmed)
            ElevatedButton.icon(
              onPressed: _confirmDeal,
              icon: const Icon(Icons.handshake),
              label: const Text('Confirm & Release Payment'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.green,
              ),
            )
          else ...[
            // Download button
            ElevatedButton.icon(
              onPressed: () async {
                final token = context.read<AuthProvider>().token ?? '';
                final uri = Uri.parse('$_downloadUrl?token=$token');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  _snack('Cannot open download link');
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Original File'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            // Review section
            if (!_reviewSubmitted) ...[
              const SizedBox(height: 24),
              const Text('Rate & Review',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                itemCount: 5,
                itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write your review (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44)),
                child: const Text('Submit Review'),
              ),
            ] else
              const _InfoCard(
                icon: Icons.star,
                color: Colors.amber,
                title: 'Review Submitted',
                subtitle: 'Thank you for your feedback!',
              ),
          ],
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  WORKER VIEW
  // ══════════════════════════════════════════════
  Widget _buildWorkerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBanner(paymentSent: _paymentSent, dealConfirmed: _dealConfirmed),
        const SizedBox(height: 16),

        // Upload section
        const Text('Upload Your Work',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // Preview current upload
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _previewUrl,
            placeholder: (_, __) => Container(height: 80, color: Colors.grey[100]),
            errorWidget: (_, __, ___) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.upload_file, color: Colors.grey),
                SizedBox(width: 8),
                Text('No file uploaded yet'),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _paymentSent && _dealConfirmed ? null : _uploadWork,
          icon: const Icon(Icons.upload),
          label: Text(_paymentSent && _dealConfirmed
              ? 'Deal Confirmed'
              : 'Upload / Replace Work'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 20),

        // Payment status for worker
        if (_paymentSent) ...[
          _InfoCard(
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            title: 'Payment Received in Escrow',
            subtitle: '\$$_paymentAmount will be released when deal is confirmed',
          ),
          const SizedBox(height: 12),
          if (!_dealConfirmed)
            ElevatedButton.icon(
              onPressed: _confirmDeal,
              icon: const Icon(Icons.handshake),
              label: const Text('Confirm Delivery'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.green,
              ),
            ),
        ],

        if (_confirmMessage != null) ...[
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.info_outline,
            color: Colors.blue,
            title: 'Status',
            subtitle: _confirmMessage!,
          ),
        ],
      ],
    );
  }
}

// ─── Helper widgets ──────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool paymentSent;
  final bool dealConfirmed;

  const _StatusBanner({required this.paymentSent, required this.dealConfirmed});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = dealConfirmed
        ? (Colors.green, Icons.check_circle, 'Deal Completed')
        : paymentSent
            ? (Colors.orange, Icons.hourglass_top, 'Payment in Escrow — Waiting for Confirmation')
            : (Colors.blue, Icons.lock_clock, 'Waiting for Payment');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoCard({required this.icon, required this.color,
      required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
