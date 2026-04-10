import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _numberController = TextEditingController();
  String _gender = 'Male';
  String _city = 'Damascus';
  String _userType = 'Normal User';
  String? _speciality;
  final _otherSpecialityController = TextEditingController();
  File? _imageFile;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    _otherSpecialityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      }
    });
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      final username = _usernameController.text;
      final password = _passwordController.text;
      final email = _emailController.text;
      final number = _numberController.text;
      final gender = _gender;
      final city = _city;
      final userType = _userType;
      final speciality = _speciality == 'Other'
          ? _otherSpecialityController.text
          : _speciality;

      if (username.isEmpty ||
          password.isEmpty ||
          email.isEmpty ||
          number.isEmpty ||
          gender.isEmpty ||
          city.isEmpty ||
          userType.isEmpty ||
          (userType == 'Worker' && speciality == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill all fields'),
          ),
        );
        return;
      }

      String? base64Image;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      try {
        final response = await http.post(
          Uri.parse('http://10.0.2.2:8000/register'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'username': username,
            'password': password,
            'email': email,
            'number': number,
            'gender': gender,
            'city': city,
            'userType': userType,
            'speciality': speciality,
            'image': base64Image,
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User registered successfully'),
            ),
          );
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => LoginPage()),
          // );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error registering user: ${response.reasonPhrase}'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown,
        title: Text('Register'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24.0),
            margin: EdgeInsets.symmetric(horizontal: 20.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter a password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter an email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _numberController,
                          decoration: InputDecoration(
                            labelText: 'Number',
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter an Number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Gender:',
                                style: TextStyle(color: Colors.black)),
                            Radio(
                              value: 'Male',
                              groupValue: _gender,
                              onChanged: (value) {
                                setState(() {
                                  _gender = value!;
                                });
                              },
                            ),
                            Text('Male', style: TextStyle(color: Colors.black)),
                            Radio(
                              value: 'Female',
                              groupValue: _gender,
                              onChanged: (value) {
                                setState(() {
                                  _gender = value!;
                                });
                              },
                            ),
                            Text('Female',
                                style: TextStyle(color: Colors.black)),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          value: _city,
                          onChanged: (value) {
                            setState(() {
                              _city = value!;
                            });
                          },
                          items: [
                            'Damascus',
                            'Aleppo',
                            'As-Suwayda',
                            'Latakia',
                            'Hama',
                            'Daraa',
                            'Tartus',
                            'Homs',
                            'Deir ez-Zor',
                          ].map((city) {
                            return DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelStyle: TextStyle(color: Colors.black),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Text('User Type:',
                                style: TextStyle(color: Colors.black)),
                            Radio(
                              value: 'Normal User',
                              groupValue: _userType,
                              onChanged: (value) {
                                setState(() {
                                  _userType = value!;
                                  _speciality = null;
                                });
                              },
                            ),
                            Text('Normal User',
                                style: TextStyle(color: Colors.black)),
                            Radio(
                              value: 'Worker',
                              groupValue: _userType,
                              onChanged: (value) {
                                setState(() {
                                  _userType = value!;
                                });
                              },
                            ),
                            Text('Worker',
                                style: TextStyle(color: Colors.black)),
                          ],
                        ),
                        if (_userType == 'Worker')
                          Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _speciality,
                                onChanged: (value) {
                                  setState(() {
                                    _speciality = value;
                                    if (value == 'Other') {
                                      _otherSpecialityController.clear();
                                    }
                                  });
                                },
                                items: [
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
                                  'Other',
                                ].map((speciality) {
                                  return DropdownMenuItem<String>(
                                    value: speciality,
                                    child: Text(speciality),
                                  );
                                }).toList(),
                                decoration: InputDecoration(
                                  labelText: 'Speciality',
                                  labelStyle: TextStyle(color: Colors.black),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                              ),
                              if (_speciality == 'Other') SizedBox(height: 20),
                              if (_speciality == 'Other')
                                TextFormField(
                                  controller: _otherSpecialityController,
                                  decoration: InputDecoration(
                                    labelText: 'Other Speciality',
                                    labelStyle: TextStyle(color: Colors.black),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter a speciality';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ),
                        SizedBox(height: 20),
                        _imageFile == null
                            ? Text('No image selected.',
                                style: TextStyle(color: Colors.black))
                            : Image.file(_imageFile!),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 71, 29, 29),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: Text('Pick Image'),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 71, 29, 29),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: Text('Register'),
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
}
