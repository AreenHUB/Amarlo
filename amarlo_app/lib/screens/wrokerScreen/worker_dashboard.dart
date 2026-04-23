// lib/screens/wrokerScreen/worker_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/dialogs.dart';
import '../../core/theme.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../services/http_client.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import '../../widgets/user_avatar.dart';

class WorkerDashboard extends StatefulWidget {
  /// callback يُنادى بعد إضافة / تعديل / حذف خدمة
  /// يُحدِّث Home screen فوراً
  final VoidCallback? onServicesChanged;

  const WorkerDashboard({super.key, this.onServicesChanged});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  List<Service> _services = [];
  bool _loading = true;
  bool _showForm = false;
  String? _error;

  // Form
  Service?   _editing;
  final _nameCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  String? _selectedCategory;
  File?   _imageFile;
  bool    _saving     = false;
  bool    _imageError = false; // إذا حاول الإرسال بدون صورة

  static const _categories = [
    'Programming and Tech', 'Graphic Design', 'Teaching',
    'Business Services', 'Writing and Translation', 'Digital Marketing',
    'Video and Animation', 'Animals care', 'Cleaning services',
    'Customer Service', 'Sales and Marketing', 'Other',
  ];

  @override
  void initState() { super.initState(); _fetch(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _locationCtrl.dispose();
    _priceCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final services = await ApiService.getMyServices();
      if (mounted) setState(() { _services = services; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _startAdd() {
    _editing = null;
    _nameCtrl.clear(); _locationCtrl.clear();
    _priceCtrl.clear(); _descCtrl.clear();
    _selectedCategory = null; _imageFile = null; _imageError = false;
    setState(() => _showForm = true);
  }

  void _startEdit(Service s) {
    _editing = s;
    _nameCtrl.text     = s.name;
    _locationCtrl.text = s.location;
    _priceCtrl.text    = s.price.toStringAsFixed(0);
    _descCtrl.text     = s.description;
    _selectedCategory  = s.category;
    _imageFile         = null; _imageError = false;
    setState(() => _showForm = true);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked != null) {
      setState(() { _imageFile = File(picked.path); _imageError = false; });
    }
  }

  Future<void> _save() async {
    // Validation
    if (_nameCtrl.text.trim().isEmpty) {
      showError(context, 'Service name is required'); return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      showError(context, 'Enter a valid price'); return;
    }
    if (_descCtrl.text.trim().length < 10) {
      showError(context, 'Description must be at least 10 characters'); return;
    }
    // صورة إجبارية عند الإضافة الجديدة
    if (_editing == null && _imageFile == null) {
      setState(() => _imageError = true);
      showError(context, 'Service image is required'); return;
    }

    setState(() { _saving = true; _imageError = false; });

    try {
      if (_editing == null) {
        await ApiService.addService(
          name:        _nameCtrl.text.trim(),
          location:    _locationCtrl.text.trim(),
          price:       price,
          description: _descCtrl.text.trim(),
          category:    _selectedCategory,
          image:       _imageFile!,
        );
        if (mounted) showSuccess(context, 'Service added successfully!');
      } else {
        await ApiService.updateService(
          _editing!.id,
          name:        _nameCtrl.text.trim(),
          location:    _locationCtrl.text.trim(),
          price:       price,
          description: _descCtrl.text.trim(),
          category:    _selectedCategory,
          image:       _imageFile,
        );
        if (mounted) showSuccess(context, 'Service updated!');
      }

      setState(() => _showForm = false);
      await _fetch();

      // ← إشعار Home screen بالتحديث الفوري
      widget.onServicesChanged?.call();
    } on ApiException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (e) {
      if (mounted) showError(context, 'Unexpected error. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Service s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Service',
      message: 'Delete "${s.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ApiService.deleteService(s.id);
      if (mounted) showSuccess(context, 'Service deleted');
      await _fetch();
      widget.onServicesChanged?.call();
    } on ApiException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          ListItemSkeleton(), ListItemSkeleton(), ListItemSkeleton(),
        ]),
      );
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _fetch);
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppTheme.primary,
      child: CustomScrollView(slivers: [
        // ── Add button ────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ElevatedButton.icon(
            onPressed: _showForm ? null : _startAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add New Service'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
        )),

        // ── Form ──────────────────────────────────────
        if (_showForm)
          SliverToBoxAdapter(child: _buildForm()),

        // ── Empty state ───────────────────────────────
        if (_services.isEmpty && !_showForm)
          SliverFillRemaining(child: EmptyState(
            title: 'No services yet',
            subtitle: 'Add your first service to start getting requests',
            icon: Icons.work_outline,
            actionLabel: 'Add Service',
            onAction: _startAdd,
          )),

        // ── Services list ─────────────────────────────
        if (_services.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ServiceTile(
                  service:  _services[i],
                  onEdit:   () => _startEdit(_services[i]),
                  onDelete: () => _delete(_services[i]),
                ),
                childCount: _services.length,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              _editing == null ? 'New Service' : 'Edit Service',
              style: AppTheme.h3,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _showForm = false),
            ),
          ]),
          const SizedBox(height: 12),
          _field(_nameCtrl, 'Service Name *'),
          _field(_locationCtrl, 'Location (city, country)'),
          _field(_priceCtrl, 'Price (USD) *', type: TextInputType.number),
          _field(_descCtrl, 'Description *', maxLines: 3),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            hint: const Text('Select Category'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _categories.map((c) =>
                DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
          const SizedBox(height: 12),

          // ── Image picker (إجبارية عند الإضافة) ──────
          Text(
            _editing == null
                ? 'Service Image * (required)'
                : 'Service Image (optional — leave empty to keep current)',
            style: TextStyle(
              fontSize: 13,
              color: _imageError ? AppTheme.error : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _imageError ? AppTheme.error : Colors.grey,
                  width: _imageError ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Image.file(_imageFile!, fit: BoxFit.cover))
                  : _editing?.imageUrl != null
                      ? Stack(fit: StackFit.expand, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            child: AppNetworkImage(imageUrl: _editing!.imageUrl, fit: BoxFit.cover),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text('Tap to change', style: TextStyle(color: Colors.white)),
                              ],
                            )),
                          ),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate, size: 36,
                              color: _imageError ? AppTheme.error : Colors.grey),
                          const SizedBox(height: 6),
                          Text(
                            _imageError ? 'Image is required!' : 'Tap to select image',
                            style: TextStyle(
                                color: _imageError ? AppTheme.error : Colors.grey),
                          ),
                        ]),
            ),
          ),

          const SizedBox(height: 16),
          LoadingButton(
            label: _editing == null ? 'Add Service' : 'Update Service',
            loading: _saving,
            onPressed: _save,
          ),
        ]),
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

// ── Service tile ──────────────────────────────────────────
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
        title: Text(service.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '\$${service.price.toStringAsFixed(0)} · ${service.location}'
          '${service.category != null ? '\n${service.category}' : ''}',
        ),
        isThreeLine: service.category != null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primary),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete, color: AppTheme.error),
              onPressed: onDelete),
        ]),
      ),
    );
  }
}
