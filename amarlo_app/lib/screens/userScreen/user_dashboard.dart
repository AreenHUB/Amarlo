// lib/screens/userScreen/user_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
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
  List<Map<String, dynamic>> _offers = [];
  bool _loadingPosts = true;
  bool _loadingOffers = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchPosts();
    _fetchOffers();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final paged = await ApiService.getMyPosts(size: 100);
      if (mounted) setState(() { _posts = paged.items; _loadingPosts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _fetchOffers() async {
    setState(() => _loadingOffers = true);
    try {
      final offers = await ApiService.getMyReceivedOffers();
      if (mounted) setState(() { _offers = offers; _loadingOffers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
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
          OffersScreen(offers: _offers, onRefresh: _fetchOffers),
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
            if (post.offers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${post.offers.length} offer(s)',
                  style: const TextStyle(color: Colors.blue, fontSize: 12)),
            ],
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: ListTile(
          leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
        PopupMenuItem(value: 'delete', child: ListTile(
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
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _titleCtrl.text = widget.post!.title;
      _descCtrl.text = widget.post!.description;
      _priceCtrl.text = widget.post!.priceRange;
      _catCtrl.text = widget.post!.category ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _priceCtrl.dispose(); _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title, description, and price are required')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.post == null) {
        await ApiService.createPost(
          title: _titleCtrl.text,
          description: _descCtrl.text,
          priceRange: _priceCtrl.text,
          category: _catCtrl.text.isNotEmpty ? _catCtrl.text : null,
        );
      } else {
        await ApiService.updatePost(widget.post!.id,
          title: _titleCtrl.text,
          description: _descCtrl.text,
          priceRange: _priceCtrl.text,
          category: _catCtrl.text.isNotEmpty ? _catCtrl.text : null,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.post == null ? 'Create Post' : 'Edit Post',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _field(_titleCtrl, 'Title *'),
          _field(_descCtrl, 'Description *', maxLines: 3),
          _field(_priceCtrl, 'Price Range * (e.g. \$50–\$100)'),
          _field(_catCtrl, 'Category (optional)'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: _saving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.post == null ? 'Post' : 'Save Changes'),
          ),
          const SizedBox(height: 20),
        ],
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
