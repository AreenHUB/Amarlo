// lib/screens/userScreen/offers_screen.dart
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/user_avatar.dart';
import '../chat_screen.dart';
import '../worker_profile_view.dart';

// ══════════════════════════════════════════════
//  OffersScreen — يعرض كل Post مع offers خاصتها
// ══════════════════════════════════════════════
class OffersScreen extends StatelessWidget {
  final List<Post> posts; // كل الـ posts بما فيها offers
  final VoidCallback onRefresh;

  const OffersScreen({super.key, required this.posts, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // فقط الـ posts التي عليها offers
    final postsWithOffers = posts.where((p) => p.offers.isNotEmpty).toList();

    if (postsWithOffers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No offers yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('Workers will send offers on your posts',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: postsWithOffers.length,
        itemBuilder: (_, i) => _PostOffersCard(
          post: postsWithOffers[i],
          onAction: onRefresh,
        ),
      ),
    );
  }
}

// ── بطاقة Post مع Offers خاصتها ─────────────────────
class _PostOffersCard extends StatelessWidget {
  final Post post;
  final VoidCallback onAction;
  const _PostOffersCard({required this.post, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final pending  = post.offers.where((o) => o.status == 'pending').length;
    final accepted = post.offers.where((o) => o.status == 'accepted').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Post header ─────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.article_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(post.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primary)),
                  ),
                  // عدد العروض
                  _CountBadge(pending: pending, accepted: accepted),
                ]),
                const SizedBox(height: 4),
                Text(post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.attach_money, size: 14, color: Colors.green),
                  Text(post.priceRange,
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                  if (post.category != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.category_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(post.category!,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ]),
              ],
            ),
          ),

          // ── Offers list ──────────────────────────
          ...post.offers.map((offer) => _OfferRow(
                offer: offer,
                postId: post.id,
                safeAreaEnabled: post.safeAreaEnabled,
                onAction: onAction,
              )),
        ],
      ),
    );
  }
}

// ── Badge عدد العروض ──────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int pending;
  final int accepted;
  const _CountBadge({required this.pending, required this.accepted});

  @override
  Widget build(BuildContext context) {
    if (accepted > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: const Text('Accepted',
            style: TextStyle(color: Colors.green, fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Text('$pending offer${pending != 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.orange, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── صف واحد لـ Offer ──────────────────────────────────
class _OfferRow extends StatefulWidget {
  final PostOffer offer;
  final String postId;
  final bool safeAreaEnabled;
  final VoidCallback onAction;
  const _OfferRow({
    required this.offer,
    required this.postId,
    required this.safeAreaEnabled,
    required this.onAction,
  });

  @override
  State<_OfferRow> createState() => _OfferRowState();
}

class _OfferRowState extends State<_OfferRow> {
  bool _acting = false;

  bool get _isPending  => widget.offer.status == 'pending';
  bool get _isAccepted => widget.offer.status == 'accepted';
  bool get _isRejected => widget.offer.status == 'rejected';

  Color get _statusColor => _isAccepted
      ? Colors.green
      : _isRejected
          ? Colors.red
          : Colors.orange;

  Future<void> _respond(bool accept) async {
    setState(() => _acting = true);
    try {
      final result = await ApiService.respondToOffer(
          widget.postId, widget.offer.id, accept);
      widget.onAction();
      if (!mounted) return;

      final msg = accept
          ? (result['safe_area_enabled'] == true
              ? 'Offer accepted! Worker will set a delivery deadline.'
              : 'Offer accepted! Connect via chat to coordinate.')
          : 'Offer rejected.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: accept ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        color: _isAccepted
            ? Colors.green.withValues(alpha: 0.03)
            : _isRejected
                ? Colors.red.withValues(alpha: 0.03)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Worker info ────────────────────────
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => WorkerProfileViewPage(
                    email: widget.offer.workerEmail),
              )),
              child: UserAvatar(imageUrl: null, radius: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => WorkerProfileViewPage(
                      email: widget.offer.workerEmail),
                )),
                child: Row(children: [
                  Text(widget.offer.workerUsername,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 3),
                  const Icon(Icons.open_in_new, size: 11, color: Colors.grey),
                ]),
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(widget.offer.status.toUpperCase(),
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),

          // ── Offer content ───────────────────────
          Text(widget.offer.content,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.attach_money, size: 16, color: Colors.green),
            Text(
              '\$${widget.offer.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Action buttons ──────────────────────
          if (_isPending && !_acting)
            Row(children: [
              // Chat
              _SmallButton(
                icon: Icons.chat_outlined,
                label: 'Chat',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    recipientEmail: widget.offer.workerEmail,
                    recipientUsername: widget.offer.workerUsername,
                  ),
                )),
              ),
              const SizedBox(width: 8),
              // Reject
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              // Accept
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ])
          else if (_acting)
            const Center(child: SizedBox(
              height: 24, width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_isAccepted)
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              const Text('Accepted — request created',
                  style: TextStyle(color: Colors.green, fontSize: 12)),
              const Spacer(),
              _SmallButton(
                icon: Icons.chat_outlined,
                label: 'Chat',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    recipientEmail: widget.offer.workerEmail,
                    recipientUsername: widget.offer.workerUsername,
                  ),
                )),
              ),
            ])
          else if (_isRejected)
            Row(children: [
              const Icon(Icons.cancel, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              const Text('Rejected',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ]),
        ],
      ),
    );
  }
}

// ── زر صغير ────────────────────────────────────────────
class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
