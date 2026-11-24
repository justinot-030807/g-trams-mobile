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
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:pinput/pinput.dart';

/// 2-Step Password Recovery supporting primary & backup recovery OTP channels.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _step = 1;
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  ForgotPasswordResponse? _resetInfo;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<void> _requestCode({
    bool useBackup = false,
    String? preferredChannel,
  }) async {
    if (_isLoading) return;
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    final contact = _contactController.text.trim();
    if (!GasanConstants.isValidContact(contact)) {
      setState(() {
        _errorMessage = strings.pick(
          'Enter a valid registered email or mobile number.',
          'Ilagay ang iyong rehistradong email o numero ng cellphone.',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final info = await ref.read(authRepositoryProvider).requestPasswordReset(
            contact: contact,
            useBackupContact: useBackup,
            preferredChannel: preferredChannel,
          );
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _resetInfo = info;
        _successMessage = info.message;
        _step = 2;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReset() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length < 4) {
      setState(() {
        _errorMessage = strings.pick(
          'Enter the 6-digit recovery code.',
          'Ilagay ang 6-digit recovery code.',
        );
      });
      return;
    }
    if (!GasanConstants.isPasswordQualified(newPass)) {
      setState(() {
        _errorMessage = strings.pick(
          'New password must meet all 5 security rules.',
          'Dapat matugunan ng bagong password ang lahat ng 5 panuntunan.',
        );
      });
      return;
    }
    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = strings.pick(
          'Passwords do not match.',
          'Hindi magkatugma ang mga password.',
        );
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dest = _resetInfo?.destination ?? '';
      final lookupContact =
          (dest.isNotEmpty && !dest.contains('*'))
              ? dest
              : _contactController.text.trim();
      final msg = await ref.read(authRepositoryProvider).resetPassword(
            contact: lookupContact,
            otp: otp,
            newPassword: newPass,
            resetChallengeToken: _resetInfo?.resetChallengeToken,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _contactController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final rules =
        GasanConstants.evaluatePasswordRules(_newPasswordController.text);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: Text(strings.resetPasswordTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: CivicCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CivicColors.purePaper,
                          border: Border.all(
                            color: CivicColors.gasanGold,
                            width: 1.4,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/gtrams-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.resetPasswordSubtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: palette.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (_errorMessage != null) ...[
                    CivicBanner(
                      message: _errorMessage!,
                      tone: CivicStatusTone.danger,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_successMessage != null) ...[
                    CivicBanner(
                      message: _successMessage!,
                      tone: CivicStatusTone.active,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_step == 1) ...[
                    CivicFieldLabel(
                      text: strings.contactLabel,
                      isRequired: true,
                    ),
                    TextField(
                      controller: _contactController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: strings.contactHint,
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CivicPrimaryButton(
                      label: strings.sendOtp,
                      icon: Icons.send_outlined,
                      isLoading: _isLoading,
                      onPressed: () => _requestCode(),
                    ),
                  ] else ...[
                    if (_resetInfo != null) ...[
                      Text(
                        'OTP sent to ${_resetInfo!.destination}',
                        style: CivicTheme.monoStyle(
                          fontSize: 12,
                          color: palette.brandAccent,
                        ),
                      ),
                      if (_resetInfo!.hasRecoveryEmail ||
                          _resetInfo!.hasRecoveryPhone) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_resetInfo!.hasRecoveryEmail)
                              ActionChip(
                                label: Text(
                                  'Send to ${_resetInfo!.maskedRecoveryEmail}',
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => _requestCode(
                                          useBackup: true,
                                          preferredChannel: 'recovery_email',
                                        ),
                              ),
                            if (_resetInfo!.hasRecoveryPhone)
                              ActionChip(
                                label: Text(
                                  'Send to ${_resetInfo!.maskedRecoveryPhone}',
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => _requestCode(
                                          useBackup: true,
                                          preferredChannel: 'recovery_phone',
                                        ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: Pinput(
                        controller: _otpController,
                        length: 6,
                        defaultPinTheme: PinTheme(
                          width: 46,
                          height: 52,
                          textStyle: CivicTheme.monoStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                          decoration: BoxDecoration(
                            color: palette.canvas,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CivicFieldLabel(
                      text: strings.pick('New Password', 'Bagong Password'),
                      isRequired: true,
                    ),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_showNewPassword,
                      decoration: InputDecoration(
                        hintText: strings.pick(
                          'Create a strong new password',
                          'Gumawa ng malakas na bagong password',
                        ),
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _showNewPassword = !_showNewPassword,
                          ),
                          icon: Icon(
                            _showNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: rules.map((r) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  r.met
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 15,
                                  color: r.met
                                      ? CivicColors.civicGreen
                                      : palette.muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strings.isFil ? r.labelFil : r.labelEn,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: r.met
                                              ? CivicColors.civicGreen
                                              : palette.muted,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CivicFieldLabel(
                      text: strings.confirmPasswordLabel,
                      isRequired: true,
                    ),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        prefixIcon:
                            const Icon(Icons.lock_reset_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () =>
                                _showConfirmPassword = !_showConfirmPassword,
                          ),
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    CivicPrimaryButton(
                      label: strings.pick(
                        'Update Password',
                        'I-update ang Password',
                      ),
                      icon: Icons.check_rounded,
                      isLoading: _isLoading,
                      onPressed: _submitReset,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: (_resendCooldown > 0 || _isLoading)
                            ? null
                            : () => _requestCode(),
                        child: Text(
                          _resendCooldown > 0
                              ? '${strings.resendCode} (${_resendCooldown}s)'
                              : strings.resendCode,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
