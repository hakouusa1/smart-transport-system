import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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

  // ============================================
  // REGISTER (role = "passenger")
  // ============================================
  Future<User?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user;
      if (user == null) throw 'Erreur lors de la création du compte.';

      // Save user with role "passenger" in Firestore
      final appUser = AppUser(
        uid: user.uid,
        email: email.trim(),
        role: 'passenger',
        displayName: displayName.trim(),
      );

      await _usersCollection.doc(user.uid).set(appUser.toMap());

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    }
  }

  // ============================================
  // SIGN IN (verify role = "passenger")
  // ============================================
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
        throw 'Compte non trouvé. Veuillez vous inscrire.';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] ?? '';

      if (role != 'passenger') {
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

  /// Sign out
  Future<void> signOut() async {
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
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé par un autre compte.';
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      default:
        return 'Erreur. Veuillez réessayer.';
    }
  }
}
