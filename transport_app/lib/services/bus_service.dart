import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/bus_model.dart';
import 'auth_service.dart';

class BusService {
  // ── Singleton ──
  static final BusService _instance = BusService._internal();
  factory BusService() => _instance;
  BusService._internal();

  final CollectionReference _busesCollection =
      FirebaseFirestore.instance.collection('buses');
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  // Shared broadcast stream — one Firestore listener for all screens.
  // Recreated automatically when the authenticated owner changes.
  String? _cachedOwnerId;
  Stream<List<Bus>>? _busesStream;
  List<Bus>? _latestBuses;

  /// The most recently emitted buses list, or null if the stream has not emitted yet.
  /// Use this to pre-populate UI before subscribing so late subscribers don't miss
  /// the initial Firestore emission.
  List<Bus>? get latestBuses => _latestBuses;

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

  /// Get all buses for current owner (real-time stream).
  /// Returns a single shared broadcast stream — all screens reuse one Firestore listener.
  Stream<List<Bus>> getBuses() {
    final uid = _ownerId;
    if (_busesStream == null || _cachedOwnerId != uid) {
      _cachedOwnerId = uid;
      _latestBuses = null;
      _busesStream = _busesCollection
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final buses = snapshot.docs
                .map((doc) => Bus.fromMap(doc.data() as Map<String, dynamic>))
                .toList();
            _latestBuses = buses;
            return buses;
          })
          .asBroadcastStream();
    }
    return _busesStream!;
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

  /// Delete a bus (hard-delete — permanently removes the document).
  /// Consider using [archiveBus] instead to preserve historical data.
  Future<void> deleteBus(String busId) async {
    try {
      await _busesCollection.doc(busId).delete();
    } catch (e) {
      throw 'Erreur lors de la suppression: $e';
    }
  }

  /// Soft-delete: marks bus as archived instead of permanently removing it.
  /// Historical trip data and logs are preserved for reporting.
  /// To use soft-delete, replace `deleteBus(id)` with `archiveBus(id)` in
  /// the screen layer and update `getBuses()` to filter out `isArchived == true`.
  Future<void> archiveBus(String busId) async {
    try {
      await _busesCollection.doc(busId).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'isActive': false,
      });
    } catch (e) {
      throw 'Erreur lors de l\'archivage: $e';
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

  /// Get available active lines for the line picker
  static Stream<List<Map<String, dynamic>>> getLines() {
    return FirebaseFirestore.instance
        .collection('lines')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
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