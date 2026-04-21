// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isWorker => _user?.userType == 'Worker';
  bool get loading => _loading;
  String? get error => _error;

  // ─── Init ───────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.kAccessToken);
    if (_token != null) {
      try {
        _user = await ApiService.getMe();
      } catch (_) {
        // token expired or invalid
        await _clearSession(prefs);
      }
    }
    notifyListeners();
  }

  // ─── Login ──────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      final prefs = await SharedPreferences.getInstance();

      _token = data['access_token'] as String;
      await prefs.setString(AppConstants.kAccessToken, _token!);
      await prefs.setString(AppConstants.kUserType, data['user_type'] ?? '');
      await prefs.setString(AppConstants.kEmail, data['email'] ?? '');
      await prefs.setString(AppConstants.kUserId, data['user_id'] ?? '');

      _user = await ApiService.getMe();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('ApiException', '').trim();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Logout ─────────────────────────────────────────
  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    notifyListeners();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.clear();
    _token = null;
    _user = null;
  }

  // ─── Update user locally ────────────────────────────
  void updateUser(User updated) {
    _user = updated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
