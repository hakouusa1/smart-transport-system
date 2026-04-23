import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  static final _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════
  // STATS
  // ══════════════════════════════════════
  static Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      _db.collection('users').where('role', isEqualTo: 'owner').count().get(),
      _db.collection('users').where('role', isEqualTo: 'driver').count().get(),
      _db.collection('users').where('role', isEqualTo: 'passenger').count().get(),
      _db.collection('buses').count().get(),
      _db.collection('lines').count().get(),
      _db.collection('buses').where('driverStatus', isEqualTo: 'on_trip').count().get(),
      _db.collection('incidents').count().get(),
      _db.collection('bookings').where('status', isEqualTo: 'confirmed').count().get(),
    ]);
    return {
      'owners': results[0].count ?? 0,
      'drivers': results[1].count ?? 0,
      'passengers': results[2].count ?? 0,
      'buses': results[3].count ?? 0,
      'lines': results[4].count ?? 0,
      'activeBuses': results[5].count ?? 0,
      'incidents': results[6].count ?? 0,
      'bookings': results[7].count ?? 0,
    };
  }

  // ══════════════════════════════════════
  // USERS
  // ══════════════════════════════════════
  static Stream<List<Map<String, dynamic>>> getUsersByRole(String role) {
    return _db.collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPendingUsers() {
    return _db.collection('users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPendingOwners() {
    return _db.collection('users')
        .where('role', isEqualTo: 'owner')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPendingSubscriptions() {
    return _db.collection('users')
        .where(Filter.and(
          Filter('role', isEqualTo: 'owner'),
          Filter.or(
            Filter('status', isEqualTo: 'pending'),
            Filter('subscriptionStatus', isEqualTo: 'pending_verification'),
          ),
        ))
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getSubscriptionRenewals() {
    return _db.collection('users')
        .where('role', isEqualTo: 'owner')
        .where('subscriptionStatus', isEqualTo: 'pending_verification')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getActiveOwners() {
    return _db.collection('users')
        .where('role', isEqualTo: 'owner')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  static Future<void> setUserStatus(String uid, String status) async {
    final fields = <String, dynamic>{'status': status};
    if (status == 'active') {
      fields['subscriptionStatus'] = 'trial';
      fields['trialExpiresAt'] = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 14)),
      );
    }
    await _db.collection('users').doc(uid).update(fields);
  }

  static Future<void> approveRenewal(String uid) async {
    await _db.collection('users').doc(uid).update({
      'subscriptionStatus': 'active',
      'subscriptionExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
  }

  // ══════════════════════════════════════
  // LINES
  // ══════════════════════════════════════
  static Future<void> createLine({
    required String departure,
    required String arrival,
    List<String> stops = const [],
    String adminId = '',
    double? departureLat,
    double? departureLng,
    double? arrivalLat,
    double? arrivalLng,
  }) async {
    final ref = _db.collection('lines').doc();
    await ref.set({
      'lineId': ref.id,
      'departure': departure,
      'arrival': arrival,
      'name': '$departure - $arrival',
      'stops': stops,
      'isActive': true,
      'createdBy': adminId,
      'createdAt': Timestamp.now(),
      if (departureLat != null) 'departureLat': departureLat,
      if (departureLng != null) 'departureLng': departureLng,
      if (arrivalLat != null) 'arrivalLat': arrivalLat,
      if (arrivalLng != null) 'arrivalLng': arrivalLng,
    });
  }

  static Stream<List<Map<String, dynamic>>> getLines() {
    return _db.collection('lines')
        .orderBy('departure')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Future<void> updateLine(String lineId, Map<String, dynamic> data) async {
    await _db.collection('lines').doc(lineId).update(data);
  }

  static Future<void> deleteLine(String lineId) async {
    await _db.collection('lines').doc(lineId).delete();
  }

  // ══════════════════════════════════════
  // BUSES
  // ══════════════════════════════════════
  static Stream<List<Map<String, dynamic>>> getAllBuses() {
    return _db.collection('buses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPendingBuses() {
    return _db.collection('buses')
        .where('validationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> getApprovedBuses() {
    return _db.collection('buses')
        .where('validationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Future<void> setBusValidationStatus(
    String busId,
    String status, {
    String? note,
    String? lineId,
    String? lineName,
    double? departureLat,
    double? departureLng,
    double? arrivalLat,
    double? arrivalLng,
  }) async {
    final fields = <String, dynamic>{
      'validationStatus': status,
      'validatedAt': Timestamp.now(),
    };
    if (status == 'approved') {
      fields['isActive'] = true;
      if (lineId != null) fields['lineId'] = lineId;
      if (lineName != null) fields['lineName'] = lineName;
      if (departureLat != null) fields['departureLat'] = departureLat;
      if (departureLng != null) fields['departureLng'] = departureLng;
      if (arrivalLat != null) fields['arrivalLat'] = arrivalLat;
      if (arrivalLng != null) fields['arrivalLng'] = arrivalLng;
    }
    if (status == 'rejected') {
      fields['isActive'] = false;
      fields['validationNote'] = note ?? '';
    }
    await _db.collection('buses').doc(busId).update(fields);
  }

  // ══════════════════════════════════════
  // TRIPS (from bookings for now)
  // ══════════════════════════════════════
  static Stream<List<Map<String, dynamic>>> getBookings() {
    return _db.collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> getTrips() {
    return _db.collection('trips')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBusData(String busId) async {
    if (busId.isEmpty) return null;
    try {
      final doc = await _db.collection('buses').doc(busId).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════
  // INCIDENTS
  // ══════════════════════════════════════
  static Stream<List<Map<String, dynamic>>> getIncidents() {
    return _db.collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Future<void> resolveIncident(String id) async {
    await _db.collection('incidents').doc(id).update({'resolved': true});
  }

  // ══════════════════════════════════════
  // SUBSCRIPTION REVENUE
  // ══════════════════════════════════════
  static Future<int> getSubscriptionRevenue({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.collection('users')
        .where('role', isEqualTo: 'owner')
        .where('subscriptionStatus', isEqualTo: 'active');

    final snap = await query.get();
    final users = snap.docs.map((d) => d.data()).toList();

    int total = 0;
    for (final user in users) {
      final expiresAt = (user['subscriptionExpiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null) continue;

      // Assume subscription started 30 days before expiry
      final startedAt = expiresAt.subtract(const Duration(days: 30));

      // Filter by date range if provided
      if (from != null && startedAt.isBefore(from)) continue;
      if (to != null && startedAt.isAfter(to)) continue;

      final planId = user['subscription'] ?? 'starter';
      final priceStr = _getPlanPrice(planId);
      final price = int.tryParse(priceStr.replaceAll(' ', '').replaceAll('DA', '')) ?? 0;
      total += price;
    }
    return total;
  }

  static String _getPlanPrice(String planId) {
    switch (planId) {
      case 'starter': return '2 000 DA';
      case 'pro': return '5 000 DA';
      case 'enterprise': return '10 000 DA';
      default: return '2 000 DA';
    }
  }

  // ══════════════════════════════════════
  // LIVE BUSES (for map)
  // ══════════════════════════════════════
  static Stream<List<Map<String, dynamic>>> getActiveBuses() {
    return _db.collection('buses')
        .where('driverStatus', isEqualTo: 'on_trip')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
