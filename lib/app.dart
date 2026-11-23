import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
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
        builder: (context, state) => const MobileShellScreen(),
      ),
    ],
  );
});

class GtramsMobileApp extends ConsumerWidget {
  const GtramsMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final router = ref.watch(appRouterProvider);

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
