import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fourthapp/models/service.dart';
import 'package:fourthapp/models/user.dart';
import 'package:fourthapp/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fourthapp/models/review.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkerProfilePage extends StatefulWidget {
  final String workerId;
  final bool isVisitor;

  const WorkerProfilePage(
      {Key? key, required this.workerId, this.isVisitor = false})
      : super(key: key);

  @override
  _WorkerProfilePageState createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  User? worker;
  List<Service> services = [];
  final TextEditingController introductionController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController telegramController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController specialityController = TextEditingController();
  String? _base64Image;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchWorkerData();
    _fetchWorkerBalance();
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchWorkerBalance() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/workers/${worker!.email}/balance'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Ensure to call setState to rebuild the widget with the new balance
        setState(() {
          _balance += data['balance'];
        });
      } else {
        print('Error fetching worker balance: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching worker balance: $e');
    }
  }

  Future<void> _fetchWorkerData() async {
    try {
      final fetchedWorker = await ApiService.getWorker(widget.workerId);
      if (fetchedWorker != null) {
        final fetchedServices =
            await ApiService.getWorkerServicesByEmail(fetchedWorker.email);
        setState(() {
          worker = fetchedWorker;
          services = fetchedServices;
          _populateTextFields(worker!);
          _fetchWorkerBalance();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching worker data: $e')),
      );
    }
  }

  void _populateTextFields(User worker) {
    introductionController.text = worker.introduction ?? '';
    facebookController.text = worker.facebook ?? '';
    instagramController.text = worker.instagram ?? '';
    telegramController.text = worker.telegram ?? '';
    usernameController.text = worker.username ?? '';
    numberController.text = worker.number ?? '';
    cityController.text = worker.city ?? '';
    specialityController.text = worker.speciality ?? '';
  }

  Future<void> _saveProfile() async {
    try {
      final updatedData = {
        'username': usernameController.text,
        'number': numberController.text,
        'city': cityController.text,
        'speciality': specialityController.text,
        'introduction': introductionController.text,
        'facebook': facebookController.text,
        'instagram': instagramController.text,
        'telegram': telegramController.text,
        if (_base64Image != null) 'imageBase64': _base64Image,
      };

      final updatedWorker = await ApiService.updateUserProfile(
        userId: worker!.id,
        updatedData: updatedData,
      );

      if (updatedWorker != null) {
        setState(() {
          worker = updatedWorker;
          _base64Image = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile saved!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(worker?.username ?? 'Worker Profile'),
        leading: widget.isVisitor
            ? IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: worker != null ? _buildProfileContent() : _buildLoadingIndicator(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isVisitor)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet',
                    style:
                        TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Balance: \$${_balance.toStringAsFixed(2)}', //  عرض  _balance  مباشرة
                    style: TextStyle(fontSize: 18.0),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          SizedBox(height: 20),
          Center(child: _buildProfilePicture()),
          SizedBox(height: 20),
          if (!widget.isVisitor) _buildEditableUserInfoSection(),
          _buildHeaderWithVisitorButton(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAboutMeSection(),
                _buildSocialMediaLinks(),
                if (!widget.isVisitor) _buildSaveButton(),
              ],
            ),
          ),
          _buildServicesSection(),
          _buildReviewsSection(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _buildProfilePicture() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60.0,
          backgroundImage: _base64Image != null
              ? MemoryImage(base64Decode(_base64Image!))
              : worker?.imageBase64 != null
                  ? MemoryImage(worker!.imageBase64!)
                  : AssetImage('images/OIG4.jpg') as ImageProvider,
        ),
        if (!widget.isVisitor)
          IconButton(
            onPressed: _pickImage,
            icon: Icon(Icons.edit, color: Colors.blue),
          ),
      ],
    );
  }

  Widget _buildHeaderWithVisitorButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            worker!.username ?? '',
            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          ),
          if (!widget.isVisitor)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerProfilePage(
                      workerId: widget.workerId,
                      isVisitor: true,
                    ),
                  ),
                );
              },
              child: Text('View as Visitor'),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutMeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Me',
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        widget.isVisitor
            ? Text(worker!.introduction ?? 'No introduction provided')
            : TextFormField(
                controller: introductionController,
                maxLines: 5,
                decoration:
                    InputDecoration(hintText: 'Write your introduction here'),
              ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSocialMediaLinks() {
    return Column(
      children: [
        _buildSocialMediaLink('Facebook', facebookController,
            FontAwesomeIcons.facebook, Colors.blue),
        SizedBox(height: 10),
        _buildSocialMediaLink('Instagram', instagramController,
            FontAwesomeIcons.instagram, Colors.pink),
        SizedBox(height: 10),
        _buildSocialMediaLink('Telegram', telegramController,
            FontAwesomeIcons.telegram, Colors.blue),
      ],
    );
  }

  Widget _buildSocialMediaLink(String label, TextEditingController controller,
      IconData icon, Color color) {
    return widget.isVisitor
        ? ListTile(
            leading: Icon(icon, color: color),
            title: Text(controller.text),
          )
        : TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: color),
            ),
          );
  }

  Widget _buildEditableUserInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          _buildEditableField('Username', usernameController, Icons.person),
          _buildEditableField('Number', numberController, Icons.phone),
          _buildEditableField('City', cityController, Icons.location_city),
          _buildEditableField('Speciality', specialityController, Icons.work),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: 8.0),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: ElevatedButton(
          onPressed: _saveProfile,
          child: Text('Save Profile'),
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return ListTile(
                title: Text(service.name),
                subtitle: Text(service.location),
                leading: service.imageBase64 != null
                    ? Image.memory(base64Decode(service.imageBase64!))
                    : Icon(Icons.image),
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews',
            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          // Display reviews here
          FutureBuilder<List<Review>>(
            future: ApiService.getReviewsForWorker(worker!.email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No reviews yet.'));
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final review = snapshot.data![index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(review.reviewerUsername),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Use RatingBarIndicator to display the rating
                            RatingBarIndicator(
                              rating: review.rating.toDouble(),
                              itemBuilder: (context, index) => Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: 20.0,
                              direction: Axis.horizontal,
                            ),
                            SizedBox(height: 4),
                            if (review.comment != null) Text(review.comment!),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
