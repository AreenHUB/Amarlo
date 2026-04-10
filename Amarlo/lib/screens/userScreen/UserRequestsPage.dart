import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:fourthapp/screens/user_request_history_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fourthapp/screens/safe_area_page.dart';
import 'package:fourthapp/models/request_data.dart';
import 'package:provider/provider.dart';
import 'package:fourthapp/screens/request_provider.dart';

class UserRequestsPage extends StatefulWidget {
  final String userId;

  const UserRequestsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserRequestsPageState createState() => _UserRequestsPageState();
}

class _UserRequestsPageState extends State<UserRequestsPage> {
  List<RequestData> _requests = [];
  WebSocketChannel? _socketChannel;
  String? _socketUrl =
      'ws://10.0.2.2:8000/ws'; // Update with your WebSocket URL

  @override
  void initState() {
    super.initState();
    print("User ID: ${widget.userId}");
    _fetchUserRequests();
    _initWebSocket();
  }

  Future<void> _fetchUserRequests() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      print("Access token is null");
      return;
    }

    final url = 'http://10.0.2.2:8000/user-requests/${widget.userId}';
    print("Fetching requests from: $url");

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final List<dynamic> requestsData = jsonDecode(response.body);
      setState(() => _requests = requestsData
          .map((data) => RequestData.fromJson(data))
          .where((element) => element.status != 'completed')
          .toList());
      print("Fetched requests: $_requests");
    } else {
      _showSnackBar('Failed to fetch requests');
    }
  }

  Future<void> _initWebSocket() async {
    try {
      _socketChannel = WebSocketChannel.connect(Uri.parse(_socketUrl!));
      _socketChannel?.stream.listen((message) {
        final data = jsonDecode(message);
        print("WebSocket message received: $data");
        if (data['user_id'] == widget.userId) {
          _showSnackBar(data[
              'message']); // Example: "Request accepted" or "Request rejected"
          _fetchUserRequests();
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours.remainder(24));
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    String daysText = duration.inDays > 0 ? '${duration.inDays} days ' : '';

    return '$daysText$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    print("Access token: $accessToken");
    return accessToken;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteRequest(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      print("Access token is null");
      return;
    }

    final url = 'http://10.0.2.2:8000/requests/$requestId';
    print("Deleting request at: $url");

    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print("Delete response status: ${response.statusCode}");
    print("Delete response body: ${response.body}");

    if (response.statusCode == 200) {
      // Remove the request from the list locally
      setState(() {
        _requests.removeWhere((element) => element.id == requestId);
      });

      _showSnackBar('Request deleted successfully');
    } else {
      _showSnackBar('Failed to delete request');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: Colors.brown[400],
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => UserRequestHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: ListView.builder(
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final request = _requests[index];
            DateTime? deadlineDateTime;

            // Try to parse the deadline string
            if (request.deadline != null) {
              try {
                deadlineDateTime = DateTime.parse(request.deadline!);
              } catch (e) {
                print("Error parsing deadline: $e");
                // Handle parsing errors (e.g., show an error message)
              }
            }

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListTile(
                title: Text(request.serviceName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.status} - ${request.createdAt}'),
                    if (request.status == 'accepted' &&
                        deadlineDateTime != null)
                      Column(
                        children: [
                          Text(
                            'Deadline: ${DateFormat('yyyy-MM-dd HH:mm').format(deadlineDateTime)}',
                            style: TextStyle(color: Colors.blue),
                          ),
                          CountdownTimer(
                            endTime: deadlineDateTime.millisecondsSinceEpoch,
                            onEnd: () {
                              print('Timer ended for request: ${request.id}');
                              // Handle timer end
                              // You might want to update the request status or refresh the list
                            },
                            widgetBuilder: (_, time) {
                              if (time == null) {
                                return Text('Time is up!');
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
                        ],
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (request.status == 'pending')
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteRequest(request.id);
                        },
                      )
                    else if (request.status == 'ready_for_delivery' ||
                        request.status == 'completed')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SafeAreaPage(
                                request: request,
                                isUserBuyer: true, // Indicate user view
                              ),
                            ),
                          );
                        },
                        child: Text('Receive'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketChannel?.sink.close(); // Close the socket when the page is disposed
    super.dispose();
  }
}
