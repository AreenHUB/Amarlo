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
import '../services/notification_service.dart';
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

  // Cached once in _init — never call context.read inside setState
  late String _myEmail;

  // De-dup: tracks message IDs already shown (including tmp_ and sent_ prefixed)
  final Set<String> _seenIds = {};
  // Tracks IDs we've already called markRead for — prevents duplicate API calls
  final Set<String> _markedReadIds = {};

  List<ChatMessage> _messages = [];

  ChatWebSocket? _ws;
  bool _wsConnected     = false;
  bool _isBlocked       = false;
  bool _loading         = true;
  bool _recipientOnline = false;
  bool _showScrollDown  = false;   // new-message badge when scrolled up

  Timer? _presenceTimer;
  String? _error;

  void Function(Map<String, dynamic>)? _notifListener;

  @override
  void initState() {
    super.initState();
    _myEmail = context.read<AuthProvider>().user?.email ?? '';
    NotificationManager.instance.setActiveChatEmail(widget.recipientEmail);
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    NotificationManager.instance.setActiveChatEmail(null);
    _ws?.disconnect();
    _presenceTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    if (_notifListener != null) {
      NotificationManager.instance.removeMessageListener(_notifListener!);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final distFromBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset;
    final shouldShow = distFromBottom > 120;
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }
  }

  // ─── Init ─────────────────────────────────────────────
  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.user == null) {
      if (mounted) setState(() { _loading = false; _error = 'Please login'; });
      return;
    }

    await Future.wait([
      _loadHistory(),
      _checkBlock(),
    ]);

    _notifListener = (data) {
      final type = data['type'] as String? ?? '';

      // New message from recipient: reload silently to get the real message + ID
      if (type == 'new_message') {
        final senderEmail = data['sender_email'] as String? ?? '';
        if (senderEmail != widget.recipientEmail) return;
        if (mounted) _loadHistory(silent: true);
        return;
      }

      // Recipient read our message — flip that bubble's checkmark to blue
      if (type == 'message_read') {
        final messageId = data['message_id'] as String? ?? '';
        final reader    = data['reader']     as String? ?? '';
        if (reader != widget.recipientEmail || messageId.isEmpty) return;
        if (!mounted) return;
        setState(() {
          _messages = _messages.map((m) {
            if (m.id == messageId && m.senderEmail == _myEmail && !m.read) {
              return m.copyWith(read: true);
            }
            return m;
          }).toList();
        });
        return;
      }

      // Recipient presence changed
      if (type == 'presence_change') {
        final email  = data['email']  as String? ?? '';
        final online = data['online'] as bool?   ?? false;
        if (email == widget.recipientEmail && mounted) {
          setState(() => _recipientOnline = online);
        }
      }
    };
    NotificationManager.instance.addMessageListener(_notifListener!);

    if (!mounted) return;
    _ws = ChatWebSocket(
      userEmail: _myEmail,
      token:     auth.token!,
      onConnectionChange: (connected) {
        if (mounted) setState(() => _wsConnected = connected);
      },
      onMessage: _onIncomingMessage,
    )..connect();

    // Presence poll as fallback — real-time via presence_change events
    _checkPresence();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 20),
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
    final pair = {_myEmail, widget.recipientEmail};
    if (!pair.containsAll({msg.senderEmail, msg.recipientEmail})) return;
    if (_seenIds.contains(msg.id)) return;
    _seenIds.add(msg.id);
    if (!mounted) return;

    setState(() {
      if (msg.senderEmail == _myEmail) {
        // Echo from another device — replace matching tmp_ bubble
        final tmpIdx = _messages.indexWhere((m) =>
            m.id.startsWith('tmp_') && m.message == msg.message);
        if (tmpIdx != -1) {
          _seenIds.remove(_messages[tmpIdx].id);
          _messages[tmpIdx] = msg;
        } else {
          _messages.add(msg);
        }
      } else {
        _messages.add(msg);
      }
    });

    // Haptic + markRead outside setState
    if (msg.senderEmail != _myEmail) {
      HapticFeedback.lightImpact();
      _markRead(msg.id);
    }

    // Only auto-scroll if user is already near the bottom
    if (!_showScrollDown) {
      _scheduleScrollToBottom(animated: true);
    }
  }

  // ─── Load history ─────────────────────────────────────
  Future<void> _loadHistory({bool silent = false}) async {
    try {
      final raw = await ApiService.getMessages(_myEmail, widget.recipientEmail);
      if (!mounted) return;

      final parsed = (raw as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      final newIds = parsed.map((m) => m.id).toSet();

      if (silent) {
        // Keep only tmp_ bubbles whose message text is NOT yet in the server
        // response — avoids duplicating confirmed messages
        final pendingTmps = _messages.where((m) =>
            m.id.startsWith('tmp_') &&
            !parsed.any((p) => p.message == m.message)).toList();

        setState(() {
          _seenIds
            ..clear()
            ..addAll(newIds);
          for (final t in pendingTmps) { _seenIds.add(t.id); }
          _messages = [...parsed, ...pendingTmps];
        });
      } else {
        _seenIds
          ..clear()
          ..addAll(newIds);
        setState(() { _messages = parsed; _loading = false; });
        _scheduleScrollToBottom();
      }

      // Mark unread incoming messages — deduplicated with _markedReadIds
      for (final m in parsed) {
        if (!m.read && m.recipientEmail == _myEmail) {
          _markRead(m.id);
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() { _loading = false; _error = e.toString(); });
      }
    }
  }

  // Deduplicated markRead — logs on failure so message_read event fires reliably
  void _markRead(String messageId) {
    if (_markedReadIds.contains(messageId)) return;
    _markedReadIds.add(messageId);
    ApiService.markRead(messageId).catchError((e) {
      _markedReadIds.remove(messageId); // allow retry
    });
  }

  Future<void> _checkBlock() async {
    try {
      final blocked = await ApiService.getBlockStatus(widget.recipientEmail);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  // ─── Scroll ───────────────────────────────────────────
  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(max,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  // ─── Send ─────────────────────────────────────────────
  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isBlocked) return;

    if (!_wsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting... please wait a moment'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final tempId   = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final msgText  = text;
    final optimistic = ChatMessage(
      id:             tempId,
      senderEmail:    _myEmail,
      senderUsername: '',
      recipientEmail: widget.recipientEmail,
      message:        msgText,
      timestamp:      DateTime.now().toUtc().toIso8601String(),
      read:           false,
    );

    final sent = _ws?.sendMessage(widget.recipientEmail, msgText) ?? false;
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _seenIds.add(tempId);
    setState(() => _messages.add(optimistic));
    _scheduleScrollToBottom(animated: true);
    _msgCtrl.clear();
    HapticFeedback.selectionClick();

    // Backend doesn't echo to the sender's own connection.
    // After 600ms, confirm the bubble: clock → single checkmark.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx == -1) return; // already replaced by a server echo or silent reload
      setState(() {
        final confirmed = ChatMessage(
          id:             'sent_${DateTime.now().millisecondsSinceEpoch}',
          senderEmail:    optimistic.senderEmail,
          senderUsername: optimistic.senderUsername,
          recipientEmail: optimistic.recipientEmail,
          message:        msgText,
          timestamp:      optimistic.timestamp,
          read:           false,
        );
        _seenIds.remove(tempId);
        _seenIds.add(confirmed.id);
        _messages[idx] = confirmed;
      });
    });
  }

  Future<void> _toggleBlock() async {
    try {
      final result  = await ApiService.toggleBlock(widget.recipientEmail);
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

    final statusText  = _recipientOnline ? 'Online' : 'Offline';
    final statusColor = _recipientOnline ? Colors.greenAccent : Colors.white38;

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
                statusText,
                key: ValueKey(statusText),
                style: TextStyle(fontSize: 11, color: statusColor),
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
        // Reconnecting banner
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: !_wsConnected && !_loading
              ? Container(
                  color: Colors.orange.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  child: const Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orange),
                    ),
                    SizedBox(width: 8),
                    Text('Reconnecting...',
                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ]),
                )
              : const SizedBox.shrink(),
        ),

        // Messages + scroll-down badge
        Expanded(
          child: Stack(children: [
            _buildBody(auth.user!.email),
            // Scroll-to-bottom badge — shown when user scrolled up
            if (_showScrollDown)
              Positioned(
                bottom: 10, right: 14,
                child: GestureDetector(
                  onTap: () => _scheduleScrollToBottom(animated: true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:     AppTheme.primary,
                      shape:     BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:       Colors.black.withValues(alpha: 0.18),
                          blurRadius:  6,
                          offset:      const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
          ]),
        ),

        // Blocked banner
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

        _buildInput(),
      ]),
    );
  }

  Widget _buildBody(String myEmail) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadHistory,
      );
    }
    if (_messages.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Say hello to ${widget.recipientUsername}!',
              style: const TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg      = _messages[i];
        final isMe     = msg.senderEmail == myEmail;
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
                hintText:  _isBlocked ? 'Blocked' : 'Type a message...',
                filled:    true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:   BorderSide.none,
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
      final a = DateTime.parse(ts1).toLocal();
      final b = DateTime.parse(ts2).toLocal();
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
      final dt        = DateTime.parse(timestamp).toLocal();
      final now       = DateTime.now();
      final today     = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDay    = DateTime(dt.year, dt.month, dt.day);

      if (msgDay == today) {
        label = 'Today';
      } else if (msgDay == yesterday) {
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
                // ⏰  tmp_  → clock    (sending in progress)
                // ✓   sent_ → single   (delivered, not yet read)
                // ✓✓  blue  → double   (read by recipient)
                Icon(
                  isTemp     ? Icons.access_time
                      : msg.read ? Icons.done_all
                      : Icons.done,
                  size: 13,
                  color: isTemp     ? Colors.white38
                      : msg.read    ? Colors.lightBlueAccent
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
