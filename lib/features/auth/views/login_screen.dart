import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Dedicated mobile Login screen for Tricycle Operators & TODA Presidents.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _isSlowWarning = false;
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  Timer? _slowTimer;

  void _startLockout(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() => _lockoutSeconds = 0);
      } else {
        setState(() => _lockoutSeconds -= 1);
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading || _lockoutSeconds > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSlowWarning = false;
    });

    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _isLoading) {
        setState(() => _isSlowWarning = true);
      }
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            contact: _contactController.text.trim(),
            password: _passwordController.text,
          );
      _slowTimer?.cancel();
      if (!mounted) return;
      context.go('/home');
    } on StaffRoleBlockedException catch (blocked) {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() => _isLoading = false);
      await showStaffRoleGuardDialog(
        context,
        displayRole: blocked.displayRole,
      );
    } on ApiException catch (e) {
      _slowTimer?.cancel();
      if (!mounted) return;

      if (e.accountDeactivated) {
        context.push(
          '/account-deactivated',
          extra: DeactivatedAccountArgs(
            contact: e.deactivationContact ?? _contactController.text.trim(),
            reason: e.deactivationReason ?? '',
            appealStatus: e.appealStatus ?? 'none',
            hasLocalPassword: e.hasLocalPassword ?? true,
            authProvider: e.authProvider ?? 'local',
          ),
        );
      } else if (e.statusCode == 429) {
        final secs = e.retryAfterSeconds ?? 60;
        _startLockout(secs);
        setState(() {
          _errorMessage =
              'Too many login attempts. Please wait $secs seconds before trying again.';
        });
      } else {
        _failedAttempts += 1;
        if (_failedAttempts >= 5) {
          _failedAttempts = 0;
          _startLockout(60);
          setState(() {
            _errorMessage =
                'Too many failed attempts. Sign-in is temporarily locked for 60 seconds.';
          });
        } else {
          setState(() => _errorMessage = e.message);
        }
      }
    } catch (e) {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() => _errorMessage = 'Cannot connect to the G-TRAMS server.');
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSlowWarning = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading || _isLoading) return;
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      context.go('/home');
    } on StaffRoleBlockedException catch (blocked) {
      if (!mounted) return;
      await showStaffRoleGuardDialog(
        context,
        displayRole: blocked.displayRole,
      );
    } on GoogleOnboardingRequiredException catch (onboarding) {
      if (!mounted) return;
      context.push(
        '/register',
        extra: {
          'prefillName': onboarding.name,
          'prefillContact': onboarding.email,
        },
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _slowTimer?.cancel();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final prefs = ref.watch(appPreferencesProvider);
    final revokedReason = ref.watch(
      authControllerProvider.select((s) => s.sessionRevokedReason),
    );
    final strings = AppStrings(prefs.language);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Heritage Maroon Municipal Crest Banner
            Stack(
              children: [
                SizedBox(
                  height: 238,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/tricycle-login.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: CivicColors.gasanMaroonDarkest,
                    ),
                  ),
                ),
                Container(
                  height: 238,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CivicColors.gasanMaroonDarkest.withValues(alpha: 0.78),
                        CivicColors.gasanMaroonDeep.withValues(alpha: 0.88),
                        CivicColors.gasanMaroon.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar controls: Seal + EN/FIL + Theme switch
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CivicColors.purePaper,
                                border: Border.all(
                                  color: CivicColors.gasanGold,
                                  width: 1.5,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/gasan-logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'G-TRAMS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: CivicColors.purePaper,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.2,
                                        ),
                                  ),
                                  Text(
                                    'LGU GASAN • OPERATOR PORTAL',
                                    style: CivicTheme.monoStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: CivicColors.gasanGoldAccessible,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _HeroPillAction(
                              label: prefs.language == 'fil' ? 'FIL' : 'EN',
                              icon: Icons.translate_rounded,
                              onTap: () => ref
                                  .read(appPreferencesProvider.notifier)
                                  .toggleLanguage(),
                            ),
                            const SizedBox(width: 8),
                            _HeroIconAction(
                              icon: isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              onTap: () => ref
                                  .read(appPreferencesProvider.notifier)
                                  .setThemeMode(
                                    isDark ? ThemeMode.light : ThemeMode.dark,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: CivicColors.gasanGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: CivicColors.gasanGoldAccessible
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'OPERATORS & TODA PRESIDENTS ONLY',
                            style: CivicTheme.monoStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: CivicColors.gasanGoldAccessible,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          strings.welcomeBack,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: CivicColors.purePaper,
                                fontSize: 26,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Form Surface Sheet
            Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: CivicCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.loginSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: palette.muted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 36,
                            height: 3,
                            decoration: BoxDecoration(
                              color: CivicColors.gasanGold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (revokedReason != null &&
                              revokedReason.isNotEmpty) ...[
                            CivicBanner(
                              title: strings.pick(
                                'Session Signed Out',
                                'Naka-sign Out ang Sesyon',
                              ),
                              message: revokedReason,
                              tone: CivicStatusTone.inProgress,
                              icon: Icons.security_rounded,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (_isSlowWarning) ...[
                            CivicBanner(
                              message: strings.wakingServer,
                              tone: CivicStatusTone.inProgress,
                              icon: Icons.cloud_sync_outlined,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (_errorMessage != null) ...[
                            CivicBanner(
                              message: _errorMessage!,
                              tone: CivicStatusTone.danger,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (_lockoutSeconds > 0) ...[
                            CivicBanner(
                              message:
                                  'Temporary security cooldown active: ${_lockoutSeconds}s remaining.',
                              tone: CivicStatusTone.inProgress,
                              icon: Icons.lock_clock_outlined,
                            ),
                            const SizedBox(height: 14),
                          ],

                          CivicFieldLabel(
                            text: strings.contactLabel,
                            isRequired: true,
                          ),
                          TextFormField(
                            controller: _contactController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: strings.contactHint,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Enter your email or mobile number.';
                              }
                              if (!GasanConstants.isValidContact(val)) {
                                return 'Enter a valid email or PH mobile number (09XXXXXXXXX).';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          CivicFieldLabel(
                            text: strings.passwordLabel,
                            isRequired: true,
                          ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              hintText: strings.passwordHint,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Enter your password.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: Text(strings.forgotPassword),
                            ),
                          ),
                          const SizedBox(height: 8),

                          CivicPrimaryButton(
                            label: _lockoutSeconds > 0
                                ? 'Locked (${_lockoutSeconds}s)'
                                : strings.signIn,
                            icon: Icons.login_rounded,
                            isLoading: _isLoading,
                            onPressed:
                                _lockoutSeconds > 0 ? null : _handleLogin,
                          ),

                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Divider(color: palette.border)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  strings.orContinueWith,
                                  style: CivicTheme.monoStyle(
                                    fontSize: 10,
                                    color: palette.muted,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: palette.border)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          OutlinedButton(
                            onPressed:
                                _isGoogleLoading ? null : _handleGoogleSignIn,
                            child: _isGoogleLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.brandAccent,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.g_mobiledata_rounded,
                                        size: 26,
                                        color: CivicColors.gasanMaroon,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          strings.continueWithGoogle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 22),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                Text(
                                  strings.noAccountYet.trim(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: Text(
                                    strings.createAccount,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: palette.brandAccent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                'Municipality of Gasan • Office of the Municipal Vice Mayor (OVM)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: palette.muted,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPillAction extends StatelessWidget {
  const _HeroPillAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: CivicColors.purePaper.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: CivicColors.purePaper),
            const SizedBox(width: 4),
            Text(
              label,
              style: CivicTheme.monoStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: CivicColors.purePaper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconAction extends StatelessWidget {
  const _HeroIconAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.25),
          border: Border.all(
            color: CivicColors.purePaper.withValues(alpha: 0.28),
          ),
        ),
        child: Icon(icon, size: 17, color: CivicColors.purePaper),
      ),
    );
  }
}
