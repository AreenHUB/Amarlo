// lib/screens/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/websocket_service.dart';
import '../widgets/states.dart';
import '../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String  recipientEmail;
  final String  recipientUsername;
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
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  // De-dup set — منع ظهور الرسالة مرتين
  final Set<String> _seenIds = {};
  List<ChatMessage> _messages = [];

  ChatWebSocket? _ws;
  bool _wsConnected    = false;
  bool _isBlocked      = false;
  bool _loading        = true;
  bool _recipientOnline = false; // presence
  Timer? _presenceTimer;
  String? _error;

  String get _myEmail =>
      context.read<AuthProvider>().user?.email ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _presenceTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Init ─────────────────────────────────────────────
  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.user == null) {
      if (mounted) setState(() { _loading = false; _error = 'Please login'; });
      return;
    }

    // تحميل السجل + فحص الحظر بشكل متوازٍ
    await Future.wait([
      _loadHistory(auth.user!.email),
      _checkBlock(),
    ]);

    // فتح WebSocket
    if (!mounted) return;
    _ws = ChatWebSocket(
      userEmail: auth.user!.email,
      token:     auth.token!,
      onConnectionChange: (connected) {
        if (mounted) setState(() => _wsConnected = connected);
      },
      onMessage: _onIncomingMessage,
    )..connect();

    // Presence polling كل 15 ثانية
    _checkPresence();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkPresence(),
    );
  }

  Future<void> _checkPresence() async {
    try {
      final online = await ApiService.getUserPresence(widget.recipientEmail);
      if (mounted) setState(() => _recipientOnline = online);
    } catch (_) {}
  }

  void _onIncomingMessage(ChatMessage msg) {
    // فقط رسائل هذه المحادثة
    final pair = {_myEmail, widget.recipientEmail};
    if (!pair.containsAll({msg.senderEmail, msg.recipientEmail})) return;
    if (_seenIds.contains(msg.id)) return;
    _seenIds.add(msg.id);

    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom(animated: true);

      if (msg.senderEmail != _myEmail) {
        HapticFeedback.lightImpact();
        ApiService.markRead(msg.id).ignore();
      }
    }
  }

  // ─── Load history ─────────────────────────────────────
  Future<void> _loadHistory(String myEmail) async {
    try {
      final raw = await ApiService.getMessages(myEmail, widget.recipientEmail);
      if (!mounted) return;

      _seenIds.clear();
      final parsed = (raw as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final m in parsed) _seenIds.add(m.id);

      setState(() { _messages = parsed; _loading = false; });

      // mark all unread
      for (final m in parsed) {
        if (!m.read && m.recipientEmail == myEmail) {
          ApiService.markRead(m.id).ignore();
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _checkBlock() async {
    try {
      final blocked = await ApiService.getBlockStatus(widget.recipientEmail);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  // ─── Scroll ───────────────────────────────────────────
  void _scrollToBottom({bool animated = false}) {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (animated) {
      _scrollCtrl.animateTo(max + 80,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scrollCtrl.jumpTo(max + 80);
    }
  }

  // ─── Send ─────────────────────────────────────────────
  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isBlocked) return;

    // Optimistic: أضف الرسالة محلياً فوراً دون انتظار Echo
    final tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id:             tempId,
      senderEmail:    _myEmail,
      senderUsername: '',
      recipientEmail: widget.recipientEmail,
      message:        text,
      timestamp:      DateTime.now().toUtc().toIso8601String(),
      read:           false,
    );
    _seenIds.add(tempId);
    setState(() => _messages.add(optimistic));
    _scrollToBottom(animated: true);

    _ws?.sendMessage(widget.recipientEmail, text);
    _msgCtrl.clear();
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleBlock() async {
    try {
      final result = await ApiService.toggleBlock(widget.recipientEmail);
      final blocked = result['blocked'] == true;
      if (mounted) {
        setState(() => _isBlocked = blocked);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(blocked ? 'User blocked' : 'User unblocked'),
          backgroundColor: blocked ? AppTheme.error : AppTheme.success,
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: EmptyState(
          title: 'Login Required',
          subtitle: 'Please login to start chatting',
          icon: Icons.chat_bubble_outline,
          actionLabel: 'Back',
          onAction: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          UserAvatar(imageUrl: widget.recipientImageUrl, radius: 17),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.recipientUsername,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _recipientOnline ? 'Online' : _wsConnected ? 'Connected' : 'Connecting...',
                key: ValueKey('$_recipientOnline|$_wsConnected'),
                style: TextStyle(
                  fontSize: 11,
                  color: _recipientOnline
                      ? Colors.greenAccent
                      : _wsConnected
                          ? Colors.white70
                          : Colors.white38,
                ),
              ),
            ),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Icon(_isBlocked ? Icons.person_add_outlined : Icons.block_outlined),
            tooltip: _isBlocked ? 'Unblock' : 'Block',
            onPressed: _toggleBlock,
          ),
        ],
      ),
      body: Column(children: [
        // ── Reconnecting banner ───────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: !_wsConnected && !_loading
              ? Container(
                  color: Colors.orange.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  child: Row(children: const [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    ),
                    SizedBox(width: 8),
                    Text('Reconnecting...', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ]),
                )
              : const SizedBox.shrink(),
        ),

        // ── Messages ──────────────────────────────────
        Expanded(child: _buildBody(auth.user!.email)),

        // ── Blocked banner ────────────────────────────
        if (_isBlocked)
          Container(
            color: Colors.red.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(children: [
              Icon(Icons.block, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text('You blocked this user.',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ]),
          ),

        // ── Input ─────────────────────────────────────
        _buildInput(),
      ]),
    );
  }

  Widget _buildBody(String myEmail) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () => _loadHistory(myEmail),
      );
    }
    if (_messages.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Say hello to ${widget.recipientUsername}! 👋',
              style: const TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg    = _messages[i];
        final isMe   = msg.senderEmail == myEmail;
        final showDate = i == 0 ||
            !_sameDay(_messages[i - 1].timestamp, msg.timestamp);
        return Column(children: [
          if (showDate) _DateDivider(msg.timestamp),
          _Bubble(msg: msg, isMe: isMe),
        ]);
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              enabled: !_isBlocked,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              maxLines: 4,
              minLines: 1,
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
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isBlocked ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBlocked ? Colors.grey : AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  bool _sameDay(String ts1, String ts2) {
    try {
      final a = DateTime.parse(ts1);
      final b = DateTime.parse(ts2);
      return a.year == b.year && a.month == b.month && a.day == b.day;
    } catch (_) { return true; }
  }
}

// ── Date Divider ──────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String timestamp;
  const _DateDivider(this.timestamp);

  @override
  Widget build(BuildContext context) {
    String label;
    try {
      final dt  = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        label = 'Today';
      } else if (dt.difference(now).inDays.abs() == 1) {
        label = 'Yesterday';
      } else {
        label = '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) { return const SizedBox.shrink(); }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

// ── Message Bubble ────────────────────────────────────
class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  const _Bubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isTemp = msg.id.startsWith('tmp_');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg.message,
                style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_time(msg.timestamp),
                  style: TextStyle(
                      color: isMe ? Colors.white60 : Colors.black38,
                      fontSize: 10)),
              if (isMe) ...[
                const SizedBox(width: 4),
                // isTemp = optimistic (لم يُؤكَّد بعد) → ساعة
                // read   → double check أزرق
                // sent   → single check
                Icon(
                  isTemp
                      ? Icons.access_time
                      : msg.read
                          ? Icons.done_all
                          : Icons.done,
                  size: 13,
                  color: isTemp
                      ? Colors.white38
                      : msg.read
                          ? Colors.lightBlueAccent
                          : Colors.white60,
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  String _time(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
