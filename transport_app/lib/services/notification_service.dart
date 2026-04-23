import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId   = 'transport_alerts';
  static const _channelName = 'Alertes Transport';
  static const _channelDesc = 'Alertes assurance, vidange et maintenance';

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request FCM permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Init local notifications plugin
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 3. Create high-importance Android channel (required for heads-up popups)
    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
        ),
      );
    }

    // 4. Save FCM token to Firestore + Supabase on init and on refresh
    await _saveToken();
    _messaging.onTokenRefresh.listen(_saveTokenValue);

    // 5. Show local notification for FCM messages received in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'Transport';
      final body  = message.notification?.body  ?? '';
      showNotification(title: title, body: body);
    });
  }

  static Future<void> saveTokenNow() => _saveToken();

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenValue(token);
    } catch (_) {}
  }

  static Future<void> _saveTokenValue(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Firestore — keeps existing behaviour for in-app listeners
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'lastTokenUpdate': Timestamp.now(),
      });
    } catch (_) {}

    // Supabase fcm_tokens table — queried by the Edge Function when sending push
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id':    uid,
        'fcm_token':  token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancel(int id) async => _local.cancel(id);
  static Future<void> cancelAll() async    => _local.cancelAll();
}
