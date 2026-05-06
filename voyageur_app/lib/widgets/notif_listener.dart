import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notify_service.dart';
import '../services/notification_service.dart';

/// Wrap your main screen with this to automatically show notifications
class NotifListener extends StatefulWidget {
  final Widget child;
  const NotifListener({super.key, required this.child});
  @override
  State<NotifListener> createState() => _NotifListenerState();
}

class _NotifListenerState extends State<NotifListener> {
  StreamSubscription? _sub;
  final _seen = <String>{};
  static const _prefsKey = 'notif_seen_ids';

  @override
  void initState() {
    super.initState();
    NotificationService.saveTokenNow();
    _loadSeenAndListen();
  }

  Future<void> _loadSeenAndListen() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    _seen.addAll(saved);
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = NotifyService.listenNotifications(uid).listen(
      (snap) async {
        final newIds = <String>[];
        for (final doc in snap.docs) {
          if (_seen.contains(doc.id)) continue;
          _seen.add(doc.id);
          newIds.add(doc.id);

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
        if (newIds.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final updated = _seen.toList();
          if (updated.length > 200) updated.removeRange(0, updated.length - 200);
          await prefs.setStringList(_prefsKey, updated);
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
