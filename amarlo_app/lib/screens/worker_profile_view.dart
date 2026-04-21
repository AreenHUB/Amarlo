// lib/screens/worker_profile_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class WorkerProfileViewPage extends StatefulWidget {
  final String email;
  const WorkerProfileViewPage({super.key, required this.email});

  @override
  State<WorkerProfileViewPage> createState() => _WorkerProfileViewPageState();
}

class _WorkerProfileViewPageState extends State<WorkerProfileViewPage> {
  User? _worker;
  List<Service> _services = [];
  List<Review> _reviews = [];
  bool _loading = true;

  double _newRating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submittingReview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final worker = await ApiService.getUserByEmail(widget.email);
      final services = await ApiService.getServices(workerEmail: widget.email);
      final reviews = await ApiService.getReviews(widget.email);
      if (mounted) {
        setState(() {
          _worker = worker;
          _services = services.items;
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _snack('Please login to add a review');
      return;
    }
    if (auth.user!.email == widget.email) {
      _snack('You cannot review yourself');
      return;
    }
    if (_newRating == 0) {
      _snack('Please select a rating');
      return;
    }

    setState(() => _submittingReview = true);
    try {
      await ApiService.addReview(widget.email, _newRating.toInt(), _reviewCtrl.text);
      _reviewCtrl.clear();
      setState(() { _newRating = 0; });
      await _load();
      _snack('Review submitted!');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_worker == null) return const Scaffold(body: Center(child: Text('Worker not found')));

    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar with cover photo ──────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_worker!.username),
              background: _worker!.imageUrl != null
                  ? AppNetworkImage(imageUrl: _worker!.imageUrl, height: 240)
                  : Container(color: Colors.brown[200]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      recipientEmail: widget.email,
                      recipientUsername: _worker!.username,
                      recipientImageUrl: _worker!.imageUrl,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Rating overview ───────────────────
                  if (_reviews.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          RatingBarIndicator(
                            rating: avg,
                            itemBuilder: (_, __) =>
                                const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5, itemSize: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${avg.toStringAsFixed(1)} · ${_reviews.length} reviews',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── About ─────────────────────────────
                  if (_worker!.introduction != null) ...[
                    const Text('About Me',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_worker!.introduction!),
                    const SizedBox(height: 16),
                  ],

                  // ── Social ────────────────────────────
                  const Text('Social Media',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _socialRow(const FaIcon(FontAwesomeIcons.facebook, size: 18, color: Color(0xFF1877F2)), Colors.blue,
                      _worker!.facebook ?? 'N/A'),
                  _socialRow(const FaIcon(FontAwesomeIcons.instagram, size: 18, color: Color(0xFFE1306C)), Colors.pink,
                      _worker!.instagram ?? 'N/A'),
                  _socialRow(const FaIcon(FontAwesomeIcons.telegram, size: 18, color: Color(0xFF0088CC)), Colors.lightBlue,
                      _worker!.telegram ?? 'N/A'),
                  const SizedBox(height: 20),

                  // ── Services ──────────────────────────
                  const Text('Services',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._services.map((s) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AppNetworkImage(
                                imageUrl: s.imageUrl, width: 50, height: 50),
                          ),
                          title: Text(s.name),
                          subtitle: Text(
                              '\$${s.price.toStringAsFixed(0)} · ${s.location}'),
                          trailing:
                              Text(s.category ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                  const SizedBox(height: 20),

                  // ── Reviews list ──────────────────────
                  const Text('Reviews',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._buildReviewList(),
                  const Divider(height: 32),

                  // ── Add review ────────────────────────
                  _buildAddReview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReviewList() {
    final auth = context.read<AuthProvider>();
    return _reviews.map((r) {
      final isMine = r.reviewerEmail == auth.user?.email;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(r.reviewerUsername),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingBarIndicator(
                rating: r.rating.toDouble(),
                itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                itemCount: 5, itemSize: 16,
              ),
              if (r.comment != null) Text(r.comment!),
            ],
          ),
          trailing: isMine
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editReviewDialog(r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _deleteReview(r.id!),
                    ),
                  ],
                )
              : null,
        ),
      );
    }).toList();
  }

  Widget _buildAddReview() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Review',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _newRating,
            minRating: 1,
            itemCount: 5,
            itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (v) => setState(() => _newRating = v),
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
            onPressed: _submittingReview ? null : _submitReview,
            child: _submittingReview
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Review'),
          ),
        ],
      );

  void _editReviewDialog(Review r) {
    double rating = r.rating.toDouble();
    final ctrl = TextEditingController(text: r.comment);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Review'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RatingBar.builder(
            initialRating: rating,
            minRating: 1,
            itemCount: 5,
            itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (v) => rating = v,
          ),
          const SizedBox(height: 8),
          TextField(controller: ctrl, maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.updateReview(r.id!, rating.toInt(), ctrl.text);
                await _load();
                _snack('Review updated');
              } on ApiException catch (e) {
                _snack(e.message);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteReview(id);
      await _load();
      _snack('Review deleted');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Widget _socialRow(Widget icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          icon,
          const SizedBox(width: 10),
          Text(text),
        ]),
      );
}
