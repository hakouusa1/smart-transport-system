import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voyageur_app/screens/search_screen_page.dart';
import '../models/bus_model.dart';
import 'map_screen.dart';
import 'all_buses_map_screen.dart';
import 'my_bookings_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';

class BusLinesScreen extends StatelessWidget {
  const BusLinesScreen({super.key});

  void _logout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () { Navigator.pop(ctx); FirebaseAuth.instance.signOut(); },
          style: FilledButton.styleFrom(
            backgroundColor: context.appRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Déconnecter'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(
          children: [
            // ════════════════════════════════════════
            // FLAT HEADER (transport_app style)
            // ════════════════════════════════════════
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Tariqi - Voyageur',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appDark),
                    ),
                  ),
                  // Dark/light toggle
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (ctx, mode, _) => _HdrBtn(
                      icon: mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                      onTap: () => themeNotifier.toggleTheme(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HdrBtn(
                    icon: Icons.bookmark_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                  ),
                  const SizedBox(width: 10),
                  _HdrBtn(
                    icon: Icons.map_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBusesMapScreen())),
                  ),
                  const SizedBox(width: 10),
                  _HdrBtn(
                    icon: Icons.logout_rounded,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════
            // SEARCH BAR
            // ════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const SearchScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 200),
                )),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.appCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, color: context.appSub, size: 20),
                    const SizedBox(width: 10),
                    Text('Où allez-vous ?', style: TextStyle(fontSize: 14, color: context.appSub)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.appCardBg2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Rechercher', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appSub)),
                    ),
                  ]),
                ),
              ),
            ),

            // ════════════════════════════════════════
            // STATS CHIPS
            // ════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('buses').where('isActive', isEqualTo: true).snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  final total = docs.length;
                  final onTrip = docs.where((d) => (d.data() as Map)['driverStatus'] == 'on_trip').length;
                  return Row(children: [
                    _StatChip(Icons.directions_bus, '$total bus actifs'),
                    const SizedBox(width: 10),
                    _StatChip(Icons.gps_fixed, '$onTrip en trajet'),
                  ]);
                },
              ),
            ),

            // ════════════════════════════════════════
            // COMBINED BUS LIST (en trajet + en ligne)
            // ════════════════════════════════════════
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('buses')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 2.5));
                  }
                  if (snapshot.hasError) {
                    debugPrint('[BusLinesScreen] Firestore error: ${snapshot.error}');
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, size: 48, color: context.appRed),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement', style: TextStyle(fontSize: 15, color: context.appRed)),
                      const SizedBox(height: 6),
                      Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: context.appSub), textAlign: TextAlign.center),
                    ]));
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final allBuses = allDocs
                      .map((d) => Bus.fromMap(d.data() as Map<String, dynamic>))
                      .toList();
                  final allTrips = allBuses.expand((b) => b.activeTrips).toList();
                  
                  final onTrip = allTrips.where((t) => t.isEnTrajet).toList();
                  final online = allTrips.where((t) => !t.isEnTrajet && t.bus.isOnline).toList()
                    ..sort((a, b) {
                      final aTime = a.scheduleTime ?? a.bus.firstScheduleTime ?? '';
                      final bTime = b.scheduleTime ?? b.bus.firstScheduleTime ?? '';
                      if (aTime.isEmpty && bTime.isEmpty) return 0;
                      if (aTime.isEmpty) return 1;
                      if (bTime.isEmpty) return -1;
                      return aTime.compareTo(bTime);
                    });

                  if (onTrip.isEmpty && online.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.directions_bus_outlined, size: 56, color: context.appBorder),
                      const SizedBox(height: 16),
                      Text('Aucun bus disponible', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.appText)),
                      const SizedBox(height: 8),
                      Text('Revenez plus tard', style: TextStyle(fontSize: 13, color: context.appSub)),
                    ]));
                  }

                  return CustomScrollView(
                    slivers: [
                      // ── En trajet grid ──
                      if (onTrip.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            child: Row(children: [
                              Container(width: 3, height: 14,
                                  decoration: BoxDecoration(color: context.appGreen, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text('En trajet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: context.appGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${onTrip.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.appGreen)),
                              ),
                            ]),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 400 + (i * 100).clamp(0, 500)),
                                curve: Curves.easeOutCubic,
                                builder: (ctx, value, child) => Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                ),
                                child: _BusCard(
                                  trip: onTrip[i],
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: onTrip[i].bus))),
                                ),
                              ),
                              childCount: onTrip.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.95,
                            ),
                          ),
                        ),
                      ],

                      // ── En ligne list ──
                      if (online.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, onTrip.isNotEmpty ? 16 : 4, 16, 10),
                            child: Row(children: [
                              Container(width: 3, height: 14,
                                  decoration: BoxDecoration(color: context.appOrange, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text('En ligne', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: context.appOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${online.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.appOrange)),
                              ),
                            ]),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(milliseconds: 350 + (i * 80).clamp(0, 400)),
                                  curve: Curves.easeOutCubic,
                                  builder: (ctx, value, child) => Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(opacity: value, child: child),
                                  ),
                                  child: _OnlineBusRow(trip: online[i]),
                                ),
                              ),
                              childCount: online.length,
                            ),
                          ),
                        ),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// BUS CARD
// ════════════════════════════════════════
class _BusCard extends StatelessWidget {
  final BusTrip trip; final VoidCallback onTap;
  const _BusCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bus = trip.bus;
    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Hero(
                tag: 'bus_icon_${bus.driverId}',
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: context.appPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_bus_rounded, color: context.appPrimary, size: 20),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.appGreen.withValues(alpha: 0.4)),
                  color: context.appGreen.withValues(alpha: 0.08),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Text('En trajet', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: context.appGreen)),
                ]),
              ),
            ]),
            const Spacer(),
            Row(children: [
              Expanded(child: Text(
                trip.displayLineName.split('-').first.trim(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText),
                overflow: TextOverflow.ellipsis,
              )),
              ...List.generate(3, (_) => Container(
                width: 3, height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: context.appSub, shape: BoxShape.circle),
              )),
              Expanded(child: Text(
                trip.displayLineName.contains('-') ? trip.displayLineName.split('-').last.trim() : '',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText),
                textAlign: TextAlign.end, overflow: TextOverflow.ellipsis,
              )),
            ]),
            const SizedBox(height: 4),
            Text(
              bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: context.appSub),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// ONLINE BUS ROW
// ════════════════════════════════════════
class _OnlineBusRow extends StatelessWidget {
  final BusTrip trip;
  const _OnlineBusRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final bus = trip.bus;
    final timeStr = trip.scheduleTime ?? bus.nextScheduleTime ?? '--:--';
    final isOnline = bus.isOnline; // If bus is on_trip or online, it's considered online
    final statusColor = isOnline ? context.appGreen : context.appSub;
    final statusLabel = isOnline ? 'En ligne' : 'Hors ligne';

    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_bus_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                trip.displayLineName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                style: TextStyle(fontSize: 11, color: context.appSub),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                color: statusColor.withValues(alpha: 0.08),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 4, height: 4, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text(statusLabel, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: statusColor)),
              ]),
            ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded, size: 10, color: context.appSub),
              const SizedBox(width: 3),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: timeStr == '--:--' ? context.appSub : context.appPrimary,
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════
class _HdrBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HdrBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: context.appSoftGray.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: context.appDark, size: 20),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: context.appPrimary),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.appText)),
      ]),
    );
  }
}
