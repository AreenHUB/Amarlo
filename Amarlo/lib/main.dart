import 'package:flutter/material.dart';
import 'package:fourthapp/screens/register.dart';
import 'package:fourthapp/screens/request_provider.dart';
import 'package:fourthapp/screens/safe_area_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens/login.dart';
import 'screens/userScreen/user_dashboard.dart' as user;
import 'screens/wrokerScreen/worker_dashboard.dart' as worker;
import 'widgets/navigation_bar.dart';
import 'package:fourthapp/screens/userScreen/normal_profile_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RequestProvider()),
        ChangeNotifierProvider(create: (context) => SafeAreaProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      initialRoute: '/',
      routes: {
        '/': (context) => MainScreen(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/userDashboard': (context) => user.DashboardScreen(),
        '/workerDashboard': (context) => worker.WorkerDashboard(),
        '/navigationBar': (context) => NavigationBarPage(),
        '/NormalProfile': (context) => NormalProfilePage(userId: '')
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  Future<bool> checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkLoginState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data == true) {
          return NavigationBarPage();
        } else {
          return NavigationBarPage();
        }
      },
    );
  }
}
