import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fourthapp/models/request_data.dart';

class RequestProvider with ChangeNotifier {
  List<RequestData> _requests = [];
  List<RequestData> _intervalRequests = [];
  List<RequestData> _completedUserRequests = [];
  List<RequestData> _completedWorkerRequests = [];

  List<RequestData> get requests => _requests;
  List<RequestData> get intervalRequests => _intervalRequests;
  List<RequestData> get completedUserRequests => _completedUserRequests;
  List<RequestData> get completedWorkerRequests => _completedWorkerRequests;

  Future<void> fetchWorkerRequests(
      String workerEmail, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/worker-requests/$workerEmail'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> requestsData = jsonDecode(response.body);
        _requests =
            requestsData.map((data) => RequestData.fromJson(data)).toList();

        // Separate requests based on status and deadline
        _intervalRequests = _requests
            .where((req) => req.status == 'accepted' && req.deadline != null)
            .toList();
        _requests = requestsData
            .map((data) => RequestData.fromJson(data))
            .where((req) =>
                req.status !=
                'completed') //  إضافة شرط  لإستبعاد   الطلبات  المكتملة
            .toList();
        notifyListeners();
      } else {
        // Handle error
        print('Error fetching requests: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error fetching requests: $e');
    }
  }

  void updateRequestStatus(String requestId, String newStatus) {
    int requestIndex =
        _requests.indexWhere((request) => request.id == requestId);
    int intervalRequestIndex =
        _intervalRequests.indexWhere((request) => request.id == requestId);

    if (requestIndex != -1) {
      _requests[requestIndex].status = newStatus;
      if (newStatus == 'completed' && intervalRequestIndex != -1) {
        _intervalRequests.removeAt(
            intervalRequestIndex); // Remove from intervalRequests if completed
      }
      notifyListeners();
    }
  }

  Future<void> fetchCompletedUserRequests(
      String userEmail, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/users/$userEmail/completed-requests'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> requestsData = jsonDecode(response.body);
        _completedUserRequests =
            requestsData.map((data) => RequestData.fromJson(data)).toList();
        notifyListeners();
      } else {
        print('Error fetching completed user requests: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching completed user requests: $e');
    }
  }

  Future<void> fetchCompletedWorkerRequests(
      String workerEmail, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:8000/workers/$workerEmail/completed-requests'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> requestsData = jsonDecode(response.body);
        _completedWorkerRequests =
            requestsData.map((data) => RequestData.fromJson(data)).toList();
        notifyListeners();
      } else {
        print(
            'Error fetching completed worker requests: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching completed worker requests: $e');
    }
  }

  void removeRequest(String requestId) {
    _requests.removeWhere((request) => request.id == requestId);
    _intervalRequests.removeWhere((request) => request.id == requestId);
    notifyListeners();
  }

  void acceptRequest(String requestId, DateTime deadline) {
    int requestIndex = _requests.indexWhere((req) => req.id == requestId);

    if (requestIndex != -1) {
      _requests[requestIndex].status = "accepted";
      _requests[requestIndex].deadline = deadline.toIso8601String();
      _intervalRequests.add(_requests[requestIndex]);
      _requests.removeAt(requestIndex);
      notifyListeners();
    }
  }

  void rejectRequest(String requestId) {
    int requestIndex = _requests.indexWhere((req) => req.id == requestId);

    if (requestIndex != -1) {
      _requests[requestIndex].status = "rejected";
      notifyListeners();
    }
  }
}
