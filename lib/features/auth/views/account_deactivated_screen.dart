import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:gtrams_mobile/shared/widgets/google_g_logo.dart';

/// Displays account deactivation notice and allows submitting a reactivation appeal
/// via password or Google identity verification.
class AccountDeactivatedScreen extends ConsumerStatefulWidget {
  const AccountDeactivatedScreen({super.key, required this.args});

  final DeactivatedAccountArgs args;

  @override
  ConsumerState<AccountDeactivatedScreen> createState() =>
      _AccountDeactivatedScreenState();
}

class _AccountDeactivatedScreenState
    extends ConsumerState<AccountDeactivatedScreen> {
  final _passwordController = TextEditingController();
  final _messageController = TextEditingController();

  late String _appealStatus;
  late bool _useGoogleVerify;
  String? _googleIdToken;
  String? _googleAccessToken;
  bool _isVerifyingGoogle = false;
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _appealStatus = widget.args.appealStatus;
    _useGoogleVerify = !widget.args.hasLocalPassword ||
        widget.args.authProvider.toLowerCase() == 'google';
  }

  Future<void> _verifyWithGoogle() async {
    if (_isVerifyingGoogle) return;
    setState(() {
      _isVerifyingGoogle = true;
      _error = null;
    });
    try {
      final creds =
          await ref.read(authRepositoryProvider).acquireGoogleCredentials();
      if (!mounted) return;
      setState(() {
        _googleIdToken = creds.idToken;
        _googleAccessToken = creds.accessToken;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isVerifyingGoogle = false);
    }
  }

  Future<void> _submitAppeal() async {
    if (_isSubmitting || _appealStatus == 'pending') return;
    final strings = AppStrings(ref.read(appPreferencesProvider).language);
    final hasGoogleToken = (_googleIdToken?.isNotEmpty ?? false) ||
        (_googleAccessToken?.isNotEmpty ?? false);

    if (_messageController.text.trim().isEmpty) {
      setState(() {
        _error = strings.pick(
          'Enter your reason for reactivation.',
          'Ilagay ang dahilan ng iyong apela.',
        );
      });
      return;
    }

    if (_useGoogleVerify) {
      if (!hasGoogleToken) {
        setState(() {
          _error = strings.pick(
            'Verify your Google account first before submitting your appeal.',
            'I-verify muna ang iyong Google account bago isumite ang apela.',
          );
        });
        return;
      }
    } else if (_passwordController.text.isEmpty) {
      setState(() {
        _error = strings.pick(
          'Enter your password to confirm account ownership.',
          'Ilagay ang iyong password upang kumpirmahin ang account.',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _success = null;
    });

    try {
      final msg =
          await ref.read(authRepositoryProvider).submitDeactivationAppeal(
                contact: widget.args.contact,
                password: _useGoogleVerify ? '' : _passwordController.text,
                googleIdToken: _useGoogleVerify ? _googleIdToken : null,
                googleAccessToken: _useGoogleVerify ? _googleAccessToken : null,
                message: _messageController.text,
              );
      if (!mounted) return;
      setState(() {
        _appealStatus = 'pending';
        _success = msg;
        _passwordController.clear();
        _messageController.clear();
        _googleIdToken = null;
        _googleAccessToken = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (_useGoogleVerify && e.statusCode == 401) {
          _googleIdToken = null;
          _googleAccessToken = null;
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final hasGoogleVerified = (_googleIdToken?.isNotEmpty ?? false) ||
        (_googleAccessToken?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(
          strings.pick('Account Deactivated', 'Na-deactivate ang Account'),
        ),
      ),
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
                        width: 44,
                        height: 44,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'G-TRAMS Mobile',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Municipality of Gasan • OVM — LLSA I',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CivicBanner(
                    title: strings.pick(
                      'Account Access Restricted',
                      'Limitado ang Access ng Account',
                    ),
                    message: widget.args.reason.isNotEmpty
                        ? widget.args.reason
                        : strings.pick(
                            'Your account has been deactivated by the system administrator.',
                            'Na-deactivate ang iyong account ng system administrator.',
                          ),
                    tone: CivicStatusTone.danger,
                  ),
                  const SizedBox(height: 16),

                  if (_success != null) ...[
                    CivicBanner(
                      message: _success!,
                      tone: CivicStatusTone.active,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null) ...[
                    CivicBanner(
                      message: _error!,
                      tone: CivicStatusTone.danger,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_appealStatus == 'pending')
                    CivicBanner(
                      title: strings.pick(
                        'Appeal Pending Review',
                        'Sinusuri ang Iyong Apela',
                      ),
                      message: strings.pick(
                        'Your reactivation appeal has been submitted and is awaiting review by the municipal administrator.',
                        'Naisumite na ang iyong apela at kasalukuyang sinusuri ng municipal administrator.',
                      ),
                      tone: CivicStatusTone.inProgress,
                    )
                  else ...[
                    Text(
                      strings.pick(
                        'Submit Reactivation Appeal',
                        'Magsumite ng Apela',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    if (_useGoogleVerify) ...[
                      CivicFieldLabel(
                        text: strings.pick(
                          'Google Identity Check',
                          'Beripikasyon sa Google',
                        ),
                        isRequired: true,
                      ),
                      if (hasGoogleVerified)
                        CivicBanner(
                          message: strings.pick(
                            'Google account verified. You can now submit your appeal.',
                            'Beripikado ang Google account. Maaari mo nang isumite ang apela.',
                          ),
                          tone: CivicStatusTone.active,
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: palette.surface,
                            side: BorderSide(color: palette.border),
                          ),
                          onPressed:
                              _isVerifyingGoogle ? null : _verifyWithGoogle,
                          child: _isVerifyingGoogle
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
                                    Text(
                                      strings.pick(
                                        'Verify with Google',
                                        'I-verify gamit ang Google',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _useGoogleVerify = false),
                          child: Text(
                            strings.pick(
                              'Use password instead',
                              'Gumamit ng password',
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      CivicFieldLabel(
                        text: strings.passwordLabel,
                        isRequired: true,
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: strings.pick(
                            'Confirm account password',
                            'Ilagay ang iyong password',
                          ),
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _useGoogleVerify = true),
                          child: Text(
                            strings.pick(
                              'Signed up with Google? Verify with Google',
                              'Gumamit ng Google? I-verify sa Google',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    CivicFieldLabel(
                      text: strings.pick(
                        'Reason for Reactivation',
                        'Dahilan ng Apela',
                      ),
                      isRequired: true,
                    ),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: strings.pick(
                          'Explain why your account should be reactivated...',
                          'Ipaliwanag kung bakit dapat ibalik ang iyong account...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    CivicPrimaryButton(
                      label: strings.pick('Submit Appeal', 'Isumite ang Apela'),
                      icon: Icons.send_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _submitAppeal,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      strings.pick('Back to Sign In', 'Bumalik sa Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
