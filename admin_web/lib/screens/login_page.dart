import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);

      // Check role
      final uid = cred.user?.uid;
      if (uid == null) {
        await FirebaseAuth.instance.signOut();
        setState(() { _error = 'Erreur d\'authentification.'; _loading = false; });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final docData = doc.data();
      if (!doc.exists || docData == null || docData['role'] != 'admin') {
        await FirebaseAuth.instance.signOut();
        setState(() { _error = 'Accès refusé. Seuls les administrateurs peuvent se connecter.'; _loading = false; });
        return;
      }

      // Check status
      if (docData['status'] == 'suspended') {
        await FirebaseAuth.instance.signOut();
        setState(() { _error = 'Votre compte est suspendu.'; _loading = false; });
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Erreur de connexion'; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Center(child: SingleChildScrollView(child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width <= 600 ? 24 : 40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28)),
          const SizedBox(height: 20),
          const Text('Admin Panel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          const Text('Système de Transport Intelligent', style: TextStyle(fontSize: 13, color: AppColors.sub)),
          const SizedBox(height: 32),

          // Email
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)))),
          const SizedBox(height: 14),

          // Password
          TextField(controller: _passCtrl, obscureText: _obscure, onSubmitted: (_) => _login(),
            decoration: InputDecoration(labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outlined, size: 20),
              suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.sub),
                onPressed: () => setState(() => _obscure = !_obscure)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)))),
          const SizedBox(height: 8),

          // Error
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12), textAlign: TextAlign.center)),

          const SizedBox(height: 16),

          // Login button
          SizedBox(width: double.infinity, height: 48, child: FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Se connecter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          )),
        ]),
      ))),
    );
  }
}
