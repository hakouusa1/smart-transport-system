import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'bus_lines_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
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

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BusLinesScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0044CC), Color(0xFF0066FF), Color(0xFF5B8DEF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
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
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            // Title
                            const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Rejoignez-nous pour suivre vos bus',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Glass card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        _glassField(
                                          controller: _nameController,
                                          label: 'Nom complet',
                                          hint: 'Ex: Sara Benali',
                                          icon: Icons.person_outline,
                                          action: TextInputAction.next,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Veuillez entrer votre nom';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        _glassField(
                                          controller: _emailController,
                                          label: 'Email',
                                          hint: 'voyageur@email.com',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          action: TextInputAction.next,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Veuillez entrer votre email';
                                            }
                                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                .hasMatch(v.trim())) {
                                              return 'Email invalide';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        _glassField(
                                          controller: _passwordController,
                                          label: 'Mot de passe',
                                          hint: '••••••',
                                          icon: Icons.lock_outlined,
                                          obscure: _obscurePassword,
                                          action: TextInputAction.next,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.white.withValues(alpha: 0.6),
                                            ),
                                            onPressed: () => setState(
                                                    () => _obscurePassword = !_obscurePassword),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Veuillez entrer un mot de passe';
                                            }
                                            if (v.length < 6) return 'Minimum 6 caractères';
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        _glassField(
                                          controller: _confirmController,
                                          label: 'Confirmer',
                                          hint: '••••••',
                                          icon: Icons.lock_outline,
                                          obscure: _obscureConfirm,
                                          action: TextInputAction.done,
                                          onSubmitted: (_) => _register(),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirm
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.white.withValues(alpha: 0.6),
                                            ),
                                            onPressed: () => setState(
                                                    () => _obscureConfirm = !_obscureConfirm),
                                          ),
                                          validator: (v) {
                                            if (v != _passwordController.text) {
                                              return 'Les mots de passe ne correspondent pas';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 28),

                                        // Register button
                                        Container(
                                          width: double.infinity,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            gradient: const LinearGradient(
                                              colors: [Colors.white, Color(0xFFF0F0F0)],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.15),
                                                blurRadius: 15,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _register,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: AppTheme.primaryDark,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: AppTheme.primaryDark,
                                              ),
                                            )
                                                : const Text(
                                              'Créer mon compte',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
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
    );
  }

  Widget _glassField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? action,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontFamily: 'Poppins',
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
      ),
      validator: validator,
    );
  }
}