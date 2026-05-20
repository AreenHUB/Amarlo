// lib/screens/userScreen/user_dashboard.dart
import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../services/notification_service.dart';
import '../../widgets/states.dart';
import 'offers_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Post> _posts = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchPosts();
    // تحديث فوري عند وصول offer جديدة + انتقال لـ Offers tab
    NotificationManager.instance.registerOffersRefresh(() {
      if (!mounted) return;
      _fetchPosts();
      _tab.animateTo(1);
    });
  }

  @override
  void dispose() {
    NotificationManager.instance.unregisterOffersRefresh();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final paged = await ApiService.getMyPosts(size: 100);
      if (mounted) {
        setState(() { _posts = paged.items; _loadingPosts = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: const [NotificationIconButton()],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'My Posts'), Tab(text: 'Offers Received')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _PostsTab(
            posts: _posts,
            loading: _loadingPosts,
            onRefresh: _fetchPosts,
          ),
          OffersScreen(posts: _posts, onRefresh: _fetchPosts),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Posts Tab
// ══════════════════════════════════════════════
class _PostsTab extends StatelessWidget {
  final List<Post> posts;
  final bool loading;
  final VoidCallback onRefresh;

  const _PostsTab({required this.posts, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
        backgroundColor: Colors.brown,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: posts.isEmpty
                  ? const Center(child: Text('No posts yet.\nCreate one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => _PostCard(post: posts[i], onRefresh: onRefresh),
                    ),
            ),
    );
  }

  void _openForm(BuildContext context, {Post? post}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostForm(post: post, onSaved: onRefresh),
    );
  }
}

// ─────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onRefresh;

  const _PostCard({required this.post, required this.onRefresh});

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
            Row(
              children: [
                Expanded(
                  child: Text(post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _actionMenu(context),
              ],
            ),
            const SizedBox(height: 4),
            Text(post.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.attach_money, size: 16, color: Colors.green),
              Text(post.priceRange, style: const TextStyle(color: Colors.green)),
              if (post.category != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.category, size: 14, color: Colors.grey),
                const SizedBox(width: 2),
                Text(post.category!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 6),
            if (post.status == 'closed')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.handshake, size: 13, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Deal agreed — no more offers accepted',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              )
            else if (post.offers.isNotEmpty)
              Text('${post.offers.length} offer(s)',
                  style: const TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _actionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'edit') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _PostForm(post: post, onSaved: onRefresh),
          );
        } else if (v == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete Post'),
              content: Text('Delete "${post.title}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (ok == true) {
            try {
              await ApiService.deletePost(post.id);
              onRefresh();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        }
      },
      itemBuilder: (_) => [
        // البوست المغلق لا يمكن تعديله
        if (post.status != 'closed')
          const PopupMenuItem(value: 'edit', child: ListTile(
            leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
        const PopupMenuItem(value: 'delete', child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
class _PostForm extends StatefulWidget {
  final Post? post;
  final VoidCallback onSaved;
  const _PostForm({this.post, required this.onSaved});

  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = [];
  bool _safeAreaEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _titleCtrl.text   = widget.post!.title;
      _descCtrl.text    = widget.post!.description;
      _priceCtrl.text   = widget.post!.priceRange;
      _selectedCategory = widget.post!.category;
      _safeAreaEnabled  = widget.post!.safeAreaEnabled;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.getPostCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title, description, and price are required')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.post == null) {
        await ApiService.createPost(
          title:            _titleCtrl.text.trim(),
          description:      _descCtrl.text.trim(),
          priceRange:       _priceCtrl.text.trim(),
          category:         _selectedCategory,
          safeAreaEnabled:  _safeAreaEnabled,
        );
      } else {
        await ApiService.updatePost(widget.post!.id,
          title:            _titleCtrl.text.trim(),
          description:      _descCtrl.text.trim(),
          priceRange:       _priceCtrl.text.trim(),
          category:         _selectedCategory,
          safeAreaEnabled:  _safeAreaEnabled,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // handle bar
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 14),
            Text(widget.post == null ? 'Create Post' : 'Edit Post',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _field(_titleCtrl, 'Title *'),
            _field(_descCtrl, 'Description *', maxLines: 3),
            _field(_priceCtrl, 'Price Range * (e.g. 50-100)'),
            // ── Category Dropdown ──────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                value: _categories.contains(_selectedCategory)
                    ? _selectedCategory
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: const Text('Select a category'),
                isExpanded: true,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
            ),
            const SizedBox(height: 4),
            // ── Safe Area Toggle ────────────────────
            Container(
              decoration: BoxDecoration(
                color: _safeAreaEnabled
                    ? Colors.green.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _safeAreaEnabled
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                title: Row(children: [
                  const Text('Activate Safe Area',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        'Enable Safe Area if your work can be delivered\n'
                        'online (e.g. logo, code, PDF, report).\n'
                        'Payment is held in escrow and released\n'
                        'only after you confirm the delivery.',
                    preferBelow: false,
                    child: const Icon(Icons.help_outline,
                        size: 16, color: Colors.grey),
                  ),
                ]),
                subtitle: Text(
                  _safeAreaEnabled
                      ? 'Payment held in escrow until delivery confirmed'
                      : 'For in-person / offline services',
                  style: TextStyle(
                    fontSize: 11,
                    color: _safeAreaEnabled ? Colors.green[700] : Colors.grey,
                  ),
                ),
                value: _safeAreaEnabled,
                activeThumbColor: Colors.green,
                activeTrackColor: Colors.green.withValues(alpha: 0.5),
                onChanged: (val) async {
                  if (val) {
                    // confirmation dialog عند التفعيل
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Row(children: [
                          Icon(Icons.shield, color: Colors.green, size: 22),
                          SizedBox(width: 8),
                          Text('Enable Safe Area?'),
                        ]),
                        content: const Text(
                          'Enable this only if your work can be delivered '
                          'online — such as:\n\n'
                          '• Design files (logo, UI)\n'
                          '• Code or software\n'
                          '• PDF reports or documents\n'
                          '• Any digital deliverable\n\n'
                          'For in-person services (cleaning, tutoring, etc.) '
                          'please leave this off.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700]),
                            child: const Text('No, go back'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: const Text('Yes, enable it'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      setState(() => _safeAreaEnabled = true);
                    }
                  } else {
                    setState(() => _safeAreaEnabled = false);
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.post == null ? 'Post' : 'Save Changes'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c, maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
