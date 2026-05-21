// lib/screens/home.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dialogs.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/notification_service.dart';
import '../widgets/skeletons.dart';
import '../widgets/states.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'login.dart';
import 'register.dart';
import 'worker_profile_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Category metadata — icon + colour for known categories.
//  Unknown categories from the server still render with a fallback icon/colour.
// ─────────────────────────────────────────────────────────────────────────────
class _Cat {
  final String   key;
  final IconData icon;
  final Color    color;
  const _Cat(this.key, this.icon, this.color);
}

// Map for O(1) lookup — keys must exactly match what the backend stores in
// service.category (see seed_data.py CATEGORIES list).
const _kCatMeta = <String, _Cat>{
  'Programming and Tech':   _Cat('Programming and Tech',   Icons.code,                    Color(0xFF1565C0)),
  'Graphic Design':         _Cat('Graphic Design',         Icons.palette_outlined,        Color(0xFFE64A19)),
  'Writing and Translation':_Cat('Writing and Translation',Icons.edit_outlined,            Color(0xFF6A1B9A)),
  'Video and Animation':    _Cat('Video and Animation',    Icons.videocam_outlined,        Color(0xFF00838F)),
  'Music and Audio':        _Cat('Music and Audio',        Icons.music_note_outlined,      Color(0xFFF9A825)),
  'Digital Marketing':      _Cat('Digital Marketing',      Icons.campaign_outlined,        Color(0xFF2E7D32)),
  'Business':               _Cat('Business',               Icons.business_center_outlined, Color(0xFF37474F)),
  'Photography':            _Cat('Photography',            Icons.camera_alt_outlined,      Color(0xFFC62828)),
  'Finance':                _Cat('Finance',                Icons.account_balance_outlined, Color(0xFF283593)),
  'Education':              _Cat('Education',              Icons.school_outlined,          Color(0xFF558B2F)),
  // Extra aliases — in case workers use short names when adding services
  'Design':                 _Cat('Design',                 Icons.palette_outlined,        Color(0xFFE64A19)),
  'Development':            _Cat('Development',            Icons.code,                    Color(0xFF1565C0)),
  'Marketing':              _Cat('Marketing',              Icons.campaign_outlined,        Color(0xFF2E7D32)),
  'Writing':                _Cat('Writing',                Icons.edit_outlined,            Color(0xFF6A1B9A)),
  'Video':                  _Cat('Video',                  Icons.videocam_outlined,        Color(0xFF00838F)),
  'Music':                  _Cat('Music',                  Icons.music_note_outlined,      Color(0xFFF9A825)),
  'Translation':            _Cat('Translation',            Icons.translate,                Color(0xFF37474F)),
};

// ─────────────────────────────────────────────────────────────────────────────
//  HomePage
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  /// Called by NavigationBarPage after a worker adds/edits a service.
  void refresh() => _load();

  // ── Raw data from server ──────────────────────────────
  List<Service> _allServices       = [];
  List<String>  _serverCategories  = [];

  // ── Derived / cached — updated only when data changes ─
  List<Service> _filtered          = [];
  List<Service> _cachedTopWorkers  = [];
  int           _cachedWorkerCount = 0;
  int           _cachedCityCount   = 0;

  // ── Filter state ──────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String?     _selectedCategory;
  String?     _selectedCity;
  RangeValues _priceRange = const RangeValues(0, 10000);

  // ── Search debounce ───────────────────────────────────
  Timer? _searchDebounce;

  // ── UI state ──────────────────────────────────────────
  bool    _loading = true;
  String? _error;

  bool get _hasActiveFilters =>
      _selectedCategory != null ||
      _selectedCity     != null ||
      _priceRange.start > 0    ||
      _priceRange.end   < 10000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Data load ─────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getServices(size: 500),
        ApiService.getCategories(),
      ]);
      if (!mounted) return;

      final services   = (results[0] as Paged<Service>).items;
      final categories = results[1] as List<String>;

      // Compute all derived state once — no extra passes in build().
      final workerEmails = <String>{};
      final cities       = <String>{};
      for (final s in services) {
        workerEmails.add(s.workerEmail);
        cities.add(s.location);
      }

      setState(() {
        _allServices       = services;
        _serverCategories  = categories;
        _cachedWorkerCount = workerEmails.length;
        _cachedCityCount   = cities.length;
        _cachedTopWorkers  = _computeTopWorkers(services);
        _filtered          = _computeFilter(services);
        _loading           = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Filter — pure computation, no setState ────────────
  List<Service> _computeFilter(List<Service> source) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return source.where((s) {
      if (q.isNotEmpty) {
        final hit = s.name.toLowerCase().contains(q)
            || s.workerUsername.toLowerCase().contains(q)
            || (s.category?.toLowerCase().contains(q) ?? false)
            || s.description.toLowerCase().contains(q);
        if (!hit) return false;
      }
      if (_selectedCategory != null && s.category != _selectedCategory) return false;
      if (_selectedCity     != null && s.location != _selectedCity)     return false;
      if (s.price < _priceRange.start || s.price > _priceRange.end)    return false;
      return true;
    }).toList();
  }

  /// Top workers: unique by email, sorted by avg rating desc, capped at 6.
  List<Service> _computeTopWorkers(List<Service> source) {
    final seen   = <String>{};
    final sorted = List.of(source)..sort((a, b) => b.price.compareTo(a.price));
    final out    = <Service>[];
    for (final s in sorted) {
      if (seen.add(s.workerEmail)) out.add(s);
      if (out.length == 6) break;
    }
    return out;
  }

  void _applyFilters() {
    setState(() => _filtered = _computeFilter(_allServices));
  }

  // Debounced version used by the search TextField.
  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), _applyFilters);
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _selectedCategory = null;
      _selectedCity     = null;
      _priceRange       = const RangeValues(0, 10000);
      _filtered         = _computeFilter(_allServices);
    });
  }

  // ── Auth guard ────────────────────────────────────────
  void _goLogin()    => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  void _goRegister() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));

  Future<bool> _requireAuth() async {
    if (context.read<AuthProvider>().isLoggedIn) return true;
    await showAuthRequired(context, onLogin: _goLogin, onRegister: _goRegister);
    return false;
  }

  // ── Send request ──────────────────────────────────────
  Future<void> _sendRequest(Service service) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    final ok = await showConfirmDialog(
      context,
      title:        'Send Request',
      message:      'Request "${service.name}" from ${service.workerUsername}?',
      confirmLabel: 'Send',
    );
    if (!ok || !mounted) return;
    try {
      await ApiService.requestService(service.id);
      if (mounted) showSuccess(context, 'Request sent successfully!');
    } on ApiException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  // ── Filter sheet ──────────────────────────────────────
  void _showFilter() {
    final cities = <String>{ for (final s in _allServices) s.location }.toList()..sort();
    final cats   = _serverCategories.isNotEmpty
        ? _serverCategories
        : (<String>{ for (final s in _allServices) if (s.category != null) s.category! }.toList()..sort());

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _FilterSheet(
        cities:           cities,
        categories:       cats,
        selectedCity:     _selectedCity,
        selectedCategory: _selectedCategory,
        priceRange:       _priceRange,
        onApply: (city, cat, range) {
          setState(() {
            _selectedCity     = city;
            _selectedCategory = cat;
            _priceRange       = range;
            _filtered         = _computeFilter(_allServices);
          });
        },
        onClear: _clearFilters,
      ),
    );
  }

  void _openWorker(String email) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => WorkerProfileViewPage(email: email)),
  );

  // ─────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: _error != null
          ? CustomScrollView(slivers: [
              _sliverAppBar(auth),
              SliverFillRemaining(child: ErrorState(message: _error!, onRetry: _load)),
            ])
          : RefreshIndicator(
              color:     AppTheme.primary,
              onRefresh: _load,
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  _sliverAppBar(auth),
                  _sliverHeroStrip(auth),
                  _sliverSearchRow(),
                  if (!_loading && _cachedTopWorkers.isNotEmpty) _sliverTopWorkers(),
                  _sliverCategoryPills(),
                  if (_loading)
                    _sliverSkeletonGrid()
                  else if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        title:       'No services found',
                        subtitle:    'Try different filters or search terms',
                        icon:        Icons.search_off_rounded,
                        actionLabel: 'Clear Filters',
                        onAction:    _clearFilters,
                      ),
                    )
                  else ...[
                    _sliverGridHeader(),
                    _sliverServiceGrid(),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────
  Widget _sliverAppBar(AuthProvider auth) {
    return SliverAppBar(
      pinned:                    true,
      elevation:                 0,
      backgroundColor:           AppTheme.primary,
      automaticallyImplyLeading: false,
      title: Row(children: [
        const Icon(Icons.handshake, size: 22, color: Colors.white),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Amarlo',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const Text('Freelance Marketplace',
              style: TextStyle(color: Color(0xFFBCAAA4), fontSize: 10, height: 1)),
        ]),
      ]),
      actions: [
        if (auth.isLoggedIn) ...[
          ListenableBuilder(
            listenable: NotificationManager.instance,
            builder: (_, __) {
              final count = NotificationManager.instance.unreadMessageCount;
              return Stack(alignment: Alignment.center, children: [
                IconButton(
                  icon:    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  tooltip: 'Messages',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => _ConversationList(onBack: () {}))),
                ),
                if (count > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding:     const EdgeInsets.all(3),
                        decoration:  const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$count',
                            style:     const TextStyle(color: Colors.white, fontSize: 9),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ]);
            },
          ),
          const NotificationIconButton(),
        ],
      ],
    );
  }

  // ─── Hero strip ───────────────────────────────────────
  Widget _sliverHeroStrip(AuthProvider auth) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [Color(0xFF5D4037), Color(0xFF8D6E63)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (auth.isLoggedIn && auth.user != null) ...[
            Row(children: [
              UserAvatar(imageUrl: auth.user!.imageUrl, radius: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back 👋',
                    style: TextStyle(color: Color(0xFFBCAAA4), fontSize: 11)),
                Text(auth.user!.username,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ]),
            const SizedBox(height: 16),
          ] else ...[
            const Text('Find your perfect',
                style: TextStyle(color: Color(0xFFBCAAA4), fontSize: 13)),
            const Text('Freelance Talent',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
          ],
          // Stats row — uses cached counts, no recompute on every build
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? Container(
                    key:    const ValueKey('loading'),
                    height: 54,
                    decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14)),
                  )
                : Container(
                    key:     const ValueKey('stats'),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      _StatChip('${_allServices.length}', 'Services'),
                      _vDivider(),
                      _StatChip('$_cachedWorkerCount', 'Workers'),
                      _vDivider(),
                      _StatChip('$_cachedCityCount', 'Cities'),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withValues(alpha: 0.25),
      );

  // ─── Search row ───────────────────────────────────────
  Widget _sliverSearchRow() {
    return SliverToBoxAdapter(
      child: Container(
        color:   AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller:      _searchCtrl,
              onChanged:       _onSearchChanged,   // debounced
              style:           const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:  'Search services, skills, workers...',
                hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9E9E9E)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon:      const Icon(Icons.close, size: 18),
                        onPressed: () { _searchDebounce?.cancel(); _searchCtrl.clear(); _applyFilters(); },
                      )
                    : null,
                filled:         true,
                fillColor:      Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense:        true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide:   BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color:     _hasActiveFilters ? AppTheme.accent : Colors.white,
                shape:     BoxShape.circle,
                boxShadow: AppTheme.shadowSm,
              ),
              child: Icon(Icons.tune,
                  color: _hasActiveFilters ? Colors.white : AppTheme.primary,
                  size:  22),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Top Workers row ──────────────────────────────────
  Widget _sliverTopWorkers() {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: AppTheme.accent, size: 18),
            const SizedBox(width: 6),
            const Text('Top Workers',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                _searchDebounce?.cancel();
                _searchCtrl.clear();
                setState(() {
                  _selectedCategory = null;
                  _filtered         = _computeFilter(_allServices);
                });
              },
              child: const Text('See all',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection:  Axis.horizontal,
            padding:          const EdgeInsets.symmetric(horizontal: 16),
            itemCount:        _cachedTopWorkers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final s = _cachedTopWorkers[i];
              return _TopWorkerChip(
                service: s,
                onTap:   () => _openWorker(s.workerEmail),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ]),
    );
  }

  // ─── Category pills ───────────────────────────────────
  Widget _sliverCategoryPills() {
    final displayCats = _serverCategories.isNotEmpty
        ? _serverCategories
        : (<String>{ for (final s in _allServices) if (s.category != null) s.category! }.toList()..sort());

    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text('Browse by Category',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
        ),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CatPill(
                label:      'All',
                icon:       Icons.apps_rounded,
                color:      AppTheme.primary,
                isSelected: _selectedCategory == null,
                onTap: () => setState(() {
                  _selectedCategory = null;
                  _filtered         = _computeFilter(_allServices);
                }),
              ),
              const SizedBox(width: 10),
              for (final catKey in displayCats) ...[
                _CatPill(
                  label:      catKey,
                  icon:       _kCatMeta[catKey]?.icon  ?? Icons.label_outline,
                  color:      _kCatMeta[catKey]?.color ?? AppTheme.primaryLight,
                  isSelected: _selectedCategory == catKey,
                  onTap: () => setState(() {
                    _selectedCategory =
                        _selectedCategory == catKey ? null : catKey;
                    _filtered = _computeFilter(_allServices);
                  }),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ]),
    );
  }

  // ─── Grid header ──────────────────────────────────────
  Widget _sliverGridHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text(_selectedCategory ?? 'All Services',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text('${_filtered.length}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _clearFilters,
              child: const Text('Clear',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w500)),
            ),
        ]),
      ),
    );
  }

  // ─── 2-column grid ────────────────────────────────────
  Widget _sliverServiceGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final s = _filtered[i];
            return _ServiceCard(
              key:       ValueKey(s.id),   // stable key — avoids unnecessary rebuilds
              service:   s,
              onTap:     () => _openWorker(s.workerEmail),
              onRequest: () => _sendRequest(s),
            );
          },
          childCount:              _filtered.length,
          addRepaintBoundaries:    true,
          addAutomaticKeepAlives:  false,  // cards are cheap to rebuild; don't keep alive off-screen
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          mainAxisSpacing:  10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  // ─── Skeleton grid ────────────────────────────────────
  Widget _sliverSkeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => const _ServiceCardSkeleton(),
          childCount:             6,
          addAutomaticKeepAlives: false,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          mainAxisSpacing:  10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stat chip
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFFBCAAA4), fontSize: 10)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top Worker chip
// ─────────────────────────────────────────────────────────────────────────────
class _TopWorkerChip extends StatelessWidget {
  final Service      service;
  final VoidCallback onTap;
  const _TopWorkerChip({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: UserAvatar(imageUrl: service.imageUrl, radius: 26),
          ),
          const SizedBox(height: 5),
          Text(
            service.workerUsername.split(' ').first,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
          ),
          Text(service.category ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Category pill
// ─────────────────────────────────────────────────────────────────────────────
class _CatPill extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final Color      color;
  final bool       isSelected;
  final VoidCallback onTap;
  const _CatPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:        isSelected ? color : color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [BoxShadow(
                      color:      color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset:     const Offset(0, 3))]
                  : null,
            ),
            child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize:   10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:      isSelected ? color : const Color(0xFF757575))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service Card — const-friendly, stable key passed from parent
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final Service      service;
  final VoidCallback onTap;
  final VoidCallback onRequest;
  const _ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = service.deliveryType != 'in_person';
    final cat      = service.category;

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    AppTheme.shadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image ──────────────────────────────────
            Stack(children: [
              RepaintBoundary(
                child: AppNetworkImage(imageUrl: service.imageUrl, height: 118, width: double.infinity),
              ),
              Positioned(
                bottom: 8, left: 8,
                child: _Chip(
                  label: isOnline ? 'Online' : 'In-Person',
                  icon:  isOnline ? Icons.language : Icons.place_outlined,
                  color: isOnline ? AppTheme.info   : AppTheme.success,
                ),
              ),
              if (cat != null)
                Positioned(
                  top: 8, right: 8,
                  child: _Chip(label: cat, color: AppTheme.primary),
                ),
            ]),

            // ── Body ───────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment:  CrossAxisAlignment.start,
                  mainAxisAlignment:   MainAxisAlignment.spaceBetween,
                  children: [
                    // Worker
                    Row(children: [
                      CircleAvatar(
                        radius:          10,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          service.workerUsername.isNotEmpty
                              ? service.workerUsername[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(service.workerUsername,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    // Name
                    Text(service.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFF212121), height: 1.3)),
                    const SizedBox(height: 4),
                    // Price
                    Text('\$${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    const SizedBox(height: 6),
                    // Request button
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding:         EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Request'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Small reusable overlay chip used inside the service card image
class _Chip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: icon != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 10, color: Colors.white),
              const SizedBox(width: 3),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
            ])
          : Text(label,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service Card Skeleton
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceCardSkeleton extends StatelessWidget {
  const _ServiceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow:    AppTheme.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          skeletonBox(height: 118, radius: 0),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              skeletonBox(height: 11, width: 80),
              const SizedBox(height: 6),
              skeletonBox(height: 13),
              const SizedBox(height: 4),
              skeletonBox(height: 13, width: 100),
              const SizedBox(height: 8),
              skeletonBox(height: 16, width: 50),
              const SizedBox(height: 8),
              skeletonBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<String> cities;
  final List<String> categories;
  final String?      selectedCity;
  final String?      selectedCategory;
  final RangeValues  priceRange;
  final void Function(String?, String?, RangeValues) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.cities,
    required this.categories,
    required this.selectedCity,
    required this.selectedCategory,
    required this.priceRange,
    required this.onApply,
    required this.onClear,
  });

  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String?     _city;
  late String?     _category;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _city     = widget.selectedCity;
    _category = widget.selectedCategory;
    _range    = widget.priceRange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20,
          24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Filter Services',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          initialValue: _city,
          decoration: const InputDecoration(
            labelText:  'City / Location',
            prefixIcon: Icon(Icons.location_on_outlined),
            border:     OutlineInputBorder(),
          ),
          hint:      const Text('All cities'),
          items:     [null, ...widget.cities]
              .map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'All cities')))
              .toList(),
          onChanged: (v) => setState(() => _city = v),
        ),
        const SizedBox(height: 14),

        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText:  'Category',
            prefixIcon: Icon(Icons.category_outlined),
            border:     OutlineInputBorder(),
          ),
          hint:      const Text('All categories'),
          items:     [null, ...widget.categories]
              .map((c) => DropdownMenuItem(value: c, child: Text(c ?? 'All categories')))
              .toList(),
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 14),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Price Range',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('\$${_range.start.round()} – \$${_range.end.round()}',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ]),
        RangeSlider(
          values:      _range,
          min:         0,
          max:         10000,
          divisions:   100,
          activeColor: AppTheme.primary,
          onChanged:   (v) => setState(() => _range = v),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () { widget.onClear(); Navigator.pop(context); },
            child: const Text('Clear All'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () { widget.onApply(_city, _category, _range); Navigator.pop(context); },
            child: const Text('Apply'),
          )),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Conversation list
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationList extends StatefulWidget {
  final VoidCallback onBack;
  const _ConversationList({required this.onBack});
  @override State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  List<Conversation> _convs  = [];
  bool               _loading = true;
  String?            _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) { if (mounted) setState(() => _loading = false); return; }
      final convs = await ApiService.getConversations(auth.user!.email);
      if (mounted) setState(() { _convs = convs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title:   const Text('Messages'),
      leading: IconButton(
        icon:      const Icon(Icons.arrow_back),
        onPressed: () { widget.onBack(); Navigator.pop(context); },
      ),
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? ErrorState(message: _error!, onRetry: _fetch)
            : _convs.isEmpty
                ? const EmptyState(
                    title:    'No conversations yet',
                    subtitle: 'Start chatting from a worker profile',
                    icon:     Icons.chat_bubble_outline)
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      itemCount:        _convs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) {
                        final c = _convs[i];
                        return ListTile(
                          leading:  UserAvatar(imageUrl: c.otherUserImageUrl),
                          title:    Text(c.otherUsername,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(c.lastMessage,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: c.unreadCount > 0
                              ? Container(
                                  padding:    const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                      color: AppTheme.accent, shape: BoxShape.circle),
                                  child: Text('${c.unreadCount}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11,
                                          fontWeight: FontWeight.bold)))
                              : null,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              recipientEmail:    c.otherEmail,
                              recipientUsername: c.otherUsername,
                              recipientImageUrl: c.otherUserImageUrl,
                            ),
                          )).then((_) => _fetch()),
                        );
                      },
                    ),
                  ),
  );
}
