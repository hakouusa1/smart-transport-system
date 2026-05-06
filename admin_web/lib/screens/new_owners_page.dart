import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/admin_service.dart';

void _showReceiptDialog(BuildContext context, String receiptUrl) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.navy, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Reçu de paiement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.sub),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2.5),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.broken_image_outlined, size: 48, color: AppColors.sub),
                        SizedBox(height: 10),
                        Text('Impossible de charger le reçu', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                      ]),
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

class NewOwnersPage extends StatefulWidget {
  const NewOwnersPage({super.key});
  @override
  State<NewOwnersPage> createState() => _NewOwnersPageState();
}

class _NewOwnersPageState extends State<NewOwnersPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Column(children: [
      // Header
      Container(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Demandes en attente',
              style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          const Text('Approuvez les renouvellements d\'abonnement.',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(width: isMobile ? double.infinity : 300, child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou email...', prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.card, contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
          )),
        ]),
      ),

      // Content
      Expanded(child: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          // ── Subscription Renewals Section ──
          _SectionHeader(
            icon: Icons.autorenew_rounded,
            color: const Color(0xFF0D9488),
            title: 'Renouvellements d\'abonnement',
            subtitle: 'Propriétaires ayant soumis un paiement',
          ),
          const SizedBox(height: 12),
          _UserList(
            stream: AdminService.getSubscriptionRenewals(),
            search: _search,
            showApproval: true,
            isRenewal: true,
            emptyLabel: 'Aucune demande de renouvellement',
          ),
        ],
      )),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
      ]),
    ]);
  }
}

class _UserList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String search;
  final bool showApproval;
  final bool isRenewal;
  final String emptyLabel;
  const _UserList({
    required this.stream,
    this.search = '',
    this.showApproval = false,
    required this.isRenewal,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2.5),
          ));
        }
        var users = snap.data ?? [];
        if (search.isNotEmpty) {
          users = users.where((u) {
            final name = (u['displayName'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            return name.contains(search) || email.contains(search);
          }).toList();
        }
        if (users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(child: Text(search.isNotEmpty ? 'Aucun résultat' : emptyLabel,
                style: const TextStyle(color: AppColors.sub, fontSize: 13))),
          );
        }
        return Column(
          children: users.map((u) => _UserCard(user: u, showApproval: showApproval, isRenewal: isRenewal)).toList(),
        );
      },
    );
  }
}

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool showApproval;
  final bool isRenewal;
  const _UserCard({required this.user, required this.showApproval, required this.isRenewal});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _loadingReceipt = false;

  Future<void> _viewReceipt() async {
    if (_loadingReceipt) return;
    setState(() => _loadingReceipt = true);
    try {
      final req = await AdminService.getLatestPaymentRequest(widget.user['uid'] ?? '');
      if (!mounted) return;
      final url = req?['receiptUrl'] as String?;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Aucun reçu trouvé pour ce propriétaire.'),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      _showReceiptDialog(context, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final showApproval = widget.showApproval;
    final isRenewal = widget.isRenewal;
    final status = user['status'] ?? 'active';
    final role = user['role'] ?? '';
    final statusColor = status == 'active' ? AppColors.green : status == 'pending' ? AppColors.orange : AppColors.red;
    final statusLabel = status == 'active' ? 'Actif' : status == 'pending' ? 'En attente' : status == 'suspended' ? 'Suspendu' : 'Rejeté';
    final isMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: isMobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                  child: Text((user['displayName'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 14))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user['displayName'] ?? 'Sans nom', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                Text(user['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.sub), overflow: TextOverflow.ellipsis, maxLines: 1),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if ((user['subscription'] ?? 'none') != 'none')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('Plan: ${user['subscription']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.purple)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRenewal ? const Color(0xFF0D9488).withValues(alpha: 0.1) : AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isRenewal ? 'Renouvellement' : 'Nouveau compte',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isRenewal ? const Color(0xFF0D9488) : AppColors.blue)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.navy)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ]),
            if (showApproval) ...[
              const SizedBox(height: 10),
              if (isRenewal)
                OutlinedButton.icon(
                  onPressed: _loadingReceipt ? null : _viewReceipt,
                  icon: _loadingReceipt
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                      : const Icon(Icons.receipt_long, size: 15, color: AppColors.navy),
                  label: const Text('Voir le reçu', style: TextStyle(fontSize: 12, color: AppColors.navy)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.navy),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
              if (isRenewal) const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FilledButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Approuver', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 10)),
                )),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  onPressed: () => _showRejectDialog(context, user['uid'], isRenewal),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Rejeter', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red, padding: const EdgeInsets.symmetric(vertical: 10)),
                )),
              ]),
            ],
          ])
        : Row(children: [
            CircleAvatar(radius: 20, backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                child: Text((user['displayName'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
            const SizedBox(width: 14),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user['displayName'] ?? 'Sans nom', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 2),
              Row(children: [
                Text(user['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                if ((user['subscription'] ?? 'none') != 'none') ...[
                  const Text('  ·  ', style: TextStyle(color: AppColors.sub, fontSize: 10)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Plan: ${user['subscription']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.purple)),
                  ),
                ],
              ]),
            ])),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isRenewal ? const Color(0xFF0D9488).withValues(alpha: 0.1) : AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isRenewal ? 'Renouvellement' : 'Nouveau compte',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: isRenewal ? const Color(0xFF0D9488) : AppColors.blue),
              ),
            ),
            const SizedBox(width: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ),
            const SizedBox(width: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3))),
              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
            const SizedBox(width: 10),

            if (showApproval) ...[
              if (isRenewal)
                IconButton(
                  tooltip: 'Voir le reçu',
                  icon: _loadingReceipt
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                      : const Icon(Icons.receipt_long, color: AppColors.navy, size: 22),
                  onPressed: _loadingReceipt ? null : _viewReceipt,
                ),
              IconButton(
                tooltip: 'Approuver',
                icon: const Icon(Icons.check_circle, color: AppColors.green, size: 22),
                onPressed: () => _approve(context),
              ),
              IconButton(
                tooltip: 'Rejeter le paiement',
                icon: const Icon(Icons.cancel, color: AppColors.red, size: 22),
                onPressed: () => _showRejectDialog(context, user['uid'], isRenewal),
              ),
            ],
          ]),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (widget.isRenewal) {
        await AdminService.approveRenewal(widget.user['uid']);
      } else {
        await AdminService.setUserStatus(widget.user['uid'], 'active');
      }
      messenger?.showSnackBar(const SnackBar(
        content: Text('Paiement approuvé. Abonnement activé.'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showRejectDialog(BuildContext context, String uid, bool isRenewal) {
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter le paiement',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Motif du rejet (visible par le propriétaire) :',
                style: TextStyle(fontSize: 13, color: AppColors.sub)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'ex: Reçu illisible, numéro de référence incorrect…',
                hintStyle: const TextStyle(color: AppColors.sub, fontSize: 12),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              try {
                if (isRenewal) {
                  await AdminService.rejectRenewal(uid, reason: reason);
                } else {
                  await AdminService.setUserStatus(uid, 'rejected');
                }
                messenger?.showSnackBar(const SnackBar(
                  content: Text('Paiement rejeté. Le propriétaire a été notifié.'),
                  backgroundColor: AppColors.orange,
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                messenger?.showSnackBar(SnackBar(
                  content: Text('Erreur : $e'),
                  backgroundColor: AppColors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }
}
