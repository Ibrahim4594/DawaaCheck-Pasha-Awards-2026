import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dawaacheck/data/services/local_session_service.dart';

/// The repository ships placeholder Firebase config, so guest mode falls back
/// to a device-local session. That fallback is the path anyone cloning this
/// repo hits first — if it breaks, the app is unusable from the welcome screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = LocalSessionService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reports no session before guest mode is entered', () async {
    expect(await service.currentGuestId(), isNull);
  });

  test('starting a session produces an id that is then readable', () async {
    final id = await service.startGuestSession();

    expect(id, isNotEmpty);
    expect(await service.currentGuestId(), id);
  });

  test('restarting reuses the same id so local history survives', () async {
    final first = await service.startGuestSession();
    final second = await service.startGuestSession();

    expect(second, first);
  });

  test('ending a session clears it', () async {
    await service.startGuestSession();
    await service.endGuestSession();

    expect(await service.currentGuestId(), isNull);
  });

  test('a blank stored value counts as no session', () async {
    SharedPreferences.setMockInitialValues({'local_guest_session_id': ''});

    expect(await service.currentGuestId(), isNull);
  });

  test('ending a session that never started is a no-op', () async {
    await service.endGuestSession();

    expect(await service.currentGuestId(), isNull);
  });
}
