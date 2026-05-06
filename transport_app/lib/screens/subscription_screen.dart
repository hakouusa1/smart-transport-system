import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_plan_service.dart';
import '../services/supabase_storage_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';
import '../widgets/notif_listener.dart';
import 'main_screen.dart';
import 'reduce_buses_screen.dart';




class SubscriptionScreen extends StatefulWidget {
  final String? initialPlanId;
  final String? initialStatus;
  final bool isChangingPlan;
  const SubscriptionScreen({
    super.key,
    this.initialPlanId,
    this.initialStatus,
    this.isChangingPlan = false,
  });
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _status;
  String _planId = 'starter';
  String? _rejectionReason;
  bool _loading = true;
  bool _isSubmitting = false;
  bool _isUploading = false;
  StreamSubscription<DocumentSnapshot>? _statusSub;
  bool _navigated = false;

  List<SubscriptionPlan> _plans = SubscriptionPlan.defaults;

  // Receipt upload state
  File? _receiptFile;
  Uint8List? _receiptBytes;
  final TextEditingController _refNumberController = TextEditingController();

  String _ccpAccount   = '0000000123 45';
  String _baridimobRip = '007 99999 1234567890 12';

  SubscriptionPlan get _currentPlan => _plans.firstWhere(
        (p) => p.id == _planId || p.name.toLowerCase() == _planId.toLowerCase(),
        orElse: () => _plans.isNotEmpty ? _plans.first : SubscriptionPlan.defaults.first,
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialPlanId != null) {
      _planId = widget.initialPlanId!;
      _status = widget.initialStatus ?? 'not_subscribed';
      _loading = false;
    } else {
      _loadStatus();
    }
    _loadPaymentConfig();
    _loadPlans();
    _listenForApproval();
  }

  Future<void> _loadPlans() async {
    final plans = await SubscriptionPlanService.fetchPlans();
    if (mounted) setState(() => _plans = plans);
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('payment_info')
          .get();
      final data = doc.data();
      if (mounted && data != null) {
        setState(() {
          _ccpAccount   = data['ccpAccount']   as String? ?? '0000000123 45';
          _baridimobRip = data['baridimobRip'] as String? ?? '007 99999 1234567890 12';
        });
      }
    } catch (_) {}
  }

  void _listenForApproval() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _statusSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || _navigated) return;
      final data = snap.data()!;
      final newStatus = data['subscriptionStatus'] ?? '';
      if (newStatus == 'active') {
        // When changing plan, only navigate once the new payment has been
        // approved (i.e. we've already seen a pending_verification state).
        // This prevents immediately redirecting an already-active user away.
        final canNavigate =
            !widget.isChangingPlan || _status == 'pending_verification';
        if (canNavigate) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateAfterActivation(uid, data);
          });
        }
      } else if (mounted && newStatus != _status) {
        setState(() {
          _status = newStatus;
          _rejectionReason = data['rejectionReason'] as String?;
          _loading = false;
        });
      }
    });
  }

  /// After the plan becomes active, check if the user has more buses than the
  /// new plan allows. If so, redirect to ReduceBusesScreen instead of MainScreen.
  Future<void> _navigateAfterActivation(
      String uid, Map<String, dynamic> userData) async {
    if (!mounted) return;

    try {
      final planId =
          ((userData['subscription'] as String?) ?? 'starter').toLowerCase();

      int maxBuses = 0;
      String planName = planId;

      final planDoc = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .doc(planId)
          .get();

      if (planDoc.exists) {
        final p = planDoc.data()!;
        maxBuses = (p['maxBuses'] as num?)?.toInt() ?? 0;
        planName = (p['name'] as String?) ?? planId;
      } else {
        final fallback = _plans.firstWhere(
          (p) => p.id == planId,
          orElse: () => _plans.isNotEmpty ? _plans.first : SubscriptionPlan.defaults.first,
        );
        maxBuses = fallback.maxBuses;
        planName = fallback.name;
      }

      if (maxBuses > 0 && mounted) {
        final busSnap = await FirebaseFirestore.instance
            .collection('buses')
            .where('ownerId', isEqualTo: uid)
            .get();

        if (busSnap.docs.length > maxBuses && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ReduceBusesScreen(
                planLimit: maxBuses,
                planName: planName,
              ),
            ),
            (route) => false,
          );
          return;
        }
      }
    } catch (_) {
      // On any error fall through to MainScreen
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const NotifListener(child: MainScreen())),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _refNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      final data = doc.data();
      setState(() {
        _status = data?['subscriptionStatus'] ?? 'not_subscribed';
        _planId = data?['subscription'] ?? 'starter';
        _rejectionReason = data?['rejectionReason'] as String?;
        _loading = false;
      });
    }
  }

  void _copy(String text) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.copied),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: context.appGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Receipt Image Picker ────────────────────────────────────────────────
  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      if (mounted) {
        setState(() {
          _receiptFile = file;
          _receiptBytes = bytes;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).receiptSelected),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.appGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).uploadError),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.appRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  // ── Upload receipt to Supabase & create Firestore record ────────────────
  Future<void> _uploadAndSubmit() async {
    if (_isSubmitting || _isUploading) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final refNum = _refNumberController.text.trim();
    if (uid == null || _receiptBytes == null || refNum.isEmpty) return;

    if (mounted) setState(() { _isSubmitting = true; _isUploading = true; });

    try {
      // 1. Rate-limit check: max 3 submissions per 24 hours
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 24)));
      final recentSnap = await FirebaseFirestore.instance
          .collection('payment_requests')
          .where('ownerId', isEqualTo: uid)
          .where('createdAt', isGreaterThan: cutoff)
          .get();
      if (recentSnap.size >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).tooManyRequests),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.appOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.all(16),
          ));
        }
        return;
      }

      // 2. Upload to Supabase payment_receipts bucket
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$uid/receipt_$timestamp.jpg';
      final url = await SupabaseStorageService.uploadReceipt(
        _receiptBytes!,
        storagePath,
      );

      // 3. Atomic Firestore write: create payment_request + update user status
      final db = FirebaseFirestore.instance;
      final reqRef = db.collection('payment_requests').doc();
      final now = Timestamp.now();
      final batch = db.batch();

      batch.set(reqRef, {
        'id': reqRef.id,
        'ownerId': uid,
        'planId': _planId,
        'receiptUrl': url,
        'refNumber': refNum,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      batch.update(db.collection('users').doc(uid), {
        'subscriptionStatus': 'pending_verification',
        'subscription': _planId,
        'updatedAt': now,
      });

      await batch.commit();

      if (mounted) {
        setState(() => _status = 'pending_verification');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).receiptUploaded),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.appGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).uploadError}: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.appRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() { _isSubmitting = false; _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: context.appBg, body: Center(child: BusLoadingIndicator(color: context.appPurple, strokeWidth: 2.5)));
    if (_status == 'active') return Scaffold(body: Center(child: BusLoadingIndicator()));
    if (_status == 'pending_verification') return _buildPending();
    if (_status == 'rejected') return _buildRejected();
    return _buildSubscribe();
  }

  Widget _buildSubscribe() {
    final l10n = AppLocalizations.of(context);
    final plan = _currentPlan;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SingleChildScrollView(child: Column(children: [
        // Dynamic Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [plan.color.withValues(alpha: 0.8), plan.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
          ),
          child: Column(children: [
            if (Navigator.canPop(context))
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Container(width: 60, height: 60,
              decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 32)),
            const SizedBox(height: 16),
            Text(l10n.planNameFmt(plan.name), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Text('${plan.price} / ${plan.durationDays} j', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ),
        const SizedBox(height: 24),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          // Plan Features Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.appBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.planIncludesLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.appText)),
              const SizedBox(height: 16),
              ...plan.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.check_circle, color: plan.color, size: 18),
                  const SizedBox(width: 10),
                  Text(f, style: TextStyle(color: context.appText)),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // CCP Account
          _AccountCard(
            title: l10n.ccpAccountLabel,
            account: _ccpAccount,
            icon: Icons.account_balance,
            onCopy: () => _copy(_ccpAccount),
          ),
          const SizedBox(height: 12),

          // BaridiMob RIP
          _AccountCard(
            title: l10n.baridimobRipLabel,
            account: _baridimobRip,
            icon: Icons.phone_android,
            onCopy: () => _copy(_baridimobRip),
          ),
          const SizedBox(height: 20),

          // ── Transaction Reference ───────────────────────────────────────
          TextField(
            controller: _refNumberController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.refNumberHint,
              prefixIcon: Icon(Icons.numbers, color: context.appSub),
              filled: true,
              fillColor: context.appCardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.appBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.appBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.appPurple, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Receipt Upload Section ──────────────────────────────────────
          _buildReceiptUploadCard(l10n),
          const SizedBox(height: 28),

          // Confirm & upload button
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: (_isSubmitting || _receiptFile == null || _refNumberController.text.trim().isEmpty) ? null : () => _confirmSent(),
            style: ElevatedButton.styleFrom(
              backgroundColor: (_receiptFile != null && _refNumberController.text.trim().isNotEmpty) ? context.appGreen : context.appSub.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: context.appSub.withValues(alpha: 0.15),
              disabledForegroundColor: context.appSub,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isSubmitting
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : Text(l10n.iSentReceipt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 12),

          // Logout
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: Text(l10n.logoutTitle, style: TextStyle(color: context.appSub)),
          ),
          const SizedBox(height: 32),
        ])),
      ])),
    );
  }

  // ── Receipt upload card with picker & preview ─────────────────────────
  Widget _buildReceiptUploadCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _receiptFile != null
              ? context.appGreen.withValues(alpha: 0.5)
              : context.appBorder,
          width: _receiptFile != null ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        // Header row
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: context.appPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.receipt_long, color: context.appPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              l10n.uploadReceipt,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
            ),
            const SizedBox(height: 2),
            Text(
              _receiptFile != null ? l10n.receiptSelected : l10n.sendReceiptTo,
              style: TextStyle(
                fontSize: 12,
                color: _receiptFile != null ? context.appGreen : context.appSub,
                fontWeight: _receiptFile != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ])),
          if (_receiptFile != null)
            Icon(Icons.check_circle, color: context.appGreen, size: 22),
        ]),

        const SizedBox(height: 16),

        // Image preview or picker button
        if (_receiptFile != null) ...[
          // Image preview with tap-to-change
          GestureDetector(
            onTap: _pickReceiptImage,
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _receiptFile!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              // Overlay hint
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.edit, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(l10n.tapToChangeReceipt,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ]),
          ),
        ] else ...[
          // Select receipt button
          GestureDetector(
            onTap: _pickReceiptImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: context.appPurple.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.appPurple.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: context.appPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined,
                    color: context.appPurple, size: 24),
                ),
                const SizedBox(height: 10),
                Text(l10n.selectReceiptImage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appPurple,
                  ),
                ),
              ]),
            ),
          ),
        ],

        // Upload progress indicator
        if (_isUploading) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.appPurple)),
            const SizedBox(width: 10),
            Text(l10n.uploadingReceipt,
              style: TextStyle(fontSize: 13, color: context.appPurple, fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }

  void _confirmSent() {
    final l10n = AppLocalizations.of(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.confirmDialogTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
      content: Text(l10n.confirmReceiptUploadQuestion),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.notYetButton)),
        FilledButton(
          onPressed: () { Navigator.pop(ctx); _uploadAndSubmit(); },
          style: FilledButton.styleFrom(backgroundColor: context.appGreen),
          child: Text(l10n.yesSentButton)),
      ],
    ));
  }

  Widget _buildPending() {
    final l10n = AppLocalizations.of(context);
    final isChanging = widget.isChangingPlan;
    return Scaffold(backgroundColor: context.appBg, body: SafeArea(child: Stack(children: [
      Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: context.appOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top_rounded, color: context.appOrange, size: 40)),
          const SizedBox(height: 24),
          Text(l10n.pendingVerificationTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark)),
          const SizedBox(height: 12),
          Text(
            isChanging ? l10n.pendingVerificationChangePlanBody : l10n.pendingVerificationBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (isChanging) ...[
            SizedBox(width: double.infinity, height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const NotifListener(child: MainScreen())),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(l10n.goToHome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(onPressed: () { setState(() => _loading = true); _loadStatus(); },
              icon: const Icon(Icons.refresh, size: 18), label: Text(l10n.checkStatusButton),
              style: FilledButton.styleFrom(backgroundColor: context.appPurple)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(),
              child: Text(l10n.logoutTitle, style: TextStyle(color: context.appSub))),
          ],
        ]),
      )),
    ])));
  }

  Widget _buildRejected() {
    final l10n = AppLocalizations.of(context);
    final hasReason = _rejectionReason != null && _rejectionReason!.trim().isNotEmpty;
    final reasonText = hasReason ? _rejectionReason! : l10n.rejectionReasonFallback;

    return Scaffold(backgroundColor: context.appBg, body: SafeArea(child: Stack(children: [
      Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: context.appRed.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.cancel, color: context.appRed, size: 40)),
          const SizedBox(height: 24),
          Text(l10n.paymentRejectedTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark)),
          const SizedBox(height: 12),
          Text(l10n.paymentRejectedBody,
            textAlign: TextAlign.center, style: TextStyle(color: context.appSub, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),

          // ── Rejection reason notice card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appRed.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, color: context.appRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.rejectionReasonLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appRed)),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appCardBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(reasonText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: hasReason ? context.appText : context.appSub,
                    fontStyle: hasReason ? FontStyle.normal : FontStyle.italic,
                  )),
              ),
            ]),
          ),

          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'subscriptionStatus': 'not_subscribed'});
                setState(() => _loading = true); _loadStatus();
              }
            },
            icon: const Icon(Icons.refresh, size: 18), label: Text(l10n.retry),
            style: FilledButton.styleFrom(backgroundColor: context.appPurple)),
        ]),
      )),
      if (Navigator.canPop(context))
        Positioned(top: 8, left: 8, child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.arrow_back, color: context.appPurple, size: 22),
          ),
        )),
    ])));
  }
}

class _AccountCard extends StatelessWidget {
  final String title, account; final IconData icon; final VoidCallback onCopy;
  const _AccountCard({required this.title, required this.account, required this.icon, required this.onCopy});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.appBorder)),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: context.appPurple, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appDark)),
          const SizedBox(height: 4),
          Text(account, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appPurple, fontFamily: 'monospace', letterSpacing: 1)),
        ])),
        GestureDetector(onTap: onCopy,
          child: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.copy, size: 18, color: context.appPurple))),
      ]),
    );
  }
}
