// lib/widgets/navigation_bar.dart
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/chat_screen.dart';
import '../providers/auth_provider.dart';
import '../screens/home.dart';
import '../screens/login.dart';
import '../screens/register.dart';
import '../screens/reporting.dart';
import '../screens/userScreen/UserRequestsPage.dart';
import '../screens/userScreen/normal_profile_page.dart';
import '../screens/userScreen/user_dashboard.dart' as user;
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
  String? _connectedEmail; // لمنع إعادة اتصال مكررة

  final _homeKey = GlobalKey<HomePageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.instance.init(Overlay.of(context));
      _tryConnect();
    });
  }

  @override
  void dispose() {
    _notifWs?.disconnect();
    super.dispose();
  }

  // يُستدعى عند كل build — يتصل فقط إذا تغيّر المستخدم
  void _tryConnect() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.user == null) {
      if (_connectedEmail != null) {
        _notifWs?.disconnect();
        _connectedEmail = null;
      }
      return;
    }
    final email = auth.user!.email;
    if (email == _connectedEmail) return; // لا تُعِد الاتصال
    _connectedEmail = email;

    _notifWs?.disconnect();
    _notifWs = NotificationWebSocket(
      userEmail: email,
      token: auth.token!,
      onUnreadCount: (_) {},
      onNotification: (event) {
        NotificationManager.instance.handleEvent(event);
      },
    )..connect();

    // تسجيل opener لفتح ChatScreen من Toast الإشعارات
    NotificationManager.instance.registerChatOpener((email, username) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          recipientEmail: email,
          recipientUsername: username,
        ),
      ));
    });
  }

  void _onServicesChanged() {
    _homeKey.currentState?.refresh();
  }

  List<Widget> _buildPages(AuthProvider auth) {
    final userId = auth.user?.id ?? '';

    if (!auth.isLoggedIn) {
      return [
        HomePage(key: _homeKey),
        const RegisterPage(),
        const LoginPage(),
        const AboutAndReportScreen(),
      ];
    }

    if (auth.isWorker) {
      return [
        HomePage(key: _homeKey),
        WorkerDashboardContainer(
          workerId: userId,
          onServicesChanged: _onServicesChanged,
        ),
        const RequestsContainer(),
        WorkerProfilePage(workerId: userId),
        const AboutAndReportScreen(),
      ];
    }

    return [
      HomePage(key: _homeKey),
      user.DashboardScreen(),
      UserRequestsPage(userId: userId),
      NormalProfilePage(userId: userId),
      const AboutAndReportScreen(),
    ];
  }

  List<BottomNavigationBarItem> _buildItems(bool loggedIn) {
    if (!loggedIn) {
      return const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined), activeIcon: Icon(Icons.person_add), label: 'Register'),
        BottomNavigationBarItem(
            icon: Icon(Icons.login_outlined), activeIcon: Icon(Icons.login), label: 'Login'),
        BottomNavigationBarItem(
            icon: Icon(Icons.info_outline), activeIcon: Icon(Icons.info), label: 'About'),
      ];
    }
    return const [
      BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Requests'),
      BottomNavigationBarItem(
          icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      BottomNavigationBarItem(
          icon: Icon(Icons.info_outline), activeIcon: Icon(Icons.info), label: 'About'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // يُعيد الاتصال إذا تغيّر المستخدم (بعد login/logout)
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryConnect());

    final pages = _buildPages(auth);
    final idx = _index.clamp(0, pages.length - 1);

    return Scaffold(
      // ── AppBar مع زر الإشعارات في المكان الصحيح ──────
      appBar: auth.isLoggedIn
          ? AppBar(
              toolbarHeight: 0, // مخفي - كل صفحة لها AppBar خاص
              // نضع زر الإشعارات في كل page AppBar بطريقة مختلفة
              // أو نستخدم Overlay من notification_service
            )
          : null,
      body: Stack(children: [
        IndexedStack(index: idx, children: pages),

        // ── زر الإشعارات — يظهر فقط للمسجلين ──────────
        // موضوع في أعلى يمين الشاشة بشكل صحيح (تحت status bar)
        if (auth.isLoggedIn)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: ListenableBuilder(
                  listenable: NotificationManager.instance,
                  builder: (_, __) {
                    final count = NotificationManager.instance.unreadCount;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationInboxScreen()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: badges.Badge(
                            showBadge: count > 0,
                            badgeContent: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 9),
                            ),
                            badgeStyle: const badges.BadgeStyle(
                              badgeColor: AppTheme.accent,
                              padding: EdgeInsets.all(4),
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                color: AppTheme.primary, size: 26),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          if (i < pages.length) setState(() => _index = i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.primary,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFBCAAA4),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        items: _buildItems(auth.isLoggedIn),
      ),
    );
  }
}
