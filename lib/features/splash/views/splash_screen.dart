import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';

/// Stage-2 animated Civic Ledger splash screen.
/// Seamlessly continues from the OS native launch screen while bootstrapping
/// session auth, `Asia/Manila` server time, and system settings.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sealScale;
  late final Animation<double> _sealOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  Timer? _slowServerTimer;
  bool _isSlowServer = false;
  double _progress = 0.18;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );

    _sealScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _sealOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _bootstrapAndNavigate();
  }

  Future<void> _bootstrapAndNavigate() async {
    _slowServerTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() => _isSlowServer = true);
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (mounted && _progress < 0.58) setState(() => _progress = 0.58);
    });

    final prefs = ref.read(appPreferencesProvider);
    final minDisplay = Future<void>.delayed(const Duration(milliseconds: 1450));
    final bootstrap = ref
        .read(authControllerProvider.notifier)
        .bootstrap(requireBiometricLock: prefs.biometricEnabled);

    await Future.wait([minDisplay, bootstrap]);
    _slowServerTimer?.cancel();

    if (!mounted) return;
    setState(() => _progress = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final updatedPrefs = ref.read(appPreferencesProvider);

    if (authState.status == AuthStatus.authenticated) {
      context.go('/home');
    } else if (authState.status == AuthStatus.biometricLocked) {
      context.go('/biometric-lock');
    } else if (!updatedPrefs.hasSeenOnboarding) {
      context.go('/onboarding');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _slowServerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final accentColor =
        isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle architectural corner hairlines
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      strings.municipalityCaption,
                      style: CivicTheme.monoStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Centered Seal + Brand Wordmark + Progress Bar
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _sealOpacity.value,
                          child: Transform.scale(
                            scale: _sealScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 128,
                        height: 128,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.surface,
                          border: Border.all(
                            color: CivicColors.gasanGold.withValues(alpha: 0.85),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.06,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/gasan-logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            Text(
                              strings.appName,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    color: accentColor,
                                    letterSpacing: 6.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 44,
                              height: 3,
                              decoration: BoxDecoration(
                                color: CivicColors.gasanGold,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              strings.appFullTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: palette.muted,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 184,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(end: _progress),
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return LinearProgressIndicator(
                                      value: value,
                                      minHeight: 4,
                                      backgroundColor: palette.border,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        accentColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                _isSlowServer
                                    ? strings.wakingServer
                                    : strings.verifyingSession,
                                key: ValueKey<bool>(_isSlowServer),
                                textAlign: TextAlign.center,
                                style: CivicTheme.monoStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom official attribution
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: Text(
                'OFFICE OF THE MUNICIPAL VICE MAYOR (OVM) • LLSA I',
                textAlign: TextAlign.center,
                style: CivicTheme.monoStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: palette.muted.withValues(alpha: 0.8),
                  letterSpacing: 0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
