import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/admin_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int>? _stats;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _statsSub = FirebaseFirestore.instance.collection('users').snapshots().listen((_) => _load());
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await AdminService.getStats();
    if (mounted) setState(() { _stats = s; });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        if (isMobile) ...[
          const Text('Tableau de bord', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 4),
          Text('Vue d\'ensemble du système', style: TextStyle(fontSize: 13, color: AppColors.sub)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () { setState(() => _stats = null); _load(); },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
            ),
          ),
        ] else ...[
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tableau de bord', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
              Text('Vue d\'ensemble du système', style: TextStyle(fontSize: 14, color: AppColors.sub)),
            ]),
            const Spacer(),
            FilledButton.icon(
              onPressed: () { setState(() => _stats = null); _load(); },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
            ),
          ]),
        ],
        const SizedBox(height: 20),

        // Stats grid — responsive
        LayoutBuilder(builder: (_, constraints) {
          final cardWidth = isMobile
              ? (constraints.maxWidth - 12) / 2  // 2 cards per row on mobile
              : 200.0;
          return Wrap(spacing: isMobile ? 12 : 16, runSpacing: isMobile ? 12 : 16, children: [
            _StatCard('Propriétaires', _stats == null ? '--' : '${_stats!['owners'] ?? 0}', Icons.business_rounded, AppColors.navy, cardWidth, isMobile),
            _StatCard('Chauffeurs', _stats == null ? '--' : '${_stats!['drivers'] ?? 0}', Icons.drive_eta_rounded, AppColors.blue, cardWidth, isMobile),
            _StatCard('Voyageurs', _stats == null ? '--' : '${_stats!['passengers'] ?? 0}', Icons.people_rounded, AppColors.purple, cardWidth, isMobile),
            _StatCard('Bus total', _stats == null ? '--' : '${_stats!['buses'] ?? 0}', Icons.directions_bus_rounded, AppColors.orange, cardWidth, isMobile),
            _StatCard('Lignes', _stats == null ? '--' : '${_stats!['lines'] ?? 0}', Icons.route_rounded, AppColors.lightBlue, cardWidth, isMobile),
            _StatCard('En trajet', _stats == null ? '--' : '${_stats!['activeBuses'] ?? 0}', Icons.gps_fixed_rounded, AppColors.green, cardWidth, isMobile),
            _StatCard('Réservations', _stats == null ? '--' : '${_stats!['bookings'] ?? 0}', Icons.bookmark_rounded, AppColors.navy, cardWidth, isMobile),
            _StatCard('Incidents', _stats == null ? '--' : '${_stats!['incidents'] ?? 0}', Icons.warning_rounded, AppColors.red, cardWidth, isMobile),
          ]);
        }),
        const SizedBox(height: 28),

        // Subscription Revenue
        const Text('Revenus des abonnements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
        const SizedBox(height: 14),
        SubscriptionRevenueWidget(),
        const SizedBox(height: 28),

        // Active buses
        const Text('Bus en trajet (temps réel)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
        const SizedBox(height: 14),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService.getActiveBuses(),
          builder: (_, snap) {
            final buses = snap.data ?? [];
            if (buses.isEmpty) return _emptyState('Aucun bus en trajet actuellement');
            if (isMobile) {
              return Column(children: buses.map((b) => _MobileListCard(
                icon: Icons.directions_bus,
                iconColor: AppColors.green,
                title: b['lineName'] ?? '--',
                subtitle: b['busName'] ?? b['busNumber'] ?? '--',
                badge: 'En trajet',
                badgeColor: AppColors.green,
              )).toList());
            }
            return _DataTable(
              columns: const ['Ligne', 'Bus', 'Statut'],
              rows: buses.map((b) => <String>[
                b['lineName'] ?? '--',
                b['busName'] ?? b['busNumber'] ?? '--',
                'En trajet',
              ]).toList(),
              statusCol: 2,
            );
          },
        ),
        const SizedBox(height: 28),

        // Recent incidents
        const Text('Incidents récents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
        const SizedBox(height: 14),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService.getIncidents(),
          builder: (_, snap) {
            final items = (snap.data ?? []).take(5).toList();
            if (items.isEmpty) return _emptyState('Aucun incident');
            if (isMobile) {
              return Column(children: items.map((i) {
                final ts = (i['timestamp'] as Timestamp?)?.toDate();
                final date = ts != null ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : '--';
                final resolved = i['resolved'] == true;
                return _MobileListCard(
                  icon: resolved ? Icons.check_circle : Icons.warning,
                  iconColor: resolved ? AppColors.green : AppColors.red,
                  title: _incidentLabel(i['type'] ?? ''),
                  subtitle: '${i['lineName'] ?? '--'} · $date',
                  badge: resolved ? 'Résolu' : 'Non résolu',
                  badgeColor: resolved ? AppColors.green : AppColors.orange,
                );
              }).toList());
            }
            return _DataTable(
              columns: const ['Type', 'Ligne', 'Date', 'Statut'],
              rows: items.map((i) {
                final ts = (i['timestamp'] as Timestamp?)?.toDate();
                final date = ts != null ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : '--';
                return <String>[
                  _incidentLabel(i['type'] ?? ''),
                  i['lineName'] ?? '--',
                  date,
                  (i['resolved'] == true) ? 'Résolu' : 'Non résolu',
                ];
              }).toList(),
              statusCol: 3,
            );
          },
        ),
      ]),
    );
  }

  String _incidentLabel(String type) {
    switch (type) {
      case 'accident': return '🚗 Accident';
      case 'delay': return '⏱ Retard';
      case 'mechanical': return '🔧 Panne';
      case 'road_blocked': return '🚧 Route bloquée';
      default: return type;
    }
  }

  Widget _emptyState(String msg) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Center(child: Text(msg, style: const TextStyle(color: AppColors.sub))),
  );
}

// ══════════════════════════════════════
// MOBILE LIST CARD (replaces table on small screens)
// ══════════════════════════════════════
class _MobileListCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, badge;
  final Color badgeColor;

  const _MobileListCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.badge, required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════
// STAT CARD
// ══════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  final double cardWidth; final bool isMobile;
  const _StatCard(this.label, this.value, this.icon, this.color, this.cardWidth, this.isMobile);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: isMobile ? 32 : 40, height: isMobile ? 32 : 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: isMobile ? 16 : 20)),
        SizedBox(height: isMobile ? 10 : 14),
        Text(value, style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: isMobile ? 11 : 13, color: AppColors.sub),
          overflow: TextOverflow.ellipsis, maxLines: 1),
      ]),
    );
  }
}

// ══════════════════════════════════════
// DATA TABLE
// ══════════════════════════════════════
class _DataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final int? statusCol;
  const _DataTable({required this.columns, required this.rows, this.statusCol});

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('trajet') || l.contains('active') || l.contains('résolu') || l.contains('confirmed')) return AppColors.green;
    if (l.contains('pending') || l.contains('retard') || l.contains('non résolu')) return AppColors.orange;
    if (l.contains('cancelled') || l.contains('accident') || l.contains('incident')) return AppColors.red;
    return AppColors.sub;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
          child: Row(children: columns.map((c) => Expanded(
            child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.sub)),
          )).toList()),
        ),
        // Rows
        ...rows.map((row) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))),
          child: Row(children: List.generate(row.length, (i) => Expanded(
            child: statusCol == i
                ? Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusColor(row[i]).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(row[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(row[i]))),
                    ),
                  ])
                : Text(row[i], style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ))),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════
// SUBSCRIPTION REVENUE WIDGET
// ══════════════════════════════════════
class SubscriptionRevenueWidget extends StatefulWidget {
  const SubscriptionRevenueWidget({super.key});

  @override
  State<SubscriptionRevenueWidget> createState() => _SubscriptionRevenueWidgetState();
}

class _SubscriptionRevenueWidgetState extends State<SubscriptionRevenueWidget> {
  int? _last24h;
  int? _last30days;
  int? _custom;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
  }

  Future<void> _loadRevenue() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final lastMonth = now.subtract(const Duration(days: 30));

    final futures = [
      AdminService.getSubscriptionRevenue(from: yesterday, to: now),
      AdminService.getSubscriptionRevenue(from: lastMonth, to: now),
      if (_customRange != null)
        AdminService.getSubscriptionRevenue(from: _customRange!.start, to: _customRange!.end),
    ];

    final results = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _last24h = results[0];
        _last30days = results[1];
        if (_customRange != null) _custom = results[2];
      });
    }
  }

  String _formatAmount(int? amount) {
    if (amount == null) return '-- DA';
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} DA';
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );
    if (range != null && mounted) {
      setState(() => _customRange = range);
      _loadRevenue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 600;

    if (isMobile) {
      return Column(children: [
        _RevenueCard('Dernières 24h', _formatAmount(_last24h), Icons.today, AppColors.green, isMobile: true),
        const SizedBox(height: 10),
        _RevenueCard('Derniers 30 jours', _formatAmount(_last30days), Icons.calendar_month, AppColors.blue, isMobile: true),
        const SizedBox(height: 10),
        _RevenueCard(
          'Période personnalisée',
          _customRange == null ? 'Sélectionner...' : _formatAmount(_custom),
          Icons.date_range,
          AppColors.purple,
          onTap: _pickCustomRange,
          isMobile: true,
        ),
      ]);
    }

    return Wrap(spacing: 16, runSpacing: 16, children: [
      _RevenueCard('Dernières 24h', _formatAmount(_last24h), Icons.today, AppColors.green),
      _RevenueCard('Derniers 30 jours', _formatAmount(_last30days), Icons.calendar_month, AppColors.blue),
      _RevenueCard(
        'Période personnalisée',
        _customRange == null ? 'Sélectionner...' : _formatAmount(_custom),
        Icons.date_range,
        AppColors.purple,
        onTap: _pickCustomRange,
      ),
    ]);
  }
}

class _RevenueCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isMobile;

  const _RevenueCard(this.label, this.value, this.icon, this.color, {this.onTap, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isMobile ? double.infinity : 250,
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: isMobile
            ? Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                ])),
                if (onTap != null) Icon(Icons.chevron_right, color: AppColors.sub, size: 20),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    value,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 13, color: AppColors.sub),
                  ),
                ],
              ),
      ),
    );
  }
}
