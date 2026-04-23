import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/subscription_plan.dart';
import 'subscription_screen.dart';
import '../utils/transitions.dart';
import '../theme_notifier.dart';



class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});
  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: StreamBuilder<Map<String, dynamic>?>(
          stream: _auth.getUserData(),
          builder: (context, snap) {
            final data = snap.data;
            final subscriptionStatus = data?['subscriptionStatus'] ?? '';
            final subscription = data?['subscription'] ?? 'none';
            final name = data?['displayName'] ?? '';
            final expiresAt = data?['subscriptionExpiresAt'] as Timestamp?;
            final isExpired = expiresAt != null && expiresAt.toDate().isBefore(DateTime.now());
            final trialEnd = data?['trialEnd'] as Timestamp?;

            // Determine display values from subscriptionStatus
            final IconData headerIcon;
            final String titleText;
            final String messageText;
            final Color badgeColor;
            final IconData badgeIcon;
            final String badgeLabel;
            final accountStatus = data?['status'] ?? 'pending';

            final isTrialEnded = trialEnd != null && trialEnd.toDate().isBefore(DateTime.now());

            if (isExpired) {
              headerIcon = Icons.timer_off;
              titleText = 'Abonnement expiré';
              messageText = 'Votre abonnement a expiré.\nChoisissez un plan pour continuer.';
              badgeColor = context.appOrange;
              badgeIcon = Icons.timer_off;
              badgeLabel = 'Expiré le ${_formatDate(expiresAt.toDate())}';
            } else if (isTrialEnded) {
              headerIcon = Icons.timer_off;
              titleText = 'Essai gratuit expiré';
              messageText = 'Votre essai gratuit de 30 jours est terminé.\nChoisissez un abonnement pour continuer.';
              badgeColor = context.appOrange;
              badgeIcon = Icons.timer_off;
              badgeLabel = 'Essai expiré le ${_formatDate(trialEnd.toDate())}';
            } else if (subscriptionStatus == 'pending_verification') {
              headerIcon = Icons.hourglass_top;
              titleText = 'Paiement en vérification';
              messageText = 'Votre paiement est en cours de vérification.\nL\'administrateur va l\'approuver bientôt.';
              badgeColor = context.appOrange;
              badgeIcon = Icons.hourglass_top;
              badgeLabel = 'En attente de validation';
            } else if (accountStatus == 'rejected') {
              headerIcon = Icons.cancel;
              titleText = 'Compte rejeté';
              messageText = 'Votre demande a été rejetée par l\'administrateur.';
              badgeColor = context.appRed;
              badgeIcon = Icons.cancel;
              badgeLabel = 'Rejeté';
            } else if (accountStatus == 'suspended') {
              headerIcon = Icons.block;
              titleText = 'Compte suspendu';
              messageText = 'Votre compte a été suspendu. Contactez le support.';
              badgeColor = context.appRed;
              badgeIcon = Icons.block;
              badgeLabel = 'Suspendu';
            } else {
              headerIcon = Icons.hourglass_top;
              titleText = 'En attente d\'abonnement';
              messageText = 'Souscrivez à un abonnement pour accéder à l\'application.';
              badgeColor = context.appOrange;
              badgeIcon = Icons.hourglass_top;
              badgeLabel = 'Aucun abonnement actif';
            }

            return SingleChildScrollView(child: Column(children: [
              // Blue header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 30),
                decoration: BoxDecoration(
                   gradient: LinearGradient(
                     colors: [context.appPrimary, context.appPurple],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _auth.signOut(),
                      child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.logout, color: Colors.white, size: 16), SizedBox(width: 4),
                          Text('Déconnexion', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ])),
                    ),
                  ]),
                  SizedBox(height: 16),
                  Container(width: 64, height: 64,
                    decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(headerIcon, color: Colors.white, size: 32)),
                  SizedBox(height: 14),
                  if (name.isNotEmpty) Text('Bienvenue, $name', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9))),
                  SizedBox(height: 6),
                  Text(titleText, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(height: 8),
                  Text(messageText, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.4)),
                ]),
              ),
              SizedBox(height: 24),

              // Status badge
              Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.appBorder)),
                child: Row(children: [
                  Icon(badgeIcon, color: badgeColor, size: 24),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Statut de l\'abonnement', style: TextStyle(fontSize: 12, color: context.appSub)),
                    SizedBox(height: 2),
                    Text(badgeLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: badgeColor)),
                  ])),
                ]),
              )),
              SizedBox(height: 20),

              // Subscription plans (unless rejected/suspended)
              if (accountStatus != 'rejected' && accountStatus != 'suspended') ...[
                Padding(padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Text('Choisir un abonnement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.appDark)),
                    const Spacer(),
                    if (subscription != 'none')
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('Plan actuel: ${SubscriptionPlan.getById(subscription).name}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appGreen)),
                      ),
                  ]),
                ),
                SizedBox(height: 14),
                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
                  ...SubscriptionPlan.plans.map((plan) => Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      currentPlan: subscription,
                      onSelect: () => _selectPlan(context, plan.id),
                    ),
                  )),
                ])),
              ],

              if (accountStatus == 'rejected' || accountStatus == 'suspended')
                Padding(padding: EdgeInsets.all(20), child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: context.appRed.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
                  child: Column(children: [
                    Icon(accountStatus == 'suspended' ? Icons.block : Icons.error_outline, color: context.appRed, size: 40),
                    SizedBox(height: 12),
                    Text(
                      accountStatus == 'suspended' ? 'Votre compte a été suspendu' : 'Votre compte a été rejeté',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appRed)),
                    SizedBox(height: 8),
                    Text('Veuillez contacter le support pour plus d\'informations.',
                      textAlign: TextAlign.center, style: TextStyle(color: context.appSub, fontSize: 13)),
                  ]),
                )),

              SizedBox(height: 32),
            ]));
          },
        ),
      ),
    );
  }

  void _selectPlan(BuildContext context, String planId) {
    if (_auth.uid.isEmpty) return;
    Navigator.push(
      context,
      AppTransitions.slideRight(
        page: SubscriptionScreen(
          initialPlanId: planId,
          initialStatus: 'not_subscribed',
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final String currentPlan;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan, required this.currentPlan, required this.onSelect,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  bool _wasClicked = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _wasClicked = true;
    });
    widget.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.currentPlan == widget.plan.id;
    final showCurrentPlanButton = isSelected && !_wasClicked;

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.plan.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.plan.color)),
            const Spacer(),
            if (widget.plan.recommended)
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: widget.plan.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Recommandé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.plan.color))),
            if (isSelected)
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, color: context.appGreen, size: 14), SizedBox(width: 4),
                  Text('Sélectionné', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appGreen)),
                ])),
          ]),
          SizedBox(height: 4),
          Text('${widget.plan.price}/mois', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
          SizedBox(height: 12),
          ...widget.plan.features.map((f) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_circle, color: widget.plan.color, size: 16),
              SizedBox(width: 8),
              Text(f, style: TextStyle(fontSize: 13, color: context.appText)),
            ]),
          )),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: showCurrentPlanButton
                ? OutlinedButton(
                    onPressed: _handleTap,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appGreen.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('Plan actuel', style: TextStyle(color: context.appGreen)))
                : _AnimatedSelectButton(
                    color: widget.plan.color,
                    shimmerCtrl: _shimmerCtrl,
                    scaleAnim: _scaleAnim,
                    pressCtrl: _pressCtrl,
                    onPressed: _handleTap,
                  ),
          ),
        ]),
      ),
    );
  }
}

class _AnimatedSelectButton extends StatelessWidget {
  final Color color;
  final AnimationController shimmerCtrl;
  final AnimationController pressCtrl;
  final Animation<double> scaleAnim;
  final VoidCallback onPressed;

  const _AnimatedSelectButton({
    required this.color,
    required this.shimmerCtrl,
    required this.pressCtrl,
    required this.scaleAnim,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => pressCtrl.forward(),
      onTapUp: (_) { pressCtrl.reverse(); onPressed(); },
      onTapCancel: () => pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([shimmerCtrl, scaleAnim]),
        builder: (context, _) {
          final glow = (math.sin(shimmerCtrl.value * 2 * math.pi) + 1) / 2;
          return Transform.scale(
            scale: scaleAnim.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    color,
                    Color.lerp(color, Colors.white, 0.22)!,
                    color,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35 + 0.3 * glow),
                    blurRadius: 8 + 10 * glow,
                    offset: const Offset(0, 3),
                    spreadRadius: glow * 1.5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final shimmerW = w * 0.45;
                  final left = -shimmerW + shimmerCtrl.value * (w + shimmerW);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: left, top: 0, bottom: 0, width: shimmerW,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.38),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Choisir ce plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
