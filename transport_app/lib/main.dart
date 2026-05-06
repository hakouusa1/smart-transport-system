import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

import 'screens/subscription_screen.dart';
import 'theme_notifier.dart';
import 'locale_notifier.dart';
import 'l10n/app_localizations.dart';
import 'screens/pending_screen.dart';
import 'services/supabase_storage_service.dart';
import 'services/notification_service.dart';
import 'widgets/notif_listener.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/bus_loading_indicator.dart';
import 'app_settings_notifier.dart';

// Must be a top-level function — runs in a separate isolate when the app is killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // flutter_local_notifications cannot be used here (no UI context).
  // FCM will display the notification automatically via the system tray.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('fr', null),
    initializeDateFormatting('en', null),
    initializeDateFormatting('ar', null),
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: SupabaseStorageService.supabaseUrl,
    anonKey: SupabaseStorageService.supabaseAnonKey,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();
  await appSettingsNotifier.load();
  runApp(const TransporteurApp());
}

class TransporteurApp extends StatelessWidget {
  const TransporteurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: 'Transporteur',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AuthWrapper(),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: BusLoadingIndicator()));
        }

        // Not logged in → login screen
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginScreen();
        }

        // Logged in → check status in Firestore
        final user = authSnap.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: BusLoadingIndicator()));
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              // User doc doesn't exist — sign out
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final data = userSnap.data!.data() as Map<String, dynamic>;
            final role = data['role'] ?? '';

            // Wrong role — sign out
            if (role != 'owner') {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final subscriptionStatus = data['subscriptionStatus'] ?? '';
            final subscription = data['subscription'] ?? 'starter';
            final expiresAt = data['subscriptionExpiresAt'] as Timestamp?;
            final isExpired = expiresAt != null && expiresAt.toDate().isBefore(DateTime.now());
            final trialEnd = data['trialEnd'] as Timestamp?;
            final isTrialActive = trialEnd != null && trialEnd.toDate().isAfter(DateTime.now());

            // Subscription expired → mark inactive and send to pending
            if (isExpired && subscriptionStatus == 'active') {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'subscriptionStatus': 'inactive'});
              return const PendingApprovalScreen();
            }

            // Active subscription → dashboard
            if (subscriptionStatus == 'active') {
              return const NotifListener(child: MainScreen());
            }

            // Pending verification → attend page
            if (subscriptionStatus == 'pending_verification') {
              return SubscriptionScreen(initialPlanId: subscription, initialStatus: 'pending_verification');
            }

            // Trial still running → dashboard
            if (isTrialActive) {
              return const NotifListener(child: MainScreen());
            }

            // Trial ended / no active subscription → pending page
            return const PendingApprovalScreen();
          },
        );
      },
    );
  }
}