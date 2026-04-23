import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class NewOwnersPage extends StatefulWidget {
  const NewOwnersPage({super.key});
  @override
  State<NewOwnersPage> createState() => _NewOwnersPageState();
}

class _NewOwnersPageState extends State<NewOwnersPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Demandes en attente',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          const Text('Approuvez les renouvellements d\'abonnement.',
              style: TextStyle(color: AppColors.sub, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(width: 300, child: TextField(
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
        padding: const EdgeInsets.all(28),
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

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool showApproval;
  final bool isRenewal;
  const _UserCard({required this.user, required this.showApproval, required this.isRenewal});

  @override
  Widget build(BuildContext context) {
    final status = user['status'] ?? 'active';
    final role = user['role'] ?? '';
    final statusColor = status == 'active' ? AppColors.green : status == 'pending' ? AppColors.orange : AppColors.red;
    final statusLabel = status == 'active' ? 'Actif' : status == 'pending' ? 'En attente' : status == 'suspended' ? 'Suspendu' : 'Rejeté';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
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
          IconButton(
            tooltip: 'Approuver',
            icon: const Icon(Icons.check_circle, color: AppColors.green, size: 22),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                if (isRenewal) {
                  await AdminService.approveRenewal(user['uid']);
                } else {
                  await AdminService.setUserStatus(user['uid'], 'active');
                }
                messenger?.showSnackBar(const SnackBar(
                  content: Text('Compte approuvé avec succès.'),
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
            },
          ),
          IconButton(
            tooltip: 'Rejeter',
            icon: const Icon(Icons.cancel, color: AppColors.red, size: 22),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                await AdminService.setUserStatus(user['uid'], 'rejected');
                messenger?.showSnackBar(const SnackBar(
                  content: Text('Compte rejeté.'),
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
          ),
        ],
      ]),
    );
  }
}
