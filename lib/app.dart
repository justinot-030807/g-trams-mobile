import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/auth/views/account_deactivated_screen.dart';
import 'package:gtrams_mobile/features/auth/views/biometric_lock_screen.dart';
import 'package:gtrams_mobile/features/auth/views/forgot_password_screen.dart';
import 'package:gtrams_mobile/features/auth/views/login_screen.dart';
import 'package:gtrams_mobile/features/auth/views/register_screen.dart';
import 'package:gtrams_mobile/features/onboarding/views/onboarding_screen.dart';
import 'package:gtrams_mobile/features/shell/views/mobile_shell_screen.dart';
import 'package:gtrams_mobile/features/splash/views/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/biometric-lock',
        builder: (context, state) => const BiometricLockScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null;
          return RegisterScreen(
            prefillName: extra?['prefillName']?.toString(),
            prefillContact: extra?['prefillContact']?.toString(),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/account-deactivated',
        builder: (context, state) {
          final args = state.extra is DeactivatedAccountArgs
              ? state.extra as DeactivatedAccountArgs
              : const DeactivatedAccountArgs(contact: '');
          return AccountDeactivatedScreen(args: args);
        },
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => switch (ref.read(authControllerProvider).status) {
          AuthStatus.unknown => '/splash',
          AuthStatus.unauthenticated => '/login',
          AuthStatus.biometricLocked => '/biometric-lock',
          AuthStatus.authenticated => null,
        },
        builder: (context, state) => const MobileShellScreen(),
      ),
    ],
  );
});

class GtramsMobileApp extends ConsumerStatefulWidget {
  const GtramsMobileApp({super.key});

  @override
  ConsumerState<GtramsMobileApp> createState() => _GtramsMobileAppState();
}

class _GtramsMobileAppState extends ConsumerState<GtramsMobileApp> {
  late final AppLifecycleListener _lifecycle;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () => _paused = true,
      onResume: _onResume,
    );
  }

  void _onResume() {
    if (!_paused) return;
    _paused = false;
    final auth = ref.read(authControllerProvider.notifier);
    final prefs = ref.read(appPreferencesProvider);
    if (!kIsWeb && prefs.biometricEnabled && auth.lockOnResume()) {
      // Keep the shell and in-progress document work underneath the lock.
      unawaited(ref.read(appRouterProvider).push<void>('/biometric-lock'));
    } else {
      unawaited(auth.revalidateOfflineSession());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final router = ref.watch(appRouterProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status == AuthStatus.biometricLocked &&
          next.status == AuthStatus.unauthenticated &&
          router.state.matchedLocation == '/biometric-lock') {
        router.go('/login');
      }
    });

    return MaterialApp.router(
      title: 'G-TRAMS Mobile',
      debugShowCheckedModeBanner: false,
      theme: CivicTheme.light(),
      darkTheme: CivicTheme.dark(),
      themeMode: prefs.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(prefs.textScale.factor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
