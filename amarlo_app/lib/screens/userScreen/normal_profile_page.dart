// lib/screens/userScreen/normal_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/user_avatar.dart';

class NormalProfilePage extends StatefulWidget {
  final String userId;
  const NormalProfilePage({super.key, required this.userId});

  @override
  State<NormalProfilePage> createState() => _NormalProfilePageState();
}

class _NormalProfilePageState extends State<NormalProfilePage> {
  final _usernameCtrl = TextEditingController();
  final _numberCtrl   = TextEditingController();
  final _cityCtrl     = TextEditingController();

  File? _newImage;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _numberCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final user = await ApiService.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _usernameCtrl.text = user.username;
          _numberCtrl.text   = user.number ?? '';
          _cityCtrl.text     = user.city ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateUser(
        userId: widget.userId,
        username: _usernameCtrl.text,
        number: _numberCtrl.text,
        city: _cityCtrl.text,
        image: _newImage,
      );
      context.read<AuthProvider>().updateUser(updated);
      setState(() => _newImage = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!')));
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Avatar ──────────────────────────────
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          _newImage != null
                              ? CircleAvatar(
                                  radius: 55,
                                  backgroundImage: FileImage(_newImage!))
                              : UserAvatar(
                                  imageUrl: auth.user?.imageUrl, radius: 55),
                          Positioned(
                            right: 0, bottom: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.brown,
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(auth.user?.email ?? '',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 28),

                    // ── Fields ──────────────────────────────
                    _field(_usernameCtrl, 'Username', Icons.person_outline),
                    _field(_numberCtrl, 'Phone Number', Icons.phone_outlined,
                        type: TextInputType.phone),
                    _field(_cityCtrl, 'City', Icons.location_city_outlined),
                    const SizedBox(height: 28),

                    // ── Save ────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: _saving
                          ? const Text('Saving...')
                          : const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
