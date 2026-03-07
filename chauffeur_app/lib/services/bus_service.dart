import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import 'auth_service.dart';

class BusService {
  final CollectionReference _busesCollection =
      FirebaseFirestore.instance.collection('buses');
  final AuthService _authService = AuthService();

  /// Get the bus assigned to the current driver (real-time stream)
  /// Looks for a bus where driverId == current user's UID
  Stream<Bus?> getAssignedBus() {
    final driverId = _authService.uid;

    return _busesCollection
        .where('driverId', isEqualTo: driverId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Bus.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
    });
  }

  /// Update driver status: "online", "offline", "on_trip"
  Future<void> updateDriverStatus(String busId, String status) async {
    try {
      await _busesCollection.doc(busId).update({
        'driverStatus': status,
      });
    } catch (e) {
      throw 'Erreur lors du changement de statut: $e';
    }
  }

  /// Set driver as online
  Future<void> goOnline(String busId) async {
    await updateDriverStatus(busId, 'online');
  }

  /// Set driver as offline
  Future<void> goOffline(String busId) async {
    await updateDriverStatus(busId, 'offline');
  }

  /// Set driver as on trip
  Future<void> startTrip(String busId) async {
    await updateDriverStatus(busId, 'on_trip');
  }

  /// Set driver back to online (trip ended)
  Future<void> endTrip(String busId) async {
    await updateDriverStatus(busId, 'online');
  }
}
