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
import 'package:gtrams_mobile/shared/widgets/google_g_logo.dart';

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

    final strings = AppStrings(ref.read(appPreferencesProvider).language);
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
          _errorMessage = strings.pick(
            'Too many login attempts. Wait ${secs}s and try again.',
            'Masyadong maraming pagsubok. Maghintay ng ${secs}s bago subukan muli.',
          );
        });
      } else {
        _failedAttempts += 1;
        if (_failedAttempts >= 5) {
          _failedAttempts = 0;
          _startLockout(60);
          setState(() {
            _errorMessage = strings.pick(
              'Too many failed attempts. Sign-in is locked for 60 seconds.',
              'Masyadong maraming maling pagsubok. Pansamantalang naka-lock ng 60 segundo.',
            );
          });
        } else {
          setState(() => _errorMessage = e.message);
        }
      }
    } catch (_) {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage = strings.pick(
            'Cannot connect to the G-TRAMS server. Check your internet and try again.',
            'Hindi makakonekta sa G-TRAMS server. Suriin ang iyong internet at subukan muli.',
          );
        });
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
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    FocusScope.of(context).unfocus();
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
      setState(() => _isGoogleLoading = false);
      final completed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => _GoogleOnboardingSheet(onboarding: onboarding),
      );
      if (completed == true && mounted) {
        context.go('/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.accountDeactivated) {
        context.push(
          '/account-deactivated',
          extra: DeactivatedAccountArgs(
            contact: e.deactivationContact ?? '',
            reason: e.deactivationReason ?? '',
            appealStatus: e.appealStatus ?? 'none',
            hasLocalPassword: e.hasLocalPassword ?? false,
            authProvider: e.authProvider ?? 'google',
          ),
        );
      } else {
        setState(() => _errorMessage = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = strings.pick(
            'Unable to complete Google Sign-In. Please try again.',
            'Hindi natapos ang Google Sign-In. Pakisubukan muli.',
          );
        });
      }
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
                  height: 220,
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
                  height: 220,
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
                        // Top bar controls: G-TRAMS Logo + EN/FIL + Theme switch
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CivicColors.purePaper,
                                border: Border.all(
                                  color: CivicColors.gasanGold,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/gtrams-logo.png',
                                  fit: BoxFit.cover,
                                ),
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
                                          letterSpacing: 1.8,
                                        ),
                                  ),
                                  Text(
                                    'Municipality of Gasan',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: CivicColors.gasanGoldAccessible,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
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
                        Text(
                          strings.welcomeBack,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: CivicColors.purePaper,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'OPERATORS & TODA PRESIDENTS ONLY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CivicTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: CivicColors.gasanGoldAccessible,
                            letterSpacing: 0.7,
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                          const SizedBox(height: 18),

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
                              message: strings.pick(
                                'Security cooldown active: ${_lockoutSeconds}s remaining.',
                                'Pansamantalang naka-lock: ${_lockoutSeconds}s na natitira.',
                              ),
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
                                return strings.pick(
                                  'Enter your email or mobile number.',
                                  'Ilagay ang iyong email o numero ng cellphone.',
                                );
                              }
                              if (!GasanConstants.isValidContact(val)) {
                                return strings.pick(
                                  'Enter a valid email or PH mobile number (09XXXXXXXXX).',
                                  'Maglagay ng wastong email o cellphone number (09XXXXXXXXX).',
                                );
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
                                return strings.pick(
                                  'Enter your password.',
                                  'Ilagay ang iyong password.',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 4),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: Text(strings.forgotPassword),
                            ),
                          ),
                          const SizedBox(height: 6),

                          CivicPrimaryButton(
                            label: _lockoutSeconds > 0
                                ? strings.pick(
                                    'Locked (${_lockoutSeconds}s)',
                                    'Naka-lock (${_lockoutSeconds}s)',
                                  )
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
                            key: const Key('google_sign_in_button'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: palette.surface,
                              side: BorderSide(color: palette.border),
                            ),
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
                                      const GoogleGLogo(size: 20),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          strings.continueWithGoogle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 18),
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
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(48, 40),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => context.push('/register'),
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
                'Municipality of Gasan • OVM — LLSA I',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
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

/// Completes operator TODA roster onboarding for brand-new Google Sign-In users
/// (`POST /api/v1/auth/google` with `onboardingData` + `googleProfile`/`onboardingToken`).
class _GoogleOnboardingSheet extends ConsumerStatefulWidget {
  const _GoogleOnboardingSheet({required this.onboarding});

  final GoogleOnboardingRequiredException onboarding;

  @override
  ConsumerState<_GoogleOnboardingSheet> createState() =>
      _GoogleOnboardingSheetState();
}

class _GoogleOnboardingSheetState
    extends ConsumerState<_GoogleOnboardingSheet> {
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _bodyNumberController = TextEditingController();

  String _selectedBarangay = '';
  String _selectedTodaId = '';
  bool _termsAccepted = false;
  bool _isCheckingRoster = false;
  RosterVerificationResult? _rosterResult;
  Timer? _rosterDebounce;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.onboarding.name);
    _nameController.addListener(_scheduleRosterCheck);
    _bodyNumberController.addListener(_scheduleRosterCheck);
  }

  void _scheduleRosterCheck() {
    _rosterDebounce?.cancel();
    if (_selectedTodaId.isEmpty || _selectedTodaId == 'NON-TODA') {
      if (_rosterResult != null) setState(() => _rosterResult = null);
      return;
    }

    final name = _nameController.text.trim();
    final body = _bodyNumberController.text.trim();
    if (name.length < 2 || body.isEmpty) {
      final strings = AppStrings(ref.read(appPreferencesProvider).language);
      setState(() {
        _rosterResult = RosterVerificationResult(
          verified: false,
          status: 'pending_input',
          message: strings.pick(
            'Enter your full legal name and Body Number to check the TODA masterlist.',
            'Ilagay ang buong pangalan at Body Number para suriin sa TODA masterlist.',
          ),
        );
      });
      return;
    }

    _rosterDebounce = Timer(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      setState(() => _isCheckingRoster = true);
      try {
        final result = await ref.read(authRepositoryProvider).verifyTodaRoster(
              fullName: name,
              todaAssociation: _selectedTodaId,
              bodyNumber: body,
            );
        if (mounted) setState(() => _rosterResult = result);
      } catch (_) {
        // Backend still enforces roster eligibility on submit.
      } finally {
        if (mounted) setState(() => _isCheckingRoster = false);
      }
    });
  }

  void _showLguAdvisorySheet({
    required String message,
    Map<String, dynamic>? advisory,
  }) {
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final palette = ctx.civic;
        final title = (advisory?['title'] ??
                strings.pick(
                  'TODA Masterlist Advisory',
                  'Abiso sa TODA Masterlist',
                ))
            .toString();
        final nextStep = (advisory?['nextSteps'] ??
                advisory?['instruction'] ??
                strings.pick(
                  'Coordinate with your TODA President to confirm your legal name and body number on the official masterlist submitted to OVM — LLSA I.',
                  'Makipag-ugnayan sa iyong TODA President upang tiyakin ang iyong pangalan at body number sa opisyal na masterlist ng OVM — LLSA I.',
                ))
            .toString();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              CivicBanner(message: message, tone: CivicStatusTone.danger),
              const SizedBox(height: 12),
              Text(
                nextStep,
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 18),
              CivicPrimaryButton(
                label: strings.pick('Understood', 'Naintindihan'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBarangayPicker() async {
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    final queryController = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = queryController.text.trim().toLowerCase();
            final filtered = GasanConstants.barangays
                .where((b) => b.toLowerCase().contains(query))
                .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              maxChildSize: 0.9,
              minChildSize: 0.45,
              builder: (_, scrollController) {
                final palette = ctx.civic;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.pick('Select Gasan Barangay', 'Piliin ang Barangay'),
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: queryController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: strings.pick(
                            'Search barangay...',
                            'Maghanap ng barangay...',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: palette.border),
                          itemBuilder: (_, idx) {
                            final brgy = filtered[idx];
                            final zone =
                                GasanConstants.getZoneForBarangay(brgy);
                            final isCurrent = brgy == _selectedBarangay;
                            return ListTile(
                              title: Text(brgy),
                              subtitle: Text(
                                '$zone Zone',
                                style: CivicTheme.monoStyle(
                                  fontSize: 11,
                                  color: palette.muted,
                                ),
                              ),
                              trailing: isCurrent
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: CivicColors.gasanMaroon,
                                    )
                                  : null,
                              onTap: () => Navigator.of(ctx).pop(brgy),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    queryController.dispose();

    if (selected != null && mounted) {
      final validTodas = GasanConstants.getTodasForBarangay(selected);
      final keepToda = validTodas.any((t) => t.id == _selectedTodaId);
      setState(() {
        _selectedBarangay = selected;
        if (!keepToda) {
          _selectedTodaId = '';
          _rosterResult = null;
        }
        _errorMessage = null;
      });
      _scheduleRosterCheck();
    }
  }

  Future<void> _openTodaPicker() async {
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    if (_selectedBarangay.isEmpty) {
      setState(() {
        _errorMessage = strings.pick(
          'Select your Barangay first.',
          'Piliin muna ang iyong Barangay.',
        );
      });
      return;
    }

    final validTodas = GasanConstants.getTodasForBarangay(_selectedBarangay);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final palette = ctx.civic;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.pick(
                  'Accredited TODA for $_selectedBarangay',
                  'Akreditadong TODA para sa $_selectedBarangay',
                ),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: validTodas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final toda = validTodas[idx];
                    final isCurrent = toda.id == _selectedTodaId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(ctx).pop(toda.id),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? CivicColors.gasanMaroon.withValues(alpha: 0.08)
                              : palette.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? CivicColors.gasanMaroon
                                : palette.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    toda.name,
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${toda.zone} Zone • ${toda.terminal}',
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: CivicColors.gasanMaroon,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedTodaId = selected;
        _errorMessage = null;
      });
      _scheduleRosterCheck();
    }
  }

  void _showTermsSheet() {
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final palette = ctx.civic;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.pick(
                  'Terms & Data Privacy (RA 10173)',
                  'Mga Tuntunin at Data Privacy (RA 10173)',
                ),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                strings.pick(
                  'Under Republic Act No. 10173, your identity and TODA roster information is collected solely by the Municipality of Gasan — OVM / LLSA I for MTOP registration, renewal, and verification.',
                  'Alinsunod sa Republic Act No. 10173, ang iyong impormasyon ay kinokolekta lamang ng Munisipyo ng Gasan — OVM / LLSA I para sa rehistrasyon at beripikasyon ng MTOP.',
                ),
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              CivicPrimaryButton(
                label: strings.pick('Accept & Close', 'Tanggapin at Isara'),
                onPressed: () {
                  setState(() => _termsAccepted = true);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitOnboarding() async {
    if (_isSubmitting) return;
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    setState(() => _errorMessage = null);

    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final bodyNumber = _bodyNumberController.text.trim();

    if (fullName.length < 2) {
      setState(() {
        _errorMessage = strings.pick(
          'Enter your full legal name (at least 2 characters).',
          'Ilagay ang iyong buong pangalan (hindi bababa sa 2 letra).',
        );
      });
      return;
    }
    if (phone.isNotEmpty) {
      final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
      final validPhone = RegExp(r'^(09|\+639)\d{9}$').hasMatch(cleaned);
      if (!validPhone) {
        setState(() {
          _errorMessage = strings.pick(
            'Enter a valid PH mobile number (09XXXXXXXXX) or leave it blank.',
            'Maglagay ng wastong cellphone number (09XXXXXXXXX) o iwang blangko.',
          );
        });
        return;
      }
    }
    if (_selectedBarangay.isEmpty) {
      setState(() {
        _errorMessage = strings.pick(
          'Select your Barangay in Gasan.',
          'Piliin ang iyong Barangay sa Gasan.',
        );
      });
      return;
    }
    if (_selectedTodaId.isEmpty || _selectedTodaId == 'NON-TODA') {
      setState(() {
        _errorMessage = strings.pick(
          'Select an accredited Gasan TODA.',
          'Pumili ng akreditadong TODA sa Gasan.',
        );
      });
      return;
    }
    if (bodyNumber.isEmpty) {
      setState(() {
        _errorMessage = strings.pick(
          'Enter your Assigned Body Number from the TODA masterlist.',
          'Ilagay ang iyong Assigned Body Number mula sa TODA masterlist.',
        );
      });
      return;
    }
    if (_rosterResult != null &&
        _rosterResult!.status != 'pending_input' &&
        !_rosterResult!.verified) {
      _showLguAdvisorySheet(
        message: _rosterResult!.message.isNotEmpty
            ? _rosterResult!.message
            : strings.pick(
                'Record not verified on the official TODA masterlist.',
                'Hindi naberipika ang rekord sa opisyal na TODA masterlist.',
              ),
        advisory: _rosterResult!.advisory,
      );
      return;
    }
    if (!_termsAccepted) {
      setState(() {
        _errorMessage = strings.pick(
          'Please accept the Terms & Data Privacy Notice.',
          'Pakitanggap ang Mga Tuntunin at Data Privacy Notice.',
        );
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authControllerProvider.notifier).completeGoogleOnboarding(
            email: widget.onboarding.email,
            fullName: fullName,
            address: _selectedBarangay,
            todaAssociation: _selectedTodaId,
            bodyNumber: bodyNumber,
            googleId: widget.onboarding.googleId,
            picture: widget.onboarding.picture,
            onboardingToken: widget.onboarding.onboardingToken,
            idToken: widget.onboarding.idToken,
            accessToken: widget.onboarding.accessToken,
            emergencyContact: phone.isEmpty ? null : phone,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StaffRoleBlockedException catch (blocked) {
      if (!mounted) return;
      await showStaffRoleGuardDialog(context, displayRole: blocked.displayRole);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && e.advisory != null) {
        _showLguAdvisorySheet(message: e.message, advisory: e.advisory);
      }
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _rosterDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _bodyNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final selectedToda = GasanConstants.findTodaById(_selectedTodaId);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CivicColors.purePaper,
                            border: Border.all(
                              color: CivicColors.gasanGold,
                              width: 1.2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/gtrams-logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.pick(
                                  'Complete Google Registration',
                                  'Tapusin ang Google Registration',
                                ),
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                strings.pick(
                                  'Verify your Gasan Barangay, TODA & Body #',
                                  'Piliin ang iyong Barangay, TODA at Body #',
                                ),
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: strings.close,
                          onPressed: () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.border),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verified Google Email summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: palette.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            const GoogleGLogo(size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.onboarding.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CivicStatusBadge(
                              label: strings.pick('Verified', 'Beripikado'),
                              tone: CivicStatusTone.active,
                              icon: Icons.verified_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        CivicBanner(
                          message: _errorMessage!,
                          tone: CivicStatusTone.danger,
                        ),
                        const SizedBox(height: 14),
                      ],

                      CivicFieldLabel(
                        text: strings.fullNameLabel,
                        isRequired: true,
                      ),
                      TextField(
                        key: const Key('google_onboarding_name_field'),
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: strings.fullNameHint,
                          prefixIcon:
                              const Icon(Icons.badge_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CivicFieldLabel(
                        text: strings.pick(
                          'Emergency Mobile (Optional)',
                          'Emergency Cellphone (Opsyonal)',
                        ),
                      ),
                      TextField(
                        key: const Key('google_onboarding_phone_field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '09171234567',
                          prefixIcon:
                              const Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CivicFieldLabel(
                        text: strings.barangayLabel,
                        isRequired: true,
                      ),
                      InkWell(
                        key: const Key('google_onboarding_barangay_picker'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openBarangayPicker,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon:
                                Icon(Icons.location_on_outlined, size: 20),
                            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          child: Text(
                            _selectedBarangay.isEmpty
                                ? strings.selectBarangay
                                : _selectedBarangay,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: _selectedBarangay.isEmpty
                                      ? palette.muted
                                      : palette.ink,
                                  fontWeight: _selectedBarangay.isEmpty
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CivicFieldLabel(
                        text: strings.todaLabel,
                        isRequired: true,
                      ),
                      InkWell(
                        key: const Key('google_onboarding_toda_picker'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openTodaPicker,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.groups_outlined, size: 20),
                            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          child: Text(
                            selectedToda?.name ?? strings.selectToda,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: selectedToda == null
                                      ? palette.muted
                                      : palette.ink,
                                  fontWeight: selectedToda == null
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CivicFieldLabel(
                        text: strings.bodyNumberLabel,
                        isRequired: true,
                      ),
                      TextField(
                        key: const Key('google_onboarding_body_field'),
                        controller: _bodyNumberController,
                        textCapitalization: TextCapitalization.characters,
                        style: CivicTheme.monoStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: strings.bodyNumberHint,
                          prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isCheckingRoster)
                        CivicBanner(
                          message: strings.pick(
                            'Checking official Gasan TODA masterlist...',
                            'Sinusuri sa opisyal na TODA masterlist...',
                          ),
                          tone: CivicStatusTone.inProgress,
                          icon: Icons.sync_rounded,
                        )
                      else if (_rosterResult != null) ...[
                        CivicBanner(
                          title: _rosterResult!.verified
                              ? strings.pick(
                                  'TODA Masterlist Verified',
                                  'Beripikado sa TODA Masterlist',
                                )
                              : (_rosterResult!.status == 'pending_input'
                                  ? strings.pick(
                                      'Roster Check Pending',
                                      'Kailangan ng Beripikasyon',
                                    )
                                  : strings.pick(
                                      'Not Found in TODA Masterlist',
                                      'Hindi Nakita sa TODA Masterlist',
                                    )),
                          message: _rosterResult!.message.isNotEmpty
                              ? _rosterResult!.message
                              : (_rosterResult!.verified
                                  ? strings.pick(
                                      'Your record matches the accredited TODA roster.',
                                      'Tugma ang iyong rekord sa akreditadong TODA roster.',
                                    )
                                  : strings.pick(
                                      'Check your legal name and assigned body number.',
                                      'Suriin ang iyong pangalan at body number.',
                                    )),
                          tone: _rosterResult!.verified
                              ? CivicStatusTone.active
                              : (_rosterResult!.status == 'pending_input'
                                  ? CivicStatusTone.inProgress
                                  : CivicStatusTone.danger),
                          action: (!_rosterResult!.verified &&
                                  _rosterResult!.status != 'pending_input')
                              ? TextButton(
                                  onPressed: () => _showLguAdvisorySheet(
                                    message: _rosterResult!.message,
                                    advisory: _rosterResult!.advisory,
                                  ),
                                  child: Text(
                                    strings.pick(
                                      'Read Official Advisory',
                                      'Basahin ang Opisyal na Abiso',
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Checkbox(
                              key: const Key('google_onboarding_terms_checkbox'),
                              value: _termsAccepted,
                              activeColor: CivicColors.gasanMaroon,
                              onChanged: (v) =>
                                  setState(() => _termsAccepted = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showTermsSheet,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  strings.acceptTerms,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: palette.ink,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      CivicPrimaryButton(
                        key: const Key('google_onboarding_submit_button'),
                        label: strings.pick(
                          'Complete Registration',
                          'Tapusin ang Rehistrasyon',
                        ),
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isSubmitting,
                        onPressed: _submitOnboarding,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        width: 36,
        height: 36,
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
