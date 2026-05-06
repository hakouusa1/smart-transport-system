import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';
import '../widgets/ticket_card_shape.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _bookingService = BookingService();
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Column(children: [
          Padding(padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: context.appPurple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_back, size: 20, color: context.appText)),
              ),
              const SizedBox(width: 16),
              Text('Mes réservations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.appText)),
            ]),
          ),
          Expanded(child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _refreshKey++);
            },
            child: StreamBuilder<List<Booking>>(
              key: ValueKey(_refreshKey),
              stream: _bookingService.getMyBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 2.5));
                }

                final bookings = snapshot.data ?? [];

                if (bookings.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded, size: 56, color: context.appBorder),
                            const SizedBox(height: 16),
                            Text('Aucune réservation',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.appText)),
                            const SizedBox(height: 8),
                            Text('Vos réservations apparaîtront ici',
                                style: TextStyle(fontSize: 13, color: context.appSub)),
                          ],
                        )),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    final statusColor = b.isBoarded
                        ? context.appGreen
                        : b.isCompleted
                            ? context.appPrimary.withValues(alpha: 0.6)
                            : b.isConfirmed
                                ? context.appGreen
                                : b.isPending
                                    ? context.appOrange
                                    : context.appSub;
                    final date = DateFormat('dd/MM/yyyy HH:mm').format(b.createdAt);

                    return TicketCardShape(
                      dividerFraction: 0.28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header zone (above the dashed divider) ──
                          Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: b.isCancelled
                                    ? context.appCardBg2
                                    : statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.directions_bus_rounded,
                                  color: b.isCancelled ? context.appSub : statusColor,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.lineName, style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: b.isCancelled ? context.appSub : context.appText,
                                  decoration: b.isCancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: context.appSub,
                                )),
                                Text(
                                  b.busName.isNotEmpty ? b.busName : 'Bus',
                                  style: TextStyle(fontSize: 11, color: context.appSub),
                                ),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(b.statusText, style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              )),
                            ),
                          ]),

                          // ── Spacer so the dashed line sits between header & body ──
                          const SizedBox(height: 16),

                          // ── Body zone (below the dashed divider) ──
                          Row(children: [
                            Icon(Icons.access_time, size: 12, color: context.appSub),
                            const SizedBox(width: 4),
                            Text(date,
                                style: TextStyle(fontSize: 11, color: context.appSub)),
                            const Spacer(),
                            if (!b.isCancelled)
                              GestureDetector(
                                onTap: () =>
                                    _confirmCancel(context, b),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: context.appRed.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Annuler', style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.appRed,
                                  )),
                                ),
                              ),
                          ]),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )),
        ]),
      ),
    );
  }

  void _confirmCancel(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('Voulez-vous annuler votre réservation pour ${booking.lineName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Non')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _bookingService.cancelBooking(booking.bookingId);
            },
            style: FilledButton.styleFrom(backgroundColor: context.appRed),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
