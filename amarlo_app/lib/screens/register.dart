// lib/screens/register.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../services/http_client.dart';
import '../core/constants.dart';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _numberCtrl      = TextEditingController();
  final _cityCtrl        = TextEditingController();
  final _otherSpecCtrl   = TextEditingController();

  String  _gender   = 'Male';
  String  _userType = 'Normal User';
  String? _speciality;
  File?   _imageFile;
  bool    _loading  = false;
  bool    _obscure  = true;

  static const _specialities = [
    'Programming and Tech', 'Graphic Design', 'Teaching',
    'Business Services', 'Writing and Translation', 'Digital Marketing',
    'Video and Animation', 'Animals care', 'Cleaning services',
    'Customer Service', 'Sales and Marketing', 'Other',
  ];

  @override
  void dispose() {
    for (final c in [
      _usernameCtrl, _emailCtrl, _passwordCtrl,
      _confirmPassCtrl, _numberCtrl, _cityCtrl, _otherSpecCtrl,
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_userType == 'Worker' && _speciality == null) {
      _snack('Please select a speciality', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final spec = _speciality == 'Other'
          ? _otherSpecCtrl.text.trim()
          : _speciality;

      // استخدام multipart فقط إذا يوجد صورة، وإلا JSON عادي
      if (_imageFile != null) {
        await api.multipartPost(
          AppConstants.registerUrl,
          fieldName: 'image',
          file: _imageFile,
          fields: {
            'username': _usernameCtrl.text.trim(),
            'email':    _emailCtrl.text.trim().toLowerCase(),
            'password': _passwordCtrl.text,
            'number':   _numberCtrl.text.trim(),
            'gender':   _gender,
            'city':     _cityCtrl.text.trim(),
            'userType': _userType,
            if (spec != null) 'speciality': spec,
          },
          auth: false,
        );
      } else {
        // بدون صورة — multipart بحقول نصية فقط
        await api.multipartPost(
          AppConstants.registerUrl,
          fieldName: 'image',
          file: null,
          fields: {
            'username': _usernameCtrl.text.trim(),
            'email':    _emailCtrl.text.trim().toLowerCase(),
            'password': _passwordCtrl.text,
            'number':   _numberCtrl.text.trim(),
            'gender':   _gender,
            'city':     _cityCtrl.text.trim(),
            'userType': _userType,
            if (spec != null) 'speciality': spec,
          },
          auth: false,
        );
      }

      if (!mounted) return;
      // Navigate to LoginPage — pushReplacement works whether this screen
      // was a nav tab (nothing to pop) or pushed via Navigator.push.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(successMessage: 'Account created! Please log in.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, isError: true);
    } catch (e) {
      if (mounted) _snack('Connection error. Is the server running?', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(children: [
              // ── Avatar ───────────────────────────────
              GestureDetector(
                onTap: _pickImage,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                            Icon(Icons.add_a_photo, size: 26, color: AppTheme.primary),
                            SizedBox(height: 4),
                            Text('Photo', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                          ])
                        : null,
                  ),
                  if (_imageFile != null)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 13),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              const Text('Optional photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),

              // ── Fields ───────────────────────────────
              _field(_usernameCtrl, 'Username', Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 2) return 'Min 2 characters';
                    return null;
                  }),
              _field(_emailCtrl, 'Email', Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
                    return null;
                  }),
              _field(_passwordCtrl, 'Password', Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null),
              _field(_confirmPassCtrl, 'Confirm Password', Icons.lock_outline,
                  obscure: true,
                  validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null),
              _field(_numberCtrl, 'Phone Number', Icons.phone_outlined,
                  type: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              _field(_cityCtrl, 'City (optional)', Icons.location_city_outlined),

              // ── Gender ───────────────────────────────
              const SizedBox(height: 8),
              _label('Gender'),
              Row(children: [_radio('Male'), const SizedBox(width: 8), _radio('Female')]),
              const SizedBox(height: 12),

              // ── Account type ─────────────────────────
              _label('Account Type'),
              Row(children: [_radioType('Normal User'), const SizedBox(width: 8), _radioType('Worker')]),
              const SizedBox(height: 12),

              // ── Speciality ───────────────────────────
              if (_userType == 'Worker') ...[
                _label('Speciality *'),
                DropdownButtonFormField<String>(
                  value: _speciality,
                  hint: const Text('Select speciality'),
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: _specialities
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _speciality = v;
                    if (v != 'Other') _otherSpecCtrl.clear();
                  }),
                  validator: (v) =>
                      _userType == 'Worker' && v == null ? 'Select a speciality' : null,
                ),
                const SizedBox(height: 12),
                if (_speciality == 'Other')
                  _field(_otherSpecCtrl, 'Describe your speciality', Icons.work_outline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              ],

              const SizedBox(height: 24),

              // ── Submit ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Create Account', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          validator: validator,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  Widget _radio(String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Radio<String>(
            value: value,
            groupValue: _gender,
            onChanged: (v) => setState(() => _gender = v!)),
        Text(value),
      ]);

  Widget _radioType(String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Radio<String>(
            value: value,
            groupValue: _userType,
            onChanged: (v) => setState(() {
                  _userType = v!;
                  if (v == 'Normal User') _speciality = null;
                })),
        Text(value),
      ]);
}
