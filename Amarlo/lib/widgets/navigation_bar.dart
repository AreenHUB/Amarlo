import 'package:flutter/material.dart';
import 'package:fourthapp/screens/register.dart';
import 'package:fourthapp/screens/worker_profile.dart';
import 'package:fourthapp/screens/wrokerScreen/user_requests.dart';
import 'package:fourthapp/screens/wrokerScreen/worker_request/WorkerRequestsPage.dart';
import 'package:fourthapp/widgets/WorkerDashboardContainer.dart';
import 'package:fourthapp/widgets/requests_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fourthapp/screens/home.dart';
import 'package:fourthapp/screens/login.dart';
import 'package:fourthapp/screens/userScreen/user_dashboard.dart' as user;
import 'package:fourthapp/screens/wrokerScreen/worker_dashboard.dart' as worker;
import 'package:fourthapp/screens/userScreen/UserRequestsPage.dart';
import 'package:fourthapp/screens/userScreen/normal_profile_page.dart';
import 'package:fourthapp/screens/reporting.dart';

class NavigationBarPage extends StatefulWidget {
  const NavigationBarPage({Key? key}) : super(key: key);

  static void updateLoginState(bool isLoggedIn, [String userType = '']) {
    NavigationBarPageState.instance?._updateLoginState(isLoggedIn, userType);
  }

  @override
  NavigationBarPageState createState() => NavigationBarPageState();
}

class NavigationBarPageState extends State<NavigationBarPage> {
  int _selectedIndex = 0;
  bool _isLoggedIn = false;
  String _userType = '';
  static NavigationBarPageState? instance;
  String? _userId; // Store user ID here
  String? _userEmail;
  String? _accessToken;

  NavigationBarPageState() {
    instance = this;
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      final userType = prefs.getString('user_type') ?? '';
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('email');
      print("Retrieved user ID from prefs: $userId");
      print("Retrieved user Email from prefs: $userEmail");
      _updateLoginState(true, userType);
      setState(() {
        _userId = userId;
        _userEmail = userEmail;
        _accessToken = token;
      });
    }
  }

  void _updateLoginState(bool isLoggedIn, [String userType = '']) {
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _userType = userType;
        _selectedIndex = 0;
      });
    }
  }

  List<Widget> _widgetOptions() {
    if (_isLoggedIn) {
      if (_userType == 'worker') {
        return [
          HomePage(),
          WorkerDashboardContainer(
            workerId: _userId ?? '',
          ),
          RequestsContainer(
            userId: _userId ?? '',
          ),
          WorkerProfilePage(
            workerId: _userId ?? '',
          ),
          AboutAndReportScreen(token: _accessToken ?? ''),
        ];
      } else if (_userType == 'customer') {
        return [
          HomePage(),
          user.DashboardScreen(),
          UserRequestsPage(
            userId: _userId ?? '',
          ),
          NormalProfilePage(
            userId: _userId ?? '',
          ),
          AboutAndReportScreen(token: _accessToken ?? ''),
        ];
      }
    }
    return [
      HomePage(),
      RegisterPage(),
      LoginPage(),
      AboutAndReportScreen(token: _accessToken ?? ''),
    ];
  }

  List<BottomNavigationBarItem> _bottomNavItems() {
    if (_isLoggedIn) {
      if (_userType == 'worker') {
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Requests',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'About',
            backgroundColor: Colors.brown, // Background color
          ),
        ];
      } else if (_userType == 'customer') {
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Colors.brown, // Background color
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'About',
            backgroundColor: Colors.brown, // Background color
          ),
        ];
      }
    }
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
        backgroundColor: Colors.brown, // Background color
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_add),
        label: 'Register',
        backgroundColor: Colors.brown, // Background color
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.login),
        label: 'Login',
        backgroundColor: Colors.brown, // Background color
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.info),
        label: 'about',
        backgroundColor: Colors.brown, // Background color
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions().elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavItems(),
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 104, 68, 56),
        backgroundColor: Color.fromARGB(127, 200, 160, 162),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Color.fromARGB(255, 158, 158, 158),
      ),
    );
  }
}
