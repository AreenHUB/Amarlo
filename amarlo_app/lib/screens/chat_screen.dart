// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/websocket_service.dart';
import '../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String recipientEmail;
  final String recipientUsername;
  final String? recipientImageUrl;

  const ChatScreen({
    super.key,
    required this.recipientEmail,
    required this.recipientUsername,
    this.recipientImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ChatMessage> _messages = [];
  ChatWebSocket? _ws;
  bool _isBlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    await Future.wait([
      _loadMessages(auth.user!.email),
      _checkBlockStatus(),
    ]);

    _ws = ChatWebSocket(
      userEmail: auth.user!.email,
      token: auth.token!,
      onMessage: (msg) {
        // مقتصر على الرسائل بين هذين المستخدمين فقط
        if ({msg.senderEmail, msg.recipientEmail}
            .containsAll({auth.user!.email, widget.recipientEmail})) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      },
    )..connect();
  }

  Future<void> _loadMessages(String myEmail) async {
    try {
      final msgs = await ApiService.getMessages(myEmail, widget.recipientEmail);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blocked = await ApiService.getBlockStatus(widget.recipientEmail);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isBlocked) return;
    _ws?.sendMessage(widget.recipientEmail, text);
    _msgCtrl.clear();
  }

  Future<void> _toggleBlock() async {
    try {
      final blocked = await ApiService.toggleBlock(widget.recipientEmail);
      setState(() => _isBlocked = blocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked ? 'User blocked' : 'User unblocked')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myEmail = auth.user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(imageUrl: widget.recipientImageUrl, radius: 18),
            const SizedBox(width: 10),
            Text(widget.recipientUsername),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isBlocked ? Icons.person_add : Icons.block),
            onPressed: _toggleBlock,
            tooltip: _isBlocked ? 'Unblock' : 'Block',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ──────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet.\nSay hello! 👋',
                        textAlign: TextAlign.center))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isMe = msg.senderEmail == myEmail;

                          // Mark as read
                          if (!isMe && !msg.read) {
                            ApiService.markMessageRead(msg.id).ignore();
                          }

                          return _MessageBubble(msg: msg, isMe: isMe);
                        },
                      ),
          ),

          // ── Blocked banner ────────────────────────────
          if (_isBlocked)
            Container(
              color: Colors.red[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('You blocked this user. Unblock to send messages.',
                      style: TextStyle(color: Colors.red)),
                ],
              ),
            ),

          // ── Input ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      enabled: !_isBlocked,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _isBlocked ? 'Blocked' : 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.brown,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isBlocked ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.brown : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white60 : Colors.black38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
