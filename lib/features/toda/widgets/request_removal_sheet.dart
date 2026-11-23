import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens the Member Disaffiliation / Removal Request sheet (`POST /toda/removal-requests`).
Future<bool?> showRequestRemovalSheet(
  BuildContext context, {
  required TodaMemberProfile member,
  required String todaName,
  required AppStrings strings,
  required Future<void> Function({
    required String memberId,
    required String reason,
    required String details,
  }) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: RequestRemovalSheet(
        member: member,
        todaName: todaName,
        strings: strings,
        onSubmit: onSubmit,
      ),
    ),
  );
}

class RequestRemovalSheet extends StatefulWidget {
  const RequestRemovalSheet({
    super.key,
    required this.member,
    required this.todaName,
    required this.strings,
    required this.onSubmit,
  });

  final TodaMemberProfile member;
  final String todaName;
  final AppStrings strings;
  final Future<void> Function({
    required String memberId,
    required String reason,
    required String details,
  }) onSubmit;

  @override
  State<RequestRemovalSheet> createState() => _RequestRemovalSheetState();
}

class _RequestRemovalSheetState extends State<RequestRemovalSheet> {
  String _reason = kTodaRemovalReasons.first;
  final _detailsCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);
    final details = _detailsCtrl.text.trim();
    if (details.isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Please provide a clear explanation for this removal request.',
          'Maglagay ng malinaw na paliwanag para sa kahilingang pag-alis ng miyembro.',
        );
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        memberId: widget.member.id,
        reason: _reason,
        details: details,
      );
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
                  Icons.person_remove_outlined,
                  color: CivicColors.crimsonAlert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.requestRemovalAction,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.member.name}${widget.member.bodyNumber.isNotEmpty ? ' • BODY #${widget.member.bodyNumber}' : ''}',
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
          const SizedBox(height: 12),

          CivicBanner(
            tone: CivicStatusTone.inProgress,
            message: strings.pick(
              'Disaffiliation requests are reviewed by the Office of the Municipal Vice Mayor (OVM) — LLSA I before updating the official ${widget.todaName} roster.',
              'Susuriin ng Office of the Municipal Vice Mayor (OVM) — LLSA I ang kahilingang pag-alis bago baguhin ang opisyal na roster ng ${widget.todaName}.',
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            CivicBanner(tone: CivicStatusTone.danger, message: _error!),
          ],

          const SizedBox(height: 14),
          CivicFieldLabel(
            text: strings.pick('Official Removal Reason', 'Opisyal na Dahilan'),
            isRequired: true,
          ),
          DropdownButtonFormField<String>(
            key: const Key('removal_reason_dropdown'),
            initialValue: _reason,
            isExpanded: true,
            items: kTodaRemovalReasons
                .map(
                  (r) => DropdownMenuItem<String>(
                    value: r,
                    child: Text(r, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (val) {
                    if (val != null) setState(() => _reason = val);
                  },
          ),
          const SizedBox(height: 14),

          CivicFieldLabel(
            text: strings.pick(
              'Detailed Explanation / Board Action',
              'Detalyadong Paliwanag',
            ),
            isRequired: true,
          ),
          TextField(
            key: const Key('removal_details_field'),
            controller: _detailsCtrl,
            maxLines: 4,
            maxLength: 500,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: strings.pick(
                'Provide dates, board resolution, or circumstances supporting disaffiliation...',
                'Ilagay ang petsa, resolusyon ng samahan, o paliwanag ng pag-alis...',
              ),
            ),
          ),
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
                  key: const Key('removal_submit_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CivicColors.crimsonAlert,
                    foregroundColor: CivicColors.purePaper,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CivicColors.purePaper,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 17),
                  label: Text(strings.requestRemovalAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
