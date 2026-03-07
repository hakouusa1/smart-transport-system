import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/bus_lines_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar style
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
    return MaterialApp(
      title: 'Voyageur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _checkPassengerRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return 'Compte non trouvé. Veuillez vous inscrire.';
      }

      final data = doc.data() as Map<String, dynamic>;
      final role = data['role'] ?? '';

      if (role == 'passenger') return null;

      final roleNames = {
        'owner': 'propriétaire',
        'driver': 'chauffeur',
        'passenger': 'voyageur',
      };
      final actual = roleNames[role] ?? role;
      return 'Ce compte est un compte $actual.\nVeuillez utiliser l\'application correspondante.';
    } catch (e) {
      return 'Erreur de vérification du compte.';
    }
  }

  void _showError(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: AppTheme.primary),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<String?>(
          future: _checkPassengerRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: AppTheme.background,
                body: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }

            if (roleSnapshot.data == null) {
              return const BusLinesScreen();
            }

            final errorMsg = roleSnapshot.data!;
            FirebaseAuth.instance.signOut();
            _showError(context, errorMsg);
            return const LoginScreen();
          },
        );
      },
    );
  }
}