import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class WorkerDashboard extends StatefulWidget {
  @override
  _WorkerDashboardState createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController =
      TextEditingController(); // Controller for category input
  File? _selectedImage;
  String? _base64Image;
  List<Service> _services = [];
  String? _editingServiceId;
  bool _isEditing = false;
  String? _selectedCategory; // Selected category from dropdown
  List<String> _categories = [
    'Programming and Tech',
    'Graphic Design',
    'Teaching',
    'Business Services',
    'Writing and Translation',
    'Digital Marketing',
    'Video and Animation',
    'Animales care',
    'Cleaning services',
    'Customer Service',
    'Sales and Marketing',
    'Other', // Add "Other" option
  ];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/worker-services'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final services = (jsonDecode(response.body) as List)
          .map((data) => Service.fromJson(data))
          .toList();
      setState(() => _services = services);
    } else {
      _showSnackBar('Failed to fetch services');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImage = File(pickedFile.path);
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _addOrUpdateService() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      _showSnackBar('You must be logged in to add or update services');
      return;
    }

    final name = _nameController.text;
    final location = _locationController.text;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final description = _descriptionController.text;
    final category = _selectedCategory; // Get selected category

    final serviceData = {
      'name': name,
      'location': location,
      'price': price,
      'imageBase64': _base64Image,
      'description': description,
      'category': category,
    };

    if (_editingServiceId == null) {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/add-service'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(serviceData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _clearForm();
        _fetchServices();
        _showSnackBar('Service added successfully');
      } else {
        _showSnackBar('Failed to add service');
      }
    } else {
      final confirm = await _showConfirmationDialog('update');
      if (confirm) {
        final response = await http.put(
          Uri.parse('http://10.0.2.2:8000/update-service/$_editingServiceId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(serviceData),
        );

        if (response.statusCode == 200) {
          _clearForm();
          _fetchServices();
          _showSnackBar('Service updated successfully');
        } else {
          _showSnackBar('Failed to update service');
        }
      }
    }

    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await _showConfirmationDialog('delete');
    if (!confirm) return;

    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    final response = await http.delete(
      Uri.parse('http://10.0.2.2:8000/delete-service/$serviceId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      _fetchServices();
      _showSnackBar('Service deleted successfully');
    } else {
      _showSnackBar('Failed to delete service');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_type');
    await prefs.remove('email');
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', ModalRoute.withName('/'));
  }

  Uint8List? base64ToImage(String? base64String) {
    if (base64String?.isEmpty ?? true) return null;
    return base64Decode(base64String!);
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  void _clearForm() {
    _nameController.clear();
    _locationController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _categoryController.clear(); // Clear category input
    setState(() {
      _selectedImage = null;
      _base64Image = null;
      _editingServiceId = null;
      _selectedCategory = null; // Reset selected category
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showConfirmationDialog(String action) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm $action'),
              content: Text('Are you sure you want to $action this service?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Yes'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker Dashboard'),
        backgroundColor: Colors.brown[400],
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (!_isEditing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12.0),
                        textStyle: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        _clearForm();
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      child: const Text('Add New Service'),
                    ),
                  ),
                if (_isEditing) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Service Name',
                      labelStyle: TextStyle(color: Colors.brown[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      labelStyle: TextStyle(color: Colors.brown[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      labelStyle: TextStyle(color: Colors.brown[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: '  description',
                      labelStyle: TextStyle(color: Colors.brown[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 40.0),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: Text('Select Category'),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Colors.brown[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[400]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                    ),
                    items: _categories
                        .map((category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),
                  // Text field for custom category (visible if 'Other' is selected)
                  Visibility(
                    visible: _selectedCategory == 'Other',
                    child: TextField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: 'Enter Category',
                        labelStyle: TextStyle(color: Colors.brown[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.brown[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.brown[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.brown[200]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _selectedImage == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 12.0),
                              textStyle: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _pickImage,
                            child: const Text('Pick Image'),
                          ),
                        )
                      : Image.file(_selectedImage!),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12.0),
                        textStyle: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _addOrUpdateService,
                      child: Text(_editingServiceId == null
                          ? 'Add Service'
                          : 'Update Service'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    Uint8List? imageBytes = base64ToImage(service.imageBase64);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        title: Text(service.name),
                        subtitle: Text(service.location),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.brown[400]),
                              onPressed: () {
                                _nameController.text = service.name;
                                _locationController.text = service.location;
                                _priceController.text =
                                    service.price.toString();
                                _descriptionController.text =
                                    service.description;
                                _selectedCategory =
                                    service.category; // Set category
                                setState(() {
                                  _base64Image = service.imageBase64;
                                  _selectedImage = null;
                                  _editingServiceId = service.id;
                                  _isEditing = true;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteService(service.id),
                            ),
                          ],
                        ),
                        leading: imageBytes != null
                            ? Image.memory(imageBytes)
                            : Placeholder(
                                fallbackHeight: 50, fallbackWidth: 50),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Service {
  final String id;
  final String name;
  final String location;
  final double price;
  final String? imageBase64;
  final String description;
  final String? category; // Add category field

  Service({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    this.imageBase64,
    required this.description,
    this.category,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['_id'],
      name: json['name'],
      location: json['location'],
      price: json['price'].toDouble(),
      imageBase64: json['imageBase64'],
      description: json['description'],
      category: json['category'], // Add category to json
    );
  }
}
