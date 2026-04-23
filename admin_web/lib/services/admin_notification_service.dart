import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  static final _db = FirebaseFirestore.instance;

  static Stream<int> getPendingOwnersCount() {
    return getPendingSubscriptionsCount();
  }

  static Stream<int> getPendingSubscriptionsCount() {
    return _db.collection('users')
        .where(Filter.and(
          Filter('role', isEqualTo: 'owner'),
          Filter.or(
            Filter('status', isEqualTo: 'pending'),
            Filter('subscriptionStatus', isEqualTo: 'pending_verification'),
          ),
        ))
        .snapshots()
        .map((s) => s.size);
  }

  static Stream<int> getPendingBusesCount() {
    return _db.collection('buses')
        .where('validationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.size);
  }

  static Stream<Map<String, int>> getAllPendingCounts() {
    return _db.collection('users')
        .where('role', isEqualTo: 'owner')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((ownersSnap) async {
      final busesSnap = await _db.collection('buses')
          .where('validationStatus', isEqualTo: 'pending')
          .get();
      return {
        'owners': ownersSnap.size,
        'buses': busesSnap.size,
      };
    });
  }
}
