import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/subscription_plan.dart';
import 'dashboard_screen.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';



// ═══════════════════════════════════════════
// CHANGE THESE TO YOUR REAL INFO
// ═══════════════════════════════════════════
const _adminEmail = 'admin@transport.com';
const _ccpAccount = '00799999 0001234567 89';
const _baridimobRip = '00799999 0001234567 89';

class SubscriptionScreen extends StatefulWidget {
  final String? initialPlanId;
  final String? initialStatus;
  const SubscriptionScreen({super.key, this.initialPlanId, this.initialStatus});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _status;
  String _planId = 'starter';
  bool _loading = true;
  StreamSubscription<DocumentSnapshot>? _statusSub;
  bool _navigated = false;

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
    _listenForApproval();
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
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          }
        });
      } else if (mounted && newStatus != _status) {
        setState(() {
          _status = newStatus;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
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
        _loading = false;
      });
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copié !'), duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating, backgroundColor: context.appGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.all(16)));
  }

  Future<void> _markAsSent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'subscription': _planId,
      'subscriptionStatus': 'pending_verification',
      'paymentDate': Timestamp.now(),
    });
    await FirebaseFirestore.instance.collection('payment_requests').add({
      'ownerId': uid,
      'ownerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'planId': _planId,
    });
    setState(() => _status = 'pending_verification');
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
    final plan = SubscriptionPlan.getById(_planId);

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
              end: Alignment.bottomRight
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
          ),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ]),
            SizedBox(height: 12),
            Container(width: 60, height: 60,
              decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.workspace_premium, color: Colors.white, size: 32)),
            SizedBox(height: 16),
            Text('Plan ${plan.name}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            SizedBox(height: 6),
            Text('${plan.price} / mois', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ),
        SizedBox(height: 24),

        Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          // Plan Features Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.appBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Inclus dans votre plan :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.appText)),
              SizedBox(height: 16),
              ...plan.features.map((f) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.check_circle, color: plan.color, size: 18),
                  SizedBox(width: 10),
                  Text(f, style: TextStyle(color: context.appText)),
                ]),
              )),
            ]),
          ),
          SizedBox(height: 12),

          // CCP Account
          _AccountCard(
            title: 'Compte CCP',
            account: _ccpAccount,
            icon: Icons.account_balance,
            onCopy: () => _copy(_ccpAccount),
          ),
          SizedBox(height: 12),

          // BaridiMob RIP
          _AccountCard(
            title: 'BaridiMob (RIP)',
            account: _baridimobRip,
            icon: Icons.phone_android,
            onCopy: () => _copy(_baridimobRip),
          ),
          SizedBox(height: 20),

          // Email instruction
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.appBorder)),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.email, color: context.appPurple, size: 20)),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Envoyez le reçu à', style: TextStyle(fontSize: 12, color: context.appSub)),
                SizedBox(height: 2),
                Text(_adminEmail, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appPurple)),
              ])),
              GestureDetector(
                onTap: () => _copy(_adminEmail),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.copy, size: 16, color: context.appPurple))),
            ]),
          ),
          SizedBox(height: 28),

          // Confirm button
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () => _confirmSent(),
            style: ElevatedButton.styleFrom(backgroundColor: context.appGreen, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: Text('J\'ai envoyé le reçu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
          SizedBox(height: 12),

          // Logout
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: Text('Déconnexion', style: TextStyle(color: context.appSub)),
          ),
          SizedBox(height: 32),
        ])),
      ])),
    );
  }

  void _confirmSent() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w600)),
      content: Text('Avez-vous bien envoyé le reçu de paiement par email ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Non, pas encore')),
        FilledButton(
          onPressed: () { Navigator.pop(ctx); _markAsSent(); },
          style: FilledButton.styleFrom(backgroundColor: context.appGreen),
          child: Text('Oui, j\'ai envoyé')),
      ],
    ));
  }

  Widget _buildPending() {
    return Scaffold(backgroundColor: context.appBg, body: SafeArea(child: Stack(children: [
      Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: context.appOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top_rounded, color: context.appOrange, size: 40)),
          SizedBox(height: 24),
          Text('En attente de vérification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark)),
          SizedBox(height: 12),
          Text('Votre paiement est en cours de vérification.\nCela peut prendre entre 1 et 3 jours.',
            textAlign: TextAlign.center, style: TextStyle(color: context.appSub, fontSize: 14, height: 1.5)),
          SizedBox(height: 32),
          FilledButton.icon(onPressed: () { setState(() => _loading = true); _loadStatus(); },
            icon: Icon(Icons.refresh, size: 18), label: Text('Vérifier le statut'),
            style: FilledButton.styleFrom(backgroundColor: context.appPurple)),
          SizedBox(height: 16),
TextButton(onPressed: () => FirebaseAuth.instance.signOut(),
            child: Text('Déconnexion', style: TextStyle(color: context.appSub))),
        ]),
      )),
      ])));
  }

  Widget _buildRejected() {
    return Scaffold(backgroundColor: context.appBg, body: SafeArea(child: Stack(children: [
      Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: context.appRed.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.cancel, color: context.appRed, size: 40)),
          SizedBox(height: 24),
          Text('Paiement rejeté', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark)),
          SizedBox(height: 12),
          Text('Votre paiement a été rejeté.\nVeuillez réessayer avec un nouveau reçu.',
            textAlign: TextAlign.center, style: TextStyle(color: context.appSub, fontSize: 14, height: 1.5)),
          SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'subscriptionStatus': 'not_subscribed'});
                setState(() => _loading = true); _loadStatus();
              }
            },
            icon: Icon(Icons.refresh, size: 18), label: Text('Réessayer'),
            style: FilledButton.styleFrom(backgroundColor: context.appPurple)),
        ]),
      )),
      Positioned(top: 8, left: 8, child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: EdgeInsets.all(8),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.appBorder)),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: context.appPurple, size: 22)),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appDark)),
          SizedBox(height: 4),
          Text(account, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appPurple, fontFamily: 'monospace', letterSpacing: 1)),
        ])),
        GestureDetector(onTap: onCopy,
          child: Container(padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.copy, size: 18, color: context.appPurple))),
      ]),
    );
  }
}
