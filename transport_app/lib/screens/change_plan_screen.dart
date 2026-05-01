import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subscription_plan.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
import '../utils/transitions.dart';
import 'subscription_screen.dart';

class ChangePlanScreen extends StatelessWidget {
  final String currentPlanId;
  const ChangePlanScreen({super.key, required this.currentPlanId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.appPrimary, context.appPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.swap_vert_circle_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.changePlan,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.changePlanSubtitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Plan list ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                context.appPrimary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: context.appPrimary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.changePlanInfo,
                              style: TextStyle(
                                  fontSize: 13, color: context.appPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Plan cards
                    ...SubscriptionPlan.plans.map((plan) => _PlanCard(
                          plan: plan,
                          isCurrent: plan.id == currentPlanId,
                          onSelect: () => Navigator.push(
                            context,
                            AppTransitions.slideRight(
                              page: SubscriptionScreen(
                                initialPlanId: plan.id,
                                initialStatus: 'not_subscribed',
                                isChangingPlan: true,
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? plan.color.withValues(alpha: 0.55)
              : context.appBorder,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: plan.color.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium,
                      color: plan.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.appDark),
                      ),
                      Text(
                        '${plan.price} ${l10n.perMonth}',
                        style: TextStyle(
                            fontSize: 13,
                            color: plan.color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  _Badge(label: l10n.currentPlan, color: plan.color)
                else if (plan.recommended)
                  _Badge(label: l10n.recommendedLabel, color: plan.color),
              ],
            ),

            const SizedBox(height: 14),

            // Features
            ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: isCurrent
                              ? plan.color
                              : context.appSub.withValues(alpha: 0.5),
                          size: 16),
                      const SizedBox(width: 8),
                      Text(f,
                          style: TextStyle(
                              fontSize: 13, color: context.appText)),
                    ],
                  ),
                )),

            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: isCurrent ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: plan.color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      context.appSub.withValues(alpha: 0.1),
                  disabledForegroundColor: context.appSub,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isCurrent ? l10n.currentPlan : l10n.selectThisPlan,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
