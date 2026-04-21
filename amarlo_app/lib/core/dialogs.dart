// lib/core/dialogs.dart
import 'package:flutter/material.dart';
import 'theme.dart';

// ══════════════════════════════════════════════
//  Snackbars
// ══════════════════════════════════════════════
void showSuccess(BuildContext context, String message) {
  _show(context, message, AppTheme.success, Icons.check_circle_outline);
}

void showError(BuildContext context, String message) {
  _show(context, message, AppTheme.error, Icons.error_outline);
}

void showInfo(BuildContext context, String message) {
  _show(context, message, AppTheme.info, Icons.info_outline);
}

void showWarning(BuildContext context, String message) {
  _show(context, message, AppTheme.warning, Icons.warning_amber_outlined);
}

void _show(BuildContext context, String message, Color color, IconData icon) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      duration: const Duration(seconds: 3),
    ),
  );
}

// ══════════════════════════════════════════════
//  Confirm dialog
// ══════════════════════════════════════════════
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      title: Text(title, style: AppTheme.h3),
      content: Text(message, style: AppTheme.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AppTheme.error : AppTheme.primary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ══════════════════════════════════════════════
//  Bottom sheet confirm
// ══════════════════════════════════════════════
Future<bool> showBottomConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppTheme.h3),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      destructive ? AppTheme.error : AppTheme.primary,
                ),
                child: Text(confirmLabel),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  return result ?? false;
}
