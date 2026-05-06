import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request FCM permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Init local notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 3. Create Android notification channel
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bus_channel',
          'Notifications Bus',
          description: 'Notifications de suivi de bus',
          importance: Importance.high,
        ),
      );
    }

    // 4. Save FCM token
    await _saveToken();
    _messaging.onTokenRefresh.listen(_saveTokenValue);

    // 5. Handle FCM messages in foreground → show as local notification
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'Chauffeur';
      final body = message.notification?.body ?? '';
      showNotification(title: title, body: body);
    });
  }

  static Future<void> saveTokenNow() => _saveToken();

  // ── Save FCM token ──
  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenValue(token);
    } catch (_) {}
  }

  static Future<void> _saveTokenValue(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'lastTokenUpdate': Timestamp.now(),
      });
    } catch (_) {}
  }

  // ── Show real notification ──
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
          'bus_channel',
          'Notifications Bus',
          channelDescription: 'Notifications de suivi de bus',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancel(int id) async {
    await _local.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _local.cancelAll();
  }
}
