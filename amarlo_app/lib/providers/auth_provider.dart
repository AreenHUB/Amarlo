// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

class AuthProvider extends ChangeNotifier {
  User?   _user;
  String? _token;
  bool    _loading = false;
  String? _error;

  User?   get user      => _user;
  String? get token     => _token;
  bool    get isLoggedIn => _token != null && _user != null;
  bool    get isWorker  => _user?.userType == 'Worker';
  bool    get loading   => _loading;
  String? get error     => _error;

  // ─── Init ─────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.kAccessToken);

    if (_token != null) {
      try {
        _user = await ApiService.getMe();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // access token منتهي → حاول refresh
          final refreshed = await api.tryRefresh();
          if (refreshed) {
            _token = prefs.getString(AppConstants.kAccessToken);
            try {
              _user = await ApiService.getMe();
            } on ApiException catch (e2) {
              // 401 بعد refresh = session منتهية فعلاً
              if (e2.statusCode == 401) await _clearSession(prefs);
              // أي خطأ آخر (شبكة) = ابقَ مسجلاً
            } catch (_) {
              // خطأ شبكة — ابقَ مسجلاً، سيُعاد المحاولة لاحقاً
            }
          } else {
            // refresh فشل = session منتهية فعلاً → logout
            await _clearSession(prefs);
          }
        }
        // statusCode != 401 (500، network error) → ابقَ مسجلاً
      } catch (_) {
        // SocketException أو أي خطأ شبكة → لا تمسح الـ session
        // المستخدم مسجل ولكن السيرفر غير متاح مؤقتاً
      }
    }
    notifyListeners();
  }

  // ─── Login ────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email, password);
      await _saveSession(data);
      _user = await ApiService.getMe();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Login failed. Please try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Logout ───────────────────────────────────────────
  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    notifyListeners();
  }

  // ─── Session helpers ──────────────────────────────────
  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _token = data['access_token'] as String;
    await prefs.setString(AppConstants.kAccessToken,  _token!);
    await prefs.setString(AppConstants.kRefreshToken,  data['refresh_token'] ?? '');
    await prefs.setString(AppConstants.kUserType,      data['user_type']     ?? '');
    await prefs.setString(AppConstants.kEmail,         data['email']         ?? '');
    await prefs.setString(AppConstants.kUserId,        data['user_id']       ?? '');
    await prefs.setString(AppConstants.kUsername,      data['username']      ?? '');
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(AppConstants.kAccessToken);
    await prefs.remove(AppConstants.kRefreshToken);
    await prefs.remove(AppConstants.kUserType);
    await prefs.remove(AppConstants.kEmail);
    await prefs.remove(AppConstants.kUserId);
    await prefs.remove(AppConstants.kUsername);
    _token = null;
    _user  = null;
  }

  // ─── Update user locally ──────────────────────────────
  void updateUser(User updated) {
    _user = updated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
