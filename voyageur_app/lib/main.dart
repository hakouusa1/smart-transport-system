import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'widgets/notif_listener.dart';
import 'screens/login_screen.dart';
import 'screens/bus_lines_screen.dart';

import 'theme/app_theme.dart';
import 'widgets/bus_loading_indicator.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const VoyageurApp());
}

class VoyageurApp extends StatelessWidget {
  const VoyageurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Voyageur',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _checkRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return 'Compte non trouvé. Veuillez vous inscrire.';
      final role = (doc.data() as Map<String, dynamic>)['role'] ?? '';
      if (role == 'passenger') return null;
      final names = {'owner': 'propriétaire', 'driver': 'chauffeur'};
      return 'Ce compte est un compte ${names[role] ?? role}.\nVeuillez utiliser l\'application correspondante.';
    } catch (_) {
      return 'Erreur de vérification du compte.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: BusLoadingIndicator(strokeWidth: 2.5)),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) return const LoginScreen();

        return FutureBuilder<String?>(
          future: _checkRole(snapshot.data!.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: BusLoadingIndicator(strokeWidth: 2.5)),
              );
            }

            if (roleSnap.data == null) return const NotifListener(child: BusLinesScreen());

            unawaited(FirebaseAuth.instance.signOut());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(roleSnap.data!),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            });
            return const LoginScreen();
          },
        );
      },
    );
  }
}