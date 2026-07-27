import 'package:shared_preferences/shared_preferences.dart';

/// Device-local guest session.
///
/// Guest mode normally goes through Firebase anonymous auth. This repository
/// ships placeholder Firebase config (see README, "Firebase"), so a fresh clone
/// has no project to authenticate against — and someone who clones, builds and
/// taps "Continue as guest" would otherwise be stranded on the welcome screen.
///
/// When Firebase cannot be reached, guest mode falls back to a session stored
/// on the device. It unlocks everything that runs locally: scanning, scan
/// history, the medicine cabinet, recalls, the safety map. It grants nothing
/// that needs a real account — cloud sync and push registration are skipped,
/// because there is no authenticated identity to attach them to.
///
/// The id is stable across restarts so local scan history survives one.
class LocalSessionService {
  static const _guestIdKey = 'local_guest_session_id';
  static const _idPrefix = 'local-guest-';

  const LocalSessionService();

  /// The active local guest id, or null when no local session exists.
  Future<String?> currentGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_guestIdKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Starts a local session, reusing the existing id when there is one.
  Future<String> startGuestSession() async {
    final existing = await currentGuestId();
    if (existing != null) return existing;

    final prefs = await SharedPreferences.getInstance();
    final id =
        '$_idPrefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await prefs.setString(_guestIdKey, id);
    return id;
  }

  Future<void> endGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestIdKey);
  }
}
