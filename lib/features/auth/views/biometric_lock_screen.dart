import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Returning-operator Fingerprint / Face quick unlock screen.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptUnlock());
  }

  Future<void> _promptUnlock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    final ok = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometrics('Verify your identity to open G-TRAMS Mobile');

    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (ok) {
      context.go('/home');
    } else {
      setState(() {
        _error =
            'Biometric verification did not complete. Try again or sign in with your password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final auth = ref.watch(authControllerProvider);
    final strings = AppStrings(ref.watch(appPreferencesProvider).language);
    final user = auth.user;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: CivicCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.canvas,
                        border: Border.all(
                          color: CivicColors.gasanGold,
                          width: 1.6,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/gasan-logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user?.name ?? 'G-TRAMS Operator',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (user != null)
                      CivicStatusBadge(
                        label: user.roleDisplayTitle,
                        tone: CivicStatusTone.active,
                        icon: Icons.verified_user_outlined,
                      ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      CivicBanner(
                        message: _error!,
                        tone: CivicStatusTone.inProgress,
                      ),
                      const SizedBox(height: 16),
                    ],
                    CivicPrimaryButton(
                      label: strings.biometricUnlock,
                      icon: Icons.fingerprint_rounded,
                      isLoading: _isAuthenticating,
                      onPressed: _promptUnlock,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Use Password Instead'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
