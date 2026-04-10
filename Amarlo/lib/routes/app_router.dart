import 'package:flutter/material.dart';
import '/screens/login.dart';
import '/screens/register.dart';
import '/screens/worker_profile.dart';

class AppRouter {
  static const String loginRoute = '/';
  static const String registerRoute = '/register';
  static const String workerProfileRoute = '/worker-profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        return MaterialPageRoute(builder: (_) => LoginPage());
      case registerRoute:
        return MaterialPageRoute(builder: (_) => RegisterPage());
      case workerProfileRoute:
        final workerId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) => WorkerProfilePage(workerId: workerId));
      default:
        return MaterialPageRoute(builder: (_) => Text('Error: Unknown Route'));
    }
  }
}
