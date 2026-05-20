// lib/services/websocket_service.dart
//
// الإصلاح الجذري:
//   المشكلة: _wsConnected يبقى false حتى تصل رسالة شات حقيقية
//   الحل:
//   1. نُرسل ping فور الاتصال
//   2. Backend يُرسل {"type":"connected"} فور القبول
//   3. نُعيّن _connected=true عند استقبال "connected" أو "pong"
//   4. لا نعتمد على رسالة شات لإثبات الاتصال

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../models/app_models.dart';

// ══════════════════════════════════════════════════════
//  Chat WebSocket
// ══════════════════════════════════════════════════════
class ChatWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _intentionalClose = false;
  bool _connected        = false;
  int  _retryCount       = 0;
  static const _maxRetryDelay = Duration(seconds: 30);

  final String userEmail;
  final String token;
  final void Function(ChatMessage msg) onMessage;
  final void Function(bool connected)? onConnectionChange;

  ChatWebSocket({
    required this.userEmail,
    required this.token,
    required this.onMessage,
    this.onConnectionChange,
  });

  void connect() {
    if (_intentionalClose) return;

    final url = AppConstants.chatWsUrl(userEmail, token);

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        connectTimeout: const Duration(seconds: 10),
      );
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      _onData,
      onError: (_) => _onDisconnected(),
      onDone:  ()  => _onDisconnected(),
    );

    // أرسل ping مباشرة بعد connect لإثبات الاتصال
    _sendPing();

    // Ping دوري كل 25 ثانية للـ keep-alive
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => _sendPing());
  }

  void _onData(dynamic raw) {
    // أي بيانات تصل = الاتصال نجح
    if (!_connected) {
      _connected = true;
      _retryCount = 0;
      onConnectionChange?.call(true);
    }

    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      // تجاهل control messages
      if (type == 'pong' || type == 'ping' || type == 'connected') return;

      // رسائل الشات فقط
      if (data.containsKey('message') &&
          data.containsKey('sender_email') &&
          data.containsKey('recipient_email')) {
        onMessage(ChatMessage.fromJson(data));
      }
    } catch (_) {}
  }

  void _sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {}
  }

  void _onDisconnected() {
    if (_connected) {
      _connected = false;
      onConnectionChange?.call(false);
    }
    _pingTimer?.cancel();
    if (!_intentionalClose) _scheduleReconnect();
  }

  /// يُرجع true إذا أُرسلت، false إذا لم يكن متصلاً بعد
  bool sendMessage(String recipientEmail, String message) {
    if (!_connected) return false;
    try {
      _channel?.sink.add(jsonEncode({
        'type':            'chat_message',
        'recipient_email': recipientEmail,
        'message':         message,
      }));
      return true;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _connected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    // Exponential backoff: 2, 4, 8, 16, 30 ثانية
    _retryCount++;
    final delay = Duration(
      seconds: (_maxRetryDelay.inSeconds).clamp(
        0,
        (2 * (_retryCount)).clamp(2, _maxRetryDelay.inSeconds),
      ),
    );
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalClose) connect();
    });
  }
}

// ══════════════════════════════════════════════════════
//  Notification WebSocket
// ══════════════════════════════════════════════════════
class NotificationWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _intentionalClose = false;
  int  _retryCount       = 0;

  final String userEmail;
  final String token;
  final void Function(int count) onUnreadCount;
  final void Function(Map<String, dynamic> event)? onNotification;

  NotificationWebSocket({
    required this.userEmail,
    required this.token,
    required this.onUnreadCount,
    this.onNotification,
  });

  void connect() {
    if (_intentionalClose) return;

    final url = AppConstants.notificationsWsUrl(userEmail, token);
    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        connectTimeout: const Duration(seconds: 10),
      );
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'unread_count') {
            onUnreadCount((data['count'] as num).toInt());
          } else if (type == 'ping') {
            // استجب بـ pong
            try { _channel?.sink.add(jsonEncode({'type': 'pong'})); } catch (_) {}
          } else if (type != null && type != 'pong' && type != 'connected') {
            onNotification?.call(data);
          }
        } catch (_) {}
      },
      onError: (_) {
        if (!_intentionalClose) _scheduleReconnect();
      },
      onDone: () {
        if (!_intentionalClose) _scheduleReconnect();
      },
    );

    // Keep-alive ping كل 30 ثانية
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {}
    });
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _retryCount++;
    final secs = (2 * _retryCount).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (!_intentionalClose) connect();
    });
  }
}
