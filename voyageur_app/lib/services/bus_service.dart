import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';

class BusService {
  final CollectionReference _busesCollection =
      FirebaseFirestore.instance.collection('buses');

  /// Get all ACTIVE buses (real-time stream)
  /// Passengers only see buses where isActive == true
  Stream<List<Bus>> getActiveBuses() {
    return _busesCollection
        .where('isActive', isEqualTo: true)
        .orderBy('lineName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bus.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Get buses that are ON TRIP (active + driverStatus == 'on_trip')
  /// Use this for map display - shows buses that are actually running
  Stream<List<Bus>> getOnTripBuses() {
    return _busesCollection
        .where('isActive', isEqualTo: true)
        .where('driverStatus', isEqualTo: 'on_trip')
        .orderBy('lineName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bus.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Get a single bus by ID (real-time stream)
  Stream<Bus?> getBusById(String busId) {
    return _busesCollection.doc(busId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Bus.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  /// Get all ACTIVE lines (real-time stream) — used by the map to show routes
  /// even when no buses are currently on trip.
  static Stream<List<Map<String, dynamic>>> getActiveLines() {
    return FirebaseFirestore.instance
        .collection('lines')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Fetch the intermediate stop names defined by the admin for a line.
  static Future<List<String>> fetchLineStops(String lineId) async {
    if (lineId.isEmpty) return [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lines')
          .doc(lineId)
          .get();
      if (!doc.exists) return [];
      return (doc.data()?['stops'] as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Get count of active buses with drivers on trip
  Stream<int> getOnTripCount() {
    return _busesCollection
        .where('isActive', isEqualTo: true)
        .where('driverStatus', isEqualTo: 'on_trip')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
