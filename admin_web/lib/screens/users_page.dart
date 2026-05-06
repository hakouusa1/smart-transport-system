import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Column(children: [
      // Header
      Container(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gestion des utilisateurs',
            style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
          SizedBox(height: isMobile ? 14 : 20),
          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou email...', prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.card, contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 16),
          TabBar(controller: _tabs, isScrollable: true,
            labelColor: AppColors.navy, unselectedLabelColor: AppColors.sub,
            indicatorColor: AppColors.navy, indicatorWeight: 2.5,
            tabs: const [
              Tab(text: '🚌 Propriétaires'),
              Tab(text: '🚗 Chauffeurs'),
              Tab(text: '👤 Voyageurs'),
            ],
          ),
        ]),
      ),

      // Content
      Expanded(child: TabBarView(controller: _tabs, children: [
        _UserList(stream: AdminService.getUsersByRole('owner'), search: _search),
        _UserList(stream: AdminService.getUsersByRole('driver'), search: _search),
        _UserList(stream: AdminService.getUsersByRole('passenger'), search: _search),
      ])),
    ]);
  }
}

class _UserList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String search;
  final bool showApproval;
  const _UserList({required this.stream, this.search = '', this.showApproval = false});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2.5));
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
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(search.isNotEmpty ? 'Aucun résultat' : 'Aucun utilisateur', style: const TextStyle(color: AppColors.sub)),
          ]));
        }
        return ListView.builder(
          padding: EdgeInsets.all(pad),
          itemCount: users.length,
          itemBuilder: (_, i) => _UserCard(user: users[i], showApproval: showApproval),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool showApproval;
  const _UserCard({required this.user, this.showApproval = false});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final status = user['status'] ?? 'active';
    final role = user['role'] ?? '';
    final statusColor = status == 'active' ? AppColors.green : status == 'pending' ? AppColors.orange : AppColors.red;
    final statusLabel = status == 'active' ? 'Actif' : status == 'pending' ? 'En attente' : status == 'suspended' ? 'Suspendu' : 'Rejeté';
    final date = (user['createdAt'] as Timestamp?)?.toDate();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '--';
    final expiry = (user['subscriptionExpiresAt'] as Timestamp?)?.toDate();
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    if (isMobile) {
      return _buildMobileCard(status, role, statusColor, statusLabel, dateStr, expiry, isExpired);
    }
    return _buildDesktopCard(status, role, statusColor, statusLabel, dateStr, expiry, isExpired);
  }

  Widget _buildMobileCard(String status, String role, Color statusColor, String statusLabel, String dateStr, DateTime? expiry, bool isExpired) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: avatar + name + status
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.navy.withValues(alpha: 0.1),
              child: Text((user['displayName'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 14))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['displayName'] ?? 'Sans nom', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
            Text(user['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.sub),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          ])),
        ]),
        const SizedBox(height: 10),
        // Badges row
        Wrap(spacing: 6, runSpacing: 6, children: [
          _badge(role, AppColors.navy),
          _badge(statusLabel, statusColor, bordered: true),
          _badge(dateStr, AppColors.sub),
          if ((user['subscription'] ?? 'none') != 'none')
            _badge('Plan: ${user['subscription']}', AppColors.purple),
          if ((user['subscriptionStatus'] ?? '') == 'pending_verification')
            _badge('Paiement envoyé', AppColors.orange),
          if ((user['subscriptionStatus'] ?? '') == 'active')
            _badge('Abonnement actif', AppColors.green),
          if (expiry != null && (user['role'] ?? '') == 'owner')
            _badge('Exp: ${expiry.day}/${expiry.month}/${expiry.year}', isExpired ? AppColors.red : AppColors.sub),
        ]),
        // Actions
        if (showApproval && status == 'pending') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () => AdminService.setUserStatus(user['uid'], 'active'),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Approuver', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 10)),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              onPressed: () => AdminService.setUserStatus(user['uid'], 'rejected'),
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Rejeter', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red, padding: const EdgeInsets.symmetric(vertical: 10)),
            )),
          ]),
        ] else if (status == 'active') ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => AdminService.setUserStatus(user['uid'], 'suspended'),
            icon: const Icon(Icons.block, size: 16, color: AppColors.orange),
            label: const Text('Suspendre', style: TextStyle(fontSize: 12, color: AppColors.orange)),
          )),
        ] else if (status == 'suspended') ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => AdminService.setUserStatus(user['uid'], 'active'),
            icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.green),
            label: const Text('Réactiver', style: TextStyle(fontSize: 12, color: AppColors.green)),
          )),
        ],
      ]),
    );
  }

  Widget _buildDesktopCard(String status, String role, Color statusColor, String statusLabel, String dateStr, DateTime? expiry, bool isExpired) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        // Avatar
        CircleAvatar(radius: 20, backgroundColor: AppColors.navy.withValues(alpha: 0.1),
            child: Text((user['displayName'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
        const SizedBox(width: 14),

        // Info
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
            if ((user['subscriptionStatus'] ?? '') == 'pending_verification') ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.sub, fontSize: 10)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Paiement envoyé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.orange)),
              ),
            ] else if ((user['subscriptionStatus'] ?? '') == 'active') ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.sub, fontSize: 10)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Abonnement actif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
              ),
            ],
            if (expiry != null && role == 'owner') ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.sub, fontSize: 10)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isExpired ? AppColors.red.withValues(alpha: 0.1) : AppColors.sub.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Exp: ${expiry.day}/${expiry.month}/${expiry.year}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: isExpired ? AppColors.red : AppColors.sub),
                ),
              ),
            ],
          ]),
        ])),

        // Role
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.navy)),
        ),
        const SizedBox(width: 10),

        // Date
        Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
        const SizedBox(width: 10),

        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.3))),
          child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
        ),
        const SizedBox(width: 10),

        // Actions
        if (showApproval && status == 'pending') ...[
          IconButton(tooltip: 'Approuver', icon: const Icon(Icons.check_circle, color: AppColors.green, size: 22),
              onPressed: () => AdminService.setUserStatus(user['uid'], 'active')),
          IconButton(tooltip: 'Rejeter', icon: const Icon(Icons.cancel, color: AppColors.red, size: 22),
              onPressed: () => AdminService.setUserStatus(user['uid'], 'rejected')),
        ] else if (status == 'active')
          IconButton(tooltip: 'Suspendre', icon: const Icon(Icons.block, color: AppColors.orange, size: 20),
              onPressed: () => AdminService.setUserStatus(user['uid'], 'suspended'))
        else if (status == 'suspended')
            IconButton(tooltip: 'Réactiver', icon: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                onPressed: () => AdminService.setUserStatus(user['uid'], 'active')),
      ]),
    );
  }

  Widget _badge(String text, Color color, {bool bordered = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: bordered ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}