import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart';
import '../l10n/app_localizations.dart';
import '../locale_notifier.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? '';
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AppLocalizations get _tr => AppLocalizations(localeNotifier.value);

  // ============================================
  // REGISTER — sends email verification
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

  // Sends verification email — called separately so Firestore errors can't suppress it
  Future<void> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _tr.authError(e.code);
    } catch (e) {
      throw _tr.errGeneric;
    }
  }

  // ============================================
  // SIGN IN — checks role + email verification
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

  // ============================================
  // GOOGLE SIGN IN
  // ============================================
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
      if (user == null) throw _tr.errGeneric;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] ?? '';
        if (role != 'passenger') {
          await _auth.signOut();
          throw _tr.roleError(_tr.roleName(role));
        }
      } else {
        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          role: 'passenger',
          displayName: user.displayName ?? '',
        );
        await _usersCollection.doc(user.uid).set(appUser.toMap());
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _tr.authError(e.code);
    }
  }

  // ============================================
  // APPLE SIGN IN (iOS/macOS only)
  // ============================================
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
      if (user == null) throw _tr.errGeneric;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] ?? '';
        if (role != 'passenger') {
          await _auth.signOut();
          throw _tr.roleError(_tr.roleName(role));
        }
      } else {
        final nameParts = '${appleCredential.givenName?.trim() ?? ''} ${appleCredential.familyName?.trim() ?? ''}'.trim();
        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? appleCredential.email ?? '',
          role: 'passenger',
          displayName: nameParts.isNotEmpty ? nameParts : (user.displayName ?? ''),
        );
        await _usersCollection.doc(user.uid).set(appUser.toMap());
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _tr.authError(e.code);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw _tr.errGeneric;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
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
