import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/auth_repository.dart';
import 'session_provider.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  try {
    return AuthRepository();
  } catch (_) {
    // Firebase not initialized — running in preview mode
    return null;
  }
});

final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.authStateChanges;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

/// Whether Firebase is available (false in preview mode)
final isFirebaseAvailable = Provider<bool>((ref) {
  return ref.watch(authRepositoryProvider) != null;
});

class AuthState {
  final bool isLoading;
  final String? error;
  final User? user;

  const AuthState({this.isLoading = false, this.error, this.user});

  AuthState copyWith({bool? isLoading, String? error, User? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository? _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState());

  bool get _isPreviewMode => _repo == null;

  Future<bool> signInWithGoogle() async {
    if (_isPreviewMode) {
      state = state.copyWith(isLoading: false, error: 'Firebase not configured');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo!.signInWithGoogle();
      state = state.copyWith(isLoading: false, user: user);
      if (user != null) {
        NotificationService().showWelcomeNotification(user.displayName ?? 'there');
      }
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isPreviewMode) {
      state = state.copyWith(isLoading: false, error: 'Firebase not configured');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo!.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user);
      if (user != null) {
        NotificationService().showWelcomeNotification(user.displayName ?? name);
      }
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_isPreviewMode) {
      state = state.copyWith(isLoading: false, error: 'Firebase not configured');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo!.signInWithEmail(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user);
      if (user != null) {
        NotificationService().showWelcomeNotification(user.displayName ?? 'there');
      }
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> continueAsGuest() async {
    state = state.copyWith(isLoading: true, error: null);

    // Firebase anonymous auth is the real path.
    if (!_isPreviewMode) {
      try {
        final user = await _repo!.continueAsGuest();
        if (user != null) {
          state = state.copyWith(isLoading: false, user: user);
          NotificationService().showWelcomeNotification('Guest');
          return true;
        }
      } catch (e) {
        debugPrint('Firebase guest sign-in failed, using local session: $e');
      }
    }

    // No reachable Firebase project — placeholder config, offline, or
    // anonymous auth disabled on the project. Fall back to a device-local
    // session so the app stays usable. See LocalSessionService for exactly
    // what a local session does and does not grant.
    try {
      await _ref.read(localGuestProvider.notifier).start();
      state = state.copyWith(isLoading: false);
      NotificationService().showWelcomeNotification('Guest');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    if (_isPreviewMode) {
      state = state.copyWith(isLoading: false, error: 'Firebase not configured');
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo!.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateDisplayName(String name) async {
    if (_isPreviewMode) return false;
    try {
      await _repo!.updateDisplayName(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _repo?.signOut();
    } catch (e) {
      // Firebase sign-out can fail when the project is unreachable. The local
      // session below still has to be cleared, or the user stays signed in.
      debugPrint('Firebase sign-out failed: $e');
    }
    await _ref.read(localGuestProvider.notifier).end();
    state = const AuthState();
  }
}
