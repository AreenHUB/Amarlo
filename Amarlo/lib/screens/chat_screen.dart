import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String recipientEmail;
  final String recipientUsername;
  final String? recipientImageBase64;

  const ChatScreen({
    Key? key,
    required this.recipientEmail,
    required this.recipientUsername,
    this.recipientImageBase64,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  IOWebSocketChannel? _channel;
  List<dynamic> _messages = [];
  bool isUserBlocked = false;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    _fetchPreviousMessages();
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _connectToWebSocket() async {
    final userEmail = await _getUserEmail();
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('ws://10.0.2.2:8000/ws/chat/$userEmail?token=$accessToken'),
      );

      _channel?.stream.listen(
        (message) {
          final decodedMessage = jsonDecode(message);
          setState(() {
            _messages.add(decodedMessage);
          });
        },
        onError: (error) {
          print("WebSocket Error: $error");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error connecting to chat. Please try again."),
          ));
        },
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final newMessage = {
        "type": "chat_message",
        "recipient_email": widget.recipientEmail,
        "message": _messageController.text,
      };
      _channel?.sink.add(jsonEncode(newMessage));
      _messageController.clear();
    }
  }

  Future<void> _toggleBlockUser() async {
    final userEmail = await _getUserEmail();
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      final response = await http.post(
        Uri.parse(
            'http://10.0.2.2:8000/toggle-block/${widget.recipientEmail}'), // Correct endpoint!
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          isUserBlocked = jsonDecode(response.body)['blocked'];
        });
        print("Block status toggled. User blocked: $isUserBlocked");
        // Optional: UI feedback (e.g., SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isUserBlocked ? "User blocked." : "User unblocked."),
        ));
      } else {
        print("Error toggling block status: ${response.statusCode}");
      }
    } else {
      print("Error: Access token is null.");
    }
  }

  Future<void> _fetchPreviousMessages() async {
    final userEmail = await _getUserEmail();
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:8000/messages/$userEmail/${widget.recipientEmail}'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body);
        });
      } else {
        print("Error fetching messages: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to load chat history."),
        ));
      }
    } else {
      print("Error: Access token is null.");
    }
  }

  Future<void> _checkBlockStatus() async {
    final userEmail = await _getUserEmail();
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      final response = await http.get(
        // Use GET for checking the status
        Uri.parse('http://10.0.2.2:8000/block-status/${widget.recipientEmail}'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          isUserBlocked = jsonDecode(response.body)['blocked'];
        });
      } else {
        print("Error checking block status: ${response.statusCode}");
      }
    }
  }

  Future<String> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('email');
    if (userEmail == null) {
      throw Exception('User Email not found in shared preferences');
    }
    return userEmail;
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _markMessageAsRead(String messageId) async {
    final accessToken = await _getAccessToken();
    if (accessToken != null) {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/messages/$messageId/read'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        print('Error marking message as read: ${response.statusCode}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true), // Return a value
        ),
        title: Row(
          // Modify the title to include the image
          children: [
            _buildUserAvatar(widget.recipientImageBase64, radius: 20),
            SizedBox(width: 8), // Add some spacing
            Text(widget.recipientUsername),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _toggleBlockUser,
            icon: Icon(isUserBlocked ? Icons.person_add : Icons.block),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<String>(
              future: _getUserEmail(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return Center(child: Text("User email not found"));
                } else {
                  String userEmail = snapshot.data!;

                  return ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_email'] == userEmail;

                      // Mark message as read when it becomes visible
                      if (!isMe && !message['read']) {
                        _markMessageAsRead(message['_id']);
                      }
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(8.0),
                          margin: EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.blue
                                : Color.fromARGB(255, 184, 184, 184),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            message['message'],
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? imageBase64, {double radius = 25}) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final imageBytes = base64Decode(imageBase64);
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(imageBytes),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.person),
      );
    }
  }
}
