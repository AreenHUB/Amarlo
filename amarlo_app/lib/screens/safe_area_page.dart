// lib/screens/safe_area_page.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../services/notification_service.dart';
import '../widgets/states.dart';
import 'review_screen.dart';

// ── Screenshot prevention via Android FLAG_SECURE ─────────
const _secureChannel = MethodChannel('com.amarlo/secure');

Future<void> _enableSecureMode()  async {
  try { await _secureChannel.invokeMethod('enable');  } catch (_) {}
}
Future<void> _disableSecureMode() async {
  try { await _secureChannel.invokeMethod('disable'); } catch (_) {}
}

class SafeAreaPage extends StatefulWidget {
  final ServiceRequest request;
  final bool isUserBuyer;

  const SafeAreaPage({super.key, required this.request, required this.isUserBuyer});

  @override
  State<SafeAreaPage> createState() => _SafeAreaPageState();
}

class _SafeAreaPageState extends State<SafeAreaPage> {
  // Payment state
  bool _paymentSent      = false;
  bool _workerConfirmed  = false;
  bool _userConfirmed    = false;
  bool _dealCompleted    = false;
  int  _paymentAmount    = 0;
  int  _expectedPrice    = 0;
  bool _fileUploaded     = false;
  bool _hasProofImage    = false;
  bool _isImageFile      = false;
  int?    _proposedPrice;
  String? _priceStatus; // "pending_user_approval" | "confirmed" | "rejected"

  bool _reviewSubmitted  = false;

  bool _loading          = true;
  bool _actionLoading    = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // منع الـ screenshot فقط عند عرض الـ preview (قبل الدفع)
    _enableSecureMode();
    // تسجيل callback — يُعيد التحميل فوراً عند وصول deal_complete أو request_ready
    NotificationManager.instance.registerSafeAreaRefresh(() {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _disableSecureMode();
    NotificationManager.instance.unregisterSafeAreaRefresh();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final status = await ApiService.getPaymentStatus(widget.request.id);
      if (!mounted) return;
      setState(() {
        _paymentSent     = status['payment_received'] ?? false;
        _paymentAmount   = status['amount']           ?? 0;
        _expectedPrice   = status['expected_price']   ?? 0;
        _fileUploaded    = status['file_uploaded']    ?? false;
        _hasProofImage   = status['has_proof_image']  ?? false;
        _isImageFile     = status['is_image']         ?? false;
        _workerConfirmed = status['worker_confirmed'] ?? false;
        _userConfirmed   = status['user_confirmed']   ?? false;
        _dealCompleted   = _workerConfirmed && _userConfirmed;
        _proposedPrice   = status['proposed_price'] as int?;
        _priceStatus     = status['price_status']   as String?;
        _loading         = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Worker: رفع الملف — خطوتان صريحتان ────────────────
  File? _pickedFile;
  String? _pickedFileName;
  bool    _pickedIsImage = false;
  File?   _pickedProof;

  static const _maxUploadBytes = 50 * 1024 * 1024; // 50 MB — matches backend

  Future<void> _pickWorkFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    // Guard against files too large to upload before hitting the network
    if ((picked.size) > _maxUploadBytes) {
      _snack('File is too large. Maximum allowed size is 50 MB.');
      return;
    }

    setState(() {
      _pickedFile     = File(picked.path!);
      _pickedFileName = picked.name;
      _pickedIsImage  = _isImageMime(picked.extension ?? '');
      _pickedProof    = null; // reset proof if file changes
    });
  }

  Future<void> _pickProofImage() async {
    final imgResult = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (imgResult == null) return;
    setState(() => _pickedProof = File(imgResult.path));
  }

  Future<void> _submitUpload() async {
    if (_pickedFile == null) {
      _snack('Please select a file first');
      return;
    }
    if (!_pickedIsImage && _pickedProof == null) {
      _snack('Please add a proof screenshot for non-image files');
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await ApiService.uploadWork(
          widget.request.id, _pickedFile!,
          proofImage: _pickedIsImage ? null : _pickedProof);
      // بعد الرفع الناجح نُعيد تعيين الاختيار
      setState(() {
        _pickedFile = null; _pickedFileName = null;
        _pickedProof = null; _pickedIsImage = false;
      });
      _snack('Work uploaded successfully!');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── User: الدفع ──────────────────────────────────────
  Future<void> _sendPayment() async {
    // المبلغ محدد من سعر الخدمة — لا يُدخله المستخدم يدوياً
    final price = _expectedPrice > 0 ? _expectedPrice : widget.request.servicePrice.toInt();
    if (price <= 0) {
      _snack('Service price is not set');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Send \$$price to escrow?\n\n'
          'The amount will be held securely and released to the worker '
          'only after you both confirm the work.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Pay \$$price'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await ApiService.sendPayment(widget.request.id, price);
      _snack('Payment sent! Held in escrow.');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Worker: اقتراح سعر جديد ─────────────────────────
  Future<void> _proposeNewPrice() async {
    final ctrl = TextEditingController();
    final currentPrice = _expectedPrice > 0
        ? _expectedPrice
        : widget.request.agreedPrice.toInt();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Propose New Price'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current price: \$$currentPrice',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'New price (\$)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The client will be notified and must approve before payment.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Proposal')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final newPrice = int.tryParse(ctrl.text.trim());
    if (newPrice == null || newPrice <= 0) {
      _snack('Enter a valid price');
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await ApiService.proposePriceChange(widget.request.id, newPrice);
      _snack('Price proposal sent to client.');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── User: موافقة/رفض سعر جديد ───────────────────────
  Future<void> _respondToPrice(bool accept) async {
    setState(() => _actionLoading = true);
    try {
      final result =
          await ApiService.confirmPriceChange(widget.request.id, accept);
      _snack(result['message'] as String? ?? (accept ? 'Price accepted!' : 'Price rejected.'));
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Confirm (online) ─────────────────────────────────
  Future<void> _confirmDeal() async {
    setState(() => _actionLoading = true);
    try {
      final result = await ApiService.confirmDeal(widget.request.id);
      final msg = result['message'] as String? ?? '';
      _snack(msg);
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Confirm (in-person) ──────────────────────────────
  Future<void> _confirmInPerson() async {
    setState(() => _actionLoading = true);
    try {
      final result = await ApiService.confirmInPerson(widget.request.id);
      _snack(result['message'] as String? ?? 'Confirmed');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Review — يفتح WorkReviewSheet الجديد ─────────────
  void _openReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => WorkReviewSheet(
        revieweeEmail:          widget.request.workerEmail,
        revieweeUsername:       widget.request.workerUsername.isNotEmpty
            ? widget.request.workerUsername
            : widget.request.workerEmail,
        preselectedRequestId:   widget.request.id,
        preselectedServiceName: widget.request.serviceName,
      ),
    ).then((submitted) {
      if (submitted == true) setState(() => _reviewSubmitted = true);
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  bool _isImageMime(String ext) =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext.toLowerCase());

  String get _previewUrl =>
      '${AppConstants.safeAreaPreviewUrl(widget.request.id)}'
      '?token=${context.read<AuthProvider>().token ?? ''}';

  // Worker يرى الملف الأصلي الذي رفعه (بدون watermark)
  String get _workerPreviewUrl =>
      '${AppConstants.safeAreaWorkerPreviewUrl(widget.request.id)}'
      '?token=${context.read<AuthProvider>().token ?? ''}';

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Safe Area · ${widget.request.serviceName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: widget.request.isInPerson
                    ? _buildInPersonView()
                    : widget.isUserBuyer
                        ? _buildBuyerView()
                        : _buildWorkerView(),
              ),
            ),
    );
  }

  // ════════════════════════════════════════════════════
  //  IN-PERSON VIEW (كلا الطرفين)
  // ════════════════════════════════════════════════════
  Widget _buildInPersonView() {
    final myEmail   = context.read<AuthProvider>().user?.email ?? '';
    final iWorker   = myEmail == widget.request.workerEmail;
    final iConfirmed = iWorker ? _workerConfirmed : _userConfirmed;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بانر توضيحي
      _InfoCard(
        icon: Icons.handshake_outlined,
        color: AppTheme.info,
        title: 'In-Person Service',
        subtitle: 'This service is delivered on-site. '
            'Both parties must confirm completion to close the request.',
      ),
      const SizedBox(height: 20),

      // حالة التأكيدات
      _ConfirmationStatus(
        workerConfirmed: _workerConfirmed,
        userConfirmed:   _userConfirmed,
        dealCompleted:   _dealCompleted,
      ),
      const SizedBox(height: 20),

      if (_dealCompleted) ...[
        const _InfoCard(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Work Completed!',
          subtitle: 'Both parties have confirmed. The deal is closed.',
        ),
        if (widget.isUserBuyer && !_reviewSubmitted) ...[
          const SizedBox(height: 20),
          _buildReviewSection(),
        ],
        if (_reviewSubmitted)
          const _InfoCard(
            icon: Icons.star,
            color: Colors.amber,
            title: 'Review Submitted',
            subtitle: 'Thank you for your feedback!',
          ),
      ] else if (!iConfirmed) ...[
        LoadingButton(
          label: iWorker ? 'Confirm Work Delivered' : 'Confirm Work Received',
          loading: _actionLoading,
          onPressed: _confirmInPerson,
        ),
        const SizedBox(height: 8),
        const Text(
          'The other party will receive a notification to confirm on their side.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ] else ...[
        const _InfoCard(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          title: 'Your Confirmation Recorded',
          subtitle: 'Waiting for the other party to confirm.',
        ),
      ],
    ]);
  }

  // ════════════════════════════════════════════════════
  //  BUYER VIEW (online)
  // ════════════════════════════════════════════════════
  Widget _buildBuyerView() {
    final price = _expectedPrice > 0 ? _expectedPrice : widget.request.servicePrice.toInt();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StatusBanner(
        paymentSent: _paymentSent, dealCompleted: _dealCompleted,
        workerConfirmed: _workerConfirmed, userConfirmed: _userConfirmed,
      ),
      const SizedBox(height: 16),

      // ── Preview ─────────────────────────────────────
      if (_fileUploaded) ...[
        Row(children: [
          const Text('Work Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (!_isImageFile && _hasProofImage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: const Text('Proof Screenshot',
                  style: TextStyle(fontSize: 11, color: AppTheme.info)),
            ),
        ]),
        const SizedBox(height: 4),
        if (!_paymentSent)
          Text(
            _isImageFile
                ? 'Watermarked preview — pay to unlock the original'
                : 'Proof image from worker — verify before paying',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _previewUrl,
            placeholder: (_, __) => Container(
              height: 200, color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Preview not available')),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ] else ...[
        const _InfoCard(
          icon: Icons.hourglass_empty,
          color: Colors.grey,
          title: 'Waiting for Worker',
          subtitle: 'The worker hasn\'t uploaded the work yet.',
        ),
        const SizedBox(height: 20),
      ],

      // ── Price negotiation (User/Buyer) ───────────────
      if (!_paymentSent) ...[
        _buildPriceSection(isWorker: false),
        const SizedBox(height: 12),
      ],

      // ── Payment / Confirm / Download ─────────────────
      if (!_paymentSent && _fileUploaded) ...[
        _InfoCard(
          icon: Icons.attach_money,
          color: AppTheme.primary,
          title: 'Service Price: \$$price',
          subtitle: 'Review the work above, then pay to release to the worker after confirmation.',
        ),
        const SizedBox(height: 12),
        LoadingButton(
          label: 'Send Payment (\$$price)',
          loading: _actionLoading,
          onPressed: _sendPayment,
        ),
      ] else if (_paymentSent && !_dealCompleted) ...[
        _InfoCard(
          icon: Icons.account_balance_wallet,
          color: Colors.green,
          title: 'Payment in Escrow: \$$_paymentAmount',
          subtitle: 'Confirm the work to release payment to the worker.',
        ),
        const SizedBox(height: 12),
        _ConfirmationStatus(
          workerConfirmed: _workerConfirmed, userConfirmed: _userConfirmed,
          dealCompleted: false,
        ),
        const SizedBox(height: 12),
        if (!_userConfirmed)
          LoadingButton(
            label: 'Confirm & Release Payment',
            loading: _actionLoading,
            onPressed: _confirmDeal,
          ),
      ] else if (_dealCompleted) ...[
        const _InfoCard(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Deal Completed!',
          subtitle: 'The original file is now available for download.',
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final token = context.read<AuthProvider>().token ?? '';
            final uri   = Uri.parse(
                '${AppConstants.safeAreaDownloadUrl(widget.request.id)}?token=$token');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _snack('Cannot open download link');
            }
          },
          icon: const Icon(Icons.download),
          label: const Text('Download Original File'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 20),
        if (!_reviewSubmitted)
          _buildReviewSection()
        else
          const _InfoCard(
            icon: Icons.star, color: Colors.amber,
            title: 'Review Submitted', subtitle: 'Thank you for your feedback!',
          ),
      ],
    ]);
  }

  // ════════════════════════════════════════════════════
  //  PRICE NEGOTIATION SECTION
  // ════════════════════════════════════════════════════
  Widget _buildPriceSection({required bool isWorker}) {
    final currentPrice = _expectedPrice > 0
        ? _expectedPrice
        : widget.request.agreedPrice.toInt();

    final hasPending = _priceStatus == 'pending_user_approval';

    // Worker: يرى السعر الحالي + زر لاقتراح سعر جديد
    if (isWorker) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.attach_money, color: Colors.green, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Agreed price: \$$currentPrice',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (hasPending)
                Text('Proposal \$${_proposedPrice ?? 0} sent — waiting for client',
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ]),
          ),
          if (!_paymentSent && !hasPending)
            TextButton.icon(
              onPressed: _proposeNewPrice,
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
        ]),
      );
    }

    // User: يرى اقتراح السعر الجديد مع Approve/Reject
    if (!hasPending || _proposedPrice == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.price_change, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Text('Worker proposes a price change',
              style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Current: \$$currentPrice',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 16),
          Text('Proposed: \$${_proposedPrice!}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
        ]),
        const SizedBox(height: 12),
        _actionLoading
            ? const Center(child: SizedBox(
                height: 24, width: 24,
                child: CircularProgressIndicator(strokeWidth: 2)))
            : Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToPrice(false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: const Text('Keep original'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respondToPrice(true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: Text('Accept \$${_proposedPrice!}'),
                  ),
                ),
              ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════
  //  UPLOAD PANEL — خطوتان صريحتان للـ Worker
  // ════════════════════════════════════════════════════
  Widget _buildUploadPanel() {
    final needsProof = _pickedFile != null && !_pickedIsImage;
    final readyToSubmit =
        _pickedFile != null && (_pickedIsImage || _pickedProof != null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upload Your Work',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Images are shown with a watermark to the client until payment.\n'
          'For other files (code, PDF, ZIP) you must add a proof screenshot.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // ── Step 1: اختيار الملف ─────────────────────────
        _StepRow(
          step: '1',
          label: _pickedFile == null
              ? 'Select the work file'
              : _pickedFileName ?? 'File selected',
          done: _pickedFile != null,
          onTap: _pickWorkFile,
          buttonLabel: _pickedFile == null ? 'Browse' : 'Change',
        ),

        // ── Step 2: proof image (إذا ليس صورة) ───────────
        if (needsProof || (_pickedFile != null && !_pickedIsImage)) ...[
          const SizedBox(height: 10),
          _StepRow(
            step: '2',
            label: _pickedProof == null
                ? 'Add a proof screenshot'
                : 'Proof screenshot selected',
            done: _pickedProof != null,
            onTap: _pickProofImage,
            buttonLabel: _pickedProof == null ? 'Pick Screenshot' : 'Change',
            hint: 'A screenshot showing the completed work',
          ),
        ] else if (_pickedFile != null && _pickedIsImage) ...[
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text('Image file — no proof needed, watermark applied automatically',
                style: TextStyle(color: Colors.green, fontSize: 11)),
          ]),
        ],

        const SizedBox(height: 14),

        // ── Submit ────────────────────────────────────────
        LoadingButton(
          label: _fileUploaded
              ? 'Replace Uploaded Work'
              : 'Upload Work',
          loading: _actionLoading,
          onPressed: readyToSubmit ? _submitUpload : null,
        ),

        if (!readyToSubmit && _pickedFile == null) ...[
          const SizedBox(height: 6),
          const Center(
            child: Text('Select a file above to enable upload',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ════════════════════════════════════════════════════
  //  WORKER VIEW (online)
  // ════════════════════════════════════════════════════
  Widget _buildWorkerView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StatusBanner(
        paymentSent: _paymentSent, dealCompleted: _dealCompleted,
        workerConfirmed: _workerConfirmed, userConfirmed: _userConfirmed,
      ),
      const SizedBox(height: 16),

      // ── Upload Section ───────────────────────────────
      const Text('Upload Your Work',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text(
        'Images: shown with watermark to client until payment.\n'
        'Other files (code, docs): upload a proof screenshot alongside.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 10),

      // ── معاينة الملف المرفوع للـ Worker ─────────────────
      if (_fileUploaded) ...[
        Container(
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('File uploaded successfully',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                // زر مشاهدة الملف كاملاً
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_workerPreviewUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      _snack('Cannot open file');
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View file', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ]),
            ),

            // صورة المعاينة إذا كان صورة
            if (_isImageFile)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: _workerPreviewUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 160,
                    color: Colors.grey[100],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 80,
                    color: Colors.grey[100],
                    child: const Center(
                      child: Text('Tap "View file" to preview',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),
              )
            // proof image أو ملف غير صورة
            else if (_hasProofImage) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: const Text('Proof screenshot (shown to client):',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: _previewUrl, // proof image
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 120,
                    color: Colors.grey[100],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 60, color: Colors.grey[100],
                    child: const Center(
                        child: Text('Tap "View file" above to check',
                            style: TextStyle(color: Colors.grey))),
                  ),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text('Non-image file — tap "View file" to verify.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
          ]),
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.upload_file, color: Colors.grey),
            SizedBox(width: 8),
            Text('No file uploaded yet'),
          ]),
        ),

      const SizedBox(height: 16),

      // ── Price negotiation (Worker) ────────────────────
      _buildPriceSection(isWorker: true),
      const SizedBox(height: 12),

      // ── Upload panel (خطوتان صريحتان) ───────────────────
      if (!_dealCompleted) _buildUploadPanel(),

      const SizedBox(height: 20),

      // ── Payment status ────────────────────────────────
      if (_paymentSent) ...[
        _InfoCard(
          icon: Icons.account_balance_wallet,
          color: Colors.green,
          title: 'Payment in Escrow: \$$_paymentAmount',
          subtitle: 'Will be released when both confirm.',
        ),
        const SizedBox(height: 12),
        _ConfirmationStatus(
          workerConfirmed: _workerConfirmed, userConfirmed: _userConfirmed,
          dealCompleted: _dealCompleted,
        ),
        const SizedBox(height: 12),
        if (!_dealCompleted && !_workerConfirmed)
          LoadingButton(
            label: 'Confirm Delivery',
            loading: _actionLoading,
            onPressed: _confirmDeal,
          ),
        if (_dealCompleted)
          const _InfoCard(
            icon: Icons.check_circle, color: Colors.green,
            title: 'Deal Completed!',
            subtitle: 'Payment will be added to your wallet.',
          ),
      ],
    ]);
  }

  // ── Review section — يفتح WorkReviewSheet الجديد ───────
  Widget _buildReviewSection() {
    return ElevatedButton.icon(
      onPressed: _openReviewSheet,
      icon: const Icon(Icons.star_outline),
      label: const Text('Rate & Review Worker'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: AppTheme.accent,
      ),
    );
  }
}

// ─── Widgets مساعدة ──────────────────────────────────

// ── Step row للـ upload panel ──────────────────────────────
class _StepRow extends StatelessWidget {
  final String step;
  final String label;
  final bool done;
  final VoidCallback onTap;
  final String buttonLabel;
  final String? hint;

  const _StepRow({
    required this.step,
    required this.label,
    required this.done,
    required this.onTap,
    required this.buttonLabel,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Step circle
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: done ? Colors.green : AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(step,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(width: 12),
      // Label + hint
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: done ? Colors.green : Colors.black87)),
          if (hint != null)
            Text(hint!,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
      const SizedBox(width: 8),
      // Button
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
          side: BorderSide(
              color: done ? Colors.green : AppTheme.primary),
          foregroundColor: done ? Colors.green : AppTheme.primary,
        ),
        child: Text(buttonLabel),
      ),
    ]);
  }
}

class _StatusBanner extends StatelessWidget {
  final bool paymentSent;
  final bool dealCompleted;
  final bool workerConfirmed;
  final bool userConfirmed;

  const _StatusBanner({
    required this.paymentSent, required this.dealCompleted,
    required this.workerConfirmed, required this.userConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = dealCompleted
        ? (Colors.green,        Icons.check_circle,   'Deal Completed')
        : (workerConfirmed || userConfirmed)
            ? (Colors.orange,   Icons.hourglass_top,  'Waiting for Both Confirmations')
            : paymentSent
                ? (Colors.blue, Icons.lock_clock,     'Payment in Escrow — Confirm to Release')
                : (Colors.grey, Icons.lock_outline,   'Waiting for Work Upload & Payment');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _ConfirmationStatus extends StatelessWidget {
  final bool workerConfirmed;
  final bool userConfirmed;
  final bool dealCompleted;

  const _ConfirmationStatus({
    required this.workerConfirmed,
    required this.userConfirmed,
    required this.dealCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        confirmRow('Worker confirmed', workerConfirmed),
        const SizedBox(height: 6),
        confirmRow('Client confirmed', userConfirmed),
      ]),
    );
  }

  Widget confirmRow(String label, bool done) => Row(children: [
    Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : Colors.grey, size: 18),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: done ? Colors.green : Colors.grey)),
  ]);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: color.withValues(alpha: 0.05),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    ),
    child: ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    ),
  );
}
