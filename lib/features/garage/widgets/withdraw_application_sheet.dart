import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens the modal bottom sheet for withdrawing an unpaid pending application
/// (`PUT /api/v1/franchises/:id/cancel`).
Future<bool?> showWithdrawApplicationSheet(
  BuildContext context, {
  required FranchiseRecord unit,
  required AppStrings strings,
  required Future<void> Function(String cancelReason) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: WithdrawApplicationSheet(
        unit: unit,
        strings: strings,
        onSubmit: onSubmit,
      ),
    ),
  );
}

class WithdrawApplicationSheet extends StatefulWidget {
  const WithdrawApplicationSheet({
    super.key,
    required this.unit,
    required this.strings,
    required this.onSubmit,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final Future<void> Function(String cancelReason) onSubmit;

  @override
  State<WithdrawApplicationSheet> createState() =>
      _WithdrawApplicationSheetState();
}

class _WithdrawApplicationSheetState extends State<WithdrawApplicationSheet> {
  String _selectedReason = kWithdrawApplicationReasons.first;
  final TextEditingController _customCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  static const String _otherOption = 'Other reason (Please specify below)';

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _error = null);

    final isOther = _selectedReason == _otherOption;
    final finalReason = isOther ? _customCtrl.text.trim() : _selectedReason;

    if (isOther && finalReason.isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Please enter your specific reason for withdrawing this application.',
          'Pakisulat ang dahilan ng pag-withdraw ng aplikasyon.',
        );
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(finalReason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.mapDioError(err).message;
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  Icons.cancel_outlined,
                  color: CivicColors.crimsonAlert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.withdrawSheetTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.plateNumberLabel} ${widget.unit.plateNo.isNotEmpty ? widget.unit.plateNo : 'PENDING'}',
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.close,
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),

          CivicBanner(
            tone: CivicStatusTone.inProgress,
            message: strings.withdrawAdvisory,
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            CivicBanner(tone: CivicStatusTone.danger, message: _error!),
          ],

          const SizedBox(height: 16),
          CivicFieldLabel(
            text: strings.pick(
              'Select Reason for Withdrawal',
              'Piliin ang Dahilan ng Pag-withdraw',
            ),
            isRequired: true,
          ),
          const SizedBox(height: 4),
          ...kWithdrawApplicationReasons.map((reason) {
            final selected = _selectedReason == reason;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isSubmitting
                    ? null
                    : () => setState(() {
                          _selectedReason = reason;
                          _error = null;
                        }),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? CivicColors.crimsonAlert.withValues(alpha: 0.08)
                        : palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected ? CivicColors.crimsonAlert : palette.border,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: selected
                            ? CivicColors.crimsonAlert
                            : palette.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (_selectedReason == _otherOption) ...[
            const SizedBox(height: 6),
            CivicFieldLabel(
              text: strings.pick(
                'Specify Reason Details',
                'Isulat ang Partikular na Dahilan',
              ),
              isRequired: true,
            ),
            TextField(
              key: const Key('withdraw_custom_reason_field'),
              controller: _customCtrl,
              maxLines: 3,
              maxLength: 300,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: strings.pick(
                  'Enter details on why you are withdrawing...',
                  'Ilagay ang dahilan kung bakit mo iwi-withdraw...',
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('withdraw_confirm_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CivicColors.crimsonAlert,
                    foregroundColor: CivicColors.purePaper,
                  ),
                  onPressed: _isSubmitting ? null : _handleConfirm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CivicColors.purePaper,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(strings.confirmWithdraw),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
