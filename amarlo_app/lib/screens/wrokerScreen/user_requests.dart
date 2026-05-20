// lib/screens/wrokerScreen/user_requests.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/states.dart'; // NotificationIconButton
import '../chat_screen.dart';

class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen> {
  List<Post> _posts    = [];
  List<Post> _filtered = [];
  List<String> _allCategories = [];
  bool _loading = true;
  String _search = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPublicPosts(size: 100),
        ApiService.getPostCategories(),
      ]);
      if (mounted) {
        final paged = results[0] as dynamic;
        final cats  = results[1] as List<String>;
        setState(() {
          _posts = paged.items as List<Post>;
          _allCategories = cats;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _posts.where((p) {
        final matchSearch = _search.isEmpty ||
            p.title.toLowerCase().contains(_search.toLowerCase()) ||
            p.description.toLowerCase().contains(_search.toLowerCase());
        final matchCat = _selectedCategory == null || p.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  // الفئات المتاحة: كل الفئات من الـ API
  List<String?> get _categories => [null, ..._allCategories];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Requests'),
        automaticallyImplyLeading: false,
        actions: const [NotificationIconButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) { _search = v; _applyFilter(); },
              decoration: InputDecoration(
                hintText: 'Search posts...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category chips
                if (_categories.length > 1)
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final label = cat ?? 'All';
                        final selected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedCategory = cat);
                              _applyFilter();
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.brown[100],
                            checkmarkColor: Colors.brown,
                          ),
                        );
                      },
                    ),
                  ),

                // Posts grid
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No posts found',
                          style: TextStyle(color: Colors.grey)))
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _PostCard(post: _filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category + days left banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.brown[50],
            child: Row(children: [
              Expanded(
                child: Text(
                  post.category ?? 'General',
                  style: const TextStyle(
                      color: Colors.brown, fontWeight: FontWeight.w600, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (post.daysLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: post.daysLeft! <= 1
                        ? Colors.red[100]
                        : post.daysLeft! <= 3
                            ? Colors.orange[100]
                            : Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.daysLeft! == 0
                        ? 'Expires today'
                        : '${post.daysLeft}d left',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: post.daysLeft! <= 1
                          ? Colors.red[800]
                          : post.daysLeft! <= 3
                              ? Colors.orange[800]
                              : Colors.green[800],
                    ),
                  ),
                ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(post.description,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(post.priceRange,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text('by ${post.creatorUsername}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Spacer(),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(child: Builder(builder: (_) {
                  // البوست مغلق — تم الاتفاق مع عامل آخر
                  if (post.status == 'closed') {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Deal agreed',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }

                  // تحقق إذا Worker أرسل offer مسبقاً
                  final myEmail = auth.user?.email ?? '';
                  PostOffer? myOffer;
                  for (final o in post.offers) {
                    if (o.workerEmail == myEmail) { myOffer = o; break; }
                  }
                  final sent    = myOffer != null;
                  final canEdit = myOffer?.status == 'pending';

                  return ElevatedButton.icon(
                    onPressed: auth.isLoggedIn
                        ? () => _showOfferForm(context, post,
                            existingOffer: canEdit ? myOffer : null)
                        : null,
                    icon: Icon(
                      sent ? (canEdit ? Icons.edit : Icons.check) : Icons.send,
                      size: 14,
                    ),
                    label: Text(
                      sent
                          ? (canEdit ? 'Edit Offer' : 'Offer Sent')
                          : 'Send Offer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: sent
                          ? (canEdit ? Colors.orange : Colors.grey)
                          : null,
                    ),
                  );
                })),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        recipientEmail: post.creatorEmail,
                        recipientUsername: post.creatorUsername,
                      ),
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.brown,
                    child: Icon(Icons.chat, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOfferForm(BuildContext context, Post post,
      {PostOffer? existingOffer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OfferForm(post: post, existingOffer: existingOffer),
    );
  }
}

// ─────────────────────────────────────────────
class _OfferForm extends StatefulWidget {
  final Post post;
  final PostOffer? existingOffer; // إذا موجود = تعديل، وإلا = إرسال جديد
  const _OfferForm({required this.post, this.existingOffer});

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _contentCtrl = TextEditingController();
  final _priceCtrl   = TextEditingController();
  bool _sending = false;

  bool get _isEdit => widget.existingOffer != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _contentCtrl.text = widget.existingOffer!.content;
      _priceCtrl.text   = widget.existingOffer!.price.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceCtrl.text);
    if (_contentCtrl.text.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content and valid price are required')));
      return;
    }
    setState(() => _sending = true);
    try {
      if (_isEdit) {
        await ApiService.updateOffer(
          widget.post.id, widget.existingOffer!.id,
          content: _contentCtrl.text, price: price,
        );
      } else {
        await ApiService.addOffer(widget.post.id, _contentCtrl.text, price);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Offer updated!' : 'Offer sent successfully!'),
        ));
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
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
          Text('Send Offer for "${widget.post.title}"',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe your offer *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Your Price (\$) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sending ? null : _submit,
            icon: Icon(_isEdit ? Icons.edit : Icons.send),
            label: _sending
                ? const Text('Saving...')
                : Text(_isEdit ? 'Update Offer' : 'Send Offer'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
