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
      case 'new_message':               return Icons.chat_bubble;
      case 'new_request':               return Icons.assignment_add;
      case 'new_offer':                 return Icons.local_offer;
      case 'request_accepted':          return Icons.check_circle;
      case 'request_rejected':          return Icons.cancel;
      case 'request_ready':             return Icons.inventory_2;
      case 'deal_complete':             return Icons.handshake;
      case 'offer_you_accepted_confirmed': return Icons.check_circle_outline;
      case 'price_change_proposed':        return Icons.price_change;
      case 'price_change_accepted':        return Icons.attach_money;
      case 'price_change_rejected':        return Icons.money_off;
      case 'safe_area_opened':             return Icons.lock_open;
      case 'safe_area_session_invite':     return Icons.description_outlined;
      case 'safe_area_session_accepted': return Icons.verified;
      case 'safe_area_session_rejected': return Icons.cancel_outlined;
      case 'offer_accepted_set_deadline':
      case 'offer_accepted_inperson':    return Icons.check_circle_outline;
      case 'deadline_proposed':          return Icons.schedule;
      case 'deadline_confirmed':         return Icons.lock_open;
      case 'deadline_rejected':          return Icons.schedule_send;
      case 'work_uploaded':              return Icons.upload_file;
      case 'payment_received':           return Icons.payments;
      case 'worker_confirmed_waiting':
      case 'user_confirmed_waiting':     return Icons.how_to_vote_outlined;
      default:                           return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'new_message':               return AppTheme.info;
      case 'request_accepted':
      case 'offer_accepted_set_deadline':
      case 'offer_accepted_inperson':
      case 'deadline_confirmed':
      case 'safe_area_session_accepted':
      case 'offer_you_accepted_confirmed':
      case 'safe_area_opened':           return AppTheme.success;
      case 'safe_area_session_invite':   return AppTheme.primary;
      case 'safe_area_session_rejected':
      case 'price_change_rejected':      return AppTheme.error;
      case 'price_change_proposed':      return Colors.orange;
      case 'price_change_accepted':      return AppTheme.success;
      case 'request_ready':
      case 'deadline_proposed':         return AppTheme.info;
      case 'deal_complete':             return AppTheme.success;
      case 'request_rejected':
      case 'deadline_rejected':          return AppTheme.error;
      case 'work_uploaded':              return AppTheme.info;
      case 'payment_received':           return AppTheme.success;
      case 'worker_confirmed_waiting':
      case 'user_confirmed_waiting':     return Colors.orange;
      default:                           return AppTheme.primary;
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

  static const _maxNotifications = 50;

  final List<AppNotification> _notifications = [];
  OverlayState? _overlay;

  // الـ email للمحادثة المفتوحة حالياً — لكبح Toast رسائلها
  String? _activeChatEmail;

  void setActiveChatEmail(String? email) => _activeChatEmail = email;

  // listeners للـ chat messages (من ChatScreen)
  final List<void Function(Map<String, dynamic>)> _messageListeners = [];

  void addMessageListener(void Function(Map<String, dynamic>) fn) {
    _messageListeners.add(fn);
  }

  void removeMessageListener(void Function(Map<String, dynamic>) fn) {
    _messageListeners.remove(fn);
  }

  // callback يُسجَّل من NavigationBarPage لإعادة تحميل الطلبات فوراً
  // عند وصول أي event متعلق بالطلبات (accept, reject, ready, complete)
  VoidCallback? _onRequestsChanged;

  void registerRequestsRefresh(VoidCallback fn) => _onRequestsChanged = fn;

  // callback يُسجَّل من SafeAreaPage لإعادة تحميلها فوراً
  VoidCallback? _onSafeAreaChanged;

  void registerSafeAreaRefresh(VoidCallback fn) => _onSafeAreaChanged = fn;
  void unregisterSafeAreaRefresh() => _onSafeAreaChanged = null;

  // callback يُسجَّل من DashboardScreen لإعادة تحميل الـ offers فوراً
  VoidCallback? _onOffersChanged;

  void registerOffersRefresh(VoidCallback fn) => _onOffersChanged = fn;
  void unregisterOffersRefresh() => _onOffersChanged = null;

  // ── D1: تجميع إشعارات الـ Offers (debounce 5 دقائق) ──
  Timer? _offerBatchTimer;
  int    _pendingOfferCount = 0;
  String _lastOfferPostTitle = '';

  void _handleNewOffer(Map<String, dynamic> data) {
    _onOffersChanged?.call();
    _pendingOfferCount++;
    _lastOfferPostTitle = data['post_title'] as String? ?? '';

    _offerBatchTimer?.cancel();

    if (_pendingOfferCount == 1) {
      // أول offer → إشعار فوري
      add(AppNotification(
        type: 'new_offer',
        title: 'New Offer',
        body: '${data['worker_username'] ?? 'Worker'} offered '
            '\$${data['price'] ?? 0} on "$_lastOfferPostTitle"',
        data: data,
      ));
    } else {
      // offers لاحقة → انتظر 5 دقائق ثم أرسل ملخصاً
      _offerBatchTimer = Timer(const Duration(minutes: 5), () {
        final count = _pendingOfferCount;
        _pendingOfferCount = 0;
        add(AppNotification(
          type: 'new_offer',
          title: '$count New Offers',
          body: 'You received $count new offers on "$_lastOfferPostTitle"',
          data: data,
        ));
      });
    }
  }

  // callback يُسجَّل من NavigationBarPage للتنقل عند الضغط على الإشعار
  // يستقبل نوع الإشعار ويتولى التوجيه الصحيح
  void Function(String type, Map<String, dynamic>? data)? _onNotifTap;

  void registerNotifTapHandler(
      void Function(String type, Map<String, dynamic>? data) fn) {
    _onNotifTap = fn;
  }

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // عدد الرسائل غير المقروءة — يُحدَّث من NotificationWebSocket الرئيسي
  int _unreadMessageCount = 0;
  int get unreadMessageCount => _unreadMessageCount;

  void updateUnreadMessageCount(int count) {
    if (_unreadMessageCount == count) return;
    _unreadMessageCount = count;
    notifyListeners();
  }

  void init(OverlayState overlay) => _overlay = overlay;

  void setNavContext(BuildContext ctx) {} // no-op — navigation via callbacks now

  // ─── Alert feedback ─────────────────────────────────
  // Notification types that warrant a stronger alert (vibration + sound)
  static const _highPriorityTypes = {
    'new_request',
    'new_offer',
    'request_accepted',
    'request_rejected',
    'request_ready',
    'deal_complete',
    'deadline_proposed',
    'deadline_confirmed',
    'deadline_rejected',
    'payment_received',
    'work_uploaded',
    'safe_area_opened',
    'safe_area_session_invite',
    'worker_confirmed_waiting',
    'user_confirmed_waiting',
  };

  void _playAlert(AppNotification notification) {
    try {
      if (_highPriorityTypes.contains(notification.type)) {
        // Strong feedback: double vibration pulse + system alert sound
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        Future.delayed(const Duration(milliseconds: 120), () {
          HapticFeedback.mediumImpact();
        });
      } else {
        // Soft feedback: single light vibration for chat messages etc.
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {}
  }

  // ─── Add ────────────────────────────────────────────
  void add(AppNotification notification, {bool showToast = true}) {
    if (!notification.isEphemeral) {
      _notifications.add(notification);
      // حد أقصى 50 — احذف الأقدم عند التجاوز
      if (_notifications.length > _maxNotifications) {
        _notifications.removeAt(0);
      }
      notifyListeners();
    }

    if (showToast && _overlay != null) {
      _showToast(notification);
    }

    _playAlert(notification);
  }

  // ─── Delete ──────────────────────────────────────────
  void remove(AppNotification n) {
    _notifications.remove(n);
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  // ─── Handle WS event ────────────────────────────────
  void handleEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    AppNotification? notif;

    switch (type) {
      case 'new_message':
        // أبلغ أي ChatScreen مفتوحة أولاً
        for (final fn in List.of(_messageListeners)) {
          fn(data);
        }
        // لا تُظهر Toast إذا كان المستخدم في محادثة مع نفس المُرسِل
        final senderEmail = data['sender_email'] as String? ?? '';
        if (senderEmail == _activeChatEmail) break;
        notif = AppNotification(
          type: 'new_message',
          title: data['sender_username'] ?? 'New Message',
          body:  _trim(data['message']),
          data:  data,
        );
        break;

      case 'new_request':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'new_request',
          title: 'New Service Request',
          body: '${data['user_name'] ?? 'Someone'} requested "${data['service_name'] ?? ''}"',
          data: data,
        );
        break;

      case 'new_offer':
        _handleNewOffer(data);
        return; // _handleNewOffer يتولى الـ add بنفسه

      case 'request_accepted':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'request_accepted',
          title: 'Request Accepted',
          body: '"${data['service_name'] ?? ''}" was accepted',
          data: data,
        );
        break;

      case 'request_rejected':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'request_rejected',
          title: 'Request Declined',
          body: '"${data['service_name'] ?? ''}" was declined',
          data: data,
        );
        break;

      case 'request_ready':
        _onRequestsChanged?.call();
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'request_ready',
          title: 'Work Ready',
          body: '"${data['service_name'] ?? ''}" is ready for review',
          data: data,
        );
        break;

      case 'deal_complete':
        _onRequestsChanged?.call();
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'deal_complete',
          title: 'Deal Completed',
          body: '"${data['service_name'] ?? ''}" is complete',
          data: data,
        );
        break;

      case 'safe_area_session_invite':
        notif = AppNotification(
          type: 'safe_area_session_invite',
          title: 'Contract Invitation',
          body: '${data['worker_name'] ?? 'Worker'} sent you a Safe Area '
              'contract for "${data['title'] ?? ''}". '
              'Expires in ${data['expires_in_hrs'] ?? 6}h.',
          data: data,
        );
        break;

      case 'safe_area_session_accepted':
        notif = AppNotification(
          type: 'safe_area_session_accepted',
          title: 'Contract Accepted!',
          body: '${data['user_name'] ?? 'Client'} accepted your contract '
              '"${data['title'] ?? ''}". You can now start working.',
          data: data,
        );
        break;

      case 'safe_area_session_rejected':
        notif = AppNotification(
          type: 'safe_area_session_rejected',
          title: 'Contract Rejected',
          body: '${data['user_name'] ?? 'Client'} rejected the contract.',
          data: data,
        );
        break;

      case 'price_change_proposed':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'price_change_proposed',
          title: 'New Price Proposed',
          body: '${data['worker_username'] ?? 'Worker'} proposes '
              '\$${data['new_price'] ?? 0} (was \$${data['old_price'] ?? 0}) '
              'for "${data['service_name'] ?? ''}". Tap to review.',
          data: data,
        );
        break;

      case 'price_change_accepted':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'price_change_accepted',
          title: 'Price Change Accepted!',
          body: 'New price \$${data['new_price'] ?? 0} confirmed for '
              '"${data['service_name'] ?? ''}".',
          data: data,
        );
        break;

      case 'price_change_rejected':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'price_change_rejected',
          title: 'Price Change Rejected',
          body: 'Client kept the original price for '
              '"${data['service_name'] ?? ''}".',
          data: data,
        );
        break;

      case 'offer_you_accepted_confirmed':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'offer_you_accepted_confirmed',
          title: 'Offer Accepted!',
          body: 'You accepted ${data['worker_username'] ?? 'Worker'}\'s offer on '
              '"${data['service_name'] ?? ''}". '
              'Waiting for them to set a delivery deadline.',
          data: data,
        );
        break;

      case 'safe_area_opened':
        _onRequestsChanged?.call();
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'safe_area_opened',
          title: 'Safe Area Is Now Open!',
          body: 'The worker will upload their work for '
              '"${data['service_name'] ?? ''}". '
              'You\'ll be notified when it\'s ready to review.',
          data: data,
        );
        break;

      case 'offer_accepted_set_deadline':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'offer_accepted_set_deadline',
          title: 'Offer Accepted!',
          body: '${data['user_name'] ?? 'User'} accepted your offer on '
              '"${data['service_name'] ?? ''}". '
              'You have 6 hours to propose a delivery deadline.',
          data: data,
        );
        break;

      case 'offer_accepted_inperson':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'offer_accepted_inperson',
          title: 'Offer Accepted!',
          body: '${data['user_name'] ?? 'User'} accepted your offer on '
              '"${data['service_name'] ?? ''}". '
              'Open chat to coordinate the in-person meeting.',
          data: data,
        );
        break;

      case 'deadline_proposed':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'deadline_proposed',
          title: 'Deadline Proposed — Action Required',
          body: '${data['worker_name'] ?? 'Worker'} proposed a delivery deadline '
              'for "${data['service_name'] ?? ''}". '
              'You have 6 hours to approve or reject it.',
          data: data,
        );
        break;

      case 'deadline_confirmed':
        _onRequestsChanged?.call();
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'deadline_confirmed',
          title: 'Deadline Confirmed — Safe Area Active!',
          body: '${data['user_name'] ?? 'Client'} approved the deadline for '
              '"${data['service_name'] ?? ''}". '
              'Safe Area is now open. Upload your work.',
          data: data,
        );
        break;

      case 'deadline_rejected':
        _onRequestsChanged?.call();
        notif = AppNotification(
          type: 'deadline_rejected',
          title: 'Deadline Rejected',
          body: '${data['user_name'] ?? 'Client'} rejected your proposed deadline '
              'for "${data['service_name'] ?? ''}". '
              'Propose a new deadline.',
          data: data,
        );
        break;

      case 'work_uploaded':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'work_uploaded',
          title: 'Work Uploaded — Review Required',
          body: '${data['worker_username'] ?? 'Worker'} uploaded the work for '
              '"${data['service_name'] ?? ''}". '
              'Review it and send payment to unlock the original file.',
          data: data,
        );
        break;

      case 'payment_received':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'payment_received',
          title: 'Payment Received!',
          body: '${data['user_username'] ?? 'Client'} sent \$${data['amount'] ?? 0} '
              'for "${data['service_name'] ?? ''}". '
              'Confirm the delivery to release the funds.',
          data: data,
        );
        break;

      case 'worker_confirmed_waiting':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'worker_confirmed_waiting',
          title: 'Worker Confirmed — Your Turn',
          body: '${data['worker_username'] ?? 'Worker'} confirmed the delivery of '
              '"${data['service_name'] ?? ''}". '
              'Please confirm to complete the deal.',
          data: data,
        );
        break;

      case 'user_confirmed_waiting':
        _onSafeAreaChanged?.call();
        notif = AppNotification(
          type: 'user_confirmed_waiting',
          title: 'Client Confirmed — Your Turn',
          body: '${data['user_username'] ?? 'Client'} confirmed the delivery of '
              '"${data['service_name'] ?? ''}". '
              'Please confirm to release the payment.',
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
    if (n.type == 'new_message') {
      final senderEmail    = n.data?['sender_email']    as String? ?? '';
      final senderUsername = n.data?['sender_username'] as String? ?? 'User';
      if (senderEmail.isNotEmpty && _onChatOpen != null) {
        _onChatOpen!(senderEmail, senderUsername);
      }
      return;
    }

    // كل الـ events الأخرى تُعالَج من NavigationBarPage
    _onNotifTap?.call(n.type, n.data);
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
          ListenableBuilder(
            listenable: NotificationManager.instance,
            builder: (_, __) {
              final hasAny = NotificationManager.instance.notifications.isNotEmpty;
              final hasUnread = NotificationManager.instance.unreadCount > 0;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                if (hasUnread)
                  TextButton(
                    onPressed: NotificationManager.instance.markAllRead,
                    child: const Text('Mark all read',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                if (hasAny)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: () => _confirmClearAll(context),
                  ),
              ]);
            },
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
              return Dismissible(
                key: ValueKey(n.createdAt.microsecondsSinceEpoch),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => NotificationManager.instance.remove(n),
                child: GestureDetector(
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NotificationManager.instance.clearAll();
            },
            child: const Text('Clear all',
                style: TextStyle(color: Colors.red)),
          ),
        ],
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
