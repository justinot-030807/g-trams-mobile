import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';

/// Stage-2 animated Civic Ledger splash screen.
/// Seamlessly continues from the OS native launch screen with a 3D coin-flip
/// transition from the Sangguniang Bayan seal to the official G-TRAMS emblem
/// while bootstrapping session auth, server time, and system settings.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _sbSealAsset = 'assets/images/gasan-logo.png';
  static const _gtramsLogoAsset = 'assets/images/gtrams-logo.png';

  late final AnimationController _controller;
  late final Animation<double> _entryOpacity;
  late final Animation<double> _entryScale;
  late final Animation<double> _flipAngle;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;

  Timer? _slowServerTimer;
  bool _isSlowServer = false;
  bool _assetsPrecached = false;
  double _progress = 0.18;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );

    // Phase A (0-40%): crisp arrival and steady display of the SB seal.
    _entryOpacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
      ),
    );
    _entryScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOutExpo),
      ),
    );

    // Phase B (40-75%): smooth 3D coin flip (0 -> pi) revealing G-TRAMS logo.
    _flipAngle = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.75, curve: Curves.easeInOutCubic),
      ),
    );

    // Phase C (65-94%): wordmark and single-line municipal caption settle in.
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.94, curve: Curves.easeOutCubic),
      ),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.94, curve: Curves.easeOutExpo),
      ),
    );

    _controller.forward();
    _bootstrapAndNavigate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      precacheImage(const AssetImage(_sbSealAsset), context);
      precacheImage(const AssetImage(_gtramsLogoAsset), context);
    }
  }

  Future<void> _bootstrapAndNavigate() async {
    _slowServerTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() => _isSlowServer = true);
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (mounted && _progress < 0.56) setState(() => _progress = 0.56);
    });
    Future<void>.delayed(const Duration(milliseconds: 1180), () {
      if (mounted && _progress < 0.80) setState(() => _progress = 0.80);
    });

    final prefs = ref.read(appPreferencesProvider);
    final minDisplay = Future<void>.delayed(const Duration(milliseconds: 1950));
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

  Widget _buildCoinFace({
    required String assetPath,
    required CivicPalette palette,
    required bool isDark,
    required bool isPrimaryEmblem,
  }) {
    return Container(
      width: 140,
      height: 140,
      padding: EdgeInsets.all(isPrimaryEmblem ? 5 : 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(
          color: CivicColors.gasanGold.withValues(
            alpha: isPrimaryEmblem ? 0.92 : 0.78,
          ),
          width: isPrimaryEmblem ? 2.2 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final accentColor =
        isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;
    final wordmarkColor =
        isDark ? CivicColors.darkParchment : CivicColors.gasanMaroonDeep;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3D Coin-Flip Medallion: SB Seal -> G-TRAMS Main Emblem
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final angle = _flipAngle.value;
                          final isBackVisible = angle >= (math.pi / 2);
                          final flipLift = 1.0 + (0.045 * math.sin(angle));
                          final coinScale = _entryScale.value * flipLift;
                          final shadowScaleX =
                              0.32 + (0.68 * math.cos(angle).abs());

                          final coinMatrix = Matrix4.identity()
                            ..setEntry(3, 2, 0.0018)
                            ..rotateY(angle);

                          return Opacity(
                            opacity: _entryOpacity.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: coinScale,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: coinMatrix,
                                    child: isBackVisible
                                        ? Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(math.pi),
                                            child: _buildCoinFace(
                                              assetPath: _gtramsLogoAsset,
                                              palette: palette,
                                              isDark: isDark,
                                              isPrimaryEmblem: true,
                                            ),
                                          )
                                        : _buildCoinFace(
                                            assetPath: _sbSealAsset,
                                            palette: palette,
                                            isDark: isDark,
                                            isPrimaryEmblem: false,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Transform.scale(
                                  scaleX: shadowScaleX,
                                  scaleY: 1.0,
                                  child: Container(
                                    width: 84,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.36 : 0.11,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      // Phase C: Bold G-TRAMS wordmark + single-line caption
                      SlideTransition(
                        position: _wordmarkSlide,
                        child: FadeTransition(
                          opacity: _wordmarkOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.appName,
                                maxLines: 1,
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      color: wordmarkColor,
                                      letterSpacing: 4.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 44,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: CivicColors.gasanGold,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Municipality of Gasan • Marinduque',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: palette.muted,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: 176,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(end: _progress),
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) {
                                      return LinearProgressIndicator(
                                        value: value,
                                        minHeight: 3.5,
                                        backgroundColor: palette.border,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          accentColor,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                child: Text(
                                  _isSlowServer
                                      ? strings.wakingServer
                                      : strings.verifyingSession,
                                  key: ValueKey<bool>(_isSlowServer),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: CivicTheme.monoStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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
            ),

            // Single-line official attribution — guaranteed never to wrap "I"
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'OVM — LLSA I • Gasan, Marinduque',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: CivicTheme.monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
