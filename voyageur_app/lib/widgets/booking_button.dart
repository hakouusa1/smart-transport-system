import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/bus_model.dart';
import '../services/booking_service.dart';
import '../services/notification_service.dart';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gDark = Color(0xFF202124);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);

class BookingButton extends StatefulWidget {
  final Bus bus;
  final int etaMinutes; // current ETA from map screen

  const BookingButton({super.key, required this.bus, required this.etaMinutes});

  @override
  State<BookingButton> createState() => _BookingButtonState();
}

class _BookingButtonState extends State<BookingButton> {
  final _bookingService = BookingService();
  bool _isLoading = false;
  bool _notified5min = false;
  bool _notified10min = false;

  @override
  void didUpdateWidget(covariant BookingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check ETA for notifications
    _checkETANotifications();
  }

  void _checkETANotifications() {
    if (widget.etaMinutes <= 5 && !_notified5min) {
      _notified5min = true;
      NotificationService.showNotification(
        title: '🚌 Bus arrive dans 5 min !',
        body: '${widget.bus.lineName} arrive bientôt. Préparez-vous !',
        id: 1,
      );
    }
    if (widget.etaMinutes <= 10 && widget.etaMinutes > 5 && !_notified10min) {
      _notified10min = true;
      NotificationService.showNotification(
        title: '🚌 Bus arrive dans 10 min',
        body: '${widget.bus.lineName} sera là dans environ 10 minutes.',
        id: 2,
      );
    }
  }

  Future<void> _book() async {
    setState(() => _isLoading = true);
    try {
      await _bookingService.bookTrip(widget.bus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Réservation confirmée !'),
            ]),
            backgroundColor: _gGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );

        // Send notification
        NotificationService.showNotification(
          title: '✅ Réservation confirmée',
          body: 'Vous avez réservé ${widget.bus.lineName}. ETA: ${widget.etaMinutes} min.',
          id: 3,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(e.toString())),
            ]),
            backgroundColor: _gRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel(String bookingId) async {
    setState(() => _isLoading = true);
    try {
      await _bookingService.cancelBooking(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.cancel, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Réservation annulée'),
            ]),
            backgroundColor: _gSub,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: _bookingService.getMyBooking(widget.bus.busId),
      builder: (context, snapshot) {
        final booking = snapshot.data;

        // Already booked — show status + cancel
        if (booking != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _gGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gGreen.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: _gGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Réservation confirmée', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _gGreen)),
                  Text(widget.bus.lineName, style: const TextStyle(fontSize: 10, color: _gSub)),
                ],
              )),
              // Passenger count
              StreamBuilder<int>(
                stream: _bookingService.getPassengerCount(widget.bus.busId),
                builder: (_, snap) {
                  final count = snap.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _gBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people, size: 12, color: _gBlue),
                      const SizedBox(width: 4),
                      Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gBlue)),
                    ]),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Cancel button
              GestureDetector(
                onTap: _isLoading ? null : () => _cancel(booking.bookingId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _gRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: _isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _gRed))
                      : const Text('Annuler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gRed)),
                ),
              ),
            ]),
          );
        }

        // Not booked — show Réserver button
        return Material(
          color: _gBlue,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isLoading ? null : _book,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Réserver ce bus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(width: 8),
                      // Passenger count
                      StreamBuilder<int>(
                        stream: _bookingService.getPassengerCount(widget.bus.busId),
                        builder: (_, snap) {
                          final count = snap.data ?? 0;
                          if (count == 0) return const SizedBox();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text('$count 👤', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          );
                        },
                      ),
                    ]),
            ),
          ),
        );
      },
    );
  }
}
