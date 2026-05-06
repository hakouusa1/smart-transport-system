import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import 'vidange_details_screen.dart';
import 'assurance_details_screen.dart';
import 'salary_details_screen.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/bus_loading_indicator.dart';
import '../constants.dart';
import '../app_settings_notifier.dart';

enum _AlertType { assurance, vidange, salary }

class _AlertItem {
  final Bus bus;
  final _AlertType type;
  final int? daysUntilExpiry;
  final int? kmRemaining;
  // Keys: 'driver', 'collector' — translated in card builder
  final List<String>? salaryPositionKeys;
  final int? daysUntilSalary;

  const _AlertItem({
    required this.bus,
    required this.type,
    this.daysUntilExpiry,
    this.kmRemaining,
    this.salaryPositionKeys,
    this.daysUntilSalary,
  });

  /// Normalized urgency on a 0–100 scale (lower = more urgent).
  /// This allows fair comparison across alert types that use
  /// different units (days vs km).
  double get urgencyScore {
    if (type == _AlertType.assurance) {
      // Insurance: 0 days left → 0 (critical), ≥365 days → 100 (safe)
      final days = daysUntilExpiry;
      if (days == null) return 0; // unknown = treat as critical
      if (days < 0) return 0;    // already expired
      return (days / 365.0 * 100).clamp(0, 100);
    }
    if (type == _AlertType.vidange) {
      // Oil change: 0 km left → 0 (critical), ≥10 000 km → 100 (safe)
      final km = kmRemaining;
      if (km == null) return 0;
      if (km <= 0) return 0;
      return (km / appSettingsNotifier.value.vidangeIntervalKm * 100).clamp(0, 100);
    }
    // Salary: 0 days left → 0 (critical), ≥30 days → 100 (safe)
    final days = daysUntilSalary;
    if (days == null) return 100; // no salary date = not urgent
    if (days <= 0) return 0;
    return (days / 30.0 * 100).clamp(0, 100);
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<_AlertItem> _alertItems = [];
  List<Bus> _lastBuses = [];
  bool _isLoading = true;
  StreamSubscription<List<Bus>>? _busSub;

  void _updateAlerts(List<Bus> buses) {
    final acceptedBuses = buses.where((b) => b.isApproved).toList();
    _lastBuses = acceptedBuses;
    _alertItems = _buildAlerts(acceptedBuses);
  }

  List<_AlertItem> _buildAlerts(List<Bus> buses) {
    final now = DateTime.now();
    final allItems = <_AlertItem>[];

    for (final bus in buses) {
      // 1. Assurance
      if (bus.insuranceEndDate != null) {
        allItems.add(_AlertItem(
            bus: bus,
            type: _AlertType.assurance,
            daysUntilExpiry: bus.insuranceEndDate!.difference(now).inDays));
      } else {
        allItems.add(_AlertItem(
            bus: bus, type: _AlertType.assurance, daysUntilExpiry: null));
      }

      // 2. Vidange — derived from odometer fields already on the bus document;
      //    no Firestore query needed (eliminates the prior N aggregate reads).
      final traveled = (bus.currentKm ?? 0) - (bus.lastVidangeKm ?? 0);
      allItems.add(_AlertItem(
          bus: bus,
          type: _AlertType.vidange,
          kmRemaining: (appSettingsNotifier.value.vidangeIntervalKm - traveled).clamp(0, appSettingsNotifier.value.vidangeIntervalKm)));

      // 3. Salary — store internal keys, translate in card builder
      final positionKeys = <String>[];
      if (bus.driverId.isNotEmpty) positionKeys.add('driver');
      if (bus.recipientSalary != null && bus.recipientSalary! > 0) {
        positionKeys.add('collector');
      }

      if (positionKeys.isNotEmpty) {
        DateTime nextSalary = _firstOfMonth(now, 1);
        if (bus.lastSalaryDate != null &&
            now.difference(bus.lastSalaryDate!).inDays < 20) {
          nextSalary = _firstOfMonth(now, 2);
        }
        allItems.add(_AlertItem(
          bus: bus,
          type: _AlertType.salary,
          salaryPositionKeys: positionKeys,
          daysUntilSalary: nextSalary.difference(now).inDays,
        ));
      }
    }

    allItems.sort((a, b) => a.urgencyScore.compareTo(b.urgencyScore));
    return allItems;
  }

  // Returns the 1st of the month that is [months] ahead of [base],
  // correctly wrapping the year when month + offset > 12.
  static DateTime _firstOfMonth(DateTime base, int months) {
    final total = base.month - 1 + months;
    return DateTime(base.year + total ~/ 12, total % 12 + 1, 1);
  }

  // ── Semantic color helpers ──
  Color _assuranceColor(int? days) {
    if (days == null || days < 30) return context.appRed;
    if (days < 90) return context.appOrange;
    return context.appGreen;
  }

  Color _vidangeColor(int? km) {
    if (km == null || km <= 0)    return context.appRed;
    if (km <= kVidangeWarnKm)     return context.appOrange;
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
    final l10n = AppLocalizations.of(context);
    final bus   = item.bus;
    final days  = item.daysUntilExpiry;
    final color = _assuranceColor(days);

    final String subtitle;
    final String badge;
    if (days == null) {
      subtitle = l10n.insuranceDateUnknown;
      badge    = l10n.insuranceBadgeUnknown;
    } else if (days < 0) {
      subtitle = l10n.insuranceExpiredSinceFmt(-days);
      badge    = l10n.insuranceBadgeExpired;
    } else if (days == 0) {
      subtitle = l10n.insuranceExpiresToday;
      badge    = l10n.badgeToday;
    } else {
      final exp = DateFormat('dd/MM/yyyy').format(bus.insuranceEndDate!);
      subtitle = l10n.insuranceExpiresFmt(exp, days);
      badge    = l10n.daysBadgeFmt(days);
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
        label: l10n.insuranceLabel,
        labelColor: context.appAccent,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  Widget _buildVidangeCard(BuildContext context, _AlertItem item) {
    final l10n = AppLocalizations.of(context);
    final bus   = item.bus;
    final km    = item.kmRemaining;
    final color = _vidangeColor(km);

    final String subtitle;
    final String badge;
    if (km == null) {
      subtitle = l10n.oilChangeMileageUnknown;
      badge    = l10n.oilChangeBadgeUnknown;
    } else if (km < 0) {
      subtitle = l10n.oilChangeExceededFmt(-km);
      badge    = l10n.oilChangeExceededBadgeFmt(-km);
    } else if (km == 0) {
      subtitle = l10n.oilChangeRequiredNow;
      badge    = '0 km';
    } else {
      subtitle = l10n.oilChangeRemainingFmt(km);
      badge    = '$km km';
    }

    final String urgencyLevel;
    if (km == null || km <= 0) urgencyLevel = 'critical';
    else if (km <= kVidangeWarnKm) urgencyLevel = 'high';
    else urgencyLevel = 'normal';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VidangeDetailsScreen(
                bus: bus,
                kmRemaining: km,
                intervalKm: appSettingsNotifier.value.vidangeIntervalKm)),
      ).then((_) => setState(() => _updateAlerts(_lastBuses))),
      child: _AlertCard(
        icon: Icons.oil_barrel_outlined,
        iconColor: color,
        title: bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
        subtitle: subtitle,
        label: l10n.oilChangeLabel,
        labelColor: context.appOrange,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  Widget _buildSalaryCard(BuildContext context, _AlertItem item) {
    final l10n = AppLocalizations.of(context);
    final bus   = item.bus;
    final days  = item.daysUntilSalary;
    final color = _salaryColor(days);

    final String subtitle;
    final String badge;
    if (days == null) {
      subtitle = l10n.salaryDateUnknown;
      badge    = l10n.salaryBadgeUnknown;
    } else if (days == 0) {
      subtitle = l10n.salaryDueToday;
      badge    = l10n.badgeToday;
    } else {
      final dt  = DateTime.now().add(Duration(days: days));
      subtitle  = l10n.salaryScheduledFmt(DateFormat('dd/MM/yyyy').format(dt), days);
      badge     = l10n.daysBadgeFmt(days);
    }

    final String urgencyLevel;
    if (days == null) urgencyLevel = 'normal';
    else if (days <= 3) urgencyLevel = 'critical';
    else if (days <= 10) urgencyLevel = 'high';
    else urgencyLevel = 'normal';

    final positionNames = (item.salaryPositionKeys ?? ['driver'])
        .map((k) => k == 'driver' ? l10n.driverLabel : l10n.collectorLabel)
        .join(' & ');
    final label = l10n.salaryLabelFmt(positionNames);

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
        label: label,
        labelColor: context.appPrimary,
        badge: badge,
        badgeColor: color,
        urgencyLevel: urgencyLevel,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Pre-populate immediately if BusService already has data (avoids missing
    // the initial Firestore emission when DashboardScreen subscribed first).
    final cached = BusService().latestBuses;
    if (cached != null) {
      _updateAlerts(cached);
      _isLoading = false;
    }
    _busSub = BusService().getBuses().listen(
      (buses) {
        if (mounted) setState(() { _updateAlerts(buses); _isLoading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Builder(
          builder: (context) {
            if (_isLoading) {
              return Center(
                  child: BusLoadingIndicator(
                      color: context.appPurple, strokeWidth: 2.5));
            }

            final alerts = _alertItems;

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
                                Text(l10n.alertsTitle,
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: context.appDark)),
                              ]),
                              const SizedBox(height: 6),
                              Text(
                                l10n.alertsSubtitle,
                                style: TextStyle(
                                    fontSize: 12, color: context.appSub),
                              ),
                              const SizedBox(height: 16),
                              // ── Summary chips ──
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: [
                                  _SummaryChip(
                                    count: alerts
                                        .where((a) =>
                                            a.type == _AlertType.assurance &&
                                            (a.daysUntilExpiry == null ||
                                                a.daysUntilExpiry! < 30))
                                        .length,
                                    label: l10n.chipInsuranceLabel,
                                    icon: Icons.shield_outlined,
                                  ),
                                  _SummaryChip(
                                    count: alerts
                                        .where((a) =>
                                            a.type == _AlertType.vidange &&
                                            (a.kmRemaining == null ||
                                                a.kmRemaining! <= kVidangeWarnKm))
                                        .length,
                                    label: l10n.chipOilChangeLabel,
                                    icon: Icons.oil_barrel_outlined,
                                  ),
                                  _SummaryChip(
                                    count: alerts
                                        .where((a) =>
                                            a.type == _AlertType.salary &&
                                            a.daysUntilSalary != null &&
                                            a.daysUntilSalary! <= 10)
                                        .length,
                                    label: l10n.chipSalariesLabel,
                                    icon: Icons.payments_outlined,
                                  ),
                                ],
                              ),
                            ]),
                      ),
                    ),

                    if (alerts.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _lastBuses.isEmpty
                                  ? [
                                      Icon(Icons.directions_bus_outlined,
                                          size: 64,
                                          color: context.appSub
                                              .withValues(alpha: 0.4)),
                                      const SizedBox(height: 16),
                                      Text(l10n.noBusesFound,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: context.appText)),
                                      const SizedBox(height: 6),
                                      Text(l10n.addBusAction,
                                          textAlign: TextAlign.center,
                                          style:
                                              TextStyle(color: context.appSub)),
                                    ]
                                  : [
                                      Icon(Icons.verified_user,
                                          size: 64,
                                          color: context.appGreen),
                                      const SizedBox(height: 16),
                                      Text(l10n.allBusesHealthy,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: context.appText)),
                                      const SizedBox(height: 6),
                                      Text(l10n.noAlertsMessage,
                                          textAlign: TextAlign.center,
                                          style:
                                              TextStyle(color: context.appSub)),
                                    ],
                            ),
                          ),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CHIP
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
    final bg = isUrgent
        ? context.appRed.withValues(alpha: 0.14)
        : context.appCardBg3;
    final fg = isUrgent ? context.appRed : context.appSub;
    final message = '$count $label';

    return Tooltip(
      message: message,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 13),
            const SizedBox(width: 5),
            Text(
              message,
              style: TextStyle(
                  color: fg, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT CARD
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
                      color: context.appDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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

        // ── Badge ──
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
