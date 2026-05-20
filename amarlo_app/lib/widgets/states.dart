// lib/widgets/states.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/notification_service.dart'; // NotificationIconButton

// ══════════════════════════════════════════════
//  Error State
// ══════════════════════════════════════════════
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: AppTheme.h3.copyWith(color: AppTheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Empty State
// ══════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTheme.h3.copyWith(color: Colors.grey[700])),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: Colors.grey[500]),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Status Badge
// ══════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge(this.status, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Info Banner
// ══════════════════════════════════════════════
class InfoBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const InfoBanner({
    super.key,
    required this.message,
    this.color = AppTheme.info,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Loading Button (shows spinner while loading)
// ══════════════════════════════════════════════
class LoadingButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double minWidth;

  const LoadingButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
    this.icon,
    this.color,
    this.minWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: minWidth,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: Size(minWidth, 50),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : icon != null
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ])
                : Text(label),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Section header
// ══════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.h3),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Animated fade + slide in
// ══════════════════════════════════════════════
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ══════════════════════════════════════════════
//  Pull-to-refresh wrapper with nice indicator
// ══════════════════════════════════════════════
class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AppRefreshIndicator(
      {super.key, required this.child, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      child: child,
    );
  }
}

// ══════════════════════════════════════════════
//  NotificationIconButton — AppBar action مشترك
// ══════════════════════════════════════════════
class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationManager.instance,
      builder: (_, __) {
        final count = NotificationManager.instance.unreadCount;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationInboxScreen(),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
