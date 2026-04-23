import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import '../theme_notifier.dart';
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
  bool _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: _emailController.text, password: _passwordController.text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.appPrimaryDark, context.appPrimary, context.appPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          ),
                          child: Icon(Icons.local_shipping_rounded, size: 48, color: Colors.white),
                        ),
                        SizedBox(height: 18),
                        Text('Transporteur', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                        SizedBox(height: 6),
                        Text('Gérez vos bus et chauffeurs', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                        SizedBox(height: 32),

                        // Form card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _GlassField(controller: _emailController, label: 'Email', hint: 'owner@email.com',
                                        icon: Icons.email_outlined, keyboard: TextInputType.emailAddress, action: TextInputAction.next,
                                        validator: (v) { if (v == null || v.trim().isEmpty) return 'Email requis'; return null; }),
                                    SizedBox(height: 16),
                                    _GlassField(controller: _passwordController, label: 'Mot de passe', hint: '••••••',
                                        icon: Icons.lock_outlined, obscure: _obscure, action: TextInputAction.done,
                                        onSubmit: (_) => _login(),
                                        suffix: IconButton(
                                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.6)),
                                            onPressed: () => setState(() => _obscure = !_obscure)),
                                        validator: (v) { if (v == null || v.length < 6) return 'Min 6 caractères'; return null; }),
                                    SizedBox(height: 24),

                                    // Login button
                                    SizedBox(width: double.infinity, height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white, foregroundColor: context.appPrimary, elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                        child: _isLoading
                                            ? SizedBox(width: 22, height: 22, child: BusLoadingIndicator(strokeWidth: 2.5, color: context.appPrimary))
                                            : Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 22),

                        // Register link
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Pas de compte ? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: Text('Créer un compte', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                          ),
                        ]),
                        SizedBox(height: 40),
                      ],
                    ),
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

class _GlassField extends StatelessWidget {
  final TextEditingController controller; final String label, hint; final IconData icon;
  final TextInputType? keyboard; final TextInputAction? action; final bool obscure;
  final Widget? suffix; final String? Function(String?)? validator; final void Function(String)? onSubmit;
  const _GlassField({required this.controller, required this.label, required this.hint, required this.icon,
    this.keyboard, this.action, this.obscure = false, this.suffix, this.validator, this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller, keyboardType: keyboard, textInputAction: action, obscureText: obscure,
      onFieldSubmitted: onSubmit, style: TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
        suffixIcon: suffix,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        errorStyle: TextStyle(color: Color(0xFFFF6B6B)),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}