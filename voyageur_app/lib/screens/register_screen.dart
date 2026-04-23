import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
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
  void dispose() {
    _anim.dispose(); _nameController.dispose(); _emailController.dispose();
    _passwordController.dispose(); _confirmController.dispose(); super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (mounted) Navigator.pop(context);
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
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: Column(
                            children: [
                              const Text('Créer un compte', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 6),
                              Text('Rejoignez-nous pour suivre vos bus', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                              const SizedBox(height: 28),

                              // Glass card
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          _GlassField(
                                            controller: _nameController, label: 'Nom complet', hint: 'Ex: Sara Benali',
                                            icon: Icons.person_outline, action: TextInputAction.next,
                                            validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                                          ),
                                          const SizedBox(height: 14),
                                          _GlassField(
                                            controller: _emailController, label: 'Email', hint: 'voyageur@email.com',
                                            icon: Icons.email_outlined, keyboard: TextInputType.emailAddress, action: TextInputAction.next,
                                            validator: (v) {
                                              if (v == null || v.trim().isEmpty) return 'Email requis';
                                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Email invalide';
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 14),
                                          _GlassField(
                                            controller: _passwordController, label: 'Mot de passe', hint: '••••••',
                                            icon: Icons.lock_outlined, obscure: _obscurePass, action: TextInputAction.next,
                                            suffix: IconButton(
                                                icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.6)),
                                                onPressed: () => setState(() => _obscurePass = !_obscurePass)),
                                            validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                                          ),
                                          const SizedBox(height: 14),
                                          _GlassField(
                                            controller: _confirmController, label: 'Confirmer', hint: '••••••',
                                            icon: Icons.lock_outline, obscure: _obscureConfirm, action: TextInputAction.done,
                                            onSubmit: (_) => _register(),
                                            suffix: IconButton(
                                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.6)),
                                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                                            validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
                                          ),
                                          const SizedBox(height: 24),

                                          // Register button
                                          SizedBox(width: double.infinity, height: 52,
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _register,
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary, elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                              child: _isLoading
                                                  ? const SizedBox(width: 22, height: 22, child: BusLoadingIndicator(strokeWidth: 2.5, color: AppTheme.primary))
                                                  : const Text('Créer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
      onFieldSubmitted: onSubmit, style: const TextStyle(color: Colors.white), validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)), suffixIcon: suffix,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}