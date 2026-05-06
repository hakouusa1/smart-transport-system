import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/bus_loading_indicator.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _resendLoading = false;
  bool _checkLoading = false;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _pollTimer?.cancel();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resendLoading) return;
    setState(() => _resendLoading = true);
    try {
      await _authService.sendVerificationEmail();
      setState(() { _resendLoading = false; _cooldown = 60; });
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() { _cooldown--; if (_cooldown <= 0) _cooldownTimer?.cancel(); });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr.verificationEmailSent),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resendLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _checkNow() async {
    setState(() => _checkLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _pollTimer?.cancel();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr.emailNotYetVerified),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _checkLoading = false);
    }
  }

  Future<void> _backToSignIn() async {
    _pollTimer?.cancel();
    await _authService.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToSignIn();
      },
      child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.appPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 56, color: context.appPrimary),
                ),
                const SizedBox(height: 28),
                Text(
                  tr.verifyEmailTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.appDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  tr.verifyEmailBody(widget.email),
                  style: TextStyle(fontSize: 14, color: context.appSub, height: 1.55),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _checkLoading ? null : _checkNow,
                    child: _checkLoading
                        ? const BusLoadingIndicator(strokeWidth: 2.5, color: Colors.white)
                        : Text(tr.checkVerification,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: (_cooldown > 0 || _resendLoading) ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _resendLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: context.appPrimary),
                          )
                        : Text(
                            _cooldown > 0
                                ? tr.resendEmailCooldown(_cooldown)
                                : tr.resendEmail,
                            style: TextStyle(fontSize: 15, color: context.appDark),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: _backToSignIn,
                  child: Text(
                    tr.backToSignIn,
                    style: TextStyle(color: context.appSub, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),   // closes Scaffold
  );     // closes PopScope
  }
}
