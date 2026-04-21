// lib/screens/userScreen/offers_screen.dart
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/user_avatar.dart';
import '../chat_screen.dart';

class OffersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final VoidCallback onRefresh;

  const OffersScreen({super.key, required this.offers, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No offers yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('Post a request and workers will send you offers',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: offers.length,
        itemBuilder: (_, i) => _OfferCard(offer: offers[i], onAction: onRefresh),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _OfferCard extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onAction;
  const _OfferCard({required this.offer, required this.onAction});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _acting = false;

  String get _status => widget.offer['status'] ?? 'pending';
  String get _postId => widget.offer['post_id'] ?? '';
  String get _offerId => widget.offer['_id'] ?? '';
  String get _workerEmail => widget.offer['worker_email'] ?? '';
  String get _workerUsername => widget.offer['worker_username'] ?? _workerEmail;

  Future<void> _respond(String action) async {
    setState(() => _acting = true);
    try {
      await ApiService.respondToOffer(_postId, _offerId, action);
      widget.onAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer ${action}ed successfully')),
        );
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _status == 'pending';
    final statusColor = _status == 'accepted'
        ? Colors.green
        : _status == 'rejected'
            ? Colors.red
            : Colors.orange;

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
                UserAvatar(imageUrl: null, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_workerUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_workerEmail,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    _status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Post & content ───────────────────────
            if (widget.offer['post_title'] != null)
              Text('Post: ${widget.offer['post_title']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(widget.offer['content'] ?? '',
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.attach_money, size: 18, color: Colors.green),
              Text(
                '\$${(widget.offer['price'] as num?)?.toStringAsFixed(0) ?? '—'}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Actions ─────────────────────────────
            Row(
              children: [
                // Chat button
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        recipientEmail: _workerEmail,
                        recipientUsername: _workerUsername,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('Chat'),
                ),
                const SizedBox(width: 8),

                if (isPending && !_acting) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond('reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respond('accept'),
                      child: const Text('Accept'),
                    ),
                  ),
                ] else if (_acting)
                  const Expanded(
                    child: Center(
                        child: SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
