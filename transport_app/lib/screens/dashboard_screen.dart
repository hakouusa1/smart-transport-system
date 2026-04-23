import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../theme_notifier.dart';
import '../services/bus_service.dart';
import '../models/bus_model.dart';
import 'add_bus_screen.dart';
import 'bus_list_screen.dart';
import 'resubmit_docs_screen.dart';
import 'bus_tracking_screen.dart';
import 'pending_screen.dart';
import 'buses_en_trajet_screen.dart';
import '../widgets/bus_card.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/bus_loading_indicator.dart';








class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;

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
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
      content: Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler')),
        FilledButton(onPressed: () async { Navigator.pop(ctx); await authService.signOut(); },
            style: FilledButton.styleFrom(backgroundColor: ctx.appRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Déconnecter')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final busService = BusService();
    final userEmail = authService.currentUser?.email ?? 'Propriétaire';
    final displayName = userEmail.split('@').first;

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
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ════════════════════════════════════════
              // HEADER (Top Bar equivalent)
              // ════════════════════════════════════════
              Padding(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tariqi - owner app',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.appDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gérez votre flotte en toute simplicité',
                          style: TextStyle(fontSize: 12, color: context.appSub),
                        ),
                      ],
                    ),
                    const Spacer(),
                     ValueListenableBuilder<ThemeMode>(
                       valueListenable: themeNotifier,
                       builder: (context, currentMode, _) {
                         final isDark = currentMode == ThemeMode.dark;
                         return GestureDetector(
                           onTap: () => themeNotifier.toggleTheme(),
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
              ),

              // ════════════════════════════════════════
              // WEEKLY REVENUE CARD
              // ════════════════════════════════════════
              _animCard(
                _WeeklyRevenueCard(ownerId: authService.uid ?? ''),
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
                        Text('Statut des bus',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                        SizedBox(height: 10),

                        // Pending banner
                        if (pending.isNotEmpty)
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const BusListScreen())),
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
                                      '${pending.length} bus en attente de validation',
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: context.appOrange),
                                    ),
                                    SizedBox(height: 2),
                                    Text('En attente de l\'approbation de l\'administrateur',
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
                                      '${bus.busName.isNotEmpty ? bus.busName : "Bus ${bus.busNumber}"} — Rejeté',
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
                                _DocNoteRow(label: 'Validation de ligne', note: bus.ligneValidationNote!),
                              ],
                              if (bus.assuranceStatus == 'issue' &&
                                  bus.assuranceNote != null &&
                                  bus.assuranceNote!.isNotEmpty) ...[
                                SizedBox(height: 6),
                                _DocNoteRow(label: 'Assurance', note: bus.assuranceNote!),
                              ],
                              // Re-submit button
                              if (hasDocIssue) ...[
                                SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.upload_file, size: 16),
                                    label: Text('Corriger les documents'),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ResubmitDocsScreen(bus: bus),
                                      ),
                                    ),
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
                    Text('Bus en trajet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusesEnTrajetScreen())),
                      child: Text('Voir tout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appPrimary)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              SizedBox(
                height: 200,
                child: StreamBuilder<List<Bus>>(
                  stream: busService.getBuses(),
                  builder: (context, snapshot) {
                    final buses = (snapshot.data ?? []).where((b) => b.driverStatus == 'on_trip').toList();
                    if (buses.isEmpty) {
                      return Center(child: Text('Aucun bus en trajet', style: TextStyle(color: context.appSub, fontSize: 13)));
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      itemCount: buses.length,
                      itemBuilder: (_, i) => StaggeredListItem(
                        index: i,
                        child: _ActiveBusCard(bus: buses[i], onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: buses[i])));
                        }),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),

              // ════════════════════════════════════════
              // RECENT TRIPS (Recettes)
              // ════════════════════════════════════════
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Derniers Trajets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appDark)),
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
                    return Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucun trajet récent', style: TextStyle(color: context.appSub, fontSize: 13))));
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
                      return StaggeredListItem(
                        index: i,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(color: context.appCardBg, borderRadius: BorderRadius.circular(20)),
                          child: Row(
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
                                    Text('${dist.toStringAsFixed(1)} km parcourus', style: TextStyle(fontSize: 11, color: context.appSub)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${recette.toStringAsFixed(2)} DZD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appGreen)),
                                  SizedBox(height: 4),
                                  Text('Recette', style: TextStyle(fontSize: 10, color: context.appSub)),
                                ],
                              ),
                            ],
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
    );
  }
}

class _TrialCountdownBanner extends StatefulWidget {
  final DateTime trialEnd;
  const _TrialCountdownBanner({required this.trialEnd});

  @override
  State<_TrialCountdownBanner> createState() => _TrialCountdownBannerState();
}

class _TrialCountdownBannerState extends State<_TrialCountdownBanner> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.trialEnd.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = widget.trialEnd.difference(DateTime.now());
      if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours % 24;
      return '${d.inDays}j ${h}h restants';
    } else if (d.inHours >= 1) {
      final m = d.inMinutes % 60;
      return '${d.inHours}h ${m.toString().padLeft(2, '0')}m restants';
    } else if (d.inMinutes >= 1) {
      final s = d.inSeconds % 60;
      return '${d.inMinutes}m ${s.toString().padLeft(2, '0')}s restants';
    } else {
      return '${d.inSeconds}s restantes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        ),
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
              Text('Essai gratuit — ${_formatCountdown(_remaining)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appOrange)),
              SizedBox(height: 2),
              Text('Choisir un abonnement',
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
// ACTIVE BUS CARD (horizontal scroll, like ticket cards)
// ════════════════════════════════════════
class _ActiveBusCard extends StatelessWidget {
  final Bus bus; final VoidCallback onTap;
  const _ActiveBusCard({required this.bus, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
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
                  child: Text(bus.lineName.split('-').first.trim(),
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
                  child: Text(bus.lineName.contains('-') ? bus.lineName.split('-').last.trim() : '',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appDark),
                      textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                style: TextStyle(fontSize: 11, color: context.appSub)),
            SizedBox(height: 4),
            RouteThumbnail(bus: bus, height: 95, onTap: onTap),
            SizedBox(height: 4),
            const Spacer(),
            // Tags
            Row(children: [
              _Tag('En trajet', context.appGreen),
              SizedBox(width: 6),
              _Tag(bus.busNumber.isNotEmpty ? 'N° ${bus.busNumber}' : 'Bus', context.appPrimary),
              if (bus.busName.isNotEmpty) ...[
                SizedBox(width: 6),
                _Tag(bus.busName, context.appSub),
              ],
              const Spacer(),
              // Passenger count
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('bookings')
                    .where('busId', isEqualTo: bus.busId)
                    .where('status', whereIn: ['pending', 'confirmed']).snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  if (count == 0) return SizedBox();
                  return _Tag('$count passagers', context.appOrange);
                },
              ),
            ]),
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
  const _DocNoteRow({required this.label, required this.note});

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
  const _Tag(this.label, this.color);
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
  const _WeeklyRevenueCard({required this.ownerId});

  @override
  State<_WeeklyRevenueCard> createState() => _WeeklyRevenueCardState();
}

class _WeeklyRevenueCardState extends State<_WeeklyRevenueCard> {
  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  List<double> _weeklyRevenue = List.filled(7, 0);
  double _todayRevenue = 0;
  double _todayProfit = 0;
  double _todayKm = 0;
  int _todayTripCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ownerId.isNotEmpty) _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final rangeStart = todayStart.subtract(const Duration(days: 6)); // index 0 = 6 days ago, index 6 = today

    final snap = await FirebaseFirestore.instance
        .collection('trips')
        .where('ownerId', isEqualTo: widget.ownerId)
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGain = _todayProfit >= 0;
    const todayIdx = 6; // today is always the last (rightmost) point
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final maxY = _weeklyRevenue.reduce((a, b) => a > b ? a : b);

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
            "Recette aujourd'hui",
            style: TextStyle(fontSize: 12, color: context.appSub, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
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
                  '${isGain ? '+' : ''}${_dashFmtDA(value)} bénéfice',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isGain ? context.appGreen : context.appRed,
                  ),
                );
              },
            ),
            Text(
              '  ·  ${_todayKm.toStringAsFixed(0)} km · $_todayTripCount trajets',
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
                        final label = _days[rangeStart.add(Duration(days: i)).weekday - 1];
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
          SizedBox(height: 18),
          Row(children: [
            _buildQuickAction(
              context, Icons.add, 'Ajouter',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBusScreen())),
            ),
            SizedBox(width: 10),
            _buildQuickAction(
              context, Icons.directions_bus_outlined, 'Flotte',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusListScreen())),
            ),
            SizedBox(width: 10),
            _buildQuickAction(
              context, Icons.location_on_outlined, 'Suivre',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusesEnTrajetScreen())),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return _QuickAction(icon: icon, label: label, onTap: onTap);
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
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
// PROFIT COMPUTATION (mirrors statistics_screen logic)
// ════════════════════════════════════════
Future<double> _computeTodayProfit(
    List<QueryDocumentSnapshot> todayTrips, String ownerId) async {
  final Map<String, Map<String, dynamic>> busCache = {};

  // Collect unique bus IDs (salary lives on the bus doc, same as statistics_screen)
  final busIds = <String>{};
  for (final doc in todayTrips) {
    final bId = (doc.data() as Map<String, dynamic>)['busId'] as String? ?? '';
    if (bId.isNotEmpty) busIds.add(bId);
  }

  await Future.wait([
    ...busIds.map((id) async {
      try {
        final doc = await FirebaseFirestore.instance.collection('buses').doc(id).get();
        final data = doc.data();
        if (data != null) busCache[id] = data;
      } catch (_) {}
    }),
  ]);

  // Count trips per driver and per bus (to split daily salary across multiple trips)
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
    final t = doc.data() as Map<String, dynamic>;
    final recette   = (t['recette']       as num?)?.toDouble() ?? 0;
    final distKm    = (t['distanceKm']    as num?)?.toDouble() ?? 0;
    final durationH = (t['durationHours'] as num?)?.toDouble() ?? 0;
    final driverId  = t['driverId'] as String? ?? '';
    final busId     = t['busId']    as String? ?? '';

    final bus = busCache[busId] ?? {};

    final chauffeurSalary = (bus['salary']      as num?)?.toDouble() ?? 0.0;
    final chauffeurType   = bus['chauffeurSalaryType'] as String? ?? 'monthly';
    final chauffeurCount  = tripsPerDriver[driverId] ?? 1;
    final chauffeurCost   = chauffeurType == 'monthly'
        ? (chauffeurSalary / 30.0) / chauffeurCount
        : chauffeurSalary;

    final receveurSalary = (bus['recipient']       as num?)?.toDouble() ?? 0.0;
    final receveurType   = bus['receveurSalaryType'] as String? ?? 'monthly';
    final receveurCount  = tripsPerBus[busId] ?? 1;
    final receveurCost   = receveurType == 'monthly' && receveurSalary > 0
        ? (receveurSalary / 30.0) / receveurCount
        : receveurSalary;

    final poidsKg = (bus['poids'] as num?)?.toDouble();
    double fuelCost = 0;
    if (distKm > 0) {
      final avgSpeed    = durationH > 0 ? distKm / durationH : 70.0;
      final speedFactor = avgSpeed < 30  ? 1.30
          : avgSpeed < 50  ? 1.10
          : avgSpeed < 80  ? 1.00
          : avgSpeed < 100 ? 1.05
          :                  1.20;
      const baseL100   = 35.0;
      const refMass    = 12000.0;
      final massFactor = (poidsKg != null && poidsKg > 0)
          ? (poidsKg / refMass).clamp(0.6, 2.5)
          : 1.0;
      fuelCost = distKm * baseL100 * massFactor * speedFactor / 100.0 * 36.0;
    }

    totalProfit += recette - chauffeurCost - receveurCost - fuelCost;
  }

  return totalProfit;
}

String _dashFmtDA(double v) => v.abs()
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u202F');