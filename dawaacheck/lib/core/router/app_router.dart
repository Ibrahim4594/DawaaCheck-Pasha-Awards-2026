import 'package:animations/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/scan_result_model.dart';
import '../../data/models/recall_alert_model.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/session_provider.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/sign_in_screen.dart';
import '../../presentation/screens/auth/sign_up_screen.dart';
import '../../presentation/screens/auth/welcome_screen.dart';
import '../../presentation/screens/onboarding/splash_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/scan/scan_camera_screen.dart';
import '../../presentation/screens/scan/scan_processing_screen.dart';
import '../../presentation/screens/results/result_verified_screen.dart';
import '../../presentation/screens/results/result_danger_screen.dart';
import '../../presentation/screens/results/result_unverified_screen.dart';
import '../../presentation/screens/history/scan_history_screen.dart';
import '../../presentation/screens/history/scan_history_detail_screen.dart';
import '../../presentation/screens/recalls/recalls_screen.dart';
import '../../presentation/screens/recalls/recall_detail_screen.dart';
import '../../presentation/screens/map/safety_map_screen.dart';
import '../../presentation/screens/terminal/agent_terminal_screen.dart';
import '../../presentation/screens/adr/adr_report_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/widgets/common/app_shell.dart';

/// Notifier that triggers GoRouter redirect re-evaluation when the session
/// changes. This avoids recreating the entire GoRouter on every auth change.
///
/// Both sources are watched: Firebase auth, and the device-local guest
/// session that guest mode falls back to when Firebase is unreachable.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(localGuestProvider, (_, _) => notifyListeners());
  }
}

final _authChangeNotifierProvider = Provider<_AuthChangeNotifier>((ref) {
  return _AuthChangeNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);

      // Don't redirect while the session is still resolving
      if (session.isLoading) return null;

      // A device-local guest counts as signed in — see LocalSessionService.
      final isLoggedIn = session.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      if (!isLoggedIn && !isAuthRoute) return '/welcome';
      if (isLoggedIn && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      // ── Onboarding flow: cinematic sequence ──────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WelcomeScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      ),

      // ── Auth screens: intentional slide+fade from right ─────────
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignInScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(begin: const Offset(0.25, 0.0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/sign-up',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignUpScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(begin: const Offset(0.25, 0.0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),

      // Shell route with bottom navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const ScanHistoryScreen(),
            routes: [
              GoRoute(
                path: ':scanId',
                builder: (context, state) {
                  final result = state.extra as ScanResultModel?;
                  return ScanHistoryDetailScreen(
                    scanId: state.pathParameters['scanId']!,
                    result: result,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/recalls',
            builder: (context, state) => const RecallsScreen(),
            routes: [
              GoRoute(
                path: ':recallId',
                builder: (context, state) => RecallDetailScreen(
                  recallId: state.pathParameters['recallId']!,
                  recall: state.extra as RecallAlertModel?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const AgentTerminalScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const SafetyMapScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Outside shell (no bottom nav) — slide up like a modal
      GoRoute(
        path: '/scan',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ScanCameraScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/scan/processing',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ScanProcessingScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
        ),
      ),
      // ── Result screens: dramatic reveals with easeOutExpo ────────
      GoRoute(
        path: '/result/verified',
        pageBuilder: (context, state) {
          final result = state.extra as ScanResultModel?;
          if (result == null) return CustomTransitionPage(key: state.pageKey, child: Scaffold(body: Center(child: Text('scanResultNotFound'.tr()))), transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c));
          return CustomTransitionPage(
            key: state.pageKey,
            child: ResultVerifiedScreen(result: result),
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
                  ),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result/danger',
        pageBuilder: (context, state) {
          final result = state.extra as ScanResultModel?;
          if (result == null) return CustomTransitionPage(key: state.pageKey, child: Scaffold(body: Center(child: Text('scanResultNotFound'.tr()))), transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c));
          return CustomTransitionPage(
            key: state.pageKey,
            child: ResultDangerScreen(result: result),
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Danger: slightly longer + heavier scale for gravity
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.90, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
                  ),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result/unverified',
        pageBuilder: (context, state) {
          final result = state.extra as ScanResultModel?;
          if (result == null) return CustomTransitionPage(key: state.pageKey, child: Scaffold(body: Center(child: Text('scanResultNotFound'.tr()))), transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c));
          return CustomTransitionPage(
            key: state.pageKey,
            child: ResultUnverifiedScreen(result: result),
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Unverified: fade-through — cautious, neutral
              return FadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/adr',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String?>?;
          return CustomTransitionPage(
            child: ADRReportScreen(
              medicineName: extra?['medicine_name'],
              batchNumber: extra?['batch_number'],
            ),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slide,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
          );
        },
      ),
    ],
  );
});
