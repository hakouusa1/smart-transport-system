import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_plan_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';

class SubscriptionHistoryScreen extends StatelessWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        title: Text(
          l10n.subscriptionHistory,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appDark,
          ),
        ),
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null
          ? Center(child: Text(l10n.errorNotLoggedIn))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payment_requests')
                  .where('ownerId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: BusLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(l10n.errorFmt(snapshot.error.toString())));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64,
                            color: context.appSub.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noHistoryFound,
                          style:
                              TextStyle(color: context.appSub, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    return _HistoryCard(data: data);
                  },
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final planId = data['planId'] ?? 'starter';
    final status = data['status'] ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr =
        createdAt != null ? l10n.formatDate(createdAt.toDate()) : '—';
    final refNumber = data['refNumber'] ?? '—';
    final receiptUrl = data['receiptUrl'] as String?;
    final rejectionReason = data['rejectionReason'] as String?;

    return FutureBuilder<SubscriptionPlan>(
      future: SubscriptionPlanService.fetchById(planId),
      initialData: SubscriptionPlan.defaults.first,
      builder: (context, snap) {
        final plan = snap.data ?? SubscriptionPlan.defaults.first;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: plan.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.workspace_premium_outlined,
                        color: plan.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.planNameFmt(plan.name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.requestedOn(dateStr),
                          style:
                              TextStyle(fontSize: 12, color: context.appSub),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.tag,
                label: l10n.refNumberLabel(refNumber),
              ),
              if (rejectionReason != null &&
                  rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: context.appRed.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: context.appRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rejectionReason,
                          style: TextStyle(
                              fontSize: 13,
                              color: context.appRed,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _viewReceipt(context, receiptUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appPurple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: context.appPurple, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          l10n.uploadReceipt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _viewReceipt(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white)),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = context.appGreen;
        label = l10n.paymentStatusApproved;
        break;
      case 'rejected':
        color = context.appRed;
        label = l10n.paymentStatusRejected;
        break;
      default:
        color = context.appOrange;
        label = l10n.paymentStatusPending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.appSub, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.appSub),
        ),
      ],
    );
  }
}
