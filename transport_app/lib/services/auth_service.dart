import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? '';
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════════
  // REGISTER — status starts as 'pending'
  // ══════════════════════════════════════
  Future<User?> register({
    required String email,
    required String password,
    required String displayName,
    String phone = '',
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      final user = result.user;
      if (user == null) throw 'Erreur lors de la création du compte.';

      await _users.doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'displayName': displayName.trim(),
        'phone': phone.trim(),
        'role': 'owner',
        'status': 'active',
        'subscription': 'none',       // ← no plan yet
        'createdAt': Timestamp.now(),
        'trialEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    }
  }

  // ══════════════════════════════════════
  // SIGN IN — checks role only (status checked in AuthWrapper)
  // ══════════════════════════════════════
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      final user = result.user;
      if (user == null) throw 'Erreur de connexion.';

      final doc = await _users.doc(user.uid).get();
      if (!doc.exists) { await _auth.signOut(); throw 'Compte non trouvé.'; }

      final data = doc.data() as Map<String, dynamic>;
      if (data['role'] != 'owner') {
        await _auth.signOut();
        throw 'Ce compte n\'est pas un compte propriétaire.';
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    }
  }

  // ══════════════════════════════════════
  // GET USER STATUS (stream for real-time)
  // ══════════════════════════════════════
  Stream<Map<String, dynamic>?> getUserData() {
    if (uid.isEmpty) return Stream.value(null);
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    });
  }

  Future<void> signOut() async => await _auth.signOut();

  String _handleError(String code) {
    switch (code) {
      case 'user-not-found': return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password': return 'Mot de passe incorrect.';
      case 'invalid-email': return 'Format d\'email invalide.';
      case 'user-disabled': return 'Ce compte a été désactivé.';
      case 'too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
      case 'invalid-credential': return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use': return 'Cet email est déjà utilisé.';
      case 'weak-password': return 'Mot de passe trop faible.';
      default: return 'Erreur. Veuillez réessayer.';
    }
  }
}