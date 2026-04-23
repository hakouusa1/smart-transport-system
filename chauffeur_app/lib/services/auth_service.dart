import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Current user UID
  String get uid => _auth.currentUser?.uid ?? '';

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email & password (checks role = "driver")
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user;
      if (user == null) throw 'Erreur de connexion.';

      // Check role
      final userDoc = await _usersCollection.doc(user.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw 'Compte non trouvé. Veuillez contacter le propriétaire.';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] ?? '';

      if (role != 'driver') {
        await _auth.signOut();
        final roleNames = {
          'owner': 'propriétaire',
          'driver': 'chauffeur',
          'passenger': 'voyageur',
        };
        final actual = roleNames[role] ?? role;
        throw 'Ce compte est un compte $actual.\n'
            'Veuillez utiliser l\'application correspondante.';
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    }
  }

  /// Sign out — removes FCM token so this device stops receiving notifications
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _usersCollection.doc(uid).update({'fcmToken': FieldValue.delete()});
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await _auth.signOut();
  }

  /// French error messages
  String _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-email':
        return 'Format d\'email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      default:
        return 'Erreur de connexion. Veuillez réessayer.';
    }
  }
}