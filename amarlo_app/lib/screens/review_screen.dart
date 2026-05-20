// lib/screens/review_screen.dart
// شاشة التقييم الثنائي: Work Review + Conduct Report
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../core/theme.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';

// ══════════════════════════════════════════════════════
//  Work Review Sheet — بعد عمل مكتمل
//  يُفتح من SafeAreaPage أو RequestsPage
// ══════════════════════════════════════════════════════
class WorkReviewSheet extends StatefulWidget {
  final String revieweeEmail;
  final String revieweeUsername;

  /// إذا عرفنا الـ request مسبقاً نمرره مباشرة
  final String? preselectedRequestId;
  final String? preselectedServiceName;

  const WorkReviewSheet({
    super.key,
    required this.revieweeEmail,
    required this.revieweeUsername,
    this.preselectedRequestId,
    this.preselectedServiceName,
  });

  @override
  State<WorkReviewSheet> createState() => _WorkReviewSheetState();
}

class _WorkReviewSheetState extends State<WorkReviewSheet> {
  final _commentCtrl = TextEditingController();

  double _quality       = 0;
  double _punctuality   = 0;
  double _communication = 0;

  List<ReviewEligibleRequest> _eligibleRequests = [];
  String? _selectedRequestId;
  String? _selectedServiceName;

  bool _loading  = true;
  bool _saving   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedRequestId != null) {
      _selectedRequestId  = widget.preselectedRequestId;
      _selectedServiceName = widget.preselectedServiceName;
      _loading = false;
    } else {
      _fetchEligible();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEligible() async {
    try {
      final result = await ApiService.canReview(widget.revieweeEmail);
      if (!mounted) return;
      final list = (result['eligible_requests'] as List? ?? [])
          .map((e) => ReviewEligibleRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _eligibleRequests = list;
        if (list.length == 1) {
          _selectedRequestId   = list.first.requestId;
          _selectedServiceName = list.first.serviceName;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _submit() async {
    if (_selectedRequestId == null) {
      _snack('Please select which job you are reviewing');
      return;
    }
    if (_quality == 0 || _punctuality == 0 || _communication == 0) {
      _snack('Please rate all three aspects');
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.addWorkReview(
        widget.revieweeEmail,
        requestId:           _selectedRequestId!,
        qualityRating:       _quality.toInt(),
        punctualityRating:   _punctuality.toInt(),
        communicationRating: _communication.toInt(),
        comment:             _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true); // true = submitted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted! Thank you.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 14),

            // Title
            Row(children: [
              const Icon(Icons.star_outline, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review ${widget.revieweeUsername}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Rate your experience working with this person.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text('Error: $_error',
                  style: const TextStyle(color: Colors.red))
            else if (_eligibleRequests.isEmpty &&
                widget.preselectedRequestId == null)
              _NoEligibleWidget(username: widget.revieweeUsername)
            else ...[
              // ── Job selector ────────────────────────────
              if (widget.preselectedRequestId == null &&
                  _eligibleRequests.length > 1) ...[
                const Text('Which job are you reviewing?',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...(_eligibleRequests.map((r) => RadioListTile<String>(
                  value: r.requestId,
                  groupValue: _selectedRequestId,
                  title: Text(r.serviceName,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    r.deliveryType == 'online'
                        ? 'Online delivery'
                        : 'In-person service',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (v) => setState(() {
                    _selectedRequestId   = v;
                    _selectedServiceName = r.serviceName;
                  }),
                ))),
                const Divider(),
              ] else if (_selectedServiceName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.work_outline,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_selectedServiceName!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ── Rating axes ──────────────────────────────
              _RatingAxis(
                label: 'Work Quality',
                icon: Icons.workspace_premium_outlined,
                value: _quality,
                onChanged: (v) => setState(() => _quality = v),
              ),
              const SizedBox(height: 12),
              _RatingAxis(
                label: 'Punctuality',
                icon: Icons.schedule_outlined,
                value: _punctuality,
                onChanged: (v) => setState(() => _punctuality = v),
              ),
              const SizedBox(height: 12),
              _RatingAxis(
                label: 'Communication',
                icon: Icons.chat_bubble_outline,
                value: _communication,
                onChanged: (v) => setState(() => _communication = v),
              ),

              // Overall preview
              if (_quality > 0 && _punctuality > 0 && _communication > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.star, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Overall: ${((_quality + _punctuality + _communication) / 3).toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 14),

              // ── Comment ──────────────────────────────────
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional) ...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // ── Submit ───────────────────────────────────
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppTheme.accent,
                      ),
                      child: const Text('Submit Review'),
                    ),
              const SizedBox(height: 8),

              // ── Conduct report link ──────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      builder: (_) => ConductReportSheet(
                        reportedEmail: widget.revieweeEmail,
                        reportedUsername: widget.revieweeUsername,
                      ),
                    );
                  },
                  icon: const Icon(Icons.flag_outlined,
                      size: 16, color: Colors.grey),
                  label: const Text(
                    'Report unprofessional behaviour instead',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Rating axis widget ────────────────────────────────
class _RatingAxis extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _RatingAxis({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.grey[600]),
      const SizedBox(width: 8),
      SizedBox(
        width: 110,
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: RatingBar.builder(
          initialRating: value,
          minRating: 1,
          itemCount: 5,
          itemSize: 28,
          itemBuilder: (_, __) =>
              const Icon(Icons.star, color: AppTheme.accent),
          onRatingUpdate: onChanged,
          allowHalfRating: false,
          unratedColor: Colors.grey[300],
        ),
      ),
      const SizedBox(width: 4),
      Text(
        value == 0 ? '—' : value.toInt().toString(),
        style: TextStyle(
          color: value == 0 ? Colors.grey : AppTheme.accent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    ]);
  }
}

// ── No eligible requests ──────────────────────────────
class _NoEligibleWidget extends StatelessWidget {
  final String username;
  const _NoEligibleWidget({required this.username});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        const Icon(Icons.star_border, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          'No completed jobs with $username yet',
          style: const TextStyle(
              color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'You can leave a review after completing a request together.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════
//  Conduct Report Sheet — بعد أي تواصل
// ══════════════════════════════════════════════════════
class ConductReportSheet extends StatefulWidget {
  final String reportedEmail;
  final String reportedUsername;

  const ConductReportSheet({
    super.key,
    required this.reportedEmail,
    required this.reportedUsername,
  });

  @override
  State<ConductReportSheet> createState() => _ConductReportSheetState();
}

class _ConductReportSheetState extends State<ConductReportSheet> {
  final Set<String> _selected = {};
  final _detailsCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      _snack('Please select at least one reason');
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.submitConductReport(
        reportedEmail: widget.reportedEmail,
        reasons:       _selected.toList(),
        details:       _detailsCtrl.text.trim().isEmpty
            ? null
            : _detailsCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Our team will review it.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 14),

            Row(children: [
              const Icon(Icons.flag, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report ${widget.reportedUsername}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Select the issue(s) you experienced. '
              'Our team will review this privately.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Reason checkboxes ────────────────────────
            ...kConductReasons.map((reason) => CheckboxListTile(
              value: _selected.contains(reason),
              title: Text(reason, style: const TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: Colors.red,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() {
                v == true ? _selected.add(reason) : _selected.remove(reason);
              }),
            )),

            const SizedBox(height: 10),

            // ── Details ──────────────────────────────────
            TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This report is anonymous. The reported user will not '
              'know who submitted it.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 16),

            _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Report'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.red,
                    ),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
