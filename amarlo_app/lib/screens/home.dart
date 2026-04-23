// lib/screens/home.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

import '../core/dialogs.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../widgets/skeletons.dart';
import '../widgets/states.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'worker_profile_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  /// يُستدعى من navigation_bar بعد إضافة/تعديل خدمة
  void refresh() => _load();

  List<Service> _services = [];
  Map<String, List<Service>> _grouped = {};
  List<Service> _filtered = [];
  List<String> _categories = [];
  List<Conversation> _conversations = [];
  int _unreadCount = 0;

  String _search = '';
  String? _selectedCity;
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 10000);

  NotificationWebSocket? _notifWs;
  bool _loading = true;
  String? _error;

  // cities are now searched dynamically

  @override
  void initState() {
    super.initState();
    _load();
    // تسجيل Context للتنقل من Toast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationManager.instance.setNavContext(context);
    });
  }

  @override
  void dispose() { _notifWs?.disconnect(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Future.wait([_fetchServices(), _fetchCategories()]);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && auth.user != null) {
        _fetchConversations();
        _connectNotifications(auth.token!, auth.user!.email);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _connectNotifications(String token, String email) {
    _notifWs?.disconnect();
    _notifWs = NotificationWebSocket(
      userEmail: email, token: token,
      onUnreadCount: (c) { if (mounted) setState(() => _unreadCount = c); },
    )..connect();
  }

  Future<void> _fetchServices() async {
    final paged = await ApiService.getServices(size: 100);
    if (!mounted) return;
    setState(() {
      _services = paged.items;
      _grouped = { for (final s in _services)
        (s.category ?? 'Other'): [...(_grouped[s.category ?? 'Other'] ?? []), s]
      };
      // Re-build grouped correctly
      final map = <String, List<Service>>{};
      for (final s in _services) { map.putIfAbsent(s.category ?? 'Other', () => []).add(s); }
      _grouped = map;
      _applyFilters();
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await ApiService.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _fetchConversations() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final convs = await ApiService.getConversations(auth.user!.email);
      if (mounted) setState(() => _conversations = convs);
    } catch (_) {}
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _services.where((s) {
        final ms = q.isEmpty || s.name.toLowerCase().contains(q)
            || s.workerUsername.toLowerCase().contains(q)
            || (s.category?.toLowerCase().contains(q) ?? false);
        final mc = _selectedCity == null || s.location == _selectedCity;
        final mp = s.price >= _priceRange.start && s.price <= _priceRange.end;
        final mk = _selectedCategory == null || s.category == _selectedCategory;
        return ms && mc && mp && mk;
      }).toList();
    });
  }

  Future<void> _sendRequest(Service service) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) { showInfo(context, 'Please login to send a request'); return; }

    final ok = await showConfirmDialog(context,
      title: 'Send Request',
      message: 'Request "${service.name}" from ${service.workerUsername}?',
      confirmLabel: 'Send',
    );
    if (!ok) return;
    try {
      await ApiService.requestService(service.id);
      if (mounted) showSuccess(context, 'Request sent successfully!');
    } on ApiException catch (e) { if (mounted) showError(context, e.message); }
  }

  void _showFilter() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg))),
    builder: (_) => _FilterSheet(
      categories: _categories,
      selectedCity: _selectedCity, selectedCategory: _selectedCategory,
      priceRange: _priceRange,
      onApply: (city, cat, range) {
        setState(() { _selectedCity = city; _selectedCategory = cat; _priceRange = range; });
        _applyFilters();
      },
      onClear: () {
        setState(() {
          _selectedCity = null; _selectedCategory = null;
          _priceRange = const RangeValues(0, 10000); _search = '';
        });
        _applyFilters();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.handshake, size: 22),
          const SizedBox(width: 8),
          const Text('Amarlo'),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: badges.Badge(
                  showBadge: _unreadCount > 0,
                  badgeContent: Text('$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                  badgeStyle: const badges.BadgeStyle(
                      badgeColor: AppTheme.accent, padding: EdgeInsets.all(4)),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _ConversationList(
                      onBack: _fetchConversations,
                      initial: _conversations),
                )).then((_) => _fetchConversations()),
              ),
            ),
        ],
      ),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : AppRefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                // ── Top section ─────────────────────────────
                SliverToBoxAdapter(child: Column(children: [
                  // Welcome
                  if (auth.isLoggedIn && auth.user != null)
                    FadeSlideIn(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: AppTheme.shadowSm,
                        ),
                        child: Row(children: [
                          UserAvatar(imageUrl: auth.user!.imageUrl, radius: 24),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Welcome back 👋', style: AppTheme.caption),
                            Text(auth.user!.username, style: AppTheme.h3),
                          ]),
                        ]),
                      ),
                    ),

                  // Hero
                  const SizedBox(height: 16),
                  _buildHero(),

                  // Carousel
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader('Featured'),
                  ),
                  CarouselSlider(
                    items: const [
                      _CarouselCard('Web Development', 'images/IMGtwo.jpg'),
                      _CarouselCard('Graphic Design', 'images/IMGthree.jpg'),
                      _CarouselCard('Digital Marketing', 'images/OIG4.jpg'),
                      _CarouselCard('Content Writing', 'images/IMGone.jpg'),
                    ],
                    options: CarouselOptions(
                      height: 160, viewportFraction: 0.82,
                      enlargeCenterPage: true, autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 4),
                    ),
                  ),
                  const SizedBox(height: 20),
                ])),

                // ── Loading skeletons ────────────────────────
                if (_loading)
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionHeader('Loading services...'),
                      SizedBox(
                        height: 270,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, __) => const ServiceCardSkeleton(),
                        ),
                      ),
                    ]),
                  )),

                // ── Empty state ──────────────────────────────
                if (!_loading && _filtered.isEmpty)
                  SliverFillRemaining(child: EmptyState(
                    title: 'No services found',
                    subtitle: 'Try adjusting your search or filters',
                    icon: Icons.search_off_rounded,
                    actionLabel: 'Clear Filters',
                    onAction: () {
                      setState(() {
                        _search = ''; _selectedCity = null;
                        _selectedCategory = null;
                        _priceRange = const RangeValues(0, 10000);
                      });
                      _applyFilters();
                    },
                  )),

                // ── Services ─────────────────────────────────
                if (!_loading && _filtered.isNotEmpty)
                  SliverToBoxAdapter(child: _buildSections()),
              ]),
            ),
    );
  }

  Widget _buildHero() {
    return Stack(children: [
      Image.asset('images/IMGone.jpg',
          height: 220, width: double.infinity, fit: BoxFit.cover),
      Container(height: 220, decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black26, Colors.black.withValues(alpha: 0.7)]),
      )),
      Positioned.fill(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('Find Your Perfect\nFreelance Talent', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              onChanged: (v) { _search = v; _applyFilters(); },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search services, skills...',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
            )),
            const SizedBox(width: 8),
            InkWell(onTap: _showFilter,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.tune, color: AppTheme.primary, size: 22),
              )),
          ]),
        ]),
      )),
    ]);
  }

  Widget _buildSections() {
    final sections = <Widget>[];
    var delay = 0;
    _grouped.forEach((cat, all) {
      final visible = all.where((s) => _filtered.contains(s)).toList();
      if (visible.isEmpty) return;
      sections.add(FadeSlideIn(
        delay: Duration(milliseconds: delay),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(cat),
            SizedBox(height: 270, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ServiceCard(
                service: visible[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WorkerProfileViewPage(email: visible[i].workerEmail))),
                onRequest: () => _sendRequest(visible[i]),
              ),
            )),
          ]),
        ),
      ));
      delay += 80;
    });
    return Column(children: sections);
  }
}

// ── Service Card ─────────────────────────────
class _ServiceCard extends StatelessWidget {
  final Service service;
  final VoidCallback onTap;
  final VoidCallback onRequest;
  const _ServiceCard({required this.service, required this.onTap, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 185,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppNetworkImage(imageUrl: service.imageUrl, height: 120, width: 185),
          Padding(padding: const EdgeInsets.all(10), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text('by ${service.workerUsername}', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(color: AppTheme.info)),
              const SizedBox(height: 6),
              Text('\$${service.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 15, color: AppTheme.primary)),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 12)),
                child: const Text('Request'),
              )),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Carousel Card ─────────────────────────────
class _CarouselCard extends StatelessWidget {
  final String title;
  final String asset;
  const _CarouselCard(this.title, this.asset);
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    child: Stack(fit: StackFit.expand, children: [
      Image.asset(asset, fit: BoxFit.cover),
      Container(color: Colors.black38),
      Center(child: Text(title, style: const TextStyle(color: Colors.white,
          fontSize: 18, fontWeight: FontWeight.bold))),
    ]),
  );
}

// ── Filter sheet ──────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<String> categories;
  final String? selectedCity, selectedCategory;
  final RangeValues priceRange;
  final void Function(String?, String?, RangeValues) onApply;
  final VoidCallback onClear;
  const _FilterSheet({required this.categories,
    required this.selectedCity, required this.selectedCategory,
    required this.priceRange, required this.onApply, required this.onClear});
  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _city; late String? _category; late RangeValues _range;
  @override void initState() {
    super.initState();
    _city = widget.selectedCity; _category = widget.selectedCategory;
    _range = widget.priceRange;
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      const Text('Filter Services',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      TextFormField(
        initialValue: _city,
        decoration: const InputDecoration(
          labelText: 'City or Location',
          hintText: 'e.g. Damascus, London...',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        onChanged: (v) => _city = v.trim().isEmpty ? null : v.trim(),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _category, decoration: const InputDecoration(labelText: 'Category'),
        hint: const Text('All categories'),
        items: [null, ...widget.categories]
            .map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'All categories'))).toList(),
        onChanged: (v) => setState(() => _category = v),
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Price Range', style: AppTheme.body.copyWith(fontWeight: FontWeight.w500)),
        Text('\$${_range.start.round()} – \$${_range.end.round()}',
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
      ]),
      RangeSlider(values: _range, min: 0, max: 10000, divisions: 100,
        activeColor: AppTheme.primary,
        onChanged: (v) => setState(() => _range = v)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () { widget.onClear(); Navigator.pop(context); },
          child: const Text('Clear All'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () { widget.onApply(_city, _category, _range); Navigator.pop(context); },
          child: const Text('Apply'))),
      ]),
    ]),
  );
}

// ── Conversation List — StatefulWidget يُحمِّل البيانات بنفسه ──
class _ConversationList extends StatefulWidget {
  final VoidCallback onBack;
  const _ConversationList({required this.onBack, List<Conversation>? initial})
      : _initial = initial;
  final List<Conversation>? _initial;
  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  List<Conversation> _convs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initial != null && widget._initial!.isNotEmpty) {
      _convs = widget._initial!;
      _loading = false;
    }
    _fetch(); // دائماً جلب أحدث البيانات
  }

  Future<void> _fetch() async {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final convs = await ApiService.getConversations(auth.user!.email);
      if (mounted) setState(() { _convs = convs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Messages'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () { widget.onBack(); Navigator.pop(context); },
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _convs.isEmpty
            ? const EmptyState(
                title: 'No conversations yet',
                subtitle: 'Start chatting from a worker profile',
                icon: Icons.chat_bubble_outline)
            : RefreshIndicator(
                onRefresh: _fetch,
                child: ListView.builder(
                  itemCount: _convs.length,
                  itemBuilder: (_, i) {
                    final c = _convs[i];
                    return ListTile(
                      leading: UserAvatar(imageUrl: c.otherUserImageUrl),
                      title: Text(c.otherUsername,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.lastMessage, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: c.unreadCount > 0
                          ? badges.Badge(
                              badgeContent: Text('${c.unreadCount}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                              child: const SizedBox.shrink())
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            recipientEmail:    c.otherEmail,
                            recipientUsername: c.otherUsername,
                            recipientImageUrl: c.otherUserImageUrl,
                          ),
                        ),
                      ).then((_) => _fetch()), // أعد التحميل عند العودة
                    );
                  },
                ),
              ),
  );
}
