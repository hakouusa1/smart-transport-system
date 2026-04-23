import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import 'vidange_details_screen.dart';
import 'assurance_details_screen.dart';
import 'salary_details_screen.dart';
import '../theme_notifier.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/bus_loading_indicator.dart';

const _vidangeIntervalKm = 10000;

enum _AlertType { assurance, vidange, salary }

class _AlertItem {
  final Bus bus;
  final _AlertType type;
  final int? daysUntilExpiry;
  final int? kmRemaining;
  final String? salaryLabel;
  final int? daysUntilSalary;

  const _AlertItem({
    required this.bus,
    required this.type,
    this.daysUntilExpiry,
    this.kmRemaining,
    this.salaryLabel,
    this.daysUntilSalary,
  });

  int get urgencyScore {
    if (type == _AlertType.assurance) return daysUntilExpiry ?? 999;
    if (type == _AlertType.vidange)   return kmRemaining    ?? 999;
    return daysUntilSalary ?? 999;
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Future<List<_AlertItem>>? _alertsFuture;
  List<Bus> _lastBuses = [];

  void _updateAlerts(List<Bus> buses) {
    _lastBuses = buses;
    _alertsFuture = _buildAlertsFuture(buses);
  }

  Future<List<_AlertItem>> _buildAlertsFuture(List<Bus> buses) async {
    final now   = DateTime.now();
    final items = <_AlertItem>[];

    for (final bus in buses) {
      // 1. Assurance
      if (bus.insuranceEndDate != null) {
        items.add(_AlertItem(
            bus: bus,
            type: _AlertType.assurance,
            daysUntilExpiry: bus.insuranceEndDate!.difference(now).inDays));
      } else {
        items.add(_AlertItem(
            bus: bus, type: _AlertType.assurance, daysUntilExpiry: null));
      }

      // 2. Vidange
      Query query = FirebaseFirestore.instance
          .collection('trips')
          .where('busId', isEqualTo: bus.busId);
      if (bus.lastVidangeDate != null) {
        query = query.where('timestamp',
            isGreaterThan: Timestamp.fromDate(bus.lastVidangeDate!));
      }
      double traveled = 0.0;
      try {
        final agg = await query.aggregate(sum('distanceKm')).get();
        traveled = agg.getSum('distanceKm') ?? 0.0;
      } catch (e) {
        debugPrint('Vidange distance error: $e');
      }
      items.add(_AlertItem(
          bus: bus,
          type: _AlertType.vidange,
          kmRemaining: (_vidangeIntervalKm - traveled).toInt().clamp(0, _vidangeIntervalKm)));

      // 3. Salary
      final positions = <String>[];
      if (bus.driverId.isNotEmpty) positions.add('Chauffeur');
      if (bus.recipientSalary != null && bus.recipientSalary! > 0) {
        positions.add('Receveur');
      }

      if (positions.isNotEmpty) {
        DateTime nextSalary = DateTime(now.year, now.month + 1, 1);
        if (bus.lastSalaryDate != null &&
            now.difference(bus.lastSalaryDate!).inDays < 20) {
          nextSalary = DateTime(now.year, now.month + 2, 1);
        }
        items.add(_AlertItem(
          bus: bus,
          type: _AlertType.salary,
          salaryLabel: 'Salaires: ${positions.join(' & ')}',
          daysUntilSalary: nextSalary.difference(now).inDays,
        ));
      }
    }

    items.sort((a, b) => a.urgencyScore.compareTo(b.urgencyScore));
    return items;
  }

  // ── Semantic color helpers ──
  Color _assuranceColor(int? days) {
    if (days == null || days < 30) return context.appRed;
    if (days < 90) return context.appOrange;
    return context.appGreen;
  }

  Color _vidangeColor(int? km) {
    if (km == null || km <= 0)    return context.appRed;
    if (km <= 1000)               return context.appOrange;
    return context.appGreen;
  }

  Color _salaryColor(int? days) {
    if (days == null)  return context.appGreen;
    if (days <= 3)     return context.appRed;
    if (days <= 10)    return context.appOrange;
    return context.appGreen;
  }

  // ── Card builders ──
  Widget _buildAssuranceCard(BuildContext context, _AlertItem item) {
    final bus   = item.bus;
    final days  = item.daysUntilExpiry;
    final color = _assuranceColor(days);

    final String subtitle;
    final String badge;
    if (days == null) {
      subtitle = 'Date d\'expiration non renseignée';
      badge    = 'Inconnue';
    } else if (days < 0) {
      subtitle = 'Expirée depuis ${-days} jour${(-days) > 1 ? 's' : ''}';
      badge    = 'Expirée';
    } else if (days == 0) {
      subtitle = 'Expire aujourd\'hui !';
      badge    = 'Aujourd\'hui';
    } else {
      final exp = DateFormat('dd/MM/yyyy').format(bus.insuranceEndDate!);
      subtitle = 'Expire le $exp · dans $days jour${days > 1 ? 's' : ''}';
      badge    = '$days j';
    }

    final String urgencyLevel;
    if (days == null || days < 30) urgencyLevel = 'critical';
    else if (days < 90) urgencyLevel = 'high';
    else urgencyLevel = 'normal';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssuranceDetailsScreen(bus: bus)),
      ).then((_) => setState(() => _updateAlerts(_lastBuses))),
      child: _AlertCard(
        icon: Icons.shield_outlined,
        iconColor: color,
        title: bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
        subtitle: subtitle,
        label: 'Assurance',
        labelColor: context.appAccent,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  Widget _buildVidangeCard(BuildContext context, _AlertItem item) {
    final bus   = item.bus;
    final km    = item.kmRemaining;
    final color = _vidangeColor(km);

    final String subtitle;
    final String badge;
    if (km == null) {
      subtitle = 'Kilométrage non renseigné';
      badge    = 'Inconnu';
    } else if (km < 0) {
      subtitle = 'Dépassé de ${-km} km !';
      badge    = '+${-km} km';
    } else if (km == 0) {
      subtitle = 'Vidange requise maintenant';
      badge    = '0 km';
    } else {
      subtitle = 'Prochaine vidange dans $km km';
      badge    = '$km km';
    }

    final String urgencyLevel;
    if (km == null || km <= 0) urgencyLevel = 'critical';
    else if (km <= 1000) urgencyLevel = 'high';
    else urgencyLevel = 'normal';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VidangeDetailsScreen(
                bus: bus,
                kmRemaining: km,
                intervalKm: _vidangeIntervalKm)),
      ).then((_) => setState(() => _updateAlerts(_lastBuses))),
      child: _AlertCard(
        icon: Icons.oil_barrel_outlined,
        iconColor: color,
        title: bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
        subtitle: subtitle,
        label: 'Vidange',
        labelColor: context.appOrange,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  Widget _buildSalaryCard(BuildContext context, _AlertItem item) {
    final bus   = item.bus;
    final days  = item.daysUntilSalary;
    final color = _salaryColor(days);

    final String subtitle;
    final String badge;
    if (days == null) {
      subtitle = 'Date inconnue';
      badge    = 'Inconnu';
    } else if (days == 0) {
      subtitle = 'Salaire à verser aujourd\'hui !';
      badge    = 'Aujourd\'hui';
    } else {
      final dt  = DateTime.now().add(Duration(days: days));
      subtitle  = 'Prévu le ${DateFormat('dd/MM/yyyy').format(dt)} · dans $days jour${days > 1 ? 's' : ''}';
      badge     = '$days j';
    }

    final String urgencyLevel;
    if (days == null) urgencyLevel = 'normal';
    else if (days <= 3) urgencyLevel = 'critical';
    else if (days <= 10) urgencyLevel = 'high';
    else urgencyLevel = 'normal';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SalaryDetailsScreen(bus: bus, daysUntilSalary: days)),
      ),
      child: _AlertCard(
        icon: Icons.payments_outlined,
        iconColor: color,
        title: bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
        subtitle: subtitle,
        label: item.salaryLabel ?? 'Salaires',
        labelColor: context.appPrimary,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: StreamBuilder<List<Bus>>(
          stream: BusService().getBuses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _alertsFuture == null) {
              return Center(
                  child: BusLoadingIndicator(
                      color: context.appPurple, strokeWidth: 2.5));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erreur: ${snapshot.error}',
                      style: TextStyle(color: context.appSub)));
            }

            final buses = snapshot.data ?? [];
            if (buses.toString() != _lastBuses.toString()) {
              _lastBuses    = buses;
              _alertsFuture = _buildAlertsFuture(buses);
            }

            return FutureBuilder<List<_AlertItem>>(
              future: _alertsFuture,
              builder: (context, alertSnap) {
                if (alertSnap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: BusLoadingIndicator(
                          color: context.appPurple, strokeWidth: 2.5));
                }

                final alerts = alertSnap.data ?? [];

                return CustomScrollView(
                  slivers: [
                    // ── Header ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            20,
                            MediaQuery.of(context).padding.top + 16,
                            20,
                            20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.notifications_active_outlined,
                                    color: context.appDark, size: 26),
                                const SizedBox(width: 10),
                                Text('Alertes',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: context.appDark)),
                              ]),
                              const SizedBox(height: 6),
                              Text(
                                'Assurances, vidanges et salaires — du plus urgent au moins urgent',
                                style: TextStyle(
                                    fontSize: 12, color: context.appSub),
                              ),
                              const SizedBox(height: 16),
                              // ── Summary chips ──
                              Row(children: [
                                _SummaryChip(
                                  count: alerts
                                      .where((a) =>
                                          a.type == _AlertType.assurance &&
                                          (a.daysUntilExpiry == null ||
                                              a.daysUntilExpiry! < 30))
                                      .length,
                                  label: 'Assurances',
                                  icon: Icons.shield_outlined,
                                ),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  count: alerts
                                      .where((a) =>
                                          a.type == _AlertType.vidange &&
                                          (a.kmRemaining == null ||
                                              a.kmRemaining! <= 1000))
                                      .length,
                                  label: 'Vidanges',
                                  icon: Icons.oil_barrel_outlined,
                                ),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  count: alerts
                                      .where((a) =>
                                          a.type == _AlertType.salary &&
                                          a.daysUntilSalary != null &&
                                          a.daysUntilSalary! <= 10)
                                      .length,
                                  label: 'Salaires',
                                  icon: Icons.payments_outlined,
                                ),
                              ]),
                            ]),
                      ),
                    ),

                    if (alerts.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64,
                                    color: context.appGreen
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 16),
                                Text('Aucun bus enregistré',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: context.appDark)),
                                const SizedBox(height: 6),
                                Text('Ajoutez des bus pour voir leurs alertes.',
                                    style:
                                        TextStyle(color: context.appSub)),
                              ]),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final item   = alerts[i];
                              final Widget card;
                              if (item.type == _AlertType.assurance) {
                                card = _buildAssuranceCard(context, item);
                              } else if (item.type == _AlertType.vidange) {
                                card = _buildVidangeCard(context, item);
                              } else {
                                card = _buildSalaryCard(context, item);
                              }
                              return StaggeredListItem(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: card,
                                  ),
                              );
                            },
                            childCount: alerts.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CHIP — horizontal filter chips at the top
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final int    count;
  final String label;
  final IconData icon;

  const _SummaryChip({
    required this.count,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = count > 0;
    // Chip bg: surface3 (#2C2C2C dark / #E8E8E8 light) — visible against scaffold
    // When urgent: tint with red at 15%
    final bg = isUrgent
        ? context.appRed.withValues(alpha: 0.14)
        : context.appCardBg3;
    final fg = isUrgent ? context.appRed : context.appSub;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUrgent
                ? context.appRed.withValues(alpha: 0.30)
                : context.appBorder,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '$count $label',
              style: TextStyle(
                  color: fg, fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT CARD — dark surface, jewel-tone badges
// ─────────────────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final String   label;
  final Color    labelColor;
  final String   badge;
  final Color    badgeColor;
  final String   urgencyLevel;

  const _AlertCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.labelColor,
    required this.badge,
    required this.badgeColor,
    this.urgencyLevel = 'normal',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Dark surface — never pure white
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(children: [
        // ── Icon bubble ──
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            if (urgencyLevel == 'critical' || urgencyLevel == 'high')
              Positioned(
                top: -2,
                right: -2,
                child: PulsingDot(
                  color: urgencyLevel == 'critical' ? context.appRed : context.appOrange,
                  size: 12,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // ── Title + subtitle ──
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      // Off-White for dark, near-black for light
                      color: context.appDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // ── Label tag — 20% opacity fill, 100% opacity text ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: labelColor)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: context.appSub)),
          ]),
        ),

        const SizedBox(width: 10),

        // ── Badge (countdown / km remaining) ──
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: badgeColor.withValues(alpha: 0.30), width: 1),
          ),
          child: Text(badge,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor)),
        ),
      ]),
    );
  }
}
