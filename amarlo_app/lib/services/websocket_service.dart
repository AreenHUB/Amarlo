// lib/services/websocket_service.dart
//
// إدارة اتصالات WebSocket:
//   - ChatWebSocket  → المراسلة الفورية
//   - NotificationWebSocket → الإشعارات وعدد الرسائل غير المقروءة

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

  final String userEmail;
  final String token;

  /// يُستدعى عند وصول رسالة جديدة
  final void Function(ChatMessage message) onMessage;

  /// يُستدعى عند حدوث خطأ
  final void Function(dynamic error)? onError;

  ChatWebSocket({
    required this.userEmail,
    required this.token,
    required this.onMessage,
    this.onError,
  });

  void connect() {
    final url = AppConstants.chatWsUrl(userEmail, token);
    _channel = IOWebSocketChannel.connect(Uri.parse(url));

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'chat_message' || data.containsKey('message')) {
            onMessage(ChatMessage.fromJson(data));
          }
        } catch (_) {}
      },
      onError: (e) {
        onError?.call(e);
        _scheduleReconnect();
      },
      onDone: () => _scheduleReconnect(),
    );
  }

  void sendMessage(String recipientEmail, String message) {
    _channel?.sink.add(jsonEncode({
      'type': 'chat_message',
      'recipient_email': recipientEmail,
      'message': message,
    }));
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _reconnectTimer?.cancel();
  }

  Timer? _reconnectTimer;
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }
}

// ══════════════════════════════════════════════════════
//  Notification WebSocket
// ══════════════════════════════════════════════════════

class NotificationWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final String userEmail;
  final String token;

  /// عدد الرسائل غير المقروءة
  final void Function(int count) onUnreadCount;

  NotificationWebSocket({
    required this.userEmail,
    required this.token,
    required this.onUnreadCount,
  });

  void connect() {
    final url = AppConstants.notificationsWsUrl(userEmail, token);
    _channel = IOWebSocketChannel.connect(Uri.parse(url));

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'unread_count') {
            onUnreadCount(data['count'] as int);
          }
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _reconnectTimer?.cancel();
  }

  Timer? _reconnectTimer;
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }
}

// ══════════════════════════════════════════════════════
//  Request WebSocket (للإشعارات الخاصة بالطلبات)
// ══════════════════════════════════════════════════════

class RequestWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final String token;
  final void Function(Map<String, dynamic> data) onUpdate;

  RequestWebSocket({required this.token, required this.onUpdate});

  void connect() {
    // نستخدم نفس الـ notification socket ونفلتر الأحداث
  }

  void sendRequest(Map<String, dynamic> requestData) {
    _channel?.sink.add(jsonEncode(requestData));
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
  }
}
