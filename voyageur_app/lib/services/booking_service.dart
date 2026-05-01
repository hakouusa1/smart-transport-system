import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_model.dart';
import '../models/bus_model.dart';
import '../services/notify_service.dart';

class BookingService {
  final _bookings = FirebaseFirestore.instance.collection('bookings');
  final _users = FirebaseFirestore.instance.collection('users');
  final _uuid = const Uuid();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Book a trip — saves passenger's current GPS location.
  /// Uses a Firestore transaction to enforce bus capacity atomically.
  Future<Booking> bookTrip(Bus bus) async {
    // Check if already booked (outside transaction — cheap pre-check)
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
      if (userDoc.exists) name = (userDoc.data() as Map)['displayName'] ?? '';
    } catch (_) {}

    // Get passenger location
    double? lat, lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      lat = pos.latitude;
      lng = pos.longitude;
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
      passengerLat: lat,
      passengerLng: lng,
    );

    // Check capacity before writing (aggregation queries cannot run inside a transaction)
    final countSnap = await _bookings
        .where('busId', isEqualTo: bus.busId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .count()
        .get();
    final current = countSnap.count ?? 0;
    if (current >= bus.capacity) {
      throw 'Bus complet (${bus.capacity} places). Essayez un autre départ.';
    }

    await _bookings.doc(bookingId).set(booking.toMap());

    // Notify the driver
    try {
      // Get the driverId from the bus document
      final busDoc = await FirebaseFirestore.instance.collection('buses').doc(bus.busId).get();
      final driverId = (busDoc.data() as Map?)?['driverId'] ?? '';
      if (driverId.isNotEmpty) {
        await NotifyService.notifyDriverBooking(
          busId: bus.busId,
          driverId: driverId,
          passengerName: name,
          lineName: bus.lineName,
        );
      }
    } catch (_) {}

    return booking;
  }

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({'status': 'cancelled'});
  }

  /// Get my active booking for a specific bus
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

  /// Get all my bookings
  Stream<List<Booking>> getMyBookings() {
    return _bookings
        .where('passengerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromMap(d.data())).toList());
  }

  /// Count active passengers for a bus
  Stream<int> getPassengerCount(String busId) {
    return _bookings
        .where('busId', isEqualTo: busId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Get active bookings for a bus (with locations) — for chauffeur
  Stream<List<Booking>> getBusBookings(String busId) {
    return _bookings
        .where('busId', isEqualTo: busId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromMap(d.data())).toList());
  }
}