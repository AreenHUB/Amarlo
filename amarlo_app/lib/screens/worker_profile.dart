// lib/screens/worker_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../widgets/states.dart';
import '../widgets/user_avatar.dart';

class WorkerProfilePage extends StatefulWidget {
  final String workerId;

  const WorkerProfilePage({super.key, required this.workerId});

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  User? _worker;
  List<Service> _services = [];
  List<Review> _reviews = [];
  double _balance = 0;
  bool _loading = true;

  // Edit controllers
  final _introCtrl     = TextEditingController();
  final _fbCtrl        = TextEditingController();
  final _igCtrl        = TextEditingController();
  final _tgCtrl        = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _numberCtrl    = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _specCtrl      = TextEditingController();

  File? _newImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final worker = await ApiService.getUser(widget.workerId);
      final services = await ApiService.getWorkerServices();
      final reviews = await ApiService.getReviews(worker.email);

      setState(() {
        _worker = worker;
        _services = services;
        _reviews = reviews;
        _loading = false;
        _introCtrl.text = worker.introduction ?? '';
        _fbCtrl.text = worker.facebook ?? '';
        _igCtrl.text = worker.instagram ?? '';
        _tgCtrl.text = worker.telegram ?? '';
        _usernameCtrl.text = worker.username;
        _numberCtrl.text = worker.number ?? '';
        _cityCtrl.text = worker.city ?? '';
        _specCtrl.text = worker.speciality ?? '';
      });

      // Load balance
      try {
        final bal = await ApiService.getWorkerBalance(worker.email);
        if (mounted) setState(() => _balance = (bal['balance'] as num?)?.toDouble() ?? 0.0);
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    try {
      final updated = await ApiService.updateUser(
        widget.workerId,
        username: _usernameCtrl.text.trim(),
        number: _numberCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        speciality: _specCtrl.text.trim(),
        introduction: _introCtrl.text.trim(),
        facebook: _fbCtrl.text.trim(),
        instagram: _igCtrl.text.trim(),
        telegram: _tgCtrl.text.trim(),
        image: _newImage,
      );
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(updated);
      setState(() { _worker = updated; _newImage = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  void dispose() {
    for (final c in [_introCtrl,_fbCtrl,_igCtrl,_tgCtrl,
        _usernameCtrl,_numberCtrl,_cityCtrl,_specCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_worker?.username ?? 'Profile'),
        actions: [
          const NotificationIconButton(),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Balance ───────────────────────────────
              _card(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.brown, size: 28),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Wallet Balance',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('\$${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Avatar ────────────────────────────────
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    _newImage != null
                        ? CircleAvatar(radius: 55, backgroundImage: FileImage(_newImage!))
                        : UserAvatar(imageUrl: _worker?.imageUrl, radius: 55),
                    Positioned(
                      right: 0, bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.brown,
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Editable fields ───────────────────────
              _section('Personal Info', [
                _field(_usernameCtrl, 'Username', const Icon(Icons.person)),
                _field(_numberCtrl, 'Phone', const Icon(Icons.phone)),
                _field(_cityCtrl, 'City', const Icon(Icons.location_city)),
                _field(_specCtrl, 'Speciality', const Icon(Icons.work)),
              ]),

              _section('About Me', [
                TextField(
                  controller: _introCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write your introduction...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ]),

              _section('Social Media', [
                _field(_fbCtrl, 'Facebook', const FaIcon(FontAwesomeIcons.facebook, size: 18, color: Color(0xFF1877F2))),
                _field(_igCtrl, 'Instagram', const FaIcon(FontAwesomeIcons.instagram, size: 18, color: Color(0xFFE1306C))),
                _field(_tgCtrl, 'Telegram', const FaIcon(FontAwesomeIcons.telegram, size: 18, color: Color(0xFF0088CC))),
              ]),

              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 24),

              // ── Services ──────────────────────────────
              _section('My Services', [
                if (_services.isEmpty)
                  const Text('No services yet')
                else
                  ..._services.map((s) => ListTile(
                        leading: AppNetworkImage(imageUrl: s.imageUrl, width: 50, height: 50),
                        title: Text(s.name),
                        subtitle: Text('\$${s.price.toStringAsFixed(0)} · ${s.location}'),
                      )),
              ]),

              // ── Reviews ───────────────────────────────
              _buildReviews(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 20),
        ],
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _field(TextEditingController ctrl, String label, Widget icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  Widget _buildReviews() {
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            RatingBarIndicator(
              rating: avg,
              itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
              itemCount: 5, itemSize: 22,
            ),
            const SizedBox(width: 8),
            Text('${avg.toStringAsFixed(1)} (${_reviews.length})'),
          ]),
        ],
        const SizedBox(height: 12),
        ..._reviews.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(r.reviewerUsername),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RatingBarIndicator(
                    rating: r.rating.toDouble(),
                    itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5, itemSize: 16,
                  ),
                  if (r.comment != null) Text(r.comment!),
                ]),
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
