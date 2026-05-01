import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme_notifier.dart';
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
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
      if (mounted) { Navigator.pop(context); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new, color: context.appDark),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          children: [
                            // Logo — transparent on app background
                            Image.asset(
                              'assets/images/massar_logo.webp',
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Créer un compte',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.appDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gérez vos bus et chauffeurs',
                              style: TextStyle(fontSize: 13, color: context.appSub),
                            ),
                            const SizedBox(height: 32),

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
                                      controller: _nameController,
                                      label: 'Nom complet',
                                      hint: 'Ex: Mohamed Ali',
                                      icon: Icons.person_outline,
                                      action: TextInputAction.next,
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppField(
                                      controller: _emailController,
                                      label: 'Email',
                                      hint: 'owner@email.com',
                                      icon: Icons.email_outlined,
                                      keyboard: TextInputType.emailAddress,
                                      action: TextInputAction.next,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Email requis';
                                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                          return 'Email invalide';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _AppField(
                                      controller: _passwordController,
                                      label: 'Mot de passe',
                                      hint: '••••••',
                                      icon: Icons.lock_outlined,
                                      obscure: _obscurePass,
                                      action: TextInputAction.next,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePass ? Icons.visibility_off : Icons.visibility,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                      ),
                                      validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppField(
                                      controller: _confirmController,
                                      label: 'Confirmer',
                                      hint: '••••••',
                                      icon: Icons.lock_outline,
                                      obscure: _obscureConfirm,
                                      action: TextInputAction.done,
                                      onSubmit: (_) => _register(),
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                      ),
                                      validator: (v) => v != _passwordController.text
                                          ? 'Les mots de passe ne correspondent pas'
                                          : null,
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _register,
                                        child: _isLoading
                                            ? const BusLoadingIndicator(strokeWidth: 2.5, color: Colors.white)
                                            : const Text(
                                                'Créer mon compte',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                              ),
                                      ),
                                    ),
                                  ],
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
    );
  }
}

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
