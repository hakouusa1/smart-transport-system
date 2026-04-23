import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/admin_shell_page.dart';
import 'screens/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't await — start Firebase in background and show UI immediately
  final firebaseReady = Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(AdminApp(firebaseReady: firebaseReady));
}

class AdminApp extends StatelessWidget {
  final Future<FirebaseApp> firebaseReady;
  const AdminApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin - Transport System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: FutureBuilder(
        future: firebaseReady,
        builder: (_, firebaseSnap) {
          // Show login screen immediately while Firebase initializes in background
          if (firebaseSnap.connectionState != ConnectionState.done) {
              return const AdminLoginPage();
          }
          // Firebase ready — now check auth state
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (_, authSnap) {
              if (authSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoginPage();
              }
              if (authSnap.hasData) return const AdminShell();
                return const AdminLoginPage();
            },
          );
        },
      ),
    );
  }
}