import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AboutAndReportScreen extends StatefulWidget {
  final String token;

  AboutAndReportScreen({required this.token});

  @override
  _AboutAndReportScreenState createState() => _AboutAndReportScreenState();
}

class _AboutAndReportScreenState extends State<AboutAndReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  File? _image;
  List<dynamic> _userReports = [];
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    _fetchUserReports();
  }

  Future<void> _fetchUserReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/user-reports'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _userReports = json.decode(response.body) as List<dynamic>;
          _isLoadingReports = false;
        });
      } else {
        // _showErrorSnackBar('Failed to fetch reports');
        setState(() {
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      // _showErrorSnackBar('Failed to fetch reports');
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitReport() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      // User is logged in (or token exists) - proceed to validate the form
      if (_formKey.currentState!.validate()) {
        final description = _descriptionController.text;
        String? base64Image;

        // Encode image if one is selected
        if (_image != null) {
          List<int> imageBytes = await _image!.readAsBytes();
          base64Image = base64Encode(imageBytes);
        }

        final reportData = {
          'user_email': prefs.getString('email'), // Get user email
          'description': description,
          'imageBase64': base64Image,
        };

        try {
          final response = await http.post(
            Uri.parse('http://10.0.2.2:8000/reports'), // Your API endpoint
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken' // Include access token
            },
            body: json.encode(reportData),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Successful report submission
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report submitted successfully')),
            );
            _formKey.currentState!.reset();
            setState(() {
              _image = null; // Clear image preview
            });
            _fetchUserReports(); // Refresh the reports list
          } else {
            // Handle error with a more descriptive message
            print('Error submitting report: ${response.body}');
            _showErrorSnackBar(
                'Failed to submit report. Please try again later.');
          }
        } catch (e) {
          print('Error submitting report: $e');
          _showErrorSnackBar(
              'Failed to submit report. Please check your connection.');
        }
      }
    } else {
      // User is not logged in - show a SnackBar with login action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to submit a report.'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About and Report'),
        backgroundColor: Colors.brown,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Welcome to Amarlo!'),
            SizedBox(height: 10),
            Text(
              'Your Marketplace for Personalized Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildSectionTitle('What is Amarlo?'),
            SizedBox(height: 10),
            Text(
              'Amarlo is a mobile marketplace designed to connect you with skilled workers who offer a wide range of personalized services. Whether you need help with home repairs, pet care, beauty services, tutoring, or any other specialized task, Amarlo makes it easy to find qualified professionals who meet your specific needs.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            _buildSectionTitle('How It Works:'),
            SizedBox(height: 10),
            _buildFeatureDescription(
                icon: Icons.search,
                title: 'Find a Service:',
                description:
                    'Browse through a variety of service categories and explore detailed listings to find the perfect service for you.'),
            _buildFeatureDescription(
                icon: Icons.request_page,
                title: 'Request a Service:',
                description:
                    'Submit a request outlining your specific requirements, desired outcomes, and preferred timeline.'),
            _buildFeatureDescription(
                icon: Icons.local_offer,
                title: 'Get Offers:',
                description:
                    'Skilled workers who can fulfill your request will send you offers with their proposed pricing and details.'),
            _buildFeatureDescription(
                icon: Icons.chat,
                title: 'Chat with Workers:',
                description:
                    'Communicate directly with workers to clarify details, negotiate terms, and ask questions before making a decision.'),
            _buildFeatureDescription(
                icon: Icons.check_circle,
                title: 'Accept an Offer:',
                description:
                    'Choose the offer that best meets your needs and accept it to proceed.'),
            _buildFeatureDescription(
                icon: Icons.payment,
                title: 'Secure Payment:',
                description:
                    'Amarlo uses a secure payment system to handle transactions, ensuring the safety of your financial information. Your payment is held in escrow until you confirm the service has been completed.'),
            _buildFeatureDescription(
                icon: Icons.security,
                title: 'Safe Area for Work:',
                description:
                    'Once the payment is confirmed, the worker will upload the completed work to a secure "Safe Area" where you can download it.'),
            _buildFeatureDescription(
                icon: Icons.star,
                title: 'Rate and Review:',
                description:
                    'After the service is complete, you can rate the worker and provide feedback to help other users make informed decisions.'),
            SizedBox(height: 20),
            _buildSectionTitle('Key Features:'),
            SizedBox(height: 10),
            _buildFeatureDescription(
                icon: Icons.person_pin_circle,
                title: 'Personalized Service Matching:',
                description:
                    'Find services tailored to your individual needs and preferences.'),
            _buildFeatureDescription(
                icon: Icons.message,
                title: 'Direct Communication:',
                description:
                    'Chat directly with workers before making a decision.'),
            _buildFeatureDescription(
                icon: Icons.lock,
                title: 'Secure Payments and Escrow:',
                description: 'Ensure safe and reliable transactions.'),
            _buildFeatureDescription(
                icon: Icons.reviews,
                title: 'User Reviews and Ratings:',
                description:
                    'Read reviews from other users to choose the best workers.'),
            _buildFeatureDescription(
                icon: Icons.folder_shared,
                title: 'Safe Area for Work File Exchange:',
                description:
                    'Securely receive completed work after payment is confirmed.'),
            SizedBox(height: 20),
            _buildSectionTitle('Need Help?'),
            SizedBox(height: 10),
            Text(
              'If you have any questions, encounter any issues, or have suggestions for improving the platform, please don\'t hesitate to submit a report through the form below. Our team is dedicated to providing you with a positive and supportive experience on Amarlo.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            _buildReportForm(),
            SizedBox(height: 30),
            _buildSectionTitle('Your Reports'),
            SizedBox(height: 10),
            _isLoadingReports
                ? Center(child: CircularProgressIndicator())
                : _userReports.isEmpty
                    ? Center(child: Text('No reports submitted yet.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _userReports.length,
                        itemBuilder: (context, index) {
                          final report = _userReports[index];
                          final reportStatus = report['status'] ?? 'Pending';
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              title: Text(report['description']),
                              subtitle: Text('Status: $reportStatus'),
                              trailing: Text(report['timestamp']),
                            ),
                          );
                        },
                      ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper function to create section titles
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  // Helper function to create feature descriptions
  Widget _buildFeatureDescription(
      {required IconData icon,
      required String title,
      required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.brown,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build the report form
  Widget _buildReportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report a Problem',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Describe your problem',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe your problem';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              // Image Preview (only show if _image is not null)
              if (_image != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: TextStyle(fontSize: 16),
                  foregroundColor: Colors.white,
                ),
                child: Text('Add Image (Optional)'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: TextStyle(fontSize: 16),
                  foregroundColor: Colors.white,
                ),
                child: Text('Submit Report'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
