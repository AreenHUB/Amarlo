// lib/providers/request_provider.dart
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';

class RequestProvider extends ChangeNotifier {
  // ─── Worker requests ────────────────────────────────
  List<ServiceRequest> _workerRequests = [];
  List<ServiceRequest> _workerCompleted = [];

  // ─── User requests ──────────────────────────────────
  List<ServiceRequest> _userRequests = [];
  List<ServiceRequest> _userCompleted = [];

  bool _loading = false;
  String? _error;

  List<ServiceRequest> get workerRequests => _workerRequests;
  List<ServiceRequest> get userRequests => _userRequests;
  List<ServiceRequest> get workerCompleted => _workerCompleted;
  List<ServiceRequest> get userCompleted => _userCompleted;
  bool get loading => _loading;
  String? get error => _error;

  /// الطلبات المقبولة مع deadline (الـ interval section)
  List<ServiceRequest> get acceptedRequests => _workerRequests
      .where((r) => r.status == 'accepted' && r.deadline != null)
      .toList();

  // ─── Fetch ──────────────────────────────────────────

  Future<void> fetchWorkerRequests(String workerEmail) async {
    _setLoading(true);
    try {
      final paged = await ApiService.getWorkerRequests(workerEmail, size: 100);
      _workerRequests = paged.items;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchUserRequests(String userId) async {
    _setLoading(true);
    try {
      final paged = await ApiService.getUserRequests(userId, size: 100);
      _userRequests = paged.items;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchWorkerCompleted(String workerEmail) async {
    try {
      _workerCompleted =
          await ApiService.getWorkerCompletedRequests(workerEmail);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> fetchUserCompleted(String userEmail) async {
    try {
      _userCompleted = await ApiService.getUserCompletedRequests(userEmail);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ─── Actions ────────────────────────────────────────

  Future<void> acceptRequest(String requestId, DateTime deadline) async {
    try {
      await ApiService.acceptRequest(requestId, deadline.toIso8601String());
      _updateStatus(requestId, 'accepted', deadline: deadline.toIso8601String());
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await ApiService.deleteRequest(requestId);
      _workerRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteUserRequest(String requestId) async {
    try {
      await ApiService.deleteRequest(requestId);
      _userRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void updateRequestStatus(String requestId, String newStatus) {
    _updateStatus(requestId, newStatus);
  }

  // ─── Private helpers ────────────────────────────────

  void _updateStatus(String id, String status, {String? deadline}) {
    for (final list in [_workerRequests, _userRequests]) {
      final i = list.indexWhere((r) => r.id == id);
      if (i != -1) {
        list[i] = list[i].copyWith(status: status, deadline: deadline);
      }
    }
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
}
