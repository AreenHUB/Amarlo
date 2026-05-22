// lib/widgets/navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/request_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/safe_area_page.dart';
import '../providers/auth_provider.dart';
import '../screens/home.dart';
import '../screens/login.dart';
import '../screens/register.dart';
import '../screens/reporting.dart';
import '../screens/userScreen/UserRequestsPage.dart';
import '../screens/userScreen/normal_profile_page.dart';
import '../screens/userScreen/user_dashboard.dart' as user;
import '../screens/worker_profile.dart';
import '../services/api_service.dart';
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
  bool _wasLoggedIn = false;
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
      onUnreadCount: (count) {
        NotificationManager.instance.updateUnreadMessageCount(count);
      },
      onNotification: (event) {
        NotificationManager.instance.handleEvent(event);
      },
    )..connect();

    // تسجيل callback لإعادة تحميل الطلبات فوراً عند وصول أي event
    NotificationManager.instance.registerRequestsRefresh(() {
      if (!mounted) return;
      final req    = context.read<RequestProvider>();
      final auth2  = context.read<AuthProvider>();
      if (auth2.user == null) return;
      if (auth2.isWorker) {
        req.fetchWorkerRequests(auth2.user!.email);
      } else {
        req.fetchUserRequests(auth2.user!.id);
      }
    });

    // تسجيل opener لفتح ChatScreen من Toast الإشعارات
    // pushAndRemoveUntil: يُزيل كل الشاشات فوق NavigationBarPage ثم يفتح ChatScreen
    // هذا يضمن أن Back يرجع مباشرة للـ NavigationBarPage بضغطة واحدة فقط
    NotificationManager.instance.registerChatOpener((recipientEmail, username) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      // إذا كانت ChatScreen مفتوحة بالفعل مع نفس الشخص، لا نفتح شاشة جديدة
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            recipientEmail: recipientEmail,
            recipientUsername: username,
          ),
        ),
        // أبقِ فقط الـ NavigationBarPage (أول route في الـ stack)
        (route) => route.isFirst,
      );
    });

    // التوجيه عند الضغط على الإشعار
    NotificationManager.instance.registerNotifTapHandler((type, data) async {
      if (!mounted) return;

      // الإشعارات التي تفتح SafeAreaPage مباشرة
      const safeAreaTypes = {
        'deal_complete',
        'request_ready',
        'deadline_confirmed',
        'safe_area_opened',
        'price_change_proposed',
        'price_change_accepted',
        'price_change_rejected',
        'work_uploaded',
        'payment_received',
        'worker_confirmed_waiting',
        'user_confirmed_waiting',
      };

      final requestId = data?['request_id'] as String?;

      if (safeAreaTypes.contains(type) && requestId != null) {
        // جلب الـ request ثم فتح SafeAreaPage مباشرة
        try {
          final auth = context.read<AuthProvider>();
          final isWorker = auth.isWorker;

          // نحاول نجد الطلب في القوائم المحملة أولاً
          final provider = context.read<RequestProvider>();
          ServiceRequest? req;

          final allRequests = [
            ...provider.workerRequests,
            ...provider.userRequests,
            ...provider.workerCompleted,
            ...provider.userCompleted,
          ];
          try {
            req = allRequests.firstWhere((r) => r.id == requestId);
          } catch (_) {
            req = null;
          }

          // إذا لم نجده في الذاكرة، نجلبه من الـ API
          if (req == null) {
            final raw = await ApiService.getRequestById(requestId);
            req = raw;
          }

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SafeAreaPage(
                request: req!,
                isUserBuyer: !isWorker,
              ),
            ),
            (route) => route.isFirst,
          );
        } catch (_) {
          // fallback: افتح Requests tab
          if (mounted) setState(() => _index = 2);
        }
        return;
      }

      switch (type) {
        case 'new_offer':
          setState(() => _index = 1);
          break;
        default:
          setState(() => _index = 2);
          break;
      }
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

    // Reset to Home tab on the transition from logged-out → logged-in.
    if (auth.isLoggedIn && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }
    _wasLoggedIn = auth.isLoggedIn;

    final pages = _buildPages(auth);
    final idx = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: idx, children: pages),
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
