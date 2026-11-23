import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

typedef ChangePasswordCallback = Future<ChangePasswordResult> Function({
  required String oldPassword,
  required String newPassword,
});

/// Bottom sheet for `PUT /api/v1/auth/change-password` (`{ oldPassword, newPassword }`)
/// with live 5-rule password policy feedback and seamless JWT rotation.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({
    super.key,
    required this.user,
    required this.strings,
    required this.onChangePassword,
  });

  final MobileUser user;
  final AppStrings strings;
  final ChangePasswordCallback onChangePassword;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final oldPass = _oldCtrl.text;
    final newPass = _newCtrl.text;
    final confirmPass = _confirmCtrl.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Please complete all password fields.',
          'Pakipunan ang lahat ng field ng password.',
        );
      });
      return;
    }
    if (newPass != confirmPass) {
      setState(() {
        _error = widget.strings.pick(
          'New password and confirmation do not match.',
          'Hindi magkatugma ang bagong password at kumpirmasyon.',
        );
      });
      return;
    }
    if (oldPass == newPass) {
      setState(() {
        _error = widget.strings.pick(
          'New password must be different from your current password.',
          'Dapat iba ang bagong password sa kasalukuyang password.',
        );
      });
      return;
    }
    if (!GasanConstants.isPasswordQualified(newPass)) {
      setState(() {
        _error = widget.strings.pick(
          'Password must be at least 8 characters with uppercase, lowercase, number, and symbol.',
          'Ang password ay dapat may 8+ karakter, malaking letra, maliit na letra, numero, at simbolo.',
        );
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await widget.onChangePassword(
        oldPassword: oldPass,
        newPassword: newPass,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
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
    final val = _newCtrl.text;

    final checks = [
      (val.length >= 8, strings.pick('8+ characters', '8+ karakter')),
      (
        RegExp(r'[A-Z]').hasMatch(val),
        strings.pick('Uppercase (A-Z)', 'Malaking letra'),
      ),
      (
        RegExp(r'[a-z]').hasMatch(val),
        strings.pick('Lowercase (a-z)', 'Maliit na letra'),
      ),
      (RegExp(r'[0-9]').hasMatch(val), strings.pick('Number (0-9)', 'Numero')),
      (
        RegExp(r'[^A-Za-z0-9]').hasMatch(val),
        strings.pick('Symbol (!@#)', 'Simbolo'),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        child: SingleChildScrollView(
          key: const Key('change_password_scroll'),
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
                strings.changePasswordTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                strings.pick(
                  'Changing your password immediately signs out other active devices for your account security.',
                  'Ang pagpalit ng password ay awtomatikong magsa-sign out sa ibang device para sa seguridad ng iyong account.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),

              if (widget.user.isGoogleOnlyAccount)
                CivicBanner(
                  tone: CivicStatusTone.inProgress,
                  title: strings.pick(
                    'Google Sign-In Account',
                    'Google Sign-In Account',
                  ),
                  message: strings.pick(
                    'Your account uses Google authentication without a local password. Manage password security in your Google Account settings.',
                    'Gumagamit ng Google Sign-In ang iyong account at walang lokal na password. Pamahalaan ito sa iyong Google Account settings.',
                  ),
                )
              else ...[
                if (_error != null) ...[
                  CivicBanner(tone: CivicStatusTone.danger, message: _error!),
                  const SizedBox(height: 12),
                ],

                CivicFieldLabel(
                  text: strings.pick('Current Password', 'Kasalukuyang Password'),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('change_pass_old_field'),
                  controller: _oldCtrl,
                  enabled: !_isSaving,
                  obscureText: !_showOld,
                  decoration: InputDecoration(
                    hintText: strings.passwordHint,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showOld = !_showOld),
                      icon: Icon(
                        _showOld
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick('New Password', 'Bagong Password'),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('change_pass_new_field'),
                  controller: _newCtrl,
                  enabled: !_isSaving,
                  obscureText: !_showNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Gasan@2026!',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showNew = !_showNew),
                      icon: Icon(
                        _showNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: checks.map((c) {
                    final passed = c.$1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: passed
                            ? CivicColors.civicGreen.withValues(alpha: 0.14)
                            : palette.canvas,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: passed
                              ? CivicColors.civicGreen.withValues(alpha: 0.4)
                              : palette.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            passed
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 13,
                            color: passed
                                ? CivicColors.civicGreen
                                : palette.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.$2,
                            style: CivicTheme.monoStyle(
                              fontSize: 10,
                              color: passed
                                  ? CivicColors.civicGreen
                                  : palette.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick(
                    'Confirm New Password',
                    'Kumpirmahin ang Bagong Password',
                  ),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('change_pass_confirm_field'),
                  controller: _confirmCtrl,
                  enabled: !_isSaving,
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    hintText: strings.pick(
                      'Re-enter new password',
                      'Ilagay muli ang bagong password',
                    ),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(
                        _showConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                CivicPrimaryButton(
                  key: const Key('change_pass_submit_button'),
                  label: strings.changePasswordTitle,
                  icon: Icons.lock_reset_rounded,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
