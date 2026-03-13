import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gYellow = Color(0xFFFBBC05);
const _gDark = Color(0xFF202124);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);
const _gLight = Color(0xFFF8F9FA);

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingService = BookingService();

    return Scaffold(
      backgroundColor: _gLight,
      appBar: AppBar(
        title: const Text('Mes réservations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _gDark)),
        backgroundColor: Colors.white,
        foregroundColor: _gDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Booking>>(
        stream: bookingService.getMyBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gBlue, strokeWidth: 2.5));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border_rounded, size: 56, color: _gBorder),
                const SizedBox(height: 16),
                const Text('Aucune réservation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _gDark)),
                const SizedBox(height: 8),
                const Text('Vos réservations apparaîtront ici', style: TextStyle(fontSize: 13, color: _gSub)),
              ],
            ));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final b = bookings[index];
              final statusColor = b.isConfirmed ? _gGreen : b.isPending ? _gYellow : _gSub;
              final date = DateFormat('dd/MM/yyyy HH:mm').format(b.createdAt);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: b.isCancelled ? _gBorder : statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: b.isCancelled ? _gLight : statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.directions_bus_rounded,
                          color: b.isCancelled ? _gSub : statusColor, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.lineName, style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: b.isCancelled ? _gSub : _gDark)),
                          Text(b.busName.isNotEmpty ? b.busName : 'Bus', style: const TextStyle(fontSize: 11, color: _gSub)),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(b.statusText, style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.access_time, size: 12, color: _gSub),
                      const SizedBox(width: 4),
                      Text(date, style: const TextStyle(fontSize: 11, color: _gSub)),
                      const Spacer(),
                      if (!b.isCancelled)
                        GestureDetector(
                          onTap: () => _confirmCancel(context, bookingService, b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _gRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Text('Annuler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gRed)),
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
    );
  }

  void _confirmCancel(BuildContext context, BookingService service, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('Voulez-vous annuler votre réservation pour ${booking.lineName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Non')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await service.cancelBooking(booking.bookingId);
            },
            style: FilledButton.styleFrom(backgroundColor: _gRed),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
