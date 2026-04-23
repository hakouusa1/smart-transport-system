import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/bus_model.dart';
import '../services/auth_service.dart';
import '../theme_notifier.dart';


class BusService {
  final CollectionReference _busesCollection =
      FirebaseFirestore.instance.collection('buses');
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  /// Get current owner's ID
  String get _ownerId => _authService.currentUser?.uid ?? '';

  /// Add a new bus
  Future<void> addBus({
    required String lineName,
    required String busName,
    required String busNumber,
    bool isActive = true,
  }) async {
    try {
      final busId = _uuid.v4();
      final bus = Bus(
        busId: busId,
        lineName: lineName,
        busName: busName,
        busNumber: busNumber,
        isActive: isActive,
        ownerId: _ownerId,
      );

      await _busesCollection.doc(busId).set(bus.toMap());
    } catch (e) {
      throw 'Erreur lors de l\'ajout du bus: $e';
    }
  }

  /// Get all buses for current owner (real-time stream)
  Stream<List<Bus>> getBuses() {
    return _busesCollection
        .where('ownerId', isEqualTo: _ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bus.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Update an existing bus
  Future<void> updateBus({
    required String busId,
    required String lineName,
    required String busName,
    required String busNumber,
    required bool isActive,
  }) async {
    try {
      await _busesCollection.doc(busId).update({
        'lineName': lineName,
        'busName': busName,
        'busNumber': busNumber,
        'isActive': isActive,
      });
    } catch (e) {
      throw 'Erreur lors de la mise à jour: $e';
    }
  }

  /// Delete a bus
  Future<void> deleteBus(String busId) async {
    try {
      await _busesCollection.doc(busId).delete();
    } catch (e) {
      throw 'Erreur lors de la suppression: $e';
    }
  }

  /// Toggle bus active status
  Future<void> toggleBusStatus(String busId, bool currentStatus) async {
    try {
      await _busesCollection.doc(busId).update({
        'isActive': !currentStatus,
      });
    } catch (e) {
      throw 'Erreur lors du changement de statut: $e';
    }
  }

  /// Get bus count for dashboard stats
  Stream<Map<String, int>> getBusStats() {
    return getBuses().map((buses) {
      final total = buses.length;
      final active = buses.where((b) => b.isActive).length;
      final inactive = total - active;
      return {
        'total': total,
        'active': active,
        'inactive': inactive,
      };
    });
  }
}
