import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fourthapp/screens/worker_request_history_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fourthapp/screens/request_provider.dart';
import 'package:fourthapp/screens/safe_area_page.dart';
import 'package:fourthapp/screens/safe_area_provider.dart';

class WorkerRequestsPage extends StatefulWidget {
  @override
  _WorkerRequestsPageState createState() => _WorkerRequestsPageState();
}

class _WorkerRequestsPageState extends State<WorkerRequestsPage> {
  WebSocketChannel? _socketChannel;
  String? _socketUrl =
      'ws://10.0.2.2:8000/ws'; // Update with your WebSocket URL
  String? _workerEmail;

  @override
  void initState() {
    super.initState();
    _getWorkerEmail();
    _fetchRequests(); // Fetch requests initially
    _initWebSocket();
  }

  @override
  void dispose() {
    _socketChannel?.sink.close();
    super.dispose();
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _getWorkerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    setState(() {
      _workerEmail = email;
    });
  }

  Future<void> _fetchRequests() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    // Fetch worker requests using the provider
    Provider.of<RequestProvider>(context, listen: false)
        .fetchWorkerRequests(_workerEmail!, accessToken);
  }

  Future<void> _initWebSocket() async {
    try {
      _socketChannel = WebSocketChannel.connect(Uri.parse(_socketUrl!));
      _socketChannel?.stream.listen((message) {
        final data = jsonDecode(message);
        print("WebSocket message received: $data");
        // Handle incoming messages (e.g., request updates)
        if (data['message'] == 'Request marked as Ready for Delivery') {
          // Refresh the list
          _fetchRequests();
        }
      }, onError: (error) {
        print("WebSocket Error: $error");
        _socketChannel?.sink.close();
      }, onDone: () {
        print("WebSocket Closed");
      });
    } catch (e) {
      print('Error initializing WebSocket: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _acceptRequest(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    // Get deadline from the worker using a dialog
    DateTime? selectedDeadline = await _showDeadlineDialog(context);
    if (selectedDeadline == null) return; // User cancelled

    try {
      final response = await http.put(
        Uri.parse(
            'http://10.0.2.2:8000/requests/$requestId/accept?deadline=${selectedDeadline.toIso8601String()}'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        // Update request in the provider
        Provider.of<RequestProvider>(context, listen: false)
            .acceptRequest(requestId, selectedDeadline);

        _showSnackBar("Request accepted");
      } else {
        _showSnackBar(
            'Failed to accept request. Status code: ${response.statusCode}');
        print("Error accepting request: ${response.body}");
      }
    } catch (e) {
      _showSnackBar('Error accepting request: $e');
      print("Error accepting request: $e");
    }
  }

  Future<DateTime?> _showDeadlineDialog(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );

    if (selectedDate != null) {
      TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        return DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
      }
    }
    return null;
  }

  Future<void> _rejectRequest(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.delete(
        // Use http.delete now
        Uri.parse(
            'http://10.0.2.2:8000/requests/$requestId'), // Updated endpoint
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Update the request status in the provider (remove the request)
        Provider.of<RequestProvider>(context, listen: false).removeRequest(
            requestId); // Assuming you have a removeRequest method

        _showSnackBar("Request rejected and deleted");
      } else {
        _showSnackBar('Failed to reject request');
        print("Error rejecting request: ${response.body}");
      }
    } catch (e) {
      _showSnackBar('Error rejecting request: $e');
      print("Error rejecting request: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours.remainder(24));
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    String daysText = duration.inDays > 0 ? '${duration.inDays} days ' : '';

    return '$daysText$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _markRequestReady(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/requests/$requestId/ready'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        // Update the request status in the provider
        Provider.of<RequestProvider>(context, listen: false)
            .updateRequestStatus(requestId, 'ready_for_delivery');
        _showSnackBar('Request marked as Ready for Delivery');
      } else {
        _showSnackBar('Failed to mark request as ready');
        print("Error marking request as ready: ${response.body}");
      }
    } catch (e) {
      _showSnackBar('Error marking request as ready: $e');
      print("Error marking request as ready: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);
    final safeAreaProvider = Provider.of<SafeAreaProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
        backgroundColor: Colors.brown[400],
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => WorkerRequestHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Colors.white),
              child: requestProvider.requests.isEmpty
                  ? Center(
                      child: Text('No requests yet'),
                    )
                  : ListView.builder(
                      itemCount: requestProvider.requests.length,
                      itemBuilder: (context, index) {
                        final request = requestProvider.requests[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: ListTile(
                            title: Text(request.serviceName),
                            subtitle: Text(
                                'From: ${request.userName} - ${request.createdAt}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (request.status == 'pending')
                                  IconButton(
                                    icon: Icon(Icons.check_circle,
                                        color: Colors.green),
                                    onPressed: () => _acceptRequest(request.id),
                                  ),
                                if (request.status == 'pending')
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => _rejectRequest(request.id),
                                  ),
                                if (request.status == 'accepted')
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SafeAreaPage(
                                            request: request,
                                            isUserBuyer:
                                                false, // Indicate worker view
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text('Open Safe Area'),
                                  ),
                                if (request.status == 'ready_for_delivery' ||
                                    request.status == 'completed')
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SafeAreaPage(
                                            request: request,
                                            isUserBuyer:
                                                false, // Indicate worker view
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text('Open Safe Area'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (requestProvider.intervalRequests.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16.0),
              color: Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interval Section',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: requestProvider.intervalRequests.length,
                    itemBuilder: (context, index) {
                      final request = requestProvider.intervalRequests[index];
                      DateTime? deadline =
                          DateTime.tryParse(request.deadline ?? '');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          title: Text(request.serviceName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'From: ${request.userName} - ${request.createdAt}'),
                              if (deadline != null &&
                                  request.status == "accepted") ...[
                                Text(
                                  'Deadline: ${DateFormat('yyyy-MM-dd HH:mm').format(deadline)}',
                                  style: TextStyle(color: Colors.blue),
                                ),
                                CountdownTimer(
                                  endTime: deadline.millisecondsSinceEpoch,
                                  onEnd: () {
                                    // Handle timer end here, such as refreshing the list
                                    // or updating the request status in the provider
                                    _showSnackBar(
                                        'Time is up for ${request.serviceName}!');
                                    // No need to call setState here as the snackbar appearance is handled separately
                                    Provider.of<RequestProvider>(context,
                                            listen: false)
                                        .updateRequestStatus(
                                            request.id, 'completed');
                                  },
                                  widgetBuilder: (_, time) {
                                    if (time == null) {
                                      return Text('Done!');
                                    }

                                    Duration remainingDuration = Duration(
                                      days: time.days ?? 0,
                                      hours: time.hours ?? 0,
                                      minutes: time.min ?? 0,
                                      seconds: time.sec ?? 0,
                                    );

                                    return Text(
                                      'Time remaining: ${_formatDuration(remainingDuration)}',
                                      style: TextStyle(color: Colors.red),
                                    );
                                  },
                                ),
                              ] else if (request.status != "accepted")
                                Text('Status: ${request.status}'),
                            ],
                          ),
                          // Always show "Open Safe Area" button in Interval Section
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SafeAreaPage(
                                        request: request,
                                        isUserBuyer:
                                            false, // Indicate worker view
                                      ),
                                    ),
                                  );
                                },
                                child: Text('Open Safe Area'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
