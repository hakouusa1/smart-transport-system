import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/bus_service.dart';
import '../models/bus_model.dart';
import '../theme_notifier.dart';
import '../locale_notifier.dart';
import '../l10n/app_localizations.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/bus_loading_indicator.dart';
import '../utils/profit_calculator.dart';
import '../app_settings_notifier.dart';

// ─────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────
class _TripProfit {
  final double recette;
  final double chauffeurSalary;
  final double chauffeurDay;
  final double receveurSalary;
  final double receveurDay;
  final bool   hasReceveur;
  final double fuelCostDA;
  final double fuelLiters;
  final double avgSpeedKmh;
  final double distKm;
  final double durationH;
  final double profit;
  final String chauffeurType;
  final String receveurType;
  final int chauffeurTripCount;
  final int receveurTripCount;

  const _TripProfit({
    required this.recette,
    required this.chauffeurSalary,
    required this.chauffeurDay,
    required this.receveurSalary,
    required this.receveurDay,
    required this.hasReceveur,
    required this.fuelCostDA,
    required this.fuelLiters,
    required this.avgSpeedKmh,
    required this.distKm,
    required this.durationH,
    required this.profit,
    required this.chauffeurType,
    required this.receveurType,
    required this.chauffeurTripCount,
    required this.receveurTripCount,
  });
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class StatisticsScreen extends StatefulWidget {
  final bool showBackButton;
  const StatisticsScreen({super.key, this.showBackButton = true});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;

  final AuthService _auth       = AuthService();
  final BusService  _busService = BusService();

  static const int _pageSize = 50;

  /// Compute the default start date: Monday of the current week.
  /// Edge case: if today IS Monday, use the previous week's Monday
  /// so the chart shows a full 7-day range instead of a single dot.
  static DateTime _defaultStartDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (now.weekday == DateTime.monday) {
      return today.subtract(const Duration(days: 7));
    }
    return today.subtract(Duration(days: now.weekday - 1));
  }

  DateTime _startDate     = _defaultStartDate();
  DateTime _endDate       = DateTime.now();
  String   _selectedBusId = 'all';

  List<Map<String, dynamic>> _allTrips    = [];
  bool _loadingTrips  = true;
  bool _hasMore       = false;
  bool _loadingMore   = false;
  DocumentSnapshot? _lastDoc;

  final Map<String, double>               _chauffeurSalaryCache     = {};
  final Map<String, String>               _chauffeurSalaryTypeCache = {};
  final Map<String, double>               _receveurSalaryCache      = {};
  final Map<String, String>               _receveurSalaryTypeCache  = {};
  final Map<String, Map<String, dynamic>> _busCache                 = {};

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadPersistedRange();
  }

  Future<void> _loadPersistedRange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rangeDays = prefs.getInt('stats_range_days');
      if (rangeDays != null && rangeDays > 0 && mounted) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        setState(() {
          _startDate = today.subtract(Duration(days: rangeDays));
          _endDate   = now;
        });
      }
    } catch (_) {}
    _loadFirstPage();
  }

  void _triggerEntrance() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _entranceCtrl.value = 1.0;
      } else {
        _entranceCtrl.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    final start = Timestamp.fromDate(DateTime(_startDate.year, _startDate.month, _startDate.day));
    final end   = Timestamp.fromDate(DateTime(_endDate.year,   _endDate.month,   _endDate.day, 23, 59, 59));
    return FirebaseFirestore.instance
        .collection('trips')
        .where('ownerId', isEqualTo: _auth.uid)
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _loadingTrips = true;
      _allTrips     = [];
      _lastDoc      = null;
      _hasMore      = false;
    });
    try {
      final snap = await _baseQuery().get();
      final trips = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == _pageSize;
      await _enrichBuses(trips);
      if (!mounted) return;
      setState(() {
        _allTrips     = trips;
        _loadingTrips = false;
      });
      _triggerEntrance();
    } catch (_) {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<void> _loadMorePage() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _baseQuery().startAfterDocument(_lastDoc!).get();
      final newTrips = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == _pageSize;
      await _enrichBuses(newTrips);
      if (!mounted) return;
      setState(() {
        _allTrips.addAll(newTrips);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _enrichBuses(List<Map<String, dynamic>> trips) async {
    final busIds = trips
        .map((t) => t['busId'] as String? ?? '')
        .where((id) => id.isNotEmpty && !_busCache.containsKey(id))
        .toSet();

    await Future.wait(busIds.map((id) async {
      try {
        final doc = await FirebaseFirestore.instance.collection('buses').doc(id).get();
        final data = doc.data();
        if (data != null) {
          _busCache[id]                = data;
          _chauffeurSalaryCache[id]    = (data['salary']            as num?)?.toDouble() ?? 0.0;
          _chauffeurSalaryTypeCache[id] = data['chauffeurSalaryType'] as String? ?? 'monthly';
          _receveurSalaryCache[id]     = (data['recipient']          as num?)?.toDouble() ?? 0.0;
          _receveurSalaryTypeCache[id]  = data['receveurSalaryType']  as String? ?? 'monthly';
        }
      } catch (_) {}
    }));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  _TripProfit _calcProfit(
    Map<String, dynamic> trip,
    Map<String, Map<String, int>> tripsPerDayPerDriver,
    Map<String, Map<String, int>> tripsPerDayPerBus,
  ) {
    final recette   = (trip['recette']       as num?)?.toDouble() ?? 0;
    final distKm    = (trip['distanceKm']    as num?)?.toDouble() ?? 0;
    final durationH = (trip['durationHours'] as num?)?.toDouble() ?? 0;
    final driverId  = trip['driverId'] as String? ?? '';
    final busId     = trip['busId']    as String? ?? '';

    final ts      = trip['timestamp'] as Timestamp?;
    final date    = ts?.toDate();
    final dateKey = date != null ? DateFormat('yyyy-MM-dd').format(date) : '';

    final chauffeurSalary = _chauffeurSalaryCache[busId] ?? 0.0;
    final chauffeurType   = _chauffeurSalaryTypeCache[busId] ?? 'monthly';
    final chauffeurTripCount = (dateKey.isNotEmpty && driverId.isNotEmpty)
        ? (tripsPerDayPerDriver[dateKey]?[driverId] ?? 1)
        : 1;

    final receveurSalary = _receveurSalaryCache[busId] ?? 0.0;
    final receveurType   = _receveurSalaryTypeCache[busId] ?? 'monthly';
    final receveurTripCount = (dateKey.isNotEmpty && busId.isNotEmpty)
        ? (tripsPerDayPerBus[dateKey]?[busId] ?? 1)
        : 1;

    final poidsKg = (_busCache[busId] ?? {})['poids'] != null
        ? ((_busCache[busId]!['poids'] as num).toDouble())
        : null;

    final fuelCostDAOverride = trip['fuelCostDA'] != null
        ? (trip['fuelCostDA'] as num).toDouble()
        : null;

    final settings = appSettingsNotifier.value;
    final result = ProfitCalculator.calcTrip(
      recette:              recette,
      distKm:               distKm,
      durationH:            durationH,
      chauffeurSalary:      chauffeurSalary,
      chauffeurSalaryType:  chauffeurType,
      chauffeurTripCount:   chauffeurTripCount,
      receveurSalary:       receveurSalary,
      receveurSalaryType:   receveurType,
      receveurTripCount:    receveurTripCount,
      fuelCostDAOverride:   fuelCostDAOverride,
      poidsKg:              poidsKg,
      fuelPriceDA:          settings.fuelPricePerLiter,
      baseConsumptionL100:  settings.fuelConsumptionL100,
    );

    return _TripProfit(
      recette:            recette,
      chauffeurSalary:    chauffeurSalary,
      chauffeurDay:       result.chauffeurDay,
      receveurSalary:     receveurSalary,
      receveurDay:        result.receveurDay,
      hasReceveur:        result.hasReceveur,
      fuelCostDA:         result.fuelCostDA,
      fuelLiters:         result.fuelLiters,
      avgSpeedKmh:        result.avgSpeedKmh,
      distKm:             distKm,
      durationH:          durationH,
      profit:             result.profit,
      chauffeurType:      chauffeurType,
      receveurType:       receveurType,
      chauffeurTripCount: chauffeurTripCount,
      receveurTripCount:  receveurTripCount,
    );
  }

  Future<void> _pickDateRange() async {
    final isDark = context.isDark;
    final locale = localeNotifier.value;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(primary: context.appPurple)
              : ColorScheme.light(primary: context.appPurple),
        ),
        child: child!,
      ),
      locale: locale,
    );
    if (range != null) {
      final diffDays = range.end.difference(range.start).inDays;
      _entranceCtrl.reset();
      setState(() {
        _startDate = range.start;
        _endDate   = range.end;
      });
      _loadFirstPage();
      _persistRangeDays(diffDays);
    }
  }

  Future<void> _persistRangeDays(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stats_range_days', days);
    } catch (_) {}
  }

  String _dateRangeText(AppLocalizations l10n) {
    final fmt  = DateFormat('d MMM', l10n.locale.languageCode);
    final year = _endDate.year;
    return '${fmt.format(_startDate)} - ${fmt.format(_endDate)} $year';
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
        body: Column(children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 24),
            child: Row(children: [
              if (widget.showBackButton) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: context.appPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.arrow_back, color: context.appDark),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                AppLocalizations.of(context).statisticsTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.appDark,
                ),
              ),
            ]),
          ),

          // ── Body ──
          Expanded(
            child: _loadingTrips
                ? Center(child: BusLoadingIndicator(color: context.appPurple))
                : _buildBody(),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);

    Widget _animCard(Widget child, int index) {
      if (MediaQuery.of(context).disableAnimations) return child;
      final start = (index * 0.15).clamp(0.0, 0.7);
      final end = (start + 0.3).clamp(0.0, 1.0);
      final curved = CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    }

    final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endOfDay   = DateTime(_endDate.year,   _endDate.month,   _endDate.day, 23, 59, 59);

    final filteredTrips = _allTrips.where((trip) {
      final busId   = trip['busId'] as String? ?? '';
      final busData = _busCache[busId];
      // Only include approved buses (default to approved for legacy)
      final status  = busData?['validationStatus'] ?? 'approved';
      if (status != 'approved') return false;

      if (_selectedBusId != 'all' && busId != _selectedBusId) return false;
      final ts = trip['timestamp'] as Timestamp?;
      if (ts == null) return false;
      final date = ts.toDate();
      return !date.isBefore(startOfDay) && !date.isAfter(endOfDay);
    }).toList();
    // Already ordered descending by Firestore query; no client-side sort needed.

    final tripsPerDayPerDriver = <String, Map<String, int>>{};
    final tripsPerDayPerBus    = <String, Map<String, int>>{};
    for (final trip in filteredTrips) {
      final ts = trip['timestamp'] as Timestamp?;
      if (ts != null) {
        final dateKey  = DateFormat('yyyy-MM-dd').format(ts.toDate());
        final driverId = trip['driverId'] as String? ?? '';
        final busId    = trip['busId']    as String? ?? '';
        if (driverId.isNotEmpty) {
          tripsPerDayPerDriver.putIfAbsent(dateKey, () => {}).update(
              driverId, (v) => v + 1, ifAbsent: () => 1);
        }
        if (busId.isNotEmpty) {
          tripsPerDayPerBus.putIfAbsent(dateKey, () => {}).update(
              busId, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    final profits = filteredTrips
        .map((t) => _calcProfit(t, tripsPerDayPerDriver, tripsPerDayPerBus))
        .toList();
    double totalRecette = 0, totalDist = 0, totalFuel = 0, totalProfit = 0;
    for (final p in profits) {
      totalRecette += p.recette;
      totalDist    += p.distKm;
      totalFuel    += p.fuelCostDA;
      totalProfit  += p.profit;
    }
    final tripCount   = filteredTrips.length;
    final isGainTotal = totalProfit >= 0;

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),

        // ── Filter row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  l10n.filterByBus,
                  style: TextStyle(
                      fontSize: 11,
                      color: context.appSub,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<Bus>>(
                  stream: _busService.getBuses(),
                  builder: (_, snap) {
                    final buses = (snap.data ?? BusService().latestBuses ?? [])
                        .where((b) => b.isApproved)
                        .toList();
                    final safeValue = (_selectedBusId == 'all' ||
                            buses.any((b) => b.busId == _selectedBusId))
                        ? _selectedBusId
                        : 'all';
                    return SizedBox(
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.appCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.appBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: safeValue,
                            isExpanded: true,
                            dropdownColor: context.appCardBg2,
                            style: TextStyle(
                                color: context.appText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            icon: Icon(Icons.keyboard_arrow_down_rounded,
                                color: context.appSub),
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(l10n.allBuses,
                                    style: TextStyle(color: context.appText)),
                              ),
                              ...buses.map((b) => DropdownMenuItem(
                                value: b.busId,
                                child: Text(
                                  b.busName.isNotEmpty ? b.busName : 'N° ${b.busNumber}',
                                  style: TextStyle(color: context.appText),
                                ),
                              )),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBusId = val);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),

            const SizedBox(width: 12),

            SizedBox(
              height: 44,
              child: GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.appCardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: context.appSub),
                    const SizedBox(width: 7),
                    Text(
                      _dateRangeText(AppLocalizations.of(context)),
                      style: TextStyle(
                          fontSize: 12,
                          color: context.appText,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Stat cards ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              Expanded(child: _animCard(_StatCard(
                title: l10n.totalRevenue,
                value: '${_fmtDA(totalRecette)} DA',
                icon: Icons.savings_outlined,
                iconColor: context.appAccent,
              ), 0)),
              const SizedBox(width: 12),
              Expanded(child: _animCard(_StatCard(
                title: l10n.netProfit,
                value: '${isGainTotal ? '+' : '-'}${_fmtDA(totalProfit)} DA',
                icon: isGainTotal
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                iconColor: isGainTotal ? context.appGreen : context.appRed,
              ), 1)),
            ]),

            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _animCard(_StatCard(
                title: l10n.totalTrips,
                value: '$tripCount',
                icon: Icons.route_outlined,
                iconColor: context.appOrange,
                compact: true,
              ), 2)),
              const SizedBox(width: 12),
              Expanded(child: _animCard(_StatCard(
                title: l10n.distanceLabel,
                value: '${totalDist.toStringAsFixed(0)} km',
                icon: Icons.map_outlined,
                iconColor: context.appPrimary,
                compact: true,
              ), 3)),
              const SizedBox(width: 12),
              Expanded(child: _animCard(_StatCard(
                title: l10n.fuelLabel,
                value: '${_fmtDA(totalFuel)} DA',
                icon: Icons.local_gas_station_outlined,
                iconColor: context.appOrange,
                compact: true,
              ), 4)),
            ]),
          ]),
        ),

        const SizedBox(height: 28),

        // ── Trip list header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.tripDetailsFmt(tripCount),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appDark),
          ),
        ),
        const SizedBox(height: 12),

        if (filteredTrips.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(l10n.noTripsForPeriod,
                  style: TextStyle(color: context.appSub)),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filteredTrips.length,
            itemBuilder: (_, i) =>
                StaggeredListItem(
                  index: i.clamp(0, 8),
                  child: _TripCard(trip: filteredTrips[i], profit: profits[i]),
                ),
          ),

        // ── Load More / End indicator ──
        if (filteredTrips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _hasMore
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore ? null : _loadMorePage,
                      icon: _loadingMore
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.appPurple,
                              ),
                            )
                          : Icon(Icons.expand_more, color: context.appPurple),
                      label: Text(
                        _loadingMore ? l10n.loading : l10n.loadMore,
                        style: TextStyle(color: context.appPurple),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.appPurple.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      l10n.noMoreTrips,
                      style: TextStyle(fontSize: 12, color: context.appSub),
                    ),
                  ),
          ),
        ],

        const SizedBox(height: 40),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String   title;
  final String   value;
  final IconData icon;
  final Color    iconColor;
  final bool     compact;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(compact ? 7 : 9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: iconColor, size: compact ? 16 : 22),
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 15 : 22,
            fontWeight: FontWeight.w700,
            color: context.appDark,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(fontSize: 11, color: context.appSub)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// TRIP CARD — expandable profit breakdown
// ─────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final _TripProfit profit;
  const _TripCard({required this.trip, required this.profit});

  @override
  Widget build(BuildContext context) {
    final p       = profit;
    final isGain  = p.profit >= 0;
    final ts      = trip['timestamp'] as Timestamp?;
    final date    = ts?.toDate();
    final timeArr = date != null ? DateFormat('HH:mm').format(date) : '';
    final durationH = (trip['durationHours'] as num?)?.toDouble() ?? 0;
    String timeDep = '';
    if (date != null) {
      final depDate = date.subtract(Duration(seconds: (durationH * 3600).toInt()));
      timeDep = DateFormat('HH:mm').format(depDate);
    }
    final lineName = trip['lineName'] as String? ?? '';
    final busName  = trip['busName']  as String? ?? 'Bus';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          iconColor: context.appSub,
          collapsedIconColor: context.appSub,

          title: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: context.appPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.directions_bus, color: context.appPurple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                lineName.isNotEmpty ? lineName : busName,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appDark),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                busName.isNotEmpty ? busName : 'Bus inconnu',
                style: TextStyle(fontSize: 11, color: context.appSub, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (p.distKm > 0) '${p.distKm.toStringAsFixed(1)} km',
                  if (p.avgSpeedKmh > 0) '${p.avgSpeedKmh.toStringAsFixed(0)} km/h',
                ].join(' · '),
                style: TextStyle(fontSize: 10, color: context.appSub),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmtDA(p.recette)} DA',
                  style: TextStyle(fontSize: 12, color: context.appSub)),
              const SizedBox(height: 2),
              Text(
                '${isGain ? '+' : '-'}${_fmtDA(p.profit)} DA',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isGain ? context.appGreen : context.appRed),
              ),
            ]),
          ]),

          children: [
            Divider(height: 1, color: context.appBorder),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.access_time_outlined, size: 14, color: context.appSub),
              const SizedBox(width: 8),
              Expanded(child: Text('Heure', style: TextStyle(fontSize: 12, color: context.appDark))),
              Text('$timeDep - $timeArr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appDark)),
            ]),
            const SizedBox(height: 8),
            _profitRow(context, Icons.payments_outlined,
                AppLocalizations.of(context).revenueLabel,
                p.recette, isRevenue: true),
            const SizedBox(height: 8),
            _profitRow(context, Icons.person_outline,
                p.chauffeurType == 'monthly'
                    ? AppLocalizations.of(context).driverSalaryMonthlyFmt(p.chauffeurTripCount)
                    : AppLocalizations.of(context).driverSalaryPerTrip,
                -p.chauffeurDay,
                detail: p.chauffeurType == 'monthly'
                    ? '${_fmtDA(p.chauffeurSalary)} DA / 30 / ${p.chauffeurTripCount}'
                    : '${_fmtDA(p.chauffeurSalary)} DA'),
            if (p.hasReceveur) ...[
              const SizedBox(height: 8),
              _profitRow(context, Icons.person_2_outlined,
                  p.receveurType == 'monthly'
                      ? AppLocalizations.of(context).collectorSalaryMonthlyFmt(p.receveurTripCount)
                      : AppLocalizations.of(context).collectorSalaryPerTrip,
                  -p.receveurDay,
                  detail: p.receveurType == 'monthly'
                      ? '${_fmtDA(p.receveurSalary)} DA / 30 / ${p.receveurTripCount}'
                      : '${_fmtDA(p.receveurSalary)} DA'),
            ],
            const SizedBox(height: 8),
            _profitRow(context, Icons.local_gas_station_outlined,
                AppLocalizations.of(context).estimatedFuel, -p.fuelCostDA,
                detail: p.distKm > 0
                    ? '${p.fuelLiters.toStringAsFixed(1)} L × ${appSettingsNotifier.value.fuelPricePerLiter.toStringAsFixed(0)} DA/L'
                    : null),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: context.appBorder),
            ),
            Row(children: [
              Icon(
                isGain ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: isGain ? context.appGreen : context.appRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(AppLocalizations.of(context).netProfit,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appDark))),
              Text(
                '${isGain ? '+' : '-'}${_fmtDA(p.profit)} DA',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isGain ? context.appGreen : context.appRed),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
Widget _profitRow(
  BuildContext context,
  IconData icon,
  String label,
  double valueDA, {
  String? detail,
  bool isRevenue = false,
}) {
  final color = isRevenue ? context.appAccent : context.appSub;
  final sign  = valueDA >= 0 ? '+' : '-';
  return Row(children: [
    Icon(icon, size: 14, color: context.appSub),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.appDark)),
      if (detail != null)
        Text(detail, style: TextStyle(fontSize: 10, color: context.appSub)),
    ])),
    Text(
      '$sign${_fmtDA(valueDA)} DA',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  ]);
}

String _fmtDA(double v) => v.abs()
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
