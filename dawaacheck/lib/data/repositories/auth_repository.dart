import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/app_exceptions.dart';
import '../datasources/remote/supabase_service.dart';

/// Authentication repository wrapping Firebase Auth
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;
  final SupabaseService _supabase = SupabaseService();

  /// Web client id from your own Firebase project — Authentication →
  /// Sign-in method → Google → Web SDK configuration. Supply it at build time:
  ///
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_ID.apps.googleusercontent.com
  ///
  /// Left empty, Google Sign-In is unavailable and the other sign-in routes —
  /// email/password and guest — are used instead.
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  GoogleSignIn get _google => _googleSignIn ??= GoogleSignIn(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase signInWithPopup directly
        final provider = GoogleAuthProvider();
        final result = await _auth.signInWithPopup(provider);
        await _syncUserToSupabase(result.user);
        return result.user;
      } else {
        // On mobile, use google_sign_in package
        final googleUser = await _google.signIn();
        if (googleUser == null) return null;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final result = await _auth.signInWithCredential(credential);
        await _syncUserToSupabase(result.user);
        return result.user;
      }
    } catch (e) {
      throw AuthException(e.toString(), code: 'google-sign-in-failed');
    }
  }

  Future<User?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user?.updateDisplayName(name);
      await result.user?.reload();
      await _syncUserToSupabase(_auth.currentUser);
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign up failed', code: e.code);
    }
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _syncUserToSupabase(result.user);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign in failed', code: e.code);
    }
  }

  Future<User?> continueAsGuest() async {
    try {
      final result = await _auth.signInAnonymously();
      await _syncUserToSupabase(result.user, isAnonymous: true);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Guest sign-in failed', code: e.code);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Password reset failed', code: e.code);
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Google sign-out may fail if user didn't sign in with Google — ignore
    }
    await _auth.signOut();
  }

  Future<void> _syncUserToSupabase(User? user, {bool isAnonymous = false}) async {
    if (user == null) return;
    try {
      await _supabase.upsertUser({
        'id': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'is_anonymous': isAnonymous,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Supabase not configured yet — skip sync silently
    }
  }
}
