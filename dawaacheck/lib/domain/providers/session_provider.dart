import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_session_service.dart';
import 'auth_provider.dart';

/// Who the app is acting for — whether that identity came from Firebase or
/// from a device-local guest session.
///
/// Screens should read [sessionProvider] rather than [authStateProvider], so
/// that a local guest is treated as a real user of the on-device features.
class AppSession {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// True when the session exists only on this device. There is no cloud
  /// account behind it, so server-side work is skipped rather than attempted.
  final bool isLocal;

  const AppSession({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.isLocal = false,
  });

  factory AppSession.fromFirebase(User user) => AppSession(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );

  factory AppSession.local(String id) => AppSession(uid: id, isLocal: true);
}

final localSessionServiceProvider =
    Provider<LocalSessionService>((ref) => const LocalSessionService());

/// The device-local guest id, restored from disk on startup.
///
/// Held as an [AsyncValue] so [sessionProvider] can tell "still reading disk"
/// apart from "no local session", which stops the router bouncing a restored
/// guest to /welcome on a cold start.
class LocalGuestNotifier extends StateNotifier<AsyncValue<String?>> {
  LocalGuestNotifier(this._service) : super(const AsyncValue.loading()) {
    _restore();
  }

  final LocalSessionService _service;

  Future<void> _restore() async {
    try {
      final id = await _service.currentGuestId();
      if (mounted) state = AsyncValue.data(id);
    } catch (e, s) {
      // A failed read means "no local session", not a broken app.
      if (mounted) state = AsyncValue<String?>.error(e, s);
    }
  }

  Future<String> start() async {
    final id = await _service.startGuestSession();
    if (mounted) state = AsyncValue.data(id);
    return id;
  }

  Future<void> end() async {
    await _service.endGuestSession();
    if (mounted) state = const AsyncValue.data(null);
  }
}

final localGuestProvider =
    StateNotifierProvider<LocalGuestNotifier, AsyncValue<String?>>((ref) {
  return LocalGuestNotifier(ref.watch(localSessionServiceProvider));
});

/// The active session: Firebase first, device-local guest as fallback.
final sessionProvider = Provider<AsyncValue<AppSession?>>((ref) {
  final auth = ref.watch(authStateProvider);
  final guest = ref.watch(localGuestProvider);

  // Both sources must settle before reporting "no session", or the router
  // redirects to /welcome in the gap before either one has resolved.
  if (auth.isLoading || guest.isLoading) {
    return const AsyncValue<AppSession?>.loading();
  }

  final user = auth.valueOrNull;
  if (user != null) return AsyncValue.data(AppSession.fromFirebase(user));

  final guestId = guest.valueOrNull;
  if (guestId != null) return AsyncValue.data(AppSession.local(guestId));

  return const AsyncValue<AppSession?>.data(null);
});
