import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? '';
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════════
  // REGISTER — sends email verification
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
        'subscription': 'none',
        'createdAt': Timestamp.now(),
        'trialEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    }
  }

  // Sends verification email — called separately so Firestore errors can't suppress it
  Future<void> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    } catch (e) {
      throw 'Impossible d\'envoyer l\'email de vérification: $e';
    }
  }

  // ══════════════════════════════════════
  // SIGN IN — checks role + email verification
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
  // GOOGLE SIGN IN
  // Requires SHA-1 fingerprint in Firebase console (Android)
  // and REVERSED_CLIENT_ID in Info.plist (iOS)
  // ══════════════════════════════════════
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw 'Erreur de connexion avec Google.';

      final doc = await _users.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] != 'owner') {
          await _auth.signOut();
          throw 'Ce compte Google n\'est pas un compte propriétaire.';
        }
      } else {
        await _users.doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'phone': '',
          'role': 'owner',
          'status': 'active',
          'subscription': 'none',
          'createdAt': Timestamp.now(),
          'trialEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    }
  }

  // ══════════════════════════════════════
  // APPLE SIGN IN (iOS/macOS only)
  // ══════════════════════════════════════
  Future<User?> signInWithApple() async {
    try {
      final nonce = _generateNonce();
      final hashedNonce = _sha256ofString(nonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: nonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;
      if (user == null) throw 'Erreur de connexion avec Apple.';

      final doc = await _users.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] != 'owner') {
          await _auth.signOut();
          throw 'Ce compte Apple n\'est pas un compte propriétaire.';
        }
      } else {
        final nameParts = '${appleCredential.givenName?.trim() ?? ''} ${appleCredential.familyName?.trim() ?? ''}'.trim();
        await _users.doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? appleCredential.email ?? '',
          'displayName': nameParts.isNotEmpty ? nameParts : 'Propriétaire',
          'phone': '',
          'role': 'owner',
          'status': 'active',
          'subscription': 'none',
          'createdAt': Timestamp.now(),
          'trialEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e.code);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw 'Erreur Apple Sign-In: ${e.message}';
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

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

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

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
