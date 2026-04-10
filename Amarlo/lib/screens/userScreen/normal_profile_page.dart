import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NormalProfilePage extends StatefulWidget {
  final String userId;

  const NormalProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<NormalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _numberController = TextEditingController();
  TextEditingController _cityController = TextEditingController();
  TextEditingController _specialityController = TextEditingController();
  String? _base64Image;
  bool _isSpecialityVisible = false; // Manage visibility of Speciality field

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/users/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAccessToken()}',
        },
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        setState(() {
          _base64Image = userData['imageBase64'];
          _usernameController.text = userData['username'];
          _numberController.text = userData['number'];
          _cityController.text = userData['city'];
          _specialityController.text = userData['speciality'];
        });
      } else {
        print("Error loading profile: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
    }
  }

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'username': _usernameController.text,
        'number': _numberController.text,
        'city': _cityController.text,
        'speciality': _specialityController.text,
        'imageBase64': _base64Image,
      };

      final accessToken = await _getAccessToken();
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/normal_users/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        _loadUserProfile(); // Refresh profile after update
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${response.body}')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_type');
    await prefs.remove('email');
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _numberController.dispose();
    _cityController.dispose();
    _specialityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Profile Image
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _base64Image != null
                          ? MemoryImage(base64Decode(_base64Image!))
                          : const AssetImage('images/OIG4.jpg')
                              as ImageProvider,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Number
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // City
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your city';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Speciality (hidden based on state)
                if (_isSpecialityVisible)
                  TextFormField(
                    controller: _specialityController,
                    decoration: const InputDecoration(
                      labelText: 'Speciality (Optional)',
                    ),
                  ),
                const SizedBox(height: 32),
                // Update Button
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Update Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
