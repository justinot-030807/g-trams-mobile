import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

typedef RequestRecoveryOtpCallback = Future<RecoveryOtpResult> Function(
  String target,
);

typedef SaveRecoveryCallback = Future<MobileUser> Function({
  String? recoveryEmail,
  String? recoveryPhone,
  bool clearRecovery,
  required String currentPassword,
  String? verificationTarget,
  String? recoveryOtp,
});

/// Bottom sheet for binding/verifying Recovery Email or Recovery Phone via OTP
/// (`POST /api/v1/auth/request-recovery-otp` + `PUT /api/v1/auth/profile`).
class AccountRecoverySheet extends StatefulWidget {
  const AccountRecoverySheet({
    super.key,
    required this.user,
    required this.strings,
    required this.onRequestOtp,
    required this.onSaveRecovery,
  });

  final MobileUser user;
  final AppStrings strings;
  final RequestRecoveryOtpCallback onRequestOtp;
  final SaveRecoveryCallback onSaveRecovery;

  @override
  State<AccountRecoverySheet> createState() => _AccountRecoverySheetState();
}

class _AccountRecoverySheetState extends State<AccountRecoverySheet> {
  String _mode = 'email'; // 'email' | 'phone'
  late final TextEditingController _targetCtrl;
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showPassword = false;
  bool _isSendingOtp = false;
  bool _isSaving = false;
  String? _otpSentTarget;
  String? _otpSentNotice;
  String? _error;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _targetCtrl = TextEditingController(
      text: widget.user.effectiveRecoveryEmail,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _targetCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(String nextMode) {
    if (_mode == nextMode) return;
    setState(() {
      _mode = nextMode;
      _targetCtrl.text = nextMode == 'email'
          ? widget.user.effectiveRecoveryEmail
          : widget.user.effectiveRecoveryPhone;
      _otpCtrl.clear();
      _otpSentTarget = null;
      _otpSentNotice = null;
      _error = null;
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    final target = _targetCtrl.text.trim();
    if (_mode == 'email' && !GasanConstants.isValidEmail(target)) {
      setState(() {
        _error = widget.strings.pick(
          'Enter a valid recovery email address.',
          'Maglagay ng wastong recovery email address.',
        );
      });
      return;
    }
    if (_mode == 'phone' && !GasanConstants.isValidPhMobile(target)) {
      setState(() {
        _error = widget.strings.pick(
          'Enter a valid Philippine mobile number (e.g. 09XXXXXXXXX).',
          'Maglagay ng wastong PH mobile number (hal. 09XXXXXXXXX).',
        );
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final result = await widget.onRequestOtp(target);
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _isSendingOtp = false;
        _otpSentTarget = GasanConstants.canonicalizeContact(target);
        _otpSentNotice = result.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _error = e.message;
      });
    }
  }

  Future<void> _saveBinding() async {
    if (_isSaving) return;
    final target = _targetCtrl.text.trim();
    final canonical = GasanConstants.canonicalizeContact(target);

    if (_otpSentTarget == null || _otpSentTarget != canonical) {
      setState(() {
        _error = widget.strings.pick(
          'Tap "Send OTP" first to verify this recovery contact.',
          'Pindutin muna ang "Send OTP" upang ma-verify ang recovery contact na ito.',
        );
      });
      return;
    }
    if (_otpCtrl.text.trim().length < 6) {
      setState(() {
        _error = widget.strings.pick(
          'Enter the 6-digit verification code sent to your recovery contact.',
          'Ilagay ang 6-digit verification code na ipinadala.',
        );
      });
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Current password is required to confirm recovery changes.',
          'Kailangan ang kasalukuyang password upang kumpirmahin ang pagbabago.',
        );
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = await widget.onSaveRecovery(
        recoveryEmail: _mode == 'email' ? target.toLowerCase() : null,
        recoveryPhone: _mode == 'phone' ? target : null,
        clearRecovery: false,
        currentPassword: _passwordCtrl.text,
        verificationTarget: canonical,
        recoveryOtp: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _clearRecovery() async {
    if (_isSaving) return;
    if (_passwordCtrl.text.isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Enter your current password before clearing saved recovery contacts.',
          'Ilagay ang iyong kasalukuyang password bago alisin ang recovery contacts.',
        );
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = await widget.onSaveRecovery(
        clearRecovery: true,
        currentPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isGoogleOnly = widget.user.isGoogleOnlyAccount;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        child: SingleChildScrollView(
          key: const Key('account_recovery_scroll'),
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
                strings.accountRecoveryTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                strings.pick(
                  'Bind a backup email or PH mobile number so you can recover your G-TRAMS account if you lose access to your primary contact.',
                  'Maglagay ng backup email o PH mobile number upang ma-recover ang iyong G-TRAMS account sakaling mawala ang pangunahing contact.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),

              // Current Saved Recovery Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT RECOVERY CHANNELS',
                      style: CivicTheme.monoStyle(
                        fontSize: 9.5,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'EMAIL: ${widget.user.effectiveRecoveryEmail.isNotEmpty ? widget.user.effectiveRecoveryEmail : 'Not set'}',
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PHONE: ${widget.user.effectiveRecoveryPhone.isNotEmpty ? widget.user.effectiveRecoveryPhone : 'Not set'}',
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (isGoogleOnly)
                CivicBanner(
                  tone: CivicStatusTone.inProgress,
                  title: strings.pick(
                    'Google-Managed Sign-In',
                    'Google-Managed ang Sign-In',
                  ),
                  message: strings.pick(
                    'Your account signs in exclusively with Google. To bind or change recovery contacts with Google step-up verification, open Account Settings on the G-TRAMS Web Portal.',
                    'Naka-Google Sign-In ang iyong account. Para sa pagbabago ng recovery contact na may Google step-up verification, buksan ang Account Settings sa G-TRAMS Web Portal.',
                  ),
                )
              else ...[
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'email',
                      label: Text(strings.pick('Recovery Email', 'Backup Email')),
                      icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'phone',
                      label: Text(strings.pick('Recovery Phone', 'Backup Phone')),
                      icon: const Icon(Icons.phone_android_rounded, size: 16),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (sel) => _switchMode(sel.first),
                ),
                const SizedBox(height: 14),

                if (_error != null) ...[
                  CivicBanner(tone: CivicStatusTone.danger, message: _error!),
                  const SizedBox(height: 10),
                ],
                if (_otpSentNotice != null) ...[
                  CivicBanner(
                    tone: CivicStatusTone.active,
                    message: _otpSentNotice!,
                  ),
                  const SizedBox(height: 10),
                ],

                CivicFieldLabel(
                  text: _mode == 'email'
                      ? strings.pick('Backup Email Address', 'Backup Email')
                      : strings.pick('Backup PH Mobile Number', 'Backup Mobile'),
                  isRequired: true,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('recovery_target_field'),
                        controller: _targetCtrl,
                        enabled: !_isSendingOtp && !_isSaving,
                        keyboardType: _mode == 'email'
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: _mode == 'email'
                              ? 'backup@email.com'
                              : '09171234567',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        key: const Key('recovery_send_otp_button'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: (_isSendingOtp || _cooldownSeconds > 0)
                            ? null
                            : _sendOtp,
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _cooldownSeconds > 0
                                    ? '${_cooldownSeconds}s'
                                    : strings.pick('Send OTP', 'Ipadala OTP'),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick(
                    '6-Digit Verification Code',
                    '6-Digit Verification Code',
                  ),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('recovery_otp_field'),
                  controller: _otpCtrl,
                  enabled: !_isSaving,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  style: CivicTheme.monoStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                  ),
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick(
                    'Current Password (Required)',
                    'Kasalukuyang Password (Kinakailangan)',
                  ),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('recovery_password_field'),
                  controller: _passwordCtrl,
                  enabled: !_isSaving,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: strings.passwordHint,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                CivicPrimaryButton(
                  key: const Key('recovery_save_button'),
                  label: strings.pick(
                    'Verify & Save Recovery Contact',
                    'I-verify at I-save ang Recovery Contact',
                  ),
                  icon: Icons.verified_user_outlined,
                  isLoading: _isSaving,
                  onPressed: _saveBinding,
                ),

                if (widget.user.hasAnyRecoveryContact) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('recovery_clear_button'),
                      onPressed: _isSaving ? null : _clearRecovery,
                      child: Text(
                        strings.pick(
                          'Remove Saved Recovery Contacts',
                          'Alisin ang Naka-save na Recovery Contact',
                        ),
                        style: const TextStyle(color: CivicColors.crimsonAlert),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
