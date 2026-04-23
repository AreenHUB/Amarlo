// lib/services/notification_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

// ══════════════════════════════════════════════════════
//  Notification model
// ══════════════════════════════════════════════════════
class AppNotification {
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.type,
    required this.title,
    required this.body,
    this.data,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // new_message لا يُضاف للقائمة - فقط Toast
  bool get isEphemeral => type == 'new_message';

  IconData get icon {
    switch (type) {
      case 'new_message':      return Icons.chat_bubble;
      case 'new_request':      return Icons.assignment_add;
      case 'new_offer':        return Icons.local_offer;
      case 'request_accepted': return Icons.check_circle;
      case 'request_rejected': return Icons.cancel;
      case 'request_ready':    return Icons.inventory_2;
      case 'deal_complete':    return Icons.handshake;
      default:                 return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'new_message':      return AppTheme.info;
      case 'request_accepted': return AppTheme.success;
      case 'request_ready':    return AppTheme.info;
      case 'deal_complete':    return AppTheme.success;
      case 'request_rejected': return AppTheme.error;
      default:                 return AppTheme.primary;
    }
  }
}

// ══════════════════════════════════════════════════════
//  Notification Manager — singleton
// ══════════════════════════════════════════════════════
class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._();
  static NotificationManager get instance => _instance;
  NotificationManager._();

  final List<AppNotification> _notifications = [];
  OverlayState? _overlay;
  BuildContext? _navContext; // للتنقل من الـ Toast

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void init(OverlayState overlay) => _overlay = overlay;

  /// يُسجَّل من NavigationBarPage لإتاحة التنقل
  void setNavContext(BuildContext ctx) => _navContext = ctx;

  // ─── Add ────────────────────────────────────────────
  void add(AppNotification notification, {bool showToast = true}) {
    // new_message: لا يُحفظ في القائمة — فقط Toast لحظي
    if (!notification.isEphemeral) {
      _notifications.add(notification);
      notifyListeners();
    }

    if (showToast && _overlay != null) {
      _showToast(notification);
    }

    // صوت/haptic
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  // ─── Handle WS event ────────────────────────────────
  void handleEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    AppNotification? notif;

    switch (type) {
      case 'new_message':
        // لحظي فقط — لا يُضاف للقائمة
        notif = AppNotification(
          type: 'new_message',
          title: data['sender_username'] ?? 'New Message',
          body:  _trim(data['message']),
          data:  data,
        );
        break;

      case 'new_request':
        notif = AppNotification(
          type: 'new_request',
          title: 'New Service Request',
          body: '${data['user_name'] ?? 'Someone'} requested "${data['service_name'] ?? ''}"',
          data: data,
        );
        break;

      case 'new_offer':
        notif = AppNotification(
          type: 'new_offer',
          title: 'New Offer',
          body: '${data['worker_username'] ?? 'Worker'} offered \$${data['price'] ?? 0}',
          data: data,
        );
        break;

      case 'request_accepted':
        notif = AppNotification(
          type: 'request_accepted',
          title: '✅ Request Accepted',
          body: '"${data['service_name'] ?? ''}" was accepted',
          data: data,
        );
        break;

      case 'request_rejected':
        notif = AppNotification(
          type: 'request_rejected',
          title: 'Request Declined',
          body: '"${data['service_name'] ?? ''}" was declined',
          data: data,
        );
        break;

      case 'request_ready':
        notif = AppNotification(
          type: 'request_ready',
          title: '📦 Work Ready',
          body: '"${data['service_name'] ?? ''}" is ready for review',
          data: data,
        );
        break;

      case 'deal_complete':
        notif = AppNotification(
          type: 'deal_complete',
          title: '🎉 Deal Completed',
          body: '"${data['service_name'] ?? ''}" is complete',
          data: data,
        );
        break;
    }

    if (notif != null) add(notif);
  }

  void markRead(AppNotification n) {
    n.isRead = true;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) { n.isRead = true; }
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }

  // ─── Toast overlay ───────────────────────────────────
  void _showToast(AppNotification notification) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        notification: notification,
        onDismiss: () { if (entry.mounted) entry.remove(); },
        onTap: () {
          if (entry.mounted) entry.remove();
          _handleTap(notification);
        },
      ),
    );
    _overlay!.insert(entry);
    Timer(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  // Callback لفتح ChatScreen — يُسجَّل من الخارج لتجنب circular import
  void Function(String email, String username)? _onChatOpen;

  void registerChatOpener(void Function(String email, String username) opener) {
    _onChatOpen = opener;
  }

  /// عند الضغط على الـ Toast
  void _handleTap(AppNotification n) {
    if (_navContext == null) return;
    final ctx = _navContext!;

    switch (n.type) {
      case 'new_message':
        final senderEmail    = n.data?['sender_email']    as String? ?? '';
        final senderUsername = n.data?['sender_username'] as String? ?? 'User';
        if (senderEmail.isNotEmpty && _onChatOpen != null) {
          _onChatOpen!(senderEmail, senderUsername);
        }
        break;

      default:
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
        );
        break;
    }
  }

  String _trim(dynamic msg) {
    final s = msg?.toString() ?? '';
    return s.length > 80 ? '${s.substring(0, 80)}...' : s;
  }
}

// لا يوجد proxy - يستخدم _onChatTap callback من الخارج

// ══════════════════════════════════════════════════════
//  Toast Widget
// ══════════════════════════════════════════════════════
class _ToastWidget extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  const _ToastWidget({
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double>  _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12, right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragUpdate: (d) { if (d.delta.dy < -3) _dismiss(); },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16, offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border(left: BorderSide(color: n.color, width: 4)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: n.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(n.icon, color: n.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(n.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(n.body,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (n.type == 'new_message')
                        const Text('Tap to open chat',
                            style: TextStyle(
                                color: AppTheme.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: _dismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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

// ══════════════════════════════════════════════════════
//  Notification Inbox Screen (work notifications only)
// ══════════════════════════════════════════════════════
class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
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
            return const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No activity yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 6),
                Text('Work updates will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = notifs[i];
              return GestureDetector(
                onTap: () => NotificationManager.instance.markRead(n),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? Colors.white
                        : n.color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: n.isRead
                          ? Colors.grey.withValues(alpha: 0.2)
                          : n.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: n.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: Icon(n.icon, color: n.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(n.title, style: TextStyle(
                            fontWeight: n.isRead
                                ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ))),
                          if (!n.isRead)
                            Container(width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: n.color, shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 3),
                        Text(n.body, style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(_timeAgo(n.createdAt), style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                      ],
                    )),
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
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60)  return 'Just now';
    if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
    if (d.inHours < 24)    return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
