// lib/screens/wrokerScreen/worker_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/user_avatar.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  List<Service> _services = [];
  bool _loading = true;
  bool _showForm = false;

  // Form
  Service? _editing;
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCategory;
  File? _imageFile;
  bool _saving = false;

  static const _categories = [
    'Programming and Tech','Graphic Design','Teaching',
    'Business Services','Writing and Translation','Digital Marketing',
    'Video and Animation','Animals care','Cleaning services',
    'Customer Service','Sales and Marketing','Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _locationCtrl.dispose();
    _priceCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final services = await ApiService.getWorkerServices();
      if (mounted) setState(() { _services = services; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAdd() {
    _editing = null;
    _nameCtrl.clear(); _locationCtrl.clear();
    _priceCtrl.clear(); _descCtrl.clear();
    _selectedCategory = null; _imageFile = null;
    setState(() => _showForm = true);
  }

  void _startEdit(Service s) {
    _editing = s;
    _nameCtrl.text = s.name;
    _locationCtrl.text = s.location;
    _priceCtrl.text = s.price.toString();
    _descCtrl.text = s.description;
    _selectedCategory = s.category;
    _imageFile = null;
    setState(() => _showForm = true);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      _snack('Name and price are required'); return;
    }
    setState(() => _saving = true);

    try {
      if (_editing == null) {
        await ApiService.addService(
          name: _nameCtrl.text,
          location: _locationCtrl.text,
          price: double.parse(_priceCtrl.text),
          description: _descCtrl.text,
          category: _selectedCategory,
          image: _imageFile,
        );
        _snack('Service added!');
      } else {
        await ApiService.updateService(_editing!.id,
          name: _nameCtrl.text,
          location: _locationCtrl.text,
          price: double.parse(_priceCtrl.text),
          description: _descCtrl.text,
          category: _selectedCategory,
          image: _imageFile,
        );
        _snack('Service updated!');
      }
      setState(() => _showForm = false);
      await _fetch();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Service s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "${s.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.deleteService(s.id);
      _snack('Deleted');
      await _fetch();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: CustomScrollView(
                slivers: [
                  // ── Add button ──────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _showForm ? null : _startAdd,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Service'),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48)),
                      ),
                    ),
                  ),

                  // ── Form ─────────────────────────────────
                  if (_showForm)
                    SliverToBoxAdapter(child: _buildForm()),

                  // ── Services list ─────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _services.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(child: Text('No services yet')))
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _ServiceTile(
                                service: _services[i],
                                onEdit: () => _startEdit(_services[i]),
                                onDelete: () => _delete(_services[i]),
                              ),
                              childCount: _services.length,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_editing == null ? 'New Service' : 'Edit Service',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showForm = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_nameCtrl, 'Service Name *'),
            _field(_locationCtrl, 'Location'),
            _field(_priceCtrl, 'Price *', type: TextInputType.number),
            _field(_descCtrl, 'Description', maxLines: 3),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Select Category'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 12),

            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_imageFile!, fit: BoxFit.cover,
                            width: double.infinity))
                    : const Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 36, color: Colors.grey),
                          Text('Tap to select image', style: TextStyle(color: Colors.grey)),
                        ],
                      )),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_editing == null ? 'Add Service' : 'Update Service'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? type, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}

class _ServiceTile extends StatelessWidget {
  final Service service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceTile({required this.service, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AppNetworkImage(imageUrl: service.imageUrl, width: 56, height: 56),
        ),
        title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '\$${service.price.toStringAsFixed(0)} · ${service.location}\n${service.category ?? ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.brown), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
