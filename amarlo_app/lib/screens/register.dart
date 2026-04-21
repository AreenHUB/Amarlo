// lib/screens/register.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/http_client.dart';

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
  final _otherSpecCtrl   = TextEditingController();

  String _gender   = 'Male';
  String _city     = 'Damascus';
  String _userType = 'Normal User';
  String? _speciality;
  File? _imageFile;
  bool _loading = false;
  bool _obscure = true;

  static const _cities = [
    'Damascus','Aleppo','As-Suwayda','Latakia',
    'Hama','Daraa','Tartus','Homs','Deir ez-Zor',
  ];

  static const _specialities = [
    'Programming and Tech','Graphic Design','Teaching',
    'Business Services','Writing and Translation','Digital Marketing',
    'Video and Animation','Animals care','Cleaning services',
    'Customer Service','Sales and Marketing','Other',
  ];

  @override
  void dispose() {
    for (final c in [_usernameCtrl,_emailCtrl,_passwordCtrl,
        _confirmPassCtrl,_numberCtrl,_otherSpecCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userType == 'Worker' && (_speciality == null)) {
      _snack('Please select a speciality');
      return;
    }

    setState(() => _loading = true);
    try {
      final spec = _speciality == 'Other' ? _otherSpecCtrl.text : _speciality;
      await ApiService.register(
        username:   _usernameCtrl.text.trim(),
        email:      _emailCtrl.text.trim(),
        password:   _passwordCtrl.text,
        number:     _numberCtrl.text.trim(),
        gender:     _gender,
        city:       _city,
        userType:   _userType,
        speciality: spec,
        image:      _imageFile,
      );
      if (!mounted) return;
      _snack('Registered successfully! Please log in.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text('Register',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        // Avatar picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                            child: _imageFile == null
                                ? const Icon(Icons.add_a_photo, size: 30)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _field(_usernameCtrl, 'Username', Icons.person_outline,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        _field(_emailCtrl, 'Email', Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) => !v!.contains('@') ? 'Invalid email' : null),
                        _field(_passwordCtrl, 'Password', Icons.lock_outline,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => v!.length < 6 ? 'Min 6 chars' : null),
                        _field(_confirmPassCtrl, 'Confirm Password', Icons.lock_outline,
                            obscure: true,
                            validator: (v) => v != _passwordCtrl.text ? 'Passwords don\'t match' : null),
                        _field(_numberCtrl, 'Phone Number', Icons.phone_outlined,
                            type: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Required' : null),

                        // Gender
                        const SizedBox(height: 8),
                        Row(children: [
                          const Text('Gender:', style: TextStyle(fontWeight: FontWeight.w500)),
                          _radio('Male'),
                          _radio('Female'),
                        ]),

                        // City
                        _dropdown<String>(
                          value: _city,
                          label: 'City',
                          items: _cities,
                          onChanged: (v) => setState(() => _city = v!),
                        ),

                        // User type
                        const SizedBox(height: 8),
                        Row(children: [
                          const Text('Type:', style: TextStyle(fontWeight: FontWeight.w500)),
                          _radioType('Normal User'),
                          _radioType('Worker'),
                        ]),

                        // Speciality (workers only)
                        if (_userType == 'Worker') ...[
                          _dropdown<String>(
                            value: _speciality,
                            label: 'Speciality',
                            items: _specialities,
                            onChanged: (v) => setState(() {
                              _speciality = v;
                              if (v != 'Other') _otherSpecCtrl.clear();
                            }),
                          ),
                          if (_speciality == 'Other')
                            _field(_otherSpecCtrl, 'Enter speciality', Icons.work_outline,
                                validator: (v) => v!.isEmpty ? 'Required' : null),
                        ],

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Create Account', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withOpacity(0.75),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _radio(String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Radio<String>(
          value: value, groupValue: _gender,
          onChanged: (v) => setState(() => _gender = v!),
        ),
        Text(value),
      ]);

  Widget _radioType(String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Radio<String>(
          value: value, groupValue: _userType,
          onChanged: (v) => setState(() {
            _userType = v!;
            if (v == 'Normal User') _speciality = null;
          }),
        ),
        Text(value),
      ]);

  Widget _dropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required void Function(T?) onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white.withOpacity(0.75),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      );
}
