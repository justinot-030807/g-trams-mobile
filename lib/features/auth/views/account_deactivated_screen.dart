import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Displays account deactivation notice and allows submitting a reactivation appeal.
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
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _appealStatus = widget.args.appealStatus;
  }

  Future<void> _submitAppeal() async {
    if (_isSubmitting || _appealStatus == 'pending') return;
    if (_messageController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password and appeal explanation.');
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
                password: _passwordController.text,
                message: _messageController.text,
              );
      if (!mounted) return;
      setState(() {
        _appealStatus = 'pending';
        _success = msg;
        _passwordController.clear();
        _messageController.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Account Deactivated')),
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
                  CivicBanner(
                    title: 'Account Access Restricted',
                    message: widget.args.reason.isNotEmpty
                        ? widget.args.reason
                        : 'Your account has been deactivated by the system administrator.',
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
                    const CivicBanner(
                      title: 'Appeal Pending Review',
                      message:
                          'Your reactivation appeal has been logged and is awaiting review by the municipal system administrator.',
                      tone: CivicStatusTone.inProgress,
                    )
                  else ...[
                    Text(
                      'Submit Reactivation Appeal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const CivicFieldLabel(text: 'Password', isRequired: true),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Confirm account password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const CivicFieldLabel(
                      text: 'Reason for Reactivation',
                      isRequired: true,
                    ),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Explain why your operator account should be reactivated...',
                      ),
                    ),
                    const SizedBox(height: 18),
                    CivicPrimaryButton(
                      label: 'Submit Appeal',
                      icon: Icons.send_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _submitAppeal,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to Sign In'),
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
