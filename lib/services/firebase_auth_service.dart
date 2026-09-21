import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google authentication is intentionally kept separate from Appwrite.
/// Appwrite remains responsible for email/password and username accounts.
class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => Firebase.apps.isEmpty ? null : _auth.currentUser;

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }

  Future<User> signInWithGoogle() async {
    try {
      await initialize();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const FirebaseGoogleAuthException('CANCELLED');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw const FirebaseGoogleAuthException('NO_USER');
      return user;
    } on FirebaseAuthException catch (error) {
      throw FirebaseGoogleAuthException('FIREBASE_${error.code}');
    } on PlatformException catch (error) {
      throw FirebaseGoogleAuthException('GOOGLE_${error.code}_${error.message ?? ''}'.trim());
    }
  }

  Future<void> signOut() async {
    await Future.wait<void>([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) await user.updateDisplayName(name.trim());
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    await _googleSignIn.signOut();
  }
}

class FirebaseGoogleAuthException implements Exception {
  final String code;
  const FirebaseGoogleAuthException(this.code);
}
