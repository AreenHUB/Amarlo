// lib/widgets/navigation_bar.dart
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../screens/home.dart';
import '../screens/login.dart';
import '../screens/register.dart';
import '../screens/reporting.dart';
import '../screens/userScreen/user_dashboard.dart' as user;
import '../screens/userScreen/UserRequestsPage.dart';
import '../screens/userScreen/normal_profile_page.dart';
import '../screens/worker_profile.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import 'WorkerDashboardContainer.dart';
import 'requests_container.dart';

class NavigationBarPage extends StatefulWidget {
  const NavigationBarPage({super.key});
  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  int _index = 0;
  NotificationWebSocket? _notifWs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.instance.init(Overlay.of(context));
      _connectWs();
    });
  }

  @override
  void dispose() {
    _notifWs?.disconnect();
    super.dispose();
  }

  void _connectWs() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.user == null) return;
    _notifWs = NotificationWebSocket(
      userEmail: auth.user!.email,
      token: auth.token!,
      onUnreadCount: (_) {},
    )..connect();
  }

  List<Widget> _pages(AuthProvider auth) {
    final userId = auth.user?.id ?? '';
    if (!auth.isLoggedIn) {
      return [
        const HomePage(),
        const RegisterPage(),
        const LoginPage(),
        const AboutAndReportScreen(),
      ];
    }
    if (auth.isWorker) {
      return [
        const HomePage(),
        WorkerDashboardContainer(workerId: userId),
        const RequestsContainer(),
        WorkerProfilePage(workerId: userId),
        const AboutAndReportScreen(),
      ];
    }
    return [
      const HomePage(),
      user.DashboardScreen(),
      UserRequestsPage(userId: userId),
      NormalProfilePage(userId: userId),
      const AboutAndReportScreen(),
    ];
  }

  List<BottomNavigationBarItem> _items(bool loggedIn) {
    if (!loggedIn) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person_add_outlined),
            activeIcon: Icon(Icons.person_add), label: 'Register'),
        BottomNavigationBarItem(icon: Icon(Icons.login_outlined),
            activeIcon: Icon(Icons.login), label: 'Login'),
        BottomNavigationBarItem(icon: Icon(Icons.info_outline),
            activeIcon: Icon(Icons.info), label: 'About'),
      ];
    }
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment), label: 'Requests'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person), label: 'Profile'),
      BottomNavigationBarItem(icon: Icon(Icons.info_outline),
          activeIcon: Icon(Icons.info), label: 'About'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pages = _pages(auth);
    final idx = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: idx, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.primary,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFBCAAA4),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        items: _items(auth.isLoggedIn),
      ),
    );
  }
}
