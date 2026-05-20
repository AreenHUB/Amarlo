// lib/screens/worker_profile_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/dialogs.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'login.dart';
import 'register.dart';
import 'review_screen.dart';

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
  int _conductWarnings = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getUserByEmail(widget.email),
        ApiService.getServices(workerEmail: widget.email),
        ApiService.getReviews(widget.email),
        ApiService.getConductSummary(widget.email),
      ]);
      if (mounted) {
        setState(() {
          _worker   = results[0] as User;
          _services = (results[1] as dynamic).items as List<Service>;
          _reviews  = results[2] as List<Review>;
          final conduct = results[3] as Map<String, dynamic>;
          _conductWarnings = conduct['conduct_warnings'] as int? ?? 0;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _goLogin()    => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  void _goRegister() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));

  Future<bool> _requireAuth() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return true;
    await showAuthRequired(context, onLogin: _goLogin, onRegister: _goRegister);
    return false;
  }

  void _openReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => WorkReviewSheet(
        revieweeEmail:    widget.email,
        revieweeUsername: _worker?.username ?? widget.email,
      ),
    ).then((submitted) {
      if (submitted == true) _load();
    });
  }

  void _openConductReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ConductReportSheet(
        reportedEmail:    widget.email,
        reportedUsername: _worker?.username ?? widget.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_worker == null) return const Scaffold(body: Center(child: Text('Worker not found')));

    // متوسط التقييم من 3 محاور
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.overallRating).reduce((a, b) => a + b) / _reviews.length;
    final avgQuality       = _reviews.isEmpty ? 0.0 : _reviews.map((r) => r.qualityRating.toDouble()).reduce((a,b)=>a+b) / _reviews.length;
    final avgPunctuality   = _reviews.isEmpty ? 0.0 : _reviews.map((r) => r.punctualityRating.toDouble()).reduce((a,b)=>a+b) / _reviews.length;
    final avgCommunication = _reviews.isEmpty ? 0.0 : _reviews.map((r) => r.communicationRating.toDouble()).reduce((a,b)=>a+b) / _reviews.length;

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
                onPressed: () async {
                  if (!await _requireAuth()) return;
                  if (!mounted) return;
                  final worker = _worker!;
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      recipientEmail:    widget.email,
                      recipientUsername: worker.username,
                      recipientImageUrl: worker.imageUrl,
                    ),
                  ));
                },
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
                  if (_reviews.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              RatingBarIndicator(
                                rating: avg,
                                itemBuilder: (_, __) =>
                                    const Icon(Icons.star, color: Colors.amber),
                                itemCount: 5, itemSize: 22,
                              ),
                              const SizedBox(width: 10),
                              Text('${avg.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Text('· ${_reviews.length} reviews',
                                  style: const TextStyle(color: Colors.grey)),
                            ]),
                            const SizedBox(height: 8),
                            _RatingRow('Quality',       avgQuality),
                            _RatingRow('Punctuality',   avgPunctuality),
                            _RatingRow('Communication', avgCommunication),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Conduct warning ───────────────────
                  if (_conductWarnings >= 3) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This user has received $_conductWarnings '
                            'conduct reports.',
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── About ─────────────────────────────
                  if (_worker!.introduction != null) ...[
                    const Text('About Me',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_worker!.introduction!),
                    const SizedBox(height: 16),
                  ],

                  // ── Social ────────────────────────────
                  const Text('Social Media',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _socialRow(
                      const FaIcon(FontAwesomeIcons.facebook,
                          size: 18, color: Color(0xFF1877F2)),
                      Colors.blue, _worker!.facebook ?? 'N/A'),
                  _socialRow(
                      const FaIcon(FontAwesomeIcons.instagram,
                          size: 18, color: Color(0xFFE1306C)),
                      Colors.pink, _worker!.instagram ?? 'N/A'),
                  _socialRow(
                      const FaIcon(FontAwesomeIcons.telegram,
                          size: 18, color: Color(0xFF0088CC)),
                      Colors.lightBlue, _worker!.telegram ?? 'N/A'),
                  const SizedBox(height: 20),

                  // ── Services ──────────────────────────
                  const Text('Services',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._services.map((s) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AppNetworkImage(
                                imageUrl: s.imageUrl,
                                width: 50, height: 50),
                          ),
                          title: Text(s.name),
                          subtitle: Text(
                              '\$${s.price.toStringAsFixed(0)} · ${s.location}'),
                          trailing: Text(s.category ?? '',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                  const SizedBox(height: 20),

                  // ── Reviews list ──────────────────────
                  const Text('Reviews',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No reviews yet.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._reviews.map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(r.reviewerUsername,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Icon(Icons.star,
                                      color: Colors.amber, size: 14),
                                  const SizedBox(width: 2),
                                  Text(r.overallRating.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12)),
                                ]),
                                const SizedBox(height: 4),
                                _RatingRow('Quality',
                                    r.qualityRating.toDouble()),
                                _RatingRow('Punctuality',
                                    r.punctualityRating.toDouble()),
                                _RatingRow('Communication',
                                    r.communicationRating.toDouble()),
                                if (r.comment != null) ...[
                                  const SizedBox(height: 6),
                                  Text(r.comment!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87)),
                                ],
                                // زر حذف إذا كان التقييم من هذا المستخدم
                                if (r.reviewerEmail ==
                                    context
                                        .read<AuthProvider>()
                                        .user
                                        ?.email) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final ok =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                                'Delete Review'),
                                            content: const Text(
                                                'Are you sure?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context,
                                                          false),
                                                  child: const Text(
                                                      'Cancel')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .red))),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await ApiService.deleteReview(
                                              r.id!);
                                          _load();
                                        }
                                      },
                                      icon: const Icon(Icons.delete,
                                          size: 14, color: Colors.red),
                                      label: const Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12)),
                                      style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 16),

                  // ── Action buttons ────────────────────
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (!await _requireAuth()) return;
                          if (!mounted) return;
                          _openReviewSheet();
                        },
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Leave a Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (!await _requireAuth()) return;
                        if (!mounted) return;
                        _openConductReport();
                      },
                      icon: const Icon(Icons.flag_outlined,
                          size: 16, color: Colors.red),
                      label: const Text('Report',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

// ── Rating row helper ──────────────────────────────────
class _RatingRow extends StatelessWidget {
  final String label;
  final double value;
  const _RatingRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ),
          RatingBarIndicator(
            rating: value,
            itemBuilder: (_, __) =>
                const Icon(Icons.star, color: Colors.amber),
            itemCount: 5,
            itemSize: 14,
            unratedColor: Colors.grey[200],
          ),
          const SizedBox(width: 4),
          Text(value.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
