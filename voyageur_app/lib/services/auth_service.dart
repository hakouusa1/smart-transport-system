import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../l10n/app_localizations.dart';
import '../locale_notifier.dart';

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

  // Helper to get current translations
  AppLocalizations get _tr => AppLocalizations(localeNotifier.value);

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
      if (user == null) throw _tr.errGeneric;

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
      throw _tr.authError(e.code);
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
      if (user == null) throw _tr.errGeneric;

      // Check role
      final userDoc = await _usersCollection.doc(user.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw _tr.accountNotFound;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] ?? '';

      if (role != 'passenger') {
        await _auth.signOut();
        throw _tr.roleError(_tr.roleName(role));
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _tr.authError(e.code);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
