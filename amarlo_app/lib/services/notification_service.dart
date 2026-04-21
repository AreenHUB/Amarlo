// lib/services/notification_service.dart
//
// إدارة الإشعارات داخل التطبيق.
// يُرسل إشعارات فورية عند:
//   - وصول رسالة جديدة
//   - قبول/رفض طلب
//   - وصول عرض جديد على منشور
//   - اكتمال صفقة في Safe Area

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

import '../core/constants.dart';
import '../core/theme.dart';

// ══════════════════════════════════════════════
//  Notification model
// ══════════════════════════════════════════════
class AppNotification {
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  AppNotification({
    required this.type,
    required this.title,
    required this.body,
    this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon {
    switch (type) {
      case 'message':      return Icons.chat_bubble;
      case 'request':      return Icons.assignment;
      case 'offer':        return Icons.local_offer;
      case 'accepted':     return Icons.check_circle;
      case 'rejected':     return Icons.cancel;
      case 'payment':      return Icons.payment;
      case 'deal_complete':return Icons.handshake;
      default:             return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'message':      return AppTheme.info;
      case 'accepted':     return AppTheme.success;
      case 'deal_complete':return AppTheme.success;
      case 'rejected':     return AppTheme.error;
      case 'payment':      return AppTheme.warning;
      default:             return AppTheme.primary;
    }
  }
}

// ══════════════════════════════════════════════
//  Notification Manager (singleton)
// ══════════════════════════════════════════════
class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._();
  static NotificationManager get instance => _instance;
  NotificationManager._();

  // All notifications (inbox)
  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  int get unreadCount =>
      _notifications.where((n) => !_read.contains(n.hashCode)).length;

  final Set<int> _read = {};
  bool isRead(AppNotification n) => _read.contains(n.hashCode);

  // Overlay entry for in-app toasts
  OverlayState? _overlay;
  final List<OverlayEntry> _toasts = [];

  // ─── Init ──────────────────────────────────
  void init(OverlayState overlay) {
    _overlay = overlay;
  }

  // ─── Add notification ─────────────────────
  void add(AppNotification notification, {bool showToast = true}) {
    _notifications.add(notification);
    if (showToast && _overlay != null) {
      _showToast(notification);
    }
    notifyListeners();
  }

  void markRead(AppNotification notification) {
    _read.add(notification.hashCode);
    notifyListeners();
  }

  void markAllRead() {
    _read.addAll(_notifications.map((n) => n.hashCode));
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    _read.clear();
    notifyListeners();
  }

  // ─── In-app toast ──────────────────────────
  void _showToast(AppNotification notification) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        notification: notification,
        onDismiss: () {
          entry.remove();
          _toasts.remove(entry);
        },
      ),
    );

    _toasts.add(entry);
    _overlay!.insert(entry);

    // Auto-dismiss after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
        _toasts.remove(entry);
      }
    });
  }

  // ─── Parse WebSocket events ─────────────────
  /// Parses a raw WS message and creates the appropriate notification.
  void handleWsMessage(Map<String, dynamic> data) {
    AppNotification? notif;

    switch (data['type']) {
      case 'new_message':
        notif = AppNotification(
          type: 'message',
          title: 'New Message',
          body: '${data['sender_username']} sent you a message',
          data: data,
        );
        break;
      case 'new_request':
        notif = AppNotification(
          type: 'request',
          title: 'New Service Request',
          body: '${data['user_name']} requested "${data['service_name']}"',
          data: data,
        );
        break;
      case 'request_accepted':
        notif = AppNotification(
          type: 'accepted',
          title: 'Request Accepted! ✅',
          body: 'Your request for "${data['service_name']}" was accepted',
          data: data,
        );
        break;
      case 'request_rejected':
        notif = AppNotification(
          type: 'rejected',
          title: 'Request Declined',
          body: 'Your request for "${data['service_name']}" was declined',
          data: data,
        );
        break;
      case 'new_offer':
        notif = AppNotification(
          type: 'offer',
          title: 'New Offer on Your Post',
          body: '${data['worker_username']} sent an offer for \$${data['price']}',
          data: data,
        );
        break;
      case 'payment_received':
        notif = AppNotification(
          type: 'payment',
          title: 'Payment Received 💰',
          body: '\$${data['amount']} is now held in escrow',
          data: data,
        );
        break;
      case 'deal_complete':
        notif = AppNotification(
          type: 'deal_complete',
          title: 'Deal Completed 🎉',
          body: 'The deal for "${data['service_name']}" is complete!',
          data: data,
        );
        break;
    }

    if (notif != null) add(notif);
  }
}

// ══════════════════════════════════════════════
//  Toast widget
// ══════════════════════════════════════════════
class _ToastWidget extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.notification, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(
            begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.shadowMd,
                  border: Border(
                    left: BorderSide(
                        color: widget.notification.color, width: 4),
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.notification.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.notification.icon,
                        color: widget.notification.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.notification.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(widget.notification.body,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: _dismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Notification Inbox Screen
// ══════════════════════════════════════════════
class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: NotificationManager.instance.markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: NotificationManager.instance,
        builder: (_, __) {
          final notifs = NotificationManager.instance.notifications;
          if (notifs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = notifs[i];
              final isRead = NotificationManager.instance.isRead(n);
              return GestureDetector(
                onTap: () => NotificationManager.instance.markRead(n),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : n.color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.withOpacity(0.2)
                          : n.color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: n.color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(n.icon, color: n.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(n.title,
                                style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 14))),
                            if (!isRead)
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: n.color, shape: BoxShape.circle),
                              ),
                          ]),
                          const SizedBox(height: 3),
                          Text(n.body,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            _timeAgo(n.createdAt),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
