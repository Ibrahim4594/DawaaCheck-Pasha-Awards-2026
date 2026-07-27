import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'core/constants/api_constants.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'domain/providers/notification_provider.dart';
import 'domain/providers/theme_provider.dart';

/// Whether Firebase initialised. False when this repository's placeholder
/// config has not been replaced — see README, "Firebase".
bool _firebaseReady = false;

/// Registers for push in the background. Failure here is not fatal: the app
/// simply runs without notifications.
Future<void> _startPushNotifications() async {
  try {
    await NotificationService().initialize();
    await NotificationService().checkScanInactivity();
  } catch (e) {
    debugPrint('Push notifications unavailable: $e');
  }
}

void main() {
  // Every call that touches Flutter (bindings, init, runApp) must run in the
  // SAME zone — mixing the root zone with `runZonedGuarded`'s inner zone
  // triggers the `Zone mismatch` assertion (harmless but noisy). Moving
  // `WidgetsFlutterBinding.ensureInitialized()` and all awaits inside the
  // guarded zone keeps Flutter happy and still catches async errors.
  runZonedGuarded<Future<void>>(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    // Preserve native splash until Flutter is fully loaded (skip on web)
    if (!kIsWeb) {
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    }
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Firebase is optional. This repository ships placeholder Firebase config
    // (see README, "Firebase"), so a fresh clone must boot without real
    // credentials. When init fails, accounts, push and Crashlytics are off;
    // scanning, history, recalls and the map all still work, and guest mode
    // falls back to a device-local session.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
    } catch (e, s) {
      debugPrint('Firebase unavailable — running without accounts or push: $e\n$s');
    }

    if (_firebaseReady) {
      // Initialize Crashlytics — catch all Flutter and async errors in release
      if (!kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      // Register background message handler before any FCM interaction
      // (skip on web — FCM requires a service worker)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);

        // Deliberately not awaited. Push registration must never gate the
        // first frame: getToken() blocks for ~40s against a project it cannot
        // reach — placeholder Firebase config, no network, or FCM disabled —
        // and the user would stare at an empty window the whole time.
        unawaited(_startPushNotifications());
      }
    }

    try {
      // Bounded: on a dead or unreachable network this would otherwise stall
      // startup. Timing out just means reference lookups degrade, which the
      // repositories already handle.
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      ).timeout(const Duration(seconds: 8));
    } catch (e, s) {
      // App will work in offline/degraded mode if Supabase init fails.
      // Log to Crashlytics in release so we see how often this happens.
      if (!kDebugMode && _firebaseReady) {
        FirebaseCrashlytics.instance.recordError(e, s, fatal: false);
      } else {
        debugPrint('Supabase init failed: $e');
      }
    }

    // Reset saved locale if it's no longer supported (removed Balochi/Sindhi/etc.)
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.contains('locale') || key.contains('Locale')) {
        final val = prefs.getString(key);
        if (val != null && !val.contains('en') && !val.contains('ur')) {
          await prefs.remove(key);
        }
      }
    }

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('ur'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        child: const ProviderScope(child: DawaaCheckApp()),
      ),
    );
  }, (error, stack) {
    // Crashlytics is only usable when Firebase actually initialised.
    if (!kDebugMode && _firebaseReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    } else {
      debugPrint('Uncaught zone error: $error\n$stack');
    }
  });
}

/// Global scroll behavior: hard stop at edges (no bounce/overscroll) on all platforms.
class _ClampingScrollBehavior extends ScrollBehavior {
  const _ClampingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// Fallback for locales not natively supported by Flutter Material (e.g. bal, sd, ps).
class _FallbackLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class _FallbackCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}

class DawaaCheckApp extends ConsumerWidget {
  const DawaaCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Sync FCM token to Supabase whenever user auth state changes
    ref.watch(fcmTokenSyncProvider);

    return MaterialApp.router(
      title: 'DawaaCheck',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scrollBehavior: const _ClampingScrollBehavior(),
      routerConfig: router,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        const _FallbackLocalizationsDelegate(),
        const _FallbackCupertinoDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...context.localizationDelegates,
      ],
    );
  }
}
