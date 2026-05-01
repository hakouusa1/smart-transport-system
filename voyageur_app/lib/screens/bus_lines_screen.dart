import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/bus_model.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/price_service.dart';
import '../app_config.dart' as config;
import 'map_screen.dart';
import 'profile_screen.dart';
import 'all_buses_list_screen.dart';
import 'pick_on_map_screen.dart';
import 'search_results_page.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../data/algeria_stops.dart';
import '../widgets/bus_loading_indicator.dart';
import '../widgets/bus_trip_card.dart';

class BusLinesScreen extends StatefulWidget {
  const BusLinesScreen({super.key});

  @override
  State<BusLinesScreen> createState() => _BusLinesScreenState();
}

class _BusLinesScreenState extends State<BusLinesScreen> {
  final _bookingService = BookingService();
  final _searchBarKey = GlobalKey();
  Map<String, double> _linePrices = {};
  Set<String> _lastFetchedLineIds = {};

  Future<void> _ensureLinePrices(Set<String> lineIds) async {
    if (lineIds.isEmpty) return;
    if (_lastFetchedLineIds.length == lineIds.length &&
        _lastFetchedLineIds.containsAll(lineIds)) {
      return;
    }
    final result = <String, double>{};
    final list = lineIds.toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(
        i,
        i + 30 > list.length ? list.length : i + 30,
      );
      final snap = await FirebaseFirestore.instance
          .collection('lines')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final price = (doc.data()['basePrice'] as num?)?.toDouble();
        if (price != null) result[doc.id] = price;
      }
    }
    if (!mounted) return;
    setState(() {
      _linePrices = result;
      _lastFetchedLineIds = lineIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final tr = context.tr;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: RefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            slivers: [
              // ════════════════════════════════════════
              // HEADER — scrollable
              // ════════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/massar_logo.webp', height: 44, fit: BoxFit.contain),
                      const Spacer(),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (ctx, mode, _) => _HdrBtn(
                          icon: mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                          onTap: () => themeNotifier.toggleTheme(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HdrBtn(
                        icon: Icons.person_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ════════════════════════════════════════
              // SEARCH BAR — outside StreamBuilder to prevent interruption
              // ════════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _HomeSearchBar(key: _searchBarKey),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ════════════════════════════════════════
              // BUS CONTENT — driven by Firestore stream
              // ════════════════════════════════════════
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buses')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 2.5)),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.error_outline, size: 48, color: context.appRed),
                        const SizedBox(height: 12),
                        Text(tr.loadingError, style: TextStyle(fontSize: 15, color: context.appRed)),
                        const SizedBox(height: 6),
                        Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: context.appSub), textAlign: TextAlign.center),
                      ])),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final allBuses = allDocs
                      .map((d) => Bus.fromMap(d.data() as Map<String, dynamic>))
                      .toList();
                  final allTrips = allBuses.expand((b) => b.activeTrips).toList();

                  final visibleLineIds = allBuses.map((b) => b.lineId).where((id) => id.isNotEmpty).toSet();
                  WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLinePrices(visibleLineIds));

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

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // greeting
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          tr.greeting,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.appDark),
                          textAlign: context.isRtl ? TextAlign.right : TextAlign.left,
                        ),
                      ),

                      if (onTrip.isEmpty && online.isEmpty) ...[
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.directions_bus_outlined, size: 56, color: context.appBorder),
                            const SizedBox(height: 16),
                            Text(tr.noBusAvailable, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.appText)),
                            const SizedBox(height: 8),
                            Text(tr.comeBackLater, style: TextStyle(fontSize: 13, color: context.appSub)),
                          ])),
                        ),
                      ] else ...[

                        // ── Reserved bus ──
                        StreamBuilder<List<Booking>>(
                          stream: _bookingService.getMyBookings(),
                          builder: (context, bookSnap) {
                            final active = (bookSnap.data ?? [])
                                .where((b) => b.isPending || b.isConfirmed)
                                .toList();
                            if (active.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: active.map((booking) {
                                  final matchedBus = allBuses.cast<Bus?>().firstWhere(
                                    (b) => b?.busId == booking.busId, orElse: () => null);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ReservedBusCard(
                                      booking: booking,
                                      bus: matchedBus,
                                      bookingService: _bookingService,
                                      basePrice: matchedBus != null ? _linePrices[matchedBus.lineId] : null,
                                      onViewMap: matchedBus != null
                                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: matchedBus)))
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),

                        // ── En trajet ──
                        if (onTrip.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            child: Row(children: [
                              Container(width: 3, height: 18, decoration: BoxDecoration(color: context.appGreen, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text(tr.onTripSectionTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.appText)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text('${onTrip.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appGreen)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text(tr.trackLive, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appGreen)),
                                ]),
                              ),
                            ]),
                          ),
                          ...onTrip.take(3).map((trip) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 350 + (onTrip.indexOf(trip) * 80).clamp(0, 400)),
                              curve: Curves.easeOutCubic,
                              builder: (ctx, v, child) => Transform.translate(offset: Offset(0, 20 * (1 - v)), child: Opacity(opacity: v, child: child)),
                              child: BusTripCard(
                                trip: trip,
                                basePrice: _linePrices[trip.bus.lineId],
                                isOnTrip: true,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                              ),
                            ),
                          )),
                          if (onTrip.length > 3)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _SeeAllButton(onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AllBusesListScreen(trips: onTrip, linePrices: _linePrices, isOnTrip: true)))),
                            ),
                        ],

                        // ── Prochains départs ──
                        if (online.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            child: Row(children: [
                              Container(width: 3, height: 18, decoration: BoxDecoration(color: context.appPrimary, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text(tr.upcomingBuses, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.appText)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: context.appPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text('${online.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appPrimary)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: context.appGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                child: Text(tr.onTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appGreen)),
                              ),
                            ]),
                          ),
                          ...online.take(3).map((trip) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 350 + (online.indexOf(trip) * 80).clamp(0, 400)),
                              curve: Curves.easeOutCubic,
                              builder: (ctx, v, child) => Transform.translate(offset: Offset(0, 20 * (1 - v)), child: Opacity(opacity: v, child: child)),
                              child: BusTripCard(trip: trip, basePrice: _linePrices[trip.bus.lineId], isOnTrip: false),
                            ),
                          )),
                          if (online.length > 3)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _SeeAllButton(onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AllBusesListScreen(trips: online, linePrices: _linePrices, isOnTrip: false)))),
                            ),
                          const SizedBox(height: 80),
                        ] else ...[
                          const SizedBox(height: 80),
                        ],

                      ], // end else
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════
// RESERVED BUS CARD  — ticket style
// ════════════════════════════════════════
class _ReservedBusCard extends StatelessWidget {
  final Booking booking;
  final Bus? bus;
  final BookingService bookingService;
  final double? basePrice;
  final VoidCallback? onViewMap;

  const _ReservedBusCard({
    required this.booking,
    required this.bus,
    required this.bookingService,
    this.basePrice,
    this.onViewMap,
  });

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final primary = context.appPrimary;
    final isDark = context.isDark;
    final statusColor = booking.isConfirmed ? context.appGreen : context.appOrange;
    final statusLabel = booking.isConfirmed ? tr.confirmed : tr.pending;

    final parts = booking.lineName.split('-');
    final cityFrom = parts.isNotEmpty ? parts.first.trim() : '--';
    final cityTo   = parts.length > 1  ? parts.last.trim()  : '--';

    const ticketYellow = Color(0xFFF2C94C);
    final ticketBg = isDark
        ? Color.alphaBlend(ticketYellow.withValues(alpha: 0.08), context.appCardBg)
        : ticketYellow.withValues(alpha: 0.28);

    return CustomPaint(
      painter: _TicketBorderPainter(
        bgColor: ticketBg,
        borderColor: ticketYellow.withValues(alpha: isDark ? 0.35 : 0.6),
        shadowColor: ticketYellow.withValues(alpha: 0.18),
        notchRadius: 5,
        borderRadius: 18,
        notchSpacing: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── TOP SECTION: header + route ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.confirmation_number_rounded, size: 16, color: context.appPrimary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr.myReservedBus,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appText,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (booking.isConfirmed) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, size: 13, color: Colors.white),
                        ],
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // City names + route track
                Row(
                  children: [
                    // From city
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cityFrom,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr.fromLabel,
                            style: TextStyle(fontSize: 10, color: context.appSub),
                          ),
                        ],
                      ),
                    ),
                    // Route track
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.appGreen, width: 2.5),
                                    color: ticketBg,
                                  )),
                              Expanded(child: Container(height: 1.5,
                                  color: context.appPrimary.withValues(alpha: 0.4))),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: context.appPrimary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.directions_bus_rounded, size: 14, color: context.appPrimary),
                              ),
                              Expanded(child: Container(height: 1.5,
                                  color: context.appPrimary.withValues(alpha: 0.4))),
                              Icon(Icons.location_on, color: context.appPrimary, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // To city
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            cityTo,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr.toLabel,
                            style: TextStyle(fontSize: 10, color: context.appSub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── PERFORATED DIVIDER ───────────────────────────────────────────
          _TicketDivider(bgColor: ticketBg, lineColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.25)),

          // ── BOTTOM SECTION: details + actions ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                // Line name + bus name + price
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.lineName.isNotEmpty ? booking.lineName : (bus?.lineName ?? '--'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.busName.isNotEmpty ? booking.busName : (bus?.busName ?? '--'),
                            style: TextStyle(fontSize: 11, color: context.appSub),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    BusPriceChip(price: basePrice),
                  ],
                ),

                const SizedBox(height: 10),

                // ETA row
                if (booking.hasLocation && bus != null)
                  _EtaBadge(
                    busId: bus!.busId,
                    passengerLat: booking.passengerLat!,
                    passengerLng: booking.passengerLng!,
                  )
                else
                  _EtaPlaceholder(),

                const SizedBox(height: 12),

                // Show on Map button
                if (onViewMap != null) ...[
                  GestureDetector(
                    onTap: onViewMap,
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? primary : const Color(0xFF1A2340),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.map_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          tr.showOnMap,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Cancel button
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: context.appCardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(tr.cancelReservation,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appText)),
                        content: Text(
                          tr.cancelConfirmMsg,
                          style: TextStyle(fontSize: 13, color: context.appSub),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(tr.cancel, style: TextStyle(color: context.appSub)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(tr.cancelReservation,
                                style: TextStyle(color: context.appRed, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await bookingService.cancelBooking(booking.bookingId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr.reservationCancelled),
                            backgroundColor: context.appGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appRed.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Text(
                        tr.cancelReservation,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
// TICKET BORDER PAINTER — stamp notches
// ════════════════════════════════════════
class _TicketBorderPainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;
  final Color shadowColor;
  final double notchRadius;
  final double borderRadius;
  final double notchSpacing;

  const _TicketBorderPainter({
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
    required this.notchRadius,
    required this.borderRadius,
    required this.notchSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawShadow(path, shadowColor, 8, true);
    canvas.drawPath(path, Paint()..color = bgColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // Computes notch centres for an edge of given length, fitting as many
  // notches as possible with the requested spacing (notches are diameter=2*nr apart).
  List<double> _notchPositions(double edgeLen, double nr, double spacing) {
    final step = nr * 2 + spacing;
    final count = ((edgeLen - nr * 2) / step).floor();
    if (count <= 0) return [];
    final totalUsed = count * step - spacing;
    final start = (edgeLen - totalUsed) / 2 + nr;
    return List.generate(count, (i) => start + i * step);
  }

  ui.Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final nr = notchRadius;

    final hPos = _notchPositions(w, nr, notchSpacing);
    final vPos = _notchPositions(h, nr, notchSpacing);

    final p = ui.Path();
    p.moveTo(r, 0);

    // ── Top edge ──────────────────────────────────────────────────────────────
    for (final cx in hPos) {
      p.lineTo(cx - nr, 0);
      p.arcToPoint(Offset(cx + nr, 0),
          radius: Radius.circular(nr), clockwise: false);
    }
    p.lineTo(w - r, 0);
    p.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);

    // ── Right edge ────────────────────────────────────────────────────────────
    for (final cy in vPos) {
      p.lineTo(w, cy - nr);
      p.arcToPoint(Offset(w, cy + nr),
          radius: Radius.circular(nr), clockwise: false);
    }
    p.lineTo(w, h - r);
    p.arcToPoint(Offset(w - r, h), radius: Radius.circular(r), clockwise: true);

    // ── Bottom edge (reversed) ────────────────────────────────────────────────
    for (final cx in hPos.reversed) {
      p.lineTo(cx + nr, h);
      p.arcToPoint(Offset(cx - nr, h),
          radius: Radius.circular(nr), clockwise: false);
    }
    p.lineTo(r, h);
    p.arcToPoint(Offset(0, h - r), radius: Radius.circular(r), clockwise: true);

    // ── Left edge (reversed) ──────────────────────────────────────────────────
    for (final cy in vPos.reversed) {
      p.lineTo(0, cy + nr);
      p.arcToPoint(Offset(0, cy - nr),
          radius: Radius.circular(nr), clockwise: false);
    }
    p.lineTo(0, r);
    p.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_TicketBorderPainter o) =>
      o.bgColor != bgColor || o.borderColor != borderColor ||
      o.notchRadius != notchRadius || o.notchSpacing != notchSpacing;
}

// ════════════════════════════════════════
// TICKET PERFORATED DIVIDER
// ════════════════════════════════════════
class _TicketDivider extends StatelessWidget {
  final Color bgColor;
  final Color lineColor;

  const _TicketDivider({required this.bgColor, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed line
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(color: lineColor),
          ),
          // Left notch
          Positioned(
            left: -12,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: context.appBg,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor, width: 1),
              ),
            ),
          ),
          // Right notch
          Positioned(
            right: -12,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: context.appBg,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ════════════════════════════════════════
// ETA PLACEHOLDER (when no location data)
// ════════════════════════════════════════
class _EtaPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 13, color: context.appSub),
        const SizedBox(width: 5),
        Text(
          context.tr.estimatedArrivalDash,
          style: TextStyle(fontSize: 12, color: context.appSub),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════
// ETA BADGE
// ════════════════════════════════════════
class _EtaBadge extends StatefulWidget {
  final String busId;
  final double passengerLat;
  final double passengerLng;

  const _EtaBadge({
    required this.busId,
    required this.passengerLat,
    required this.passengerLng,
  });

  @override
  State<_EtaBadge> createState() => _EtaBadgeState();
}

class _EtaBadgeState extends State<_EtaBadge> {
  final _locationService = LocationService();
  String? _etaText;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _locationService.getBusLocationStream(widget.busId).listen((loc) async {
      if (!mounted) return;
      if (loc == null) {
        setState(() { _loading = false; _etaText = null; });
        return;
      }
      final result = await RouteService.getRoute(
        loc.latLng,
        LatLng(widget.passengerLat, widget.passengerLng),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _etaText = result != null ? _buildEtaText(result.etaMinutes) : null;
      });
    });
  }

  String _buildEtaText(int minutes) {
    if (minutes < 1) return context.tr.etaImminent;
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}min';
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final color = context.appPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.access_time_rounded, size: 14, color: color),
        const SizedBox(width: 7),
        Text(
          tr.etaLabel,
          style: TextStyle(fontSize: 11, color: context.appSub),
        ),
        const Spacer(),
        if (_loading)
          SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        else
          Text(
            _etaText ?? tr.etaUnavailable,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _etaText != null ? color : context.appSub,
            ),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════
class _SeeAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.tr.seeAll,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 15, color: context.appPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

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

// ════════════════════════════════════════
// HOME SEARCH BAR — interactive
// ════════════════════════════════════════
class _HomeSearchBar extends StatefulWidget {
  const _HomeSearchBar({super.key});

  @override
  State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _departureFocus = FocusNode();
  final _arrivalFocus = FocusNode();

  // ValueNotifiers — updating them never calls setState on this widget,
  // so the TextField is never rebuilt while the user is typing.
  final _suggestions = ValueNotifier<List<_SearchPlace>>([]);
  final _isSearching = ValueNotifier<bool>(false);

  String _activeField = ''; // 'departure' or 'arrival'
  LatLng? _departureLatLng;
  LatLng? _arrivalLatLng;
  LatLng? _myPosition;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _departureFocus.addListener(() {
      if (!_departureFocus.hasFocus) {
        _suggestions.value = [];
        _activeField = '';
      }
    });
    _arrivalFocus.addListener(() {
      if (!_arrivalFocus.hasFocus) {
        _suggestions.value = [];
        _activeField = '';
      }
    });
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _departureFocus.dispose();
    _arrivalFocus.dispose();
    _suggestions.dispose();
    _isSearching.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      _myPosition = ll;
      _departureLatLng = ll;
      _departureController.text = context.tr.myPosition;
      _reverseGeocode(ll, isDeparture: true);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng pos, {required bool isDeparture}) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${pos.longitude},${pos.latitude}.json'
            '?access_token=${config.mapboxToken}&language=fr&limit=1',
      );
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) {
        final features = jsonDecode(res.body)['features'] as List;
        if (features.isNotEmpty) {
          final name = features.first['text'] as String? ?? context.tr.myPosition;
          if (isDeparture) {
            _departureController.text = name;
          } else {
            _arrivalController.text = name;
          }
        }
      }
    } catch (_) {}
  }

  /// Filters local Algeria stops instantly (no network), returns matches.
  List<_SearchPlace> _filterLocalStops(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return kAlgeriaStops
        .where((s) => s.name.toLowerCase().contains(q))
        .take(5)
        .map((s) => _SearchPlace(
              name: s.name,
              fullName: s.name,
              latLng: LatLng(s.lat, s.lng),
            ))
        .toList();
  }

  void _onChanged(String query, String field) {
    _activeField = field;
    // Show local results immediately (no delay)
    final local = _filterLocalStops(query);
    _suggestions.value = local;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().length >= 2) {
        _fetchSuggestions(query, local);
      } else {
        _suggestions.value = [];
      }
    });
  }

  Future<void> _fetchSuggestions(String query, List<_SearchPlace> localResults) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
            '?access_token=${config.mapboxToken}&country=dz&language=fr&limit=5'
            '&types=place,locality,neighborhood,address,poi',
      );
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) {
        final features = jsonDecode(res.body)['features'] as List;
        final mapboxResults = features.map((f) {
          final c = f['geometry']['coordinates'] as List;
          return _SearchPlace(
            name: f['text'] ?? '',
            fullName: f['place_name'] ?? '',
            latLng: LatLng(c[1].toDouble(), c[0].toDouble()),
          );
        }).toList();

        // Merge: local first, then Mapbox results (skip duplicates)
        final localNames = localResults.map((p) => p.name.toLowerCase()).toSet();
        final merged = <_SearchPlace>[
          ...localResults,
          ...mapboxResults.where((p) => !localNames.contains(p.name.toLowerCase())),
        ];
        _suggestions.value = merged.take(7).toList();
      }
    } catch (_) {}
  }

  void _selectSuggestion(_SearchPlace place) {
    if (_activeField == 'departure') {
      _departureLatLng = place.latLng;
      _departureController.text = place.name;
      _suggestions.value = [];
      _departureFocus.unfocus();
      FocusScope.of(context).requestFocus(_arrivalFocus);
    } else {
      _arrivalLatLng = place.latLng;
      _arrivalController.text = place.name;
      _suggestions.value = [];
      _arrivalFocus.unfocus();
    }
    _activeField = '';
  }

  void _resetToMyPosition() {
    if (_myPosition == null) return;
    _departureLatLng = _myPosition;
    _departureController.text = context.tr.myPosition;
    _suggestions.value = [];
    _activeField = '';
    _reverseGeocode(_myPosition!, isDeparture: true);
  }

  Future<void> _pickOnMap({required bool isDeparture}) async {
    _departureFocus.unfocus();
    _arrivalFocus.unfocus();
    final tr = context.tr;
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickOnMapScreen(
          title: isDeparture ? tr.departurePointTitle : tr.arrivalPointTitle,
          pinColor: isDeparture ? context.appGreen : context.appRed,
        ),
      ),
    );
    if (result != null && mounted) {
      final ll = LatLng(result['latitude']!, result['longitude']!);
      if (isDeparture) {
        _departureLatLng = ll;
        _departureController.text = tr.myPosition;
        _reverseGeocode(ll, isDeparture: true);
      } else {
        _arrivalLatLng = ll;
        _arrivalController.text = tr.myPosition;
        _reverseGeocode(ll, isDeparture: false);
      }
    }
  }


  Future<void> _doSearch() async {
    if (_departureLatLng == null || _arrivalLatLng == null) return;
    _departureFocus.unfocus();
    _arrivalFocus.unfocus();
    _isSearching.value = true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('buses').where('isActive', isEqualTo: true).get();
      final all = snap.docs.map((d) => Bus.fromMap(d.data())).where((b) => b.hasDeparture && b.hasArrival).toList();

      final ids = <String>{};
      final needsRoute = <Bus>[];
      const dist = Distance();

      for (final bus in all) {
        final busDepart = LatLng(bus.departureLat!, bus.departureLng!);
        final busArrive = LatLng(bus.arrivalLat!, bus.arrivalLng!);
        if (dist.as(LengthUnit.Kilometer, _departureLatLng!, busDepart) <= 15.0 &&
            dist.as(LengthUnit.Kilometer, _arrivalLatLng!, busArrive) <= 15.0) {
          ids.add(bus.busId);
        } else {
          needsRoute.add(bus);
        }
      }

      for (final bus in needsRoute) {
        final from = LatLng(bus.departureLat!, bus.departureLng!);
        final to = LatLng(bus.arrivalLat!, bus.arrivalLng!);
        final route = await RouteService.getRoute(from, to);
        if (route == null || route.points.isEmpty) continue;
        bool near(LatLng pt) {
          for (final rp in route.points) {
            if (dist.as(LengthUnit.Kilometer, pt, rp) <= 2.0) return true;
          }
          return false;
        }
        int closest(LatLng pt) {
          double min = double.infinity; int idx = 0;
          for (int i = 0; i < route.points.length; i++) {
            final d = dist.as(LengthUnit.Meter, pt, route.points[i]);
            if (d < min) { min = d; idx = i; }
          }
          return idx;
        }
        if (near(_departureLatLng!) && near(_arrivalLatLng!)) {
          if (closest(_departureLatLng!) < closest(_arrivalLatLng!)) ids.add(bus.busId);
        }
      }

      final matched = all.where((b) => ids.contains(b.busId)).toList()
        ..sort((a, b) {
          if (a.isOnTrip && !b.isOnTrip) return -1;
          if (!a.isOnTrip && b.isOnTrip) return 1;
          return 0;
        });

      final lineIds = matched.map((b) => b.lineId).where((id) => id.isNotEmpty).toSet();
      final basePrices = <String, double>{};
      final list = lineIds.toList();
      for (var i = 0; i < list.length; i += 30) {
        final chunk = list.sublist(i, (i + 30).clamp(0, list.length));
        final s = await FirebaseFirestore.instance.collection('lines')
            .where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in s.docs) {
          final p = (doc.data()['basePrice'] as num?)?.toDouble();
          if (p != null) basePrices[doc.id] = p;
        }
      }

      final segmentPrices = <String, double?>{};
      for (final lineId in lineIds) {
        try {
          segmentPrices[lineId] = await PriceService.calculateSegmentPriceForCoords(
            lineId: lineId, from: _departureLatLng!, to: _arrivalLatLng!,
          );
        } catch (_) { segmentPrices[lineId] = null; }
      }

      if (!mounted) return;
      _isSearching.value = false;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          departureLabel: _departureController.text,
          arrivalLabel: _arrivalController.text,
          departureLatLng: _departureLatLng!,
          arrivalLatLng: _arrivalLatLng!,
          matchedBuses: matched,
          linePrices: basePrices,
          segmentPrices: segmentPrices,
        ),
      ));
    } catch (_) {
      if (mounted) {
        _isSearching.value = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr.searchErrorMsg),
          backgroundColor: context.appRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search card ──
        Container(
          decoration: BoxDecoration(
            color: context.appCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Column(
            children: [
              // ── Departure row — TextField with search suggestions ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                child: Row(children: [
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _departureController,
                      focusNode: _departureFocus,
                      onChanged: (v) => _onChanged(v, 'departure'),
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(fontSize: 13, color: context.appText),
                      decoration: InputDecoration(
                        hintText: tr.departureHint,
                        hintStyle: TextStyle(fontSize: 13, color: context.appSub),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _departureController,
                              builder: (_, v, __) => v.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _departureController.clear();
                                        _departureLatLng = null;
                                        _suggestions.value = [];
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(Icons.close, size: 15, color: context.appSub),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            if (_myPosition != null)
                              GestureDetector(
                                onTap: _resetToMyPosition,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 2, left: 2),
                                  child: Icon(Icons.my_location, size: 15, color: context.appPrimary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _pickOnMap(isDeparture: true),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.map_outlined, size: 18, color: context.appPrimary),
                    ),
                  ),
                ]),
              ),

              Divider(height: 1, color: context.appBorder, indent: 14, endIndent: 14),

              // ── Arrival row — TextField is NEVER rebuilt by suggestions/departure changes ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                child: Row(children: [
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: context.appRed, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _arrivalController,
                      focusNode: _arrivalFocus,
                      onChanged: (v) => _onChanged(v, 'arrival'),
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(fontSize: 13, color: context.appText),
                      decoration: InputDecoration(
                        hintText: tr.destinationHint,
                        hintStyle: TextStyle(fontSize: 13, color: context.appSub),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        // suffix driven by controller so no setState needed
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _arrivalController,
                          builder: (_, v, __) => v.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _arrivalController.clear();
                                    _arrivalLatLng = null;
                                    _suggestions.value = [];
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.close, size: 15, color: context.appSub),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _pickOnMap(isDeparture: false),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.map_outlined, size: 18, color: context.appPrimary),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),

        // ── Suggestions — only this subtree rebuilds when suggestions change ──
        ValueListenableBuilder<List<_SearchPlace>>(
          valueListenable: _suggestions,
          builder: (_, sugg, __) {
            if (sugg.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appBorder),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.06),
                  blurRadius: 8,
                )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sugg.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: context.appBorder, indent: 46),
                  itemBuilder: (_, i) {
                    final p = sugg[i];
                    return ListTile(
                      dense: true,
                      leading: Container(width: 30, height: 30,
                          decoration: BoxDecoration(color: context.appCardBg2, shape: BoxShape.circle),
                          child: Icon(Icons.location_on_outlined, color: context.appSub, size: 16)),
                      title: Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText)),
                      subtitle: Text(p.fullName, style: TextStyle(fontSize: 11, color: context.appSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _selectSuggestion(p),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // ── Search button ──
        const SizedBox(height: 10),
        ValueListenableBuilder<bool>(
          valueListenable: _isSearching,
          builder: (_, searching, __) => SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: (!searching && _departureLatLng != null && (_arrivalLatLng != null || _arrivalController.text.isNotEmpty))
                  ? _doSearch
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: context.appBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: searching
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.search_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(tr.searchBtn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPlace {
  final String name;
  final String fullName;
  final LatLng latLng;
  _SearchPlace({required this.name, required this.fullName, required this.latLng});
}

