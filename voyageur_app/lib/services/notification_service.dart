import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize FCM + local notifications
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init local notifications (for foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create notification channel (Android)
    const channel = AndroidNotificationChannel(
      'bus_tracking',
      'Suivi de bus',
      description: 'Notifications de suivi de bus en temps réel',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Save FCM token
    await _saveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) => _saveTokenValue(token));

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(
        title: message.notification?.title ?? 'Bus Voyageur',
        body: message.notification?.body ?? '',
      );
    });
  }

  static Future<void> saveTokenNow() => _saveToken();

  /// Save FCM token to Firestore
  static Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenValue(token);
  }

  static Future<void> _saveTokenValue(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
      'lastTokenUpdate': Timestamp.now(),
    });
  }

  /// Show a local notification (for foreground + ETA alerts)
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await _showLocalNotification(title: title, body: body, id: id);
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bus_tracking',
      'Suivi de bus',
      channelDescription: 'Notifications de suivi de bus en temps réel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(id, title, body, details);
  }

  /// Cancel a notification by id
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
