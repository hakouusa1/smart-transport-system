import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
import '../services/bus_service.dart';
import '../models/bus_model.dart';
import 'add_bus_screen.dart';
import 'bus_list_screen.dart';
import 'resubmit_docs_screen.dart';
import 'bus_tracking_screen.dart';
import 'pending_screen.dart';
import 'buses_en_trajet_screen.dart';
import 'trip_detail_screen.dart';
import '../widgets/bus_card.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/bus_loading_indicator.dart';
import '../utils/profit_calculator.dart';
import '../app_settings_notifier.dart';








class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _entranceCtrl.value = 1.0;
    } else {
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context, AuthService authService) {
    final l10n = AppLocalizations.of(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.logoutTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
      content: Text(l10n.logoutConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        FilledButton(onPressed: () async { Navigator.pop(ctx); await authService.signOut(); },
            style: FilledButton.styleFrom(backgroundColor: ctx.appRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(l10n.logoutAction)),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final busService = BusService();

    Widget _animCard(Widget child, Interval interval) {
      if (MediaQuery.of(context).disableAnimations) return child;
      return AnimatedBuilder(
        animation: _entranceCtrl,
        builder: (ctx, ch) {
          final val = CurvedAnimation(
            parent: _entranceCtrl,
            curve: interval,
          ).value;
          return Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + (0.15 * val),
              child: ch,
            ),
          );
        },
        child: child,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() => _refreshToken++);
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               // ════════════════════════════════════════
               // HEADER (Top Bar equivalent)
               // ════════════════════════════════════════
               Padding(
                 padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 12),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.center,
                       children: [
                         Image.asset(
                           'assets/images/massar_logo.webp',
                           height: 44,
                           fit: BoxFit.contain,
                         ),
                         const SizedBox(width: 10),
                         const Spacer(),
                         ValueListenableBuilder<ThemeMode>(
                           valueListenable: themeNotifier,
                           builder: (context, currentMode, _) {
                             final isDark = currentMode == ThemeMode.dark;
                             return GestureDetector(
                               onTap: () {
                                 HapticFeedback.lightImpact();
                                 themeNotifier.toggleTheme();
                               },
                               child: Container(
                                 width: 44, height: 44,
                                 decoration: BoxDecoration(color: context.appSoftGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(14)),
                                 child: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: context.appDark, size: 20),
                               ),
                             );
                           },
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     Text(
                       AppLocalizations.of(context).ownerDashboardTitle,
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       AppLocalizations.of(context).ownerDashboardDescription,
                       style: TextStyle(fontSize: 14, color: context.appSub),
                     ),
                   ],
                 ),
               ),

              // ════════════════════════════════════════
              // WEEKLY REVENUE CARD
              // ════════════════════════════════════════
              _animCard(
                _WeeklyRevenueCard(key: ValueKey(_refreshToken), ownerId: authService.uid),
                const Interval(0.0, 0.55, curve: Curves.easeOutBack),
              ),
              // ════════════════════════════════════════
              // TRIAL BANNER
              // ════════════════════════════════════════
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(authService.uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>?;
                  final trialEnd = data?['trialEnd'] as Timestamp?;
                  final subscriptionStatus = data?['subscriptionStatus'] ?? '';
                  if (trialEnd == null ||
                      subscriptionStatus == 'active' ||
                      trialEnd.toDate().isBefore(DateTime.now())) {
                    return SizedBox(height: 5);
                  }
                  return _animCard(
                    _TrialCountdownBanner(trialEnd: trialEnd.toDate()),
                    const Interval(0.25, 0.80, curve: Curves.easeOutBack),
                  );
                },
              ),

              SizedBox(height: 12),


              // ════════════════════════════════════════
              // PENDING / REJECTED BUS ALERTS
              // ════════════════════════════════════════
              StreamBuilder<List<Bus>>(
                stream: busService.getBuses(),
                builder: (context, snapshot) {
                  final buses = snapshot.data ?? [];
                  final pending = buses.where((b) => b.validationStatus == 'pending').toList();
                  final rejected = buses.where((b) => b.validationStatus == 'rejected').toList();

                  if (pending.isEmpty && rejected.isEmpty) return SizedBox();

                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).busStatus,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                        SizedBox(height: 10),

                        // Pending banner
                        if (pending.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const BusListScreen()));
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.appOrange.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.appOrange.withValues(alpha: 0.35)),
                              ),
                              child: Row(children: [
                                Icon(Icons.hourglass_top_rounded, color: context.appOrange, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      AppLocalizations.of(context).busesAwaitingValidation(pending.length),
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: context.appOrange),
                                    ),
                                    SizedBox(height: 2),
                                    Text(AppLocalizations.of(context).awaitingAdminApproval,
                                        style: TextStyle(fontSize: 11, color: context.appSub)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right, color: context.appOrange, size: 18),
                              ]),
                            ),
                          ),

                        // Rejected cards (one per bus)
                        ...rejected.map((bus) {
                          final hasDocIssue =
                              bus.ligneValidationStatus == 'issue' ||
                              bus.assuranceStatus == 'issue';
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.appRed.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.appRed.withValues(alpha: 0.35)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Header row
                              Row(children: [
                                Icon(Icons.cancel_outlined, color: context.appRed, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      '${bus.busName.isNotEmpty ? bus.busName : "Bus ${bus.busNumber}"} — ${AppLocalizations.of(context).rejectedSuffix}',
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: context.appRed),
                                    ),
                                    SizedBox(height: 2),
                                    Text('N° ${bus.busNumber}',
                                        style: TextStyle(fontSize: 11, color: context.appSub)),
                                  ]),
                                ),
                              ]),
                              // General rejection note
                              if (bus.validationNote != null && bus.validationNote!.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: context.appRed.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(Icons.info_outline, color: context.appRed, size: 14),
                                    SizedBox(width: 6),
                                    Expanded(child: Text(bus.validationNote!,
                                        style: TextStyle(fontSize: 11, color: context.appRed))),
                                  ]),
                                ),
                              ],
                              // Per-document issue notes
                              if (bus.ligneValidationStatus == 'issue' &&
                                  bus.ligneValidationNote != null &&
                                  bus.ligneValidationNote!.isNotEmpty) ...[
                                SizedBox(height: 6),
                                _DocNoteRow(label: AppLocalizations.of(context).lineValidation, note: bus.ligneValidationNote!),
                              ],
                              if (bus.assuranceStatus == 'issue' &&
                                  bus.assuranceNote != null &&
                                  bus.assuranceNote!.isNotEmpty) ...[
                                SizedBox(height: 6),
                                _DocNoteRow(label: AppLocalizations.of(context).insurance, note: bus.assuranceNote!),
                              ],
                              // Re-submit button
                              if (hasDocIssue) ...[
                                SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.upload_file, size: 16),
                                    label: Text(AppLocalizations.of(context).fixDocuments),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ResubmitDocsScreen(bus: bus),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.appPrimary,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      textStyle: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ]),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),

              // ════════════════════════════════════════
              // ACTIVE BUSES (like "Aktif Tiket")
              // ════════════════════════════════════════
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(AppLocalizations.of(context).busesOnTrip, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BusesEnTrajetScreen()));
                      },
                      child: Text(AppLocalizations.of(context).seeAll, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appPrimary)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              const SizedBox(height: 200, child: _ActiveBusSection()),
              SizedBox(height: 24),

              // ════════════════════════════════════════
              // RECENT TRIPS (Recettes)
              // ════════════════════════════════════════
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(AppLocalizations.of(context).recentTrips, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                  ],
                ),
              ),
              SizedBox(height: 12),
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('trips')
                    .where('ownerId', isEqualTo: authService.uid)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: Padding(padding: EdgeInsets.all(20), child: BusLoadingIndicator()));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Padding(padding: EdgeInsets.all(20), child: Text(AppLocalizations.of(context).noRecentTrips, style: TextStyle(color: context.appSub, fontSize: 13))));
                  }
                  
                  // Sort locally to avoid needing complex composite index initially
                  final trips = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return {'id': d.id, ...data};
                  }).toList();
                  trips.sort((a, b) {
                    final tA = a['timestamp'] as Timestamp?;
                    final tB = b['timestamp'] as Timestamp?;
                    if (tA == null && tB == null) return 0;
                    if (tA == null) return 1;
                    if (tB == null) return -1;
                    return tB.compareTo(tA);
                  });
                  
                  final recentTrips = trips.take(5).toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recentTrips.length,
                    itemBuilder: (_, i) {
                      final trip = recentTrips[i];
                      final busName = trip['busName']?.toString() ?? 'Bus';
                      final lineName = trip['lineName']?.toString() ?? '';
                      final recette = (trip['recette'] as num?)?.toDouble() ?? 0.0;
                      final dist = (trip['distanceKm'] as num?)?.toDouble() ?? 0.0;
                      
                      final ts = trip['timestamp'] as Timestamp?;
                      final date = ts?.toDate();
                      final timeArr = date != null ? DateFormat('HH:mm').format(date) : '';
                      final durationH = (trip['durationHours'] as num?)?.toDouble() ?? 0;
                      String timeDep = '';
                      if (date != null) {
                        final depDate = date.subtract(Duration(seconds: (durationH * 3600).toInt()));
                        timeDep = DateFormat('HH:mm').format(depDate);
                      }
                      
                      return StaggeredListItem(
                        index: i,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 10),
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
                               title: Row(
                                 children: [
                                   Container(
                                     width: 44, height: 44,
                                     decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                     child: Icon(Icons.check_circle_outline, color: context.appGreen, size: 24),
                                   ),
                                   SizedBox(width: 14),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(lineName.isNotEmpty ? lineName : busName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark), overflow: TextOverflow.ellipsis),
                                         SizedBox(height: 4),
                                         Text(busName.isNotEmpty ? busName : AppLocalizations.of(context).unknownBus, style: TextStyle(fontSize: 11, color: context.appSub, fontWeight: FontWeight.w500)),
                                         SizedBox(height: 2),
                                         Text(AppLocalizations.of(context).kmCoveredFmt(dist), style: TextStyle(fontSize: 10, color: context.appSub)),
                                       ],
                                     ),
                                   ),
                                   Column(
                                     crossAxisAlignment: CrossAxisAlignment.end,
                                     children: [
                                       Text('${recette.toStringAsFixed(2)} DZD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appGreen)),
                                       SizedBox(height: 2),
                                       Text(AppLocalizations.of(context).revenueLabel, style: TextStyle(fontSize: 10, color: context.appSub)),
                                     ],
                                   ),
                                 ],
                               ),
                               children: [
                                 Divider(height: 1, color: context.appBorder),
                                 const SizedBox(height: 12),
                                 _tripDetailRow(context, Icons.access_time_outlined, AppLocalizations.of(context).tripDetailHour, '$timeDep - $timeArr'),
                                 const SizedBox(height: 8),
                                 _tripDetailRow(context, Icons.directions_bus_outlined, AppLocalizations.of(context).tripDetailBus, busName),
                                 const SizedBox(height: 8),
                                 _tripDetailRow(context, Icons.timer_outlined, AppLocalizations.of(context).tripDetailDuration,
                                   trip['durationHours'] != null ? '${((trip['durationHours'] as num).toDouble() * 60).toInt()} min' : '—'
                                 ),
                                 const SizedBox(height: 8),
                                 _tripDetailRow(context, Icons.place_outlined, AppLocalizations.of(context).tripDetailRoute,
                                   '${trip['departure'] ?? '...'} ➝ ${trip['arrival'] ?? '...'}'
                                 ),
                                 const SizedBox(height: 12),
                                 GestureDetector(
                                   onTap: () {
                                     HapticFeedback.selectionClick();
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(
                                         builder: (_) => TripDetailScreen(trip: trip),
                                       ),
                                     );
                                   },
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(vertical: 10),
                                     decoration: BoxDecoration(
                                       color: context.appPrimary.withValues(alpha: 0.08),
                                       borderRadius: BorderRadius.circular(10),
                                       border: Border.all(color: context.appPrimary.withValues(alpha: 0.2)),
                                     ),
                                     child: Row(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [
                                         Icon(Icons.receipt_long_outlined, size: 14, color: context.appPrimary),
                                         const SizedBox(width: 6),
                                         Text(
                                           AppLocalizations.of(context).tripDetailTitle,
                                           style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appPrimary),
                                         ),
                                         const SizedBox(width: 4),
                                         Icon(Icons.arrow_forward_ios_rounded, size: 10, color: context.appPrimary),
                                       ],
                                     ),
                                   ),
                                 ),
                               ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 24),

              SizedBox(height: 32),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _TrialCountdownBanner extends StatefulWidget {
  final DateTime trialEnd;
  const _TrialCountdownBanner({super.key, required this.trialEnd});

  @override
  State<_TrialCountdownBanner> createState() => _TrialCountdownBannerState();
}

class _TrialCountdownBannerState extends State<_TrialCountdownBanner> {
  Timer? _timer;
  late Duration _remaining;
  bool _isSecondMode = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.trialEnd.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // Second mode: < 1 minute remaining → tick every second
    // Minute mode: >= 1 minute remaining → tick every minute
    _isSecondMode = _remaining.inMinutes < 1;
    final interval = _isSecondMode
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);

    _timer = Timer.periodic(interval, (_) {
      final r = widget.trialEnd.difference(DateTime.now());
      final clamped = r.isNegative ? Duration.zero : r;

      // Transition: minute-mode → second-mode when < 1 min remains
      if (!_isSecondMode && clamped.inMinutes < 1) {
        if (mounted) {
          setState(() => _remaining = clamped);
          _startTimer(); // restart with 1-second interval
        }
        return;
      }

      if (mounted) setState(() => _remaining = clamped);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Minute mode: shows Days, Hours, Minutes only (no seconds).
  /// Second mode (< 1 min): shows seconds for the final countdown.
  String _formatCountdown(AppLocalizations l10n, Duration d) {
    if (d.inDays >= 1) {
      return l10n.daysHoursMinutesLeftFmt(d.inDays, d.inHours % 24, d.inMinutes % 60);
    } else if (d.inHours >= 1) {
      return l10n.hoursMinutesLeftFmt(d.inHours, d.inMinutes % 60);
    } else if (d.inMinutes >= 1) {
      // Still in minute mode — no seconds shown
      return l10n.minutesLeftFmt(d.inMinutes);
    } else {
      // Second mode — final countdown
      return l10n.secondsLeftFmt(d.inSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.appOrange.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appOrange.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: context.appOrange, size: 20),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.of(context).freeTrialCountdownFmt(_formatCountdown(AppLocalizations.of(context), _remaining)),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appOrange)),
              SizedBox(height: 2),
              Text(AppLocalizations.of(context).chooseSubscription,
                  style: TextStyle(fontSize: 12, color: context.appSub)),
            ])),
            Icon(Icons.chevron_right, color: context.appOrange, size: 18),
          ]),
        ),
      ),
    );
  }
}




// ════════════════════════════════════════
// ACTIVE BUS SECTION — one batched booking listener for all active buses
// ════════════════════════════════════════
class _ActiveBusSection extends StatefulWidget {
  const _ActiveBusSection();

  @override
  State<_ActiveBusSection> createState() => _ActiveBusSectionState();
}

class _ActiveBusSectionState extends State<_ActiveBusSection> {
  final _busService = BusService();
  StreamSubscription<List<Bus>>? _busSub;
  StreamSubscription<QuerySnapshot>? _bookingSub;
  List<Bus> _activeBuses = [];
  Map<String, int> _passengerCounts = {};

  @override
  void initState() {
    super.initState();
    _busSub = _busService.getBuses().listen((buses) {
      final active = buses.where((b) => b.driverStatus == 'on_trip').toList();
      if (mounted) setState(() => _activeBuses = active);
      _subscribeToBookings(active.map((b) => b.busId).toList());
    });
  }

  void _subscribeToBookings(List<String> busIds) {
    _bookingSub?.cancel();
    if (busIds.isEmpty) {
      if (mounted) setState(() => _passengerCounts = {});
      return;
    }
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('busId', whereIn: busIds)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .listen((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final id = (doc.data()['busId'] as String?) ?? '';
        if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
      }
      if (mounted) setState(() => _passengerCounts = counts);
    });
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _bookingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: _activeBuses.isEmpty
          ? Center(
              key: const ValueKey('empty_buses'),
              child: Text(AppLocalizations.of(context).noBusesOnTrip,
                  style: TextStyle(color: context.appSub, fontSize: 13)),
            )
          : ListView.builder(
              key: const ValueKey('active_buses_list'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _activeBuses.length,
              itemBuilder: (_, i) {
                final bus = _activeBuses[i];
                return StaggeredListItem(
                  index: i,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _ActiveBusCard(
                      key: ValueKey(bus.busId),
                      bus: bus,
                      passengerCount: _passengerCounts[bus.busId] ?? 0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ════════════════════════════════════════
// ACTIVE BUS CARD (horizontal scroll, like ticket cards)
// ════════════════════════════════════════
class _ActiveBusCard extends StatelessWidget {
  final Bus bus;
  final int passengerCount;
  final VoidCallback onTap;
  const _ActiveBusCard({super.key, required this.bus, required this.passengerCount, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: (MediaQuery.of(context).size.width * 0.75).clamp(240.0, 320.0),
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route: Départ ● ● ● ● Arrivée
            Row(
              children: [
                Expanded(
                  child: Text(bus.displayLineName.split('-').first.trim(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
                      overflow: TextOverflow.ellipsis),
                ),
                // Dotted line
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Row(children: List.generate(5, (_) => Container(
                    width: 4, height: 4, margin: EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: context.appSub, shape: BoxShape.circle),
                  ))),
                ),
                Expanded(
                  child: Text(bus.displayLineName.contains('-') ? bus.displayLineName.split('-').last.trim() : '',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
                      textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                style: TextStyle(fontSize: 11, color: context.appSub),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
            SizedBox(height: 4),
            RouteThumbnail(bus: bus, height: 95, onTap: onTap),
            SizedBox(height: 4),
            const Spacer(),
            // Tags
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Tag(AppLocalizations.of(context).onTrip, context.appGreen),
                SizedBox(width: 6),
                _Tag(bus.busNumber.isNotEmpty ? 'N° ${bus.busNumber}' : 'Bus', context.appPrimary),
                if (bus.busName.isNotEmpty) ...[
                  SizedBox(width: 6),
                  _Tag(bus.busName, context.appSub),
                ],
                if (passengerCount > 0) ...[
                  const SizedBox(width: 12),
                  _Tag(AppLocalizations.of(context).passengersFmt(passengerCount), context.appOrange),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}


// ════════════════════════════════════════
// DOCUMENT ISSUE NOTE ROW (shown to owner)
// ════════════════════════════════════════
class _DocNoteRow extends StatelessWidget {
  final String label;
  final String note;
  const _DocNoteRow({super.key, required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.appRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appRed.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.description_outlined, color: context.appRed, size: 13),
        SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: context.appRed),
              children: [
                TextSpan(text: '$label : ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: note),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}


class _Tag extends StatelessWidget {
  final String label; final Color color;
  const _Tag(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ════════════════════════════════════════
// WEEKLY REVENUE CARD
// ════════════════════════════════════════
class _WeeklyRevenueCard extends StatefulWidget {
  final String ownerId;
  const _WeeklyRevenueCard({super.key, required this.ownerId});

  @override
  State<_WeeklyRevenueCard> createState() => _WeeklyRevenueCardState();
}

class _WeeklyRevenueCardState extends State<_WeeklyRevenueCard> {
  // Returns 7 distinct day labels (Mon–Sun, index 0–6) for the current locale.
  // Uses the narrow single-character format (EEEEE) and upgrades to 2-char
  // abbreviations only for days that would otherwise collide (e.g. Mardi/Mercredi
  // both produce 'M' in French, Tuesday/Thursday both produce 'T' in English).
  static List<String> _buildDayLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final baseMonday = DateTime(2024, 1, 1); // 2024-01-01 is a Monday

    final narrow = List.generate(7, (i) =>
        DateFormat('EEEEE', locale).format(baseMonday.add(Duration(days: i))));

    final counts = <String, int>{};
    for (final l in narrow) counts[l] = (counts[l] ?? 0) + 1;

    final shortFmt = DateFormat.E(locale);
    return List.generate(7, (i) {
      if ((counts[narrow[i]] ?? 0) > 1) {
        final s = shortFmt.format(baseMonday.add(Duration(days: i)));
        final chars = s.characters.toList();
        return (chars.length >= 2 ? chars[0] + chars[1] : chars[0]).toUpperCase();
      }
      return narrow[i].toUpperCase();
    });
  }

  List<double> _weeklyRevenue = List.filled(7, 0);
  double _todayRevenue = 0;
  double _todayProfit = 0;
  double _todayKm = 0;
  int _todayTripCount = 0;

  bool _isLoadingRevenue = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.ownerId.isNotEmpty) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _isLoadingRevenue = true; _hasError = false; });
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final rangeStart = todayStart.subtract(const Duration(days: 6));

      final snap = await FirebaseFirestore.instance
          .collection('trips')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .get();

      final weekly = List<double>.filled(7, 0);
      double todayRev = 0, todayKm = 0;
      int todayCount = 0;
      final todayDocs = <QueryDocumentSnapshot>[];

      for (final doc in snap.docs) {
        final t = doc.data();
        final ts = (t['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;

        final dayIdx = ts.difference(rangeStart).inDays;
        if (dayIdx >= 0 && dayIdx < 7) {
          weekly[dayIdx] += (t['recette'] as num?)?.toDouble() ?? 0;
        }
        if (ts.isAfter(todayStart)) {
          todayRev += (t['recette'] as num?)?.toDouble() ?? 0;
          todayKm += (t['distanceKm'] as num?)?.toDouble() ?? 0;
          todayCount++;
          todayDocs.add(doc);
        }
      }

      final profit = await _computeTodayProfit(todayDocs, widget.ownerId);
      if (!mounted) return;

      setState(() {
        _weeklyRevenue = weekly;
        _todayRevenue = todayRev;
        _todayProfit = profit;
        _todayKm = todayKm;
        _todayTripCount = todayCount;
        _isLoadingRevenue = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('[WeeklyRevenue] Load error: $e');
      if (mounted) setState(() { _isLoadingRevenue = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGain = _todayProfit >= 0;
    const todayIdx = 6;
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final maxY = _weeklyRevenue.reduce((a, b) => a > b ? a : b);
    final dayLabels = _buildDayLabels(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: context.appBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).todayRevenue,
            style: TextStyle(fontSize: 12, color: context.appSub, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),

          // ── Error state ──
          if (_hasError) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_outlined, size: 32, color: context.appSub.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).errorFmt(''),
                    style: TextStyle(fontSize: 12, color: context.appSub),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.appPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh, size: 14, color: context.appPurple),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context).retry,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appPurple),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ]

          // ── Loading shimmer ──
          else if (_isLoadingRevenue) ...[
            _buildRevenueSkeleton(context),
          ]

          // ── Loaded state ──
          else ...[
            TweenAnimationBuilder<double>(
              key: ValueKey(_todayRevenue),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: _todayRevenue),
              builder: (context, value, child) {
                return Text(
                  '${_dashFmtDA(value)} DA',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: context.appDark),
                );
              },
            ),
            SizedBox(height: 6),
            Row(children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_todayProfit),
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: _todayProfit),
                builder: (context, value, child) {
                  return Text(
                    '${isGain ? '+' : ''}${_dashFmtDA(value)} ${AppLocalizations.of(context).profitLabel}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isGain ? context.appGreen : context.appRed,
                    ),
                  );
                },
              ),
              Text(
                AppLocalizations.of(context).tripStatsFmt(_todayKm, _todayTripCount),
                style: TextStyle(fontSize: 12, color: context.appSub),
              ),
            ]),
            SizedBox(height: 20),
            SizedBox(
              height: 90,
              child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY > 0 ? maxY * 1.25 : 1000,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i > 6) return const SizedBox();
                        final label = dayLabels[rangeStart.add(Duration(days: i)).weekday - 1];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == todayIdx ? FontWeight.w700 : FontWeight.w400,
                              color: i == todayIdx ? context.appDark : context.appSub,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), _weeklyRevenue[i])),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: context.appDark,
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) => spot.x.toInt() == todayIdx,
                      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                        radius: 4,
                        color: context.appDark,
                        strokeWidth: 2,
                        strokeColor: context.appBg,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
            ),
          ),
          ],
          if (!_isLoadingRevenue && !_hasError) ...[
            SizedBox(height: 18),
            Row(children: [
              _buildQuickAction(
                context, Icons.add, AppLocalizations.of(context).addLabel,
                () async {
                  final busService = BusService();
                  final limit = await busService.getPlanLimit();
                  final currentBuses = busService.latestBuses ?? [];
                  if (limit != null && currentBuses.length >= limit) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Vous avez atteint le nombre maximum de bus pour votre forfait.'),
                        backgroundColor: context.appOrange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                    return;
                  }
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBusScreen()));
                  }
                },
              ),
              SizedBox(width: 10),
              _buildQuickAction(
                context, Icons.directions_bus_outlined, AppLocalizations.of(context).fleetLabel,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusListScreen())),
              ),
              SizedBox(width: 10),
              _buildQuickAction(
                context, Icons.location_on_outlined, AppLocalizations.of(context).trackLabel,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusesEnTrajetScreen())),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return _QuickAction(icon: icon, label: label, onTap: onTap);
  }

  /// Shimmer skeleton that matches the exact shape/size of the loaded
  /// WeeklyRevenueCard content (revenue text, profit row, chart, quick actions).
  Widget _buildRevenueSkeleton(BuildContext context) {
    final baseColor = context.isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlightColor = context.isDark
        ? Colors.grey.shade600
        : Colors.grey.shade100;

    Widget bone(double width, double height, {double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue amount placeholder (matches ~32px font height)
          bone(180, 36),
          const SizedBox(height: 10),
          // Profit + trip stats row placeholder
          Row(children: [
            bone(110, 14, radius: 6),
            const SizedBox(width: 10),
            bone(90, 14, radius: 6),
          ]),
          const SizedBox(height: 20),
          // Chart area placeholder (matches 90px chart height)
          bone(double.infinity, 90, radius: 12),
          const SizedBox(height: 18),
          // Quick-action buttons placeholder row
          Row(children: [
            Expanded(child: bone(double.infinity, 52, radius: 14)),
            const SizedBox(width: 10),
            Expanded(child: bone(double.infinity, 52, radius: 14)),
            const SizedBox(width: 10),
            Expanded(child: bone(double.infinity, 52, radius: 14)),
          ]),
        ],
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          if (!MediaQuery.of(context).disableAnimations) _pressCtrl.forward();
        },
        onTapUp: (_) {
          if (!MediaQuery.of(context).disableAnimations) _pressCtrl.reverse();
        },
        onTapCancel: () {
          if (!MediaQuery.of(context).disableAnimations) _pressCtrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (0.05 * _pressCtrl.value),
              child: child,
            );
          },
          child: Material(
            color: context.appSoftGray.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 22, color: context.appDark),
                    SizedBox(height: 6),
                    Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appDark)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// PROFIT COMPUTATION
// ════════════════════════════════════════
Future<double> _computeTodayProfit(
    List<QueryDocumentSnapshot> todayTrips, String ownerId) async {
  final Map<String, Map<String, dynamic>> busCache = {};

  final busIds = <String>{};
  for (final doc in todayTrips) {
    final bId = (doc.data() as Map<String, dynamic>)['busId'] as String? ?? '';
    if (bId.isNotEmpty) busIds.add(bId);
  }

  await Future.wait(busIds.map((id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('buses').doc(id).get();
      final data = doc.data();
      if (data != null) busCache[id] = data;
    } catch (_) {}
  }));

  final tripsPerDriver = <String, int>{};
  final tripsPerBus    = <String, int>{};
  for (final doc in todayTrips) {
    final t = doc.data() as Map<String, dynamic>;
    final dId = t['driverId'] as String? ?? '';
    final bId = t['busId']    as String? ?? '';
    if (dId.isNotEmpty) tripsPerDriver[dId] = (tripsPerDriver[dId] ?? 0) + 1;
    if (bId.isNotEmpty) tripsPerBus[bId]    = (tripsPerBus[bId]    ?? 0) + 1;
  }

  double totalProfit = 0;
  for (final doc in todayTrips) {
    final t        = doc.data() as Map<String, dynamic>;
    final busId    = t['busId']    as String? ?? '';
    final driverId = t['driverId'] as String? ?? '';
    final bus      = busCache[busId] ?? {};

    final settings = appSettingsNotifier.value;
    final result = ProfitCalculator.calcTrip(
      recette:             (t['recette']       as num?)?.toDouble() ?? 0,
      distKm:              (t['distanceKm']    as num?)?.toDouble() ?? 0,
      durationH:           (t['durationHours'] as num?)?.toDouble() ?? 0,
      chauffeurSalary:     (bus['salary']             as num?)?.toDouble() ?? 0.0,
      chauffeurSalaryType: bus['chauffeurSalaryType'] as String? ?? 'monthly',
      chauffeurTripCount:  tripsPerDriver[driverId] ?? 1,
      receveurSalary:      (bus['recipient']          as num?)?.toDouble() ?? 0.0,
      receveurSalaryType:  bus['receveurSalaryType']  as String? ?? 'monthly',
      receveurTripCount:   tripsPerBus[busId] ?? 1,
      fuelCostDAOverride:  t['fuelCostDA'] != null ? (t['fuelCostDA'] as num).toDouble() : null,
      poidsKg:             (bus['poids'] as num?)?.toDouble(),
      fuelPriceDA:         settings.fuelPricePerLiter,
      baseConsumptionL100: settings.fuelConsumptionL100,
    );

    totalProfit += result.profit;
  }

  return totalProfit;
}

String _dashFmtDA(double v) => v.abs()
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u202F');

Widget _tripDetailRow(BuildContext context, IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 14, color: context.appSub),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 12, color: context.appSub)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appDark)),
    ],
  );
}