import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notify_service.dart';
import '../services/notification_service.dart';

/// Wrap your main screen with this to automatically show notifications
/// Usage: NotificationListener(child: YourMainScreen())
class NotifListener extends StatefulWidget {
  final Widget child;
  const NotifListener({super.key, required this.child});
  @override
  State<NotifListener> createState() => _NotifListenerState();
}

class _NotifListenerState extends State<NotifListener> {
  StreamSubscription? _sub;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    NotificationService.saveTokenNow();
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = NotifyService.listenNotifications(uid).listen(
      (snap) {
        for (final doc in snap.docs) {
          if (_seen.contains(doc.id)) continue;
          _seen.add(doc.id);

          final data = doc.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'Notification';
          final body = data['body'] ?? '';

          NotificationService.showNotification(
            title: title,
            body: body,
            id: doc.id.hashCode.abs() % 100000,
          );

          NotifyService.markRead(doc.id);
        }
      },
      onError: (e) => debugPrint('[NotifListener] stream error: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
