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
import 'package:pinput/pinput.dart';

/// Mobile-first 3-Step Operator Registration with live TODA Roster Verification
/// and 6-digit OTP activation.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    this.prefillName,
    this.prefillContact,
  });

  final String? prefillName;
  final String? prefillContact;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 1; // 1 = Identity & TODA, 2 = Credentials & Privacy, 3 = OTP

  late final TextEditingController _nameController;
  late final TextEditingController _bodyNumberController;
  late final TextEditingController _contactController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedBarangay = '';
  String _selectedTodaId = '';
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _termsAccepted = false;

  bool _isCheckingRoster = false;
  RosterVerificationResult? _rosterResult;
  Timer? _rosterDebounce;

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prefillName ?? '');
    _bodyNumberController = TextEditingController();
    _contactController =
        TextEditingController(text: widget.prefillContact ?? '');

    _nameController.addListener(_scheduleRosterCheck);
    _bodyNumberController.addListener(_scheduleRosterCheck);
    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });
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
      setState(() {
        _rosterResult = const RosterVerificationResult(
          verified: false,
          status: 'pending_input',
          message:
              'Enter your Full Legal Name and Assigned Body Number to verify TODA masterlist status.',
        );
      });
      return;
    }

    _rosterDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _isCheckingRoster = true);
      try {
        final result = await ref.read(authRepositoryProvider).verifyTodaRoster(
              fullName: name,
              todaAssociation: _selectedTodaId,
              bodyNumber: body,
            );
        if (mounted) {
          setState(() => _rosterResult = result);
        }
      } catch (_) {
        // Keep silent on transient lookup errors; backend still enforces on submit.
      } finally {
        if (mounted) setState(() => _isCheckingRoster = false);
      }
    });
  }

  void _startResendCooldown() {
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

  void _showLguAdvisorySheet({
    required String message,
    Map<String, dynamic>? advisory,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final palette = ctx.civic;
        final title = (advisory?['title'] ??
                'Official LGU Gasan TODA Roster Advisory')
            .toString();
        final nextStep = (advisory?['nextSteps'] ??
                advisory?['instruction'] ??
                'Coordinate with your TODA President to confirm your legal name and assigned body number on the official masterlist submitted to the Office of the Municipal Vice Mayor (OVM) — LLSA I.')
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CivicColors.crimsonAlert.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: CivicColors.crimsonAlert,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CivicBanner(message: message, tone: CivicStatusTone.danger),
              const SizedBox(height: 14),
              Text(
                'What to do next',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                nextStep,
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 20),
              CivicPrimaryButton(
                label: 'Understood',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBarangayPicker() async {
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
                        'Select Gasan Barangay (25 Official)',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: queryController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search barangay...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              title: Text(
                                brgy,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
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
    if (_selectedBarangay.isEmpty) {
      setState(() {
        _errorMessage =
            'Select your Gasan Barangay first so accredited TODAs in your jurisdiction are displayed.';
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
                'Accredited TODA for $_selectedBarangay',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Filtered according to Municipality of Gasan route jurisdiction.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
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
                'Terms & Data Privacy Notice (RA 10173)',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'In compliance with the Philippine Data Privacy Act of 2012 (Republic Act No. 10173), all identity, TODA roster, and franchise information submitted through G-TRAMS Mobile is collected exclusively by the Municipality of Gasan — Office of the Municipal Vice Mayor (OVM) / LLSA I for MTOP registration, renewal, and regulatory verification.\n\nSensitive attributes excluded by LGU policy (driver blood type, personal payment amounts, and private document signatures) are never extracted by automated OCR.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted, height: 1.55),
              ),
              const SizedBox(height: 18),
              CivicPrimaryButton(
                label: 'Accept & Close',
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

  void _advanceFromStep1() {
    setState(() => _errorMessage = null);

    if (_nameController.text.trim().length < 2) {
      setState(() =>
          _errorMessage = 'Enter your full legal name (at least 2 characters).');
      return;
    }
    if (_selectedBarangay.isEmpty) {
      setState(() => _errorMessage = 'Select your Barangay in Gasan.');
      return;
    }
    if (_selectedTodaId.isEmpty || _selectedTodaId == 'NON-TODA') {
      setState(() => _errorMessage =
          'Under Municipal Ordinance, operators must select an accredited TODA.');
      return;
    }
    if (_bodyNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage =
          'Enter your Assigned Body Number from the official TODA masterlist.');
      return;
    }
    if (_rosterResult != null &&
        _rosterResult!.status != 'pending_input' &&
        !_rosterResult!.verified) {
      _showLguAdvisorySheet(
        message: _rosterResult!.message.isNotEmpty
            ? _rosterResult!.message
            : 'Registration blocked: Record not verified on official TODA masterlist.',
        advisory: _rosterResult!.advisory,
      );
      return;
    }

    setState(() => _step = 2);
  }

  Future<void> _submitRegistration() async {
    if (_isSubmitting) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final contact = _contactController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (!GasanConstants.isValidContact(contact)) {
      setState(() =>
          _errorMessage = 'Enter a valid email address or PH mobile number.');
      return;
    }
    if (!GasanConstants.isPasswordQualified(password)) {
      setState(() => _errorMessage =
          'Password must meet all 5 security requirements shown below.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_termsAccepted) {
      setState(() =>
          _errorMessage = 'Please accept the Terms and Data Privacy Notice.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final msg = await ref.read(authRepositoryProvider).registerOperator(
            fullName: _nameController.text,
            address: _selectedBarangay,
            todaAssociation: _selectedTodaId,
            bodyNumber: _bodyNumberController.text,
            contact: contact,
            password: password,
            confirmPassword: confirm,
          );
      if (!mounted) return;
      _startResendCooldown();
      setState(() {
        _successMessage = msg;
        _step = 3;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 || e.advisory != null) {
        _showLguAdvisorySheet(message: e.message, advisory: e.advisory);
      }
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_isSubmitting || _resendCooldown > 0) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final msg = await ref.read(authRepositoryProvider).registerOperator(
            fullName: _nameController.text,
            address: _selectedBarangay,
            todaAssociation: _selectedTodaId,
            bodyNumber: _bodyNumberController.text,
            contact: _contactController.text,
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
          );
      if (!mounted) return;
      _startResendCooldown();
      setState(() => _successMessage = msg);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_isSubmitting) return;
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _errorMessage = 'Enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = await ref.read(authRepositoryProvider).verifyRegistrationOtp(
            contact: _contactController.text,
            otp: code,
          );
      if (!mounted) return;
      if (user != null) {
        ref.read(authControllerProvider.notifier).setAuthenticatedUser(user);
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified! Please sign in to continue.'),
          ),
        );
        context.go('/login');
      }
    } on StaffRoleBlockedException catch (blocked) {
      if (!mounted) return;
      await showStaffRoleGuardDialog(context, displayRole: blocked.displayRole);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _rosterDebounce?.cancel();
    _resendTimer?.cancel();
    _nameController.dispose();
    _bodyNumberController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);

    final stepTitle = switch (_step) {
      1 => strings.step1Title,
      2 => strings.step2Title,
      _ => strings.step3Title,
    };

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step > 1) {
              setState(() {
                _step -= 1;
                _errorMessage = null;
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
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
                    strings.registerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    strings.pick(
                      'Step $_step of 3 · $stepTitle',
                      'Hakbang $_step ng 3 · $stepTitle',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 3-segment step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Row(
              children: List.generate(3, (i) {
                final active = (i + 1) <= _step;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          active ? CivicColors.gasanMaroon : palette.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: CivicCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                        if (_step == 1) _buildStep1(strings, palette),
                        if (_step == 2) _buildStep2(strings, palette),
                        if (_step == 3) _buildStep3(strings, palette),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AppStrings strings, CivicPalette palette) {
    final resolvedZone = GasanConstants.getZoneForBarangay(_selectedBarangay);
    final selectedToda = GasanConstants.findTodaById(_selectedTodaId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CivicFieldLabel(text: strings.fullNameLabel, isRequired: true),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: strings.fullNameHint,
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 16),

        CivicFieldLabel(text: strings.barangayLabel, isRequired: true),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openBarangayPicker,
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedBarangay.isEmpty
                        ? strings.selectBarangay
                        : _selectedBarangay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _selectedBarangay.isEmpty
                              ? palette.muted
                              : palette.ink,
                          fontWeight: _selectedBarangay.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (resolvedZone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  CivicStatusBadge(
                    label: '$resolvedZone Zone',
                    tone: CivicStatusTone.neutral,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        CivicFieldLabel(text: strings.todaLabel, isRequired: true),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openTodaPicker,
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.groups_outlined, size: 20),
              suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: Text(
              selectedToda?.name ?? strings.selectToda,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selectedToda == null ? palette.muted : palette.ink,
                    fontWeight: selectedToda == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 16),

        CivicFieldLabel(text: strings.bodyNumberLabel, isRequired: true),
        TextField(
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
        const SizedBox(height: 14),

        // Live TODA Roster Verification Status
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

        const SizedBox(height: 22),
        CivicPrimaryButton(
          label: strings.next,
          icon: Icons.arrow_forward_rounded,
          onPressed: _advanceFromStep1,
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                strings.alreadyHaveAccount.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.pop(),
                child: Text(
                  strings.signIn,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.brandAccent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(AppStrings strings, CivicPalette palette) {
    final rules =
        GasanConstants.evaluatePasswordRules(_passwordController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CivicFieldLabel(text: strings.contactLabel, isRequired: true),
        TextField(
          controller: _contactController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: strings.contactHint,
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 16),

        CivicFieldLabel(text: strings.passwordLabel, isRequired: true),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            hintText: strings.passwordHint,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 5-Rule Live Strength Checklist
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.canvas,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: rules.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Icon(
                      r.met
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: r.met ? CivicColors.civicGreen : palette.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.isFil ? r.labelFil : r.labelEn,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: r.met
                                  ? CivicColors.civicGreen
                                  : palette.muted,
                              fontWeight:
                                  r.met ? FontWeight.w600 : FontWeight.w400,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        CivicFieldLabel(text: strings.confirmPasswordLabel, isRequired: true),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPassword,
          decoration: InputDecoration(
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _showConfirmPassword = !_showConfirmPassword,
              ),
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: _termsAccepted,
                activeColor: CivicColors.gasanMaroon,
                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _showTermsSheet,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    strings.acceptTerms,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        CivicPrimaryButton(
          label: strings.sendOtp,
          icon: Icons.mark_email_read_outlined,
          isLoading: _isSubmitting,
          onPressed: _submitRegistration,
        ),
      ],
    );
  }

  Widget _buildStep3(AppStrings strings, CivicPalette palette) {
    final pinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: CivicTheme.monoStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: palette.ink,
      ),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border, width: 1.2),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CivicColors.gasanMaroon.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: CivicColors.gasanMaroon,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Enter 6-Digit Verification Code',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Sent to ${_contactController.text.trim()}',
          textAlign: TextAlign.center,
          style: CivicTheme.monoStyle(
            fontSize: 12,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 22),

        Pinput(
          controller: _otpController,
          length: 6,
          defaultPinTheme: pinTheme,
          focusedPinTheme: pinTheme.copyWith(
            decoration: pinTheme.decoration!.copyWith(
              border: Border.all(color: palette.brandAccent, width: 1.8),
            ),
          ),
          onCompleted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 22),

        CivicPrimaryButton(
          label: strings.verifyAndContinue,
          icon: Icons.check_circle_outline_rounded,
          isLoading: _isSubmitting,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: (_resendCooldown > 0 || _isSubmitting) ? null : _resendOtp,
          child: Text(
            _resendCooldown > 0
                ? '${strings.resendCode} (${_resendCooldown}s)'
                : strings.resendCode,
          ),
        ),
      ],
    );
  }
}
