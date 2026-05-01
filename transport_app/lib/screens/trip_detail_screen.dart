import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../theme_notifier.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  String? _driverName;
  bool _loadingDriver = true;

  @override
  void initState() {
    super.initState();
    _fetchDriverName();
  }

  Future<void> _fetchDriverName() async {
    final driverId = widget.trip['driverId'] as String? ?? '';
    if (driverId.isEmpty) {
      if (mounted) setState(() => _loadingDriver = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      final data = doc.data();
      final name = (data?['name'] ?? data?['displayName'] ?? data?['fullName'])
          as String?;
      if (mounted) setState(() { _driverName = name; _loadingDriver = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDriver = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = widget.trip;

    final busName = trip['busName']?.toString() ?? '';
    final lineName = trip['lineName']?.toString() ?? '';
    final departure = trip['departure']?.toString() ?? '—';
    final arrival = trip['arrival']?.toString() ?? '—';
    final recette = (trip['recette'] as num?)?.toDouble() ?? 0.0;
    final distKm = (trip['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final durationH = (trip['durationHours'] as num?)?.toDouble() ?? 0.0;
    final fuelCostDA = (trip['fuelCostDA'] as num?)?.toDouble();
    final fuelLiters = (trip['fuelLiters'] as num?)?.toDouble();
    final driverId = trip['driverId']?.toString() ?? '';

    final ts = trip['timestamp'] as Timestamp?;
    final arrivalDt = ts?.toDate();
    DateTime? departureDt;
    if (arrivalDt != null && durationH > 0) {
      departureDt = arrivalDt.subtract(
          Duration(seconds: (durationH * 3600).toInt()));
    }

    final dateStr = arrivalDt != null
        ? DateFormat('EEEE d MMMM yyyy',
                Localizations.localeOf(context).toString())
            .format(arrivalDt)
        : '—';
    final arrivalTimeStr =
        arrivalDt != null ? DateFormat('HH:mm').format(arrivalDt) : '—';
    final departureTimeStr =
        departureDt != null ? DateFormat('HH:mm').format(departureDt) : '—';

    final durationMin = (durationH * 60).round();
    final durationStr = durationMin > 0
        ? (durationMin >= 60
            ? '${durationMin ~/ 60}h ${(durationMin % 60).toString().padLeft(2, '0')}min'
            : '${durationMin}min')
        : '—';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: context.appDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.tripDetailTitle,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.appDark),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Route header ──────────────────────────────────────────────
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lineName.isNotEmpty ? lineName : busName,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.appDark),
                          ),
                        ),
                      ],
                    ),
                    if (busName.isNotEmpty && lineName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(busName,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.appSub,
                              fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _RouteStop(label: departure, isOrigin: true),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (_) => Container(
                                width: 4,
                                height: 4,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                    color: context.appSub.withValues(alpha: 0.5),
                                    shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ),
                        _RouteStop(label: arrival, isOrigin: false),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: context.appSub),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 12, color: context.appSub),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Revenue card ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: context.appGreen.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.payments_outlined,
                          size: 16, color: context.appGreen),
                      const SizedBox(width: 8),
                      Text(l10n.revenueLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.appGreen)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      '${_fmtDA(recette)} DZD',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: context.appGreen),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.appGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14,
                              color: context.appGreen.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.revenueEnteredByDriver,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      context.appGreen.withValues(alpha: 0.85),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Driver section ────────────────────────────────────────────
              _Section(
                child: Column(
                  children: [
                    _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        label: l10n.driverLabel),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: l10n.tripDetailDriverName,
                      value: _loadingDriver
                          ? l10n.loadingLabel
                          : (_driverName?.isNotEmpty == true
                              ? _driverName!
                              : l10n.unknownDriver),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.fingerprint,
                      label: l10n.tripDetailDriverId,
                      value: driverId.isNotEmpty
                          ? driverId.length > 12
                              ? '...${driverId.substring(driverId.length - 12)}'
                              : driverId
                          : '—',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Time section ──────────────────────────────────────────────
              _Section(
                child: Column(
                  children: [
                    _SectionHeader(
                        icon: Icons.schedule_outlined,
                        label: l10n.tripDetailTimeSection),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.login_outlined,
                      label: l10n.tripDetailDeparture,
                      value: departureTimeStr,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.logout_outlined,
                      label: l10n.tripDetailArrival,
                      value: arrivalTimeStr,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.timer_outlined,
                      label: l10n.tripDetailDuration,
                      value: durationStr,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Distance section ──────────────────────────────────────────
              _Section(
                child: Column(
                  children: [
                    _SectionHeader(
                        icon: Icons.route_outlined,
                        label: l10n.tripDetailRouteSection),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.straighten_outlined,
                      label: l10n.distanceLabel,
                      value: distKm > 0
                          ? '${distKm.toStringAsFixed(1)} km'
                          : '—',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: l10n.tripDetailRoute,
                      value: '$departure → $arrival',
                    ),
                  ],
                ),
              ),

              // ── Fuel section (shown only if data present) ─────────────────
              if (fuelCostDA != null || fuelLiters != null) ...[
                const SizedBox(height: 14),
                _Section(
                  child: Column(
                    children: [
                      _SectionHeader(
                          icon: Icons.local_gas_station_outlined,
                          label: l10n.fuelLabel),
                      const SizedBox(height: 12),
                      if (fuelCostDA != null)
                        _DetailRow(
                          icon: Icons.paid_outlined,
                          label: l10n.tripDetailFuelCost,
                          value: '${_fmtDA(fuelCostDA)} DZD',
                        ),
                      if (fuelCostDA != null && fuelLiters != null)
                        const SizedBox(height: 8),
                      if (fuelLiters != null)
                        _DetailRow(
                          icon: Icons.opacity_outlined,
                          label: l10n.tripDetailFuelLiters,
                          value: '${fuelLiters.toStringAsFixed(1)} L',
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: context.appSub),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appSub,
              letterSpacing: 0.4)),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.appSub),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 13, color: context.appSub)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appDark),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final bool isOrigin;
  const _RouteStop({required this.label, required this.isOrigin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOrigin ? context.appPrimary : context.appGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appDark)),
      ],
    );
  }
}

String _fmtDA(double v) => v
    .toStringAsFixed(2)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
