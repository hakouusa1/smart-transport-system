import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme_notifier.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _authService      = AuthService();
  final _nameController   = TextEditingController();
  final _phoneController  = TextEditingController();

  late AnimationController _anim;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  bool _isLoading = true;
  bool _isSaving  = false;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _authService.uid;
      if (uid.isEmpty) return;
      final doc  = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _nameController.text  = (data['displayName'] as String?) ?? '';
        _phoneController.text = (data['phone'] as String?) ?? '';
        _isLoading = false;
      });
      _anim.forward();
    } catch (_) {
      if (mounted) { setState(() => _isLoading = false); _anim.forward(); }
    }
  }

  Future<void> _saveUserData() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Le nom ne peut pas être vide.'),
        backgroundColor: context.appRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_authService.uid).update({
        'displayName': name,
        'phone':       _phoneController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Profil mis à jour avec succès.'),
        backgroundColor: context.appGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: context.appRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        backgroundColor: context.appBg,
        appBar: AppBar(
          title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: context.appPrimary))
            : FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(children: [

                      // ── PROFILE HEADER (gradient accent) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.appPrimaryDark, context.appPrimary, context.appPrimaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                        ),
                        child: Column(children: [
                          Stack(children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                              ),
                              child: const CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.person, size: 54, color: Colors.white70),
                              ),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                                ),
                                child: Icon(Icons.camera_alt, size: 16, color: context.appPrimary),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          Text(
                            _nameController.text.isNotEmpty ? _nameController.text : 'Chauffeur',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _authService.currentUser?.email ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 24),

                      // ── FORM CARD ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.appCardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.appBorder),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Informations personnelles',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: context.appSub, letterSpacing: 0.4)),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(color: context.appDark),
                              decoration: InputDecoration(
                                labelText: 'Nom complet',
                                prefixIcon: Icon(Icons.person_outline, color: context.appPrimary),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: context.appDark),
                              decoration: InputDecoration(
                                labelText: 'Téléphone',
                                prefixIcon: Icon(Icons.phone_outlined, color: context.appPrimary),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              initialValue: _authService.currentUser?.email ?? '',
                              enabled: false,
                              style: TextStyle(color: context.appSub),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: context.appSub),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveUserData,
                                child: _isSaving
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Text('Enregistrer les modifications',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── SIGN OUT ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              await _authService.signOut();
                              nav.popUntil((route) => route.isFirst);
                            },
                            icon: Icon(Icons.logout, color: context.appRed, size: 18),
                            label: Text('Se déconnecter',
                                style: TextStyle(color: context.appRed, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.appRed.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}
