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

  /// Get a single bus by ID (real-time stream)
  Stream<Bus?> getBusById(String busId) {
    return _busesCollection.doc(busId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Bus.fromMap(doc.data() as Map<String, dynamic>);
    });
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
