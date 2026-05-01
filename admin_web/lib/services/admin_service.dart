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
    required double basePrice,
    List<String> stops = const [],
    String adminId = '',
    double? departureLat,
    double? departureLng,
    double? arrivalLat,
    double? arrivalLng,
  }) async {
    if (basePrice <= 0) {
      throw Exception('Le prix de base doit être supérieur à 0');
    }
    final ref = _db.collection('lines').doc();
    await ref.set({
      'lineId': ref.id,
      'departure': departure,
      'arrival': arrival,
      'name': '$departure - $arrival',
      'stops': stops,
      'basePrice': basePrice,
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

  // ══════════════════════════════════════
  // STOPS
  // ══════════════════════════════════════
  static Future<void> createStop({
    required String name,
    required String type,
    required double lat,
    required double lng,
  }) async {
    final ref = _db.collection('stops').doc();
    await ref.set({
      'id': ref.id,
      'name': name,
      'type': type,
      'lat': lat,
      'lng': lng,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  static Stream<List<Map<String, dynamic>>> getStops() {
    return _db.collection('stops')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Stream<List<Map<String, dynamic>>> getStopsByType(String type) {
    return _db.collection('stops')
        .where('type', isEqualTo: type)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Future<void> updateStop(String stopId, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _db.collection('stops').doc(stopId).update(data);
  }

  static Future<void> deleteStop(String stopId) async {
    await _db.collection('stops').doc(stopId).delete();
  }

  // ══════════════════════════════════════
  // LINE STOPS
  // ══════════════════════════════════════
  static Future<void> addStopToLine({
    required String lineId,
    required String stopId,
    required int orderIndex,
  }) async {
    // Check if orderIndex is unique for this line
    final existing = await _db.collection('lines').doc(lineId).collection('lineStops')
        .where('orderIndex', isEqualTo: orderIndex)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Order index already exists for this line');
    }

    final ref = _db.collection('lines').doc(lineId).collection('lineStops').doc();
    await ref.set({
      'id': ref.id,
      'lineId': lineId,
      'stopId': stopId,
      'orderIndex': orderIndex,
      'createdAt': Timestamp.now(),
    });
  }

  static Stream<List<Map<String, dynamic>>> getLineStops(String lineId) {
    return _db.collection('lines').doc(lineId).collection('lineStops')
        .orderBy('orderIndex')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Future<void> updateLineStop(String lineId, String lineStopId, Map<String, dynamic> data) async {
    // If updating orderIndex, check uniqueness
    if (data.containsKey('orderIndex')) {
      final existing = await _db.collection('lines').doc(lineId).collection('lineStops')
          .where('orderIndex', isEqualTo: data['orderIndex'])
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != lineStopId) {
        throw Exception('Order index already exists for this line');
      }
    }
    await _db.collection('lines').doc(lineId).collection('lineStops').doc(lineStopId).update(data);
  }

  static Future<void> removeStopFromLine(String lineId, String lineStopId) async {
    await _db.collection('lines').doc(lineId).collection('lineStops').doc(lineStopId).delete();
  }

  // ══════════════════════════════════════
  // SEGMENT PRICES
  // ══════════════════════════════════════
  static Future<void> setSegmentPrice({
    required String lineId,
    required String fromStopId,
    required String toStopId,
    required double price,
  }) async {
    if (price <= 0) {
      throw Exception('Price must be positive');
    }
    // Validate that from and to are consecutive in the line
    final lineStopsSnap = await _db.collection('lines').doc(lineId).collection('lineStops')
        .orderBy('orderIndex')
        .get();
    final lineStops = lineStopsSnap.docs.map((d) => d.data()).toList();
    final stopIds = lineStops.map((ls) => ls['stopId'] as String).toList();
    final fromIndex = stopIds.indexOf(fromStopId);
    final toIndex = stopIds.indexOf(toStopId);
    if (fromIndex == -1 || toIndex == -1 || (toIndex - fromIndex) != 1) {
      throw Exception('Stops must be consecutive in the line');
    }

    // Check if segment already exists
    final existingSnap = await _db.collection('lines').doc(lineId).collection('segmentPrices')
        .where('fromStopId', isEqualTo: fromStopId)
        .where('toStopId', isEqualTo: toStopId)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      // Update existing segment
      final docId = existingSnap.docs.first.id;
      await _db.collection('lines').doc(lineId).collection('segmentPrices').doc(docId).update({
        'price': price,
      });
    } else {
      final ref = _db.collection('lines').doc(lineId).collection('segmentPrices').doc();
      await ref.set({
        'id': ref.id,
        'lineId': lineId,
        'fromStopId': fromStopId,
        'toStopId': toStopId,
        'price': price,
        'createdAt': Timestamp.now(),
      });
    }
  }

  static Stream<List<Map<String, dynamic>>> getSegmentPrices(String lineId) {
    return _db.collection('lines').doc(lineId).collection('segmentPrices')
        .orderBy('fromStopId')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static Future<void> updateSegmentPrice(String lineId, String segmentPriceId, Map<String, dynamic> data) async {
    // If updating stops, re-validate consecutiveness
    if (data.containsKey('fromStopId') || data.containsKey('toStopId')) {
      final fromStopId = data['fromStopId'] ?? (await _db.collection('lines').doc(lineId).collection('segmentPrices').doc(segmentPriceId).get()).data()?['fromStopId'];
      final toStopId = data['toStopId'] ?? (await _db.collection('lines').doc(lineId).collection('segmentPrices').doc(segmentPriceId).get()).data()?['toStopId'];
      final lineStops = await _db.collection('lines').doc(lineId).collection('lineStops')
          .orderBy('orderIndex')
          .get();
      final stopIds = lineStops.docs.map((d) => d.data()['stopId'] as String).toList();
      final fromIndex = stopIds.indexOf(fromStopId);
      final toIndex = stopIds.indexOf(toStopId);
      if (fromIndex == -1 || toIndex == -1 || (toIndex - fromIndex) != 1) {
        throw Exception('Stops must be consecutive in the line');
      }
    }
    await _db.collection('lines').doc(lineId).collection('segmentPrices').doc(segmentPriceId).update(data);
  }

  static Future<void> deleteSegmentPrice(String lineId, String segmentPriceId) async {
    await _db.collection('lines').doc(lineId).collection('segmentPrices').doc(segmentPriceId).delete();
  }

  // ══════════════════════════════════════
  // TRIP PRICE CALCULATION
  // ══════════════════════════════════════
  static Future<double> calculateTripPrice({
    required String lineId,
    required String departureStopId,
    required String destinationStopId,
  }) async {
    // 1. Get all stops of the line ordered by order_index
    final lineStopsSnap = await _db.collection('lines').doc(lineId).collection('lineStops')
        .orderBy('orderIndex')
        .get();
    final lineStops = lineStopsSnap.docs.map((d) => d.data()).toList();
    final stopIds = lineStops.map((ls) => ls['stopId'] as String).toList();

    // 2. Find departure and destination positions
    final departureIndex = stopIds.indexOf(departureStopId);
    final destinationIndex = stopIds.indexOf(destinationStopId);

    // 3. Ensure departure comes before destination
    if (departureIndex == -1) {
      throw Exception('Departure stop not found in line');
    }
    if (destinationIndex == -1) {
      throw Exception('Destination stop not found in line');
    }
    if (departureIndex >= destinationIndex) {
      throw Exception('Departure stop must come before destination stop');
    }

    // 4. Get all segments for the line
    final segmentsSnap = await _db.collection('lines').doc(lineId).collection('segmentPrices').get();
    final segments = segmentsSnap.docs.map((d) => d.data()).toList();

    // Create a map for quick lookup of segment prices
    final segmentPrices = <String, double>{};
    for (final segment in segments) {
      final fromStopId = segment['fromStopId'] as String;
      final toStopId = segment['toStopId'] as String;
      final price = (segment['price'] as num).toDouble();
      segmentPrices['$fromStopId-$toStopId'] = price;
    }

    // 5. Sum all segment prices between departure and destination
    double totalPrice = 0.0;
    for (int i = departureIndex; i < destinationIndex; i++) {
      final fromStopId = stopIds[i];
      final toStopId = stopIds[i + 1];
      final segmentKey = '$fromStopId-$toStopId';
      final price = segmentPrices[segmentKey];
      if (price == null) {
        throw Exception('Missing segment price for $segmentKey');
      }
      totalPrice += price;
    }

    // 6. Return total price
    return totalPrice;
  }
}
