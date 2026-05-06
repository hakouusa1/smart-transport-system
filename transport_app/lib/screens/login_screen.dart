import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
import '../widgets/bus_loading_indicator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: _emailController.text, password: _passwordController.text);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      // null = user cancelled picker → reset loading
      // non-null = success → keep loading; AuthWrapper will navigate to home
      if (user == null && mounted) setState(() => _googleLoading = false);
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
        setState(() => _googleLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _appleLoading = true);
    try {
      final user = await _authService.signInWithApple();
      if (user == null && mounted) setState(() => _appleLoading = false);
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
        setState(() => _appleLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Image.asset('assets/images/massar_logo.webp', height: 90, fit: BoxFit.contain),
                      const SizedBox(height: 10),
                      Text(tr.appTagline, style: TextStyle(fontSize: 13, color: context.appSub)),
                      const SizedBox(height: 40),

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.appBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AppField(
                                controller: _emailController,
                                label: tr.emailLabel,
                                hint: 'owner@email.com',
                                icon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                action: TextInputAction.next,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? tr.emailRequired : null,
                              ),
                              const SizedBox(height: 16),
                              _AppField(
                                controller: _passwordController,
                                label: tr.passwordLabel,
                                hint: '••••••',
                                icon: Icons.lock_outlined,
                                obscure: _obscure,
                                action: TextInputAction.done,
                                onSubmit: (_) => _login(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: context.appSub, size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) => v == null || v.length < 6
                                    ? tr.minSixChars : null,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? BusLoadingIndicator(strokeWidth: 2.5, color: Colors.white)
                                      : Text(tr.signIn,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── or ───
                      _OrDivider(label: tr.orDivider),
                      const SizedBox(height: 16),

                      // Google
                      _SocialButton(
                        onPressed: _googleLoading ? null : _signInWithGoogle,
                        loading: _googleLoading,
                        label: tr.continueWithGoogle,
                        icon: const _GoogleIcon(),
                      ),
                      const SizedBox(height: 10),

                      // Apple (iOS / macOS only)
                      if (Platform.isIOS || Platform.isMacOS)
                        _SocialButton(
                          onPressed: _appleLoading ? null : _signInWithApple,
                          loading: _appleLoading,
                          label: tr.continueWithApple,
                          icon: Icon(Icons.apple, size: 22, color: context.appDark),
                        ),

                      const SizedBox(height: 24),

                      // Register link
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${tr.noAccount} ',
                            style: TextStyle(color: context.appSub, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: Text(tr.createAccount,
                              style: TextStyle(
                                  color: context.appPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Or divider ───────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: context.appBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: TextStyle(color: context.appSub, fontSize: 13)),
      ),
      Expanded(child: Divider(color: context.appBorder)),
    ]);
  }
}

// ─── Social button ────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;
  final Widget icon;

  const _SocialButton({
    required this.onPressed,
    required this.loading,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.appCardBg,
          side: BorderSide(color: context.appBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.appPrimary),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                icon,
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(fontSize: 15, color: context.appDark, fontWeight: FontWeight.w500)),
              ]),
      ),
    );
  }
}

// ─── Google "G" icon ──────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────
class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmit;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.action,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: action,
      obscureText: obscure,
      onFieldSubmitted: onSubmit,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
