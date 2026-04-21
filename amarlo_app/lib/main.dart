// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/request_provider.dart';
import 'screens/safe_area_provider.dart';
import 'widgets/navigation_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => SafeAreaProvider()),
      ],
      child: const AmarloApp(),
    ),
  );
}

class AmarloApp extends StatelessWidget {
  const AmarloApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Amarlo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AppEntryPoint(),
      );
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();
  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();
    return const NavigationBarPage();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: const Icon(Icons.handshake, size: 52, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              const Text('Amarlo',
                  style: TextStyle(color: Colors.white, fontSize: 32,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              const Text('Your freelance marketplace',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 48),
              const SizedBox(width: 26, height: 26,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            ],
          ),
        ),
      );
}
