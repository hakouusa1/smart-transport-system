import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart' as config;

class NotifyService {
  static final _db = FirebaseFirestore.instance;

  static const _supabaseUrl = config.supabaseUrl;
  static const _supabaseAnonKey = config.supabaseAnonKey;

  static Future<void> _sendPush({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/send-push'),
        headers: {
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId, 'title': title, 'body': body}),
      );
    } catch (_) {}
  }

  static Future<void> notifyDriverBooking({
    required String busId,
    required String driverId,
    required String passengerName,
    required String lineName,
  }) async {
    const title = '🎫 Nouvelle réservation';
    final body =
        '${passengerName.isNotEmpty ? passengerName : "Un passager"} a réservé une place sur $lineName';

    await _db.collection('notifications').add({
      'targetUserId': driverId,
      'type': 'booking',
      'title': title,
      'body': body,
      'busId': busId,
      'read': false,
      'createdAt': Timestamp.now(),
    });

    await _sendPush(userId: driverId, title: title, body: body);
  }

  static Future<void> notifyOwnerTripStarted({
    required String ownerId,
    required String lineName,
    required String busName,
  }) async {
    const title = '🚌 Trajet démarré';
    final body =
        '$lineName (${busName.isNotEmpty ? busName : "Bus"}) a commencé le trajet';

    await _db.collection('notifications').add({
      'targetUserId': ownerId,
      'type': 'trip_started',
      'title': title,
      'body': body,
      'read': false,
      'createdAt': Timestamp.now(),
    });

    await _sendPush(userId: ownerId, title: title, body: body);
  }

  static Future<void> notifyOwnerTripEnded({
    required String ownerId,
    required String lineName,
    required String busName,
    required double recette,
  }) async {
    final recetteText =
        recette > 0 ? '${recette.toStringAsFixed(0)} DA' : 'non renseignée';
    const title = '🏁 Trajet terminé';
    final body =
        '$lineName (${busName.isNotEmpty ? busName : "Bus"}) a terminé · Recette : $recetteText';

    await _db.collection('notifications').add({
      'targetUserId': ownerId,
      'type': 'trip_ended',
      'title': title,
      'body': body,
      'read': false,
      'createdAt': Timestamp.now(),
    });

    await _sendPush(userId: ownerId, title: title, body: body);
  }

  static Stream<QuerySnapshot> listenNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .limit(10)
        .snapshots();
  }

  static Future<void> markRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({'read': true});
  }
}
