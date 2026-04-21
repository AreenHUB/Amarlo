// lib/core/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─── Brand colors ─────────────────────────────────
  static const Color primary = Color(0xFF6D4C41); // Brown 600
  static const Color primaryLight = Color(0xFF9C786C); // Brown 300
  static const Color primaryDark = Color(0xFF4B2C20); // Brown 900
  static const Color accent = Color(0xFFFF8F00); // Amber 800
  static const Color surface = Color(0xFFFFF8F5);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // ─── Text styles ──────────────────────────────────
  static const TextStyle h1 = TextStyle(
      fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF212121));
  static const TextStyle h2 = TextStyle(
      fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF212121));
  static const TextStyle h3 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF212121));
  static const TextStyle body =
      TextStyle(fontSize: 15, color: Color(0xFF424242));
  static const TextStyle caption =
      TextStyle(fontSize: 12, color: Color(0xFF757575));
  static const TextStyle label =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5);

  // ─── Spacing ──────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Border radius ────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusFull = 100;

  // ─── Shadows ──────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // ─── Theme data ───────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
          error: error,
        ),
        scaffoldBackgroundColor: surface,
        fontFamily: 'Roboto',

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),

        // Bottom navigation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: primary,
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFFBCAAA4),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // Cards
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),

        // Input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: error),
          ),
          labelStyle: const TextStyle(color: Color(0xFF757575)),
        ),

        // Elevated buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        // Text buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        // Outlined buttons
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd)),
          ),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF5F5F5),
          selectedColor: const Color(0xFFEFEBE9),
          labelStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusFull)),
          side: BorderSide.none,
        ),

        // Dividers
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
          space: 1,
        ),

        // FloatingActionButton
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),

        // Tab bar
        tabBarTheme: const TabBarThemeData(
          // <--- Changed here
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFFBCAAA4),
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      );
}

// ─── Status color helper ──────────────────────
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return AppTheme.warning;
    case 'accepted':
      return AppTheme.info;
    case 'ready_for_delivery':
      return AppTheme.success;
    case 'completed':
      return const Color(0xFF00897B); // Teal
    case 'rejected':
      return AppTheme.error;
    default:
      return Colors.grey;
  }
}

// ─── Status label helper ─────────────────────
String statusLabel(String status) => status.replaceAll('_', ' ').toUpperCase();
