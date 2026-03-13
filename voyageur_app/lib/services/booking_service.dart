import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_model.dart';
import '../models/bus_model.dart';

class BookingService {
  final _bookings = FirebaseFirestore.instance.collection('bookings');
  final _users = FirebaseFirestore.instance.collection('users');
  final _uuid = const Uuid();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Book a trip on a bus
  Future<Booking> bookTrip(Bus bus) async {
    // Check if already booked this bus
    final existing = await _bookings
        .where('busId', isEqualTo: bus.busId)
        .where('passengerId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'confirmed'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw 'Vous avez déjà une réservation pour ce bus.';
    }

    // Get passenger name
    String name = '';
    try {
      final userDoc = await _users.doc(_uid).get();
      if (userDoc.exists) {
        name = (userDoc.data() as Map)['displayName'] ?? '';
      }
    } catch (_) {}

    final bookingId = _uuid.v4();
    final booking = Booking(
      bookingId: bookingId,
      busId: bus.busId,
      passengerId: _uid,
      passengerName: name,
      lineName: bus.lineName,
      busName: bus.busName,
      status: 'confirmed',
    );

    await _bookings.doc(bookingId).set(booking.toMap());
    return booking;
  }

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({'status': 'cancelled'});
  }

  /// Get my active booking for a specific bus (stream)
  Stream<Booking?> getMyBooking(String busId) {
    return _bookings
        .where('busId', isEqualTo: busId)
        .where('passengerId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'confirmed'])
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return Booking.fromMap(snap.docs.first.data());
    });
  }

  /// Get all my bookings (stream)
  Stream<List<Booking>> getMyBookings() {
    return _bookings
        .where('passengerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromMap(d.data())).toList());
  }

  /// Count active passengers for a bus (stream) — for driver/owner
  Stream<int> getPassengerCount(String busId) {
    return _bookings
        .where('busId', isEqualTo: busId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Get active bookings for a bus (stream) — for driver/owner
  Stream<List<Booking>> getBusBookings(String busId) {
    return _bookings
        .where('busId', isEqualTo: busId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromMap(d.data())).toList());
  }
}
