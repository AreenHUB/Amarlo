
import 'dart:convert';
import 'dart:typed_data';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:fourthapp/screens/chat_screen.dart';
import 'package:fourthapp/screens/login.dart';
import 'package:fourthapp/screens/userScreen/UserRequestsPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'worker_profile_view.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // For WebSockets
import 'package:badges/badges.dart' as badges;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, List<Service>> _groupedServices = {};
  List<Service> _filteredServices = [];
  String? _username;
  String? _profileImageBase64;
  String? _email;
  bool _isLoggedIn = false;
  WebSocketChannel? _socketChannel; // Socket channel for communication
  String? _socketUrl =
      'ws://10.0.2.2:8000/ws'; // Update with your websocket server URL
  String? _userId;
  List<String> _categories = []; // List to store fetched categories
  WebSocketChannel? _notificationChannel;
  int _unreadMessageCount = 0;
  List<Map<String, dynamic>> _conversations = [];

  List<String> _cities = ['Damascus', 'Aleppo', 'Homs', 'Latakia'];

  // Filter variables
  String _searchText = "";
  String? _selectedCity;
  RangeValues _priceRange = RangeValues(0, 10000);
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchUserInfo(); // Only fetch user info if logged in
    _fetchCategories(); // Fetch categories on initialization
    _fetchServices();
    _initWebSocket();
    _initNotificationWebSocket();
    _fetchConversations();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    // Check if the user is logged in
    bool isLoggedIn = accessToken != null;

    // Update the state with the login status
    setState(() {
      _isLoggedIn = isLoggedIn;
    });

    // If logged in, fetch user info and services
    if (_isLoggedIn) {
      await _fetchUserInfo();
      await _fetchServices();
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken != null) {
        final response = await ApiService.getUserInfo(accessToken);
        if (response != null) {
          final userInfo = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _username = userInfo['username'];
              _profileImageBase64 = userInfo['imageBase64'];
              _email = userInfo['email'];
              _userId = userInfo['_id']; // Store the user ID
            });
          }
        } else {
          prefs.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load user info: $e');
      }
    }
  }

  @override
  void dispose() {
    _socketChannel?.sink.close(); // Ensure closure on widget disposal
    _notificationChannel?.sink.close();
    super.dispose();
  }

  Future<void> _initNotificationWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('email');
    final accessToken = prefs.getString('access_token');

    if (userEmail != null && accessToken != null) {
      _notificationChannel = WebSocketChannel.connect(
        Uri.parse(
            'ws://10.0.2.2:8000/ws/notifications/$userEmail?token=$accessToken'),
      );

      _notificationChannel?.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == 'unread_count') {
          setState(() {
            _unreadMessageCount = data['count'];
          });
        }
        // You can add more notification types here (e.g., 'new_message')
      }, onError: (error) {
        print("Notification WebSocket Error: $error");
        // Handle errors (e.g., attempt reconnection)
      });
    }
  }

  Future<void> _fetchConversations() async {
    final userEmail = await _getUserEmail();
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/conversations/$userEmail'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        // Check if the widget is still mounted before calling setState()
        if (mounted) {
          setState(() {
            _conversations =
                List<Map<String, dynamic>>.from(jsonDecode(response.body));
          });
        }
      } else {
        print('Error fetching conversations: ${response.statusCode}');
      }
    }
  }

  Future<void> _markConversationAsRead(String conversationId) async {
    final accessToken = await _getAccessToken();
    if (accessToken != null) {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/messages/$conversationId/read'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        print('Error marking conversation as read: ${response.statusCode}');
      } else {
        // Update the UI after successfully marking the conversation as read
        _fetchConversations();
      }
    }
  }

  // Ensure proper async/await usage
  Future<void> _fetchServices() async {
    try {
      final response = await ApiService.getServices();
      if (response.statusCode == 200) {
        final List<dynamic> servicesData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _groupedServices = _groupServicesByCategory(
              servicesData.map((data) => Service.fromJson(data)).toList(),
            );
            // تحديث _filteredServices عند تحميل البيانات
            _applyFilters(); // تطبيق الفلاتر بعد تحميل الخدمات
          });
        }
      } else {
        throw Exception('Failed to load services');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load services: $e');
      }
    }
  }

  // Function to fetch categories from the backend
  // Function to fetch categories from the backend
  Future<void> _fetchCategories() async {
    try {
      final response = await ApiService.getCategories();
      if (response.statusCode == 200) {
        final categoriesData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _categories = categoriesData.cast<String>();
          });
        }
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load categories: $e');
      }
    }
  }

  Uint8List? base64ToImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding base64 string: $e');
      return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showServiceGroup2(String category, List<Service> services) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceGroupPage(
          category: category,
          services: services,
          name: '',
        ), // Pass category
      ),
    );
  }

  Future<void> _initWebSocket() async {
    try {
      _socketChannel = WebSocketChannel.connect(Uri.parse(_socketUrl!));

      _socketChannel?.stream.listen((message) {
        // Handle incoming messages (e.g., request updates)
        print("Received from websocket: $message");
      }, onError: (error) {
        print("WebSocket Error: $error");
        _socketChannel?.sink.close();
      }, onDone: () {
        print("WebSocket Closed");
      });
    } catch (e) {
      print('Error initializing WebSocket: $e');
    }
  }

  void _sendServiceRequest(Service service) {
    if (_isLoggedIn) {
      // Check _isLoggedIn directly
      // Send the request data
      final requestData = {
        "service_id": service.id,
        "user_email": _email,
        "user_name": _username,
        "worker_email": service.workerEmail,
        "service_name": service.name,
        "created_at": DateTime.now()
            .toIso8601String(), // Store current time in ISO format
      };
      _socketChannel?.sink.add(jsonEncode(requestData));
      _showSnackBar("Request sent");
    } else {
      _showSnackBar("Please login to send a request.");
    }
  }

  Future<void> _showRequestConfirmationDialog(Service service) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Service Request'),
          content: Text('Are you sure you want to request ${service.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoggedIn
                  ? () {
                      _sendServiceRequest(service);
                      Navigator.of(context).pop();
                    }
                  : () {
                      // Navigate to login page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginPage(),
                        ),
                      );
                    }, // Only allow sending if logged in
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<Service>> _groupServicesByCategory(List<Service> services) {
    Map<String, List<Service>> groupedServices = {};
    for (var service in services) {
      if (service.category != null) {
        if (groupedServices.containsKey(service.category)) {
          groupedServices[service.category]!.add(service);
        } else {
          groupedServices[service.category!] = [service];
        }
      }
    }
    return groupedServices;
  }

  void _searchAndFilterServices(String searchText) {
    setState(() {
      _filteredServices = _groupedServices.values
          .expand((services) => services)
          .where((service) {
        double? parsedPrice = double.tryParse(searchText);

        // التحقق من مطابقة مُدخلات البحث الأخرى
        bool matchesSearch =
            service.name.toLowerCase().contains(searchText.toLowerCase()) ||
                service.category!
                    .toLowerCase()
                    .contains(searchText.toLowerCase()) ||
                service.workerUsername
                    .toLowerCase()
                    .contains(searchText.toLowerCase()) ||
                (parsedPrice != null
                    ? (service.price - parsedPrice).abs() <= 100
                    : false);

        // دمج شرط المدينة مع شروط البحث الأخرى
        if (_selectedCity != null) {
          return matchesSearch && service.location == _selectedCity;
        } else {
          return matchesSearch;
        }
      }).toList();
    });
  }

  void _filterServicesByCity(String? city) {
    setState(() {
      if (city != null) {
        _filteredServices = _groupedServices.values
            .expand((services) => services)
            .where((service) => service.location == city)
            .toList();
      } else {
        // إذا لم يتم اختيار مدينة، نعرض جميع الخدمات
        _filteredServices =
            _groupedServices.values.expand((services) => services).toList();
      }
    });
  }

  // دالة لعرض قائمة الفلترة
  void _showFilterMenu(BuildContext context) async {
    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(1000.0, 100.0, 0.0, 0.0),
      items: [
        PopupMenuItem(
          child: Text('Filter by City'),
          value: 'city',
        ),
        PopupMenuItem(
          child: Text('Filter by Price'),
          value: 'price',
        ),
        PopupMenuItem(
          child: Text('Filter by Category'),
          value: 'category',
        ),
      ],
    ).then((value) {
      // No need to check 'value' here, just call _showFilterDialog
      _showFilterDialog(context);
    });
  }

// دالة لعرض نافذة حوار الفلترة
  // Function to display the filter dialog
  void _showFilterDialog(BuildContext context) async {
    RangeValues _tempPriceRange = _priceRange;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Services'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Field
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name, category, or username',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (text) {
                        setState(() {
                          _searchText = text;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // City Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'City'),
                      value: _selectedCity,
                      items: _cities
                          .map((city) => DropdownMenuItem(
                                value: city,
                                child: Text(city),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCity = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Price Range Slider
                    RangeSlider(
                      values: _tempPriceRange,
                      min: 0,
                      max: 10000, // Adjust max value as needed
                      divisions: 100,
                      labels: RangeLabels(
                        _tempPriceRange.start.round().toString(),
                        _tempPriceRange.end.round().toString(),
                      ),
                      onChanged: (values) {
                        setState(() {
                          _tempPriceRange = values;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Category'),
                      value: _selectedCategory,
                      items: _categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Dialog Actions
              actions: <Widget>[
                TextButton(
                  child: Text('Clear Filters'),
                  onPressed: () {
                    setState(() {
                      _searchText = '';
                      _selectedCity = null;
                      _tempPriceRange =
                          RangeValues(0, 10000); // Reset temp range
                      _selectedCategory = null;
                    });
                  },
                ),
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    setState(() {
                      _priceRange = _tempPriceRange;
                    });
                    Navigator.of(context).pop();
                    _applyFilters();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredServices = _groupedServices.values
          .expand((services) => services)
          .where((service) {
        // Search
        bool matchesSearch =
            service.name.toLowerCase().contains(_searchText.toLowerCase()) ||
                (service.category != null &&
                    service.category!
                        .toLowerCase()
                        .contains(_searchText.toLowerCase())) ||
                service.workerUsername
                    .toLowerCase()
                    .contains(_searchText.toLowerCase());

        // City
        bool matchesCity =
            _selectedCity == null || service.location == _selectedCity;

        // Price
        bool matchesPrice = service.price >= _priceRange.start &&
            service.price <= _priceRange.end;

        // Category
        bool matchesCategory =
            _selectedCategory == null || service.category == _selectedCategory;

        return matchesSearch && matchesCity && matchesPrice && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown[400],
        title: const Text(
          'Amarlo App',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationListScreen(
                    conversations: _conversations,
                    onConversationTap: (conversation) {
                      _navigateToChat(
                        context,
                        conversation['other_email'],
                        conversation['other_username'],
                        conversation['conversationId'],
                      );
                    },
                    onBack: () {
                      setState(() {
                        _fetchConversations();
                      });
                    },
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  _fetchConversations();
                }
              });
            },
            icon: badges.Badge(
              badgeContent: Text(_unreadMessageCount.toString()),
              showBadge: _unreadMessageCount > 0,
              child: const Icon(Icons.messenger_outline),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              if (_isLoggedIn &&
                  _username != null &&
                  _profileImageBase64 != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30.0,
                        backgroundImage: MemoryImage(
                          base64Decode(_profileImageBase64!),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Text(
                        'Welcome, $_username',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Hero Image Section
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'images/IMGone.jpg',
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Find Your Perfect Freelance Talent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Search Bar and Filter Icon
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText:
                                      'Search for freelancers, skills, or locations',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (text) {
                                  _searchText = text;
                                  _applyFilters();
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.filter_list),
                              onPressed: () {
                                _showFilterDialog(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Mobile Marketplace Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile MarketPlace',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    // Carousel Slider
                    CarouselSlider(
                      items: [
                        buildFeaturedFreelancerCard(
                            'John Doe', 'Web Developer', 'images/IMGtwo.jpg'),
                        buildFeaturedFreelancerCard('Jane Smith',
                            'Graphic Designer', 'images/IMGthree.jpg'),
                        buildFeaturedFreelancerCard(
                            'John Doe', 'Web Developer', 'images/OIG4.jpg'),
                        buildFeaturedFreelancerCard('Jane Smith',
                            'Graphic Designer', 'images/IMGone.jpg'),
                      ],
                      options: CarouselOptions(
                        height: 260,
                        viewportFraction: 0.8,
                        enlargeCenterPage: true,
                        autoPlay: true,
                        autoPlayInterval: Duration(seconds: 3),
                        autoPlayAnimationDuration: Duration(milliseconds: 800),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Dynamic Service Sections
                    if (_filteredServices.isNotEmpty)
                      ..._buildServiceSections(_filteredServices),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String recipientEmail,
      String recipientUsername, String conversationId) async {
    // Add conversationId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientEmail: recipientEmail,
          recipientUsername: recipientUsername,
        ),
      ),
    );
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  List<Widget> _buildServiceSections(List<Service> services) {
    List<Widget> sections = [];
    _groupedServices.forEach((category, categoryServices) {
      // تصفية الخدمات لكل قسم بناءً على _filteredServices
      List<Service> filteredCategoryServices = categoryServices
          .where((service) => _filteredServices.contains(service))
          .toList();

      if (filteredCategoryServices.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  height: 350.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredCategoryServices.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          _showServiceGroup2(
                              category, filteredCategoryServices);
                        },
                        child:
                            _buildServiceCard(filteredCategoryServices[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
    return sections;
  }

  Widget buildFeaturedFreelancerCard(String name, String title, String image) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                image,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Service service) {
    Uint8List? imageBytes = base64ToImage(service.imageBase64);
    return Container(
      width: 200.0,
      margin: const EdgeInsets.only(right: 16.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
                      width: 200.0,
                      height: 150.0,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'images/IMGtwo.jpg',
                      width: 200.0,
                      height: 150.0,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('by: ${service.workerUsername}',
                      style: const TextStyle(color: Colors.blue)),
                  const SizedBox(height: 4.0),
                  Text(
                    '\$${service.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 12.0),
                      textStyle: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _showRequestConfirmationDialog(service);
                    },
                    child: const Text('Request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceGroup(String name, List<Service> services) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceGroupPage(
          name: name,
          services: services,
          category: '',
        ),
      ),
    );
  }
}

class ServiceGroupPage extends StatelessWidget {
  final String category; // Category for this group
  final List<Service> services;

  ServiceGroupPage(
      {required this.category, required this.services, required String name});

  Uint8List? base64ToImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding base64 string: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown[400],
        title: Text(
          category, // Display the category name
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: ListView.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerProfileViewPage(
                        email: services[index].workerEmail),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: base64ToImage(services[index].imageBase64) != null
                          ? Image.memory(
                              base64ToImage(services[index].imageBase64)!,
                              width: double.infinity,
                              height: 200.0,
                              fit: BoxFit.cover,
                            )
                          : const Placeholder(
                              fallbackHeight: 200.0,
                            ),
                    ),
                    const SizedBox(height: 8.0),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            services[index].name,
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(services[index].location),
                          const SizedBox(height: 8.0),
                          Text('Worker: ${services[index].workerUsername}',
                              style: const TextStyle(color: Colors.blue)),
                          Text('\$${services[index].price.toStringAsFixed(2)}'),
                          const SizedBox(height: 8.0),
                          Text(
                            'Description:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              services[index].description,
                              style: const TextStyle(
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
  final String workerEmail;
  final String workerUsername;
  final String? imageBase64;
  final String description;
  final String? category; // Add category field

  Service({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.workerEmail,
    required this.workerUsername,
    this.imageBase64,
    required this.description,
    this.category,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['_id'].toString(),
      name: json['name'],
      location: json['location'],
      price: json['price'].toDouble(),
      workerEmail: json['worker_email'],
      workerUsername: json['worker_username'],
      imageBase64: json['imageBase64'],
      description: json['description'],
      category: json['category'], // Add category to json
    );
  }
}

class ApiService {
  static Future<http.Response?> getUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/user-info'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    return null;
  }

  // Function to get all services
  static Future<http.Response> getServices() async {
    try {
      final response =
          await http.get(Uri.parse('http://10.0.2.2:8000/services'));
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print('Error fetching services: $e');
    }
    return http.Response('Error fetching services', 500);
  }

  // Function to get all categories (you'll need to create a backend endpoint)
  static Future<http.Response> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/categories'),
      ); // Your backend endpoint
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
    return http.Response('Error fetching categories', 500);
  }

  static Future<http.Response?> getUserFromToken(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/get-user-from-token'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print('Error fetching user info from token: $e');
    }
    return null;
  }
}

class ConversationListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final Function(Map<String, dynamic>) onConversationTap;
  final VoidCallback? onBack;

  const ConversationListScreen({
    Key? key,
    required this.conversations,
    required this.onConversationTap,
    this.onBack,
  }) : super(key: key);

  @override
  _ConversationListScreenState createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            widget.onBack?.call();
            Navigator.pop(context);
          },
        ),
        title: const Text('Conversations'),
      ),
      body: ListView.builder(
        itemCount:
            widget.conversations.length, // Access conversations from widget
        itemBuilder: (context, index) {
          final conversation = widget.conversations[index];
          return _buildConversationTile(context, conversation);
        },
      ),
    );
  }

  Widget _buildConversationTile(
      BuildContext context, Map<String, dynamic> conversation) {
    final String otherEmail = conversation['other_email'];
    final String otherUsername = conversation['other_username'];
    final String? otherUserImageBase64 =
        conversation['other_user_image']; // Fetch image data
    final String lastMessage = conversation['message'];
    final int unreadCount = conversation['unread_count'] ?? 0;

    return ListTile(
      leading:
          _buildUserAvatar(otherUserImageBase64), // Use the helper function
      title: Text(otherUsername),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unreadCount > 0
          ? badges.Badge(
              badgeContent: Text(unreadCount.toString()),
              child: const SizedBox.shrink(),
            )
          : null,
      onTap: () {
        widget.onConversationTap({
          'other_email': otherEmail,
          'other_username': otherUsername,
          'other_user_image':
              otherUserImageBase64, // Pass image data to ChatScreen
          'conversationId': conversation['_id'],
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              recipientEmail: otherEmail,
              recipientUsername: otherUsername,
              recipientImageBase64: otherUserImageBase64, // Pass image data
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(String? imageBase64) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final imageBytes = base64Decode(imageBase64);
      return CircleAvatar(
        backgroundImage: MemoryImage(imageBytes),
      );
    } else {
      return const CircleAvatar(
        child: Icon(Icons.person),
      );
    }
  }
}
