import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens the Individual Member Registration sheet (`POST /toda/members/individual`)
/// with automatic collision-free next Body Number lookup (`GET /toda/next-body-number`).
Future<String?> showAddTodaMemberSheet(
  BuildContext context, {
  required String todaName,
  required AppStrings strings,
  required Future<String> Function() onFetchNextBodyNumber,
  required Future<String> Function({
    required String operatorName,
    required String bodyNumber,
    required String plateNo,
    required String contact,
    required String remarks,
  }) onSubmit,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: AddTodaMemberSheet(
        todaName: todaName,
        strings: strings,
        onFetchNextBodyNumber: onFetchNextBodyNumber,
        onSubmit: onSubmit,
      ),
    ),
  );
}

class AddTodaMemberSheet extends StatefulWidget {
  const AddTodaMemberSheet({
    super.key,
    required this.todaName,
    required this.strings,
    required this.onFetchNextBodyNumber,
    required this.onSubmit,
  });

  final String todaName;
  final AppStrings strings;
  final Future<String> Function() onFetchNextBodyNumber;
  final Future<String> Function({
    required String operatorName,
    required String bodyNumber,
    required String plateNo,
    required String contact,
    required String remarks,
  }) onSubmit;

  @override
  State<AddTodaMemberSheet> createState() => _AddTodaMemberSheetState();
}

class _AddTodaMemberSheetState extends State<AddTodaMemberSheet> {
  final _nameCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _loadingNextBody = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNextBodyNumber();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    _plateCtrl.dispose();
    _contactCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNextBodyNumber() async {
    setState(() => _loadingNextBody = true);
    try {
      final next = await widget.onFetchNextBodyNumber();
      if (!mounted) return;
      if (next.isNotEmpty) {
        _bodyCtrl.text = next;
      }
    } catch (_) {
      // Operator can still type manually or leave empty for backend auto-assign
    } finally {
      if (mounted) setState(() => _loadingNextBody = false);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() {
        _error = widget.strings.pick(
          'Enter the operator\'s full legal name (at least 2 characters).',
          'Ilagay ang buong legal na pangalan ng operator (hindi bababa sa 2 karakter).',
        );
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await widget.onSubmit(
        operatorName: name,
        bodyNumber: _bodyCtrl.text.trim().toUpperCase(),
        plateNo: _plateCtrl.text.trim().toUpperCase(),
        contact: _contactCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(message);
    } catch (err) {
      if (!mounted) return;
      final apiErr = ApiClient.mapDioError(err);
      final suggested = apiErr.rawData?['suggestedBodyNumber']?.toString();
      if (suggested != null && suggested.trim().isNotEmpty) {
        _bodyCtrl.text = suggested.trim();
      }
      setState(() {
        _error = apiErr.message;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.addMemberAction,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.todaName,
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.brandAccent,
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

          if (_error != null) ...[
            CivicBanner(tone: CivicStatusTone.danger, message: _error!),
            const SizedBox(height: 12),
          ],

          CivicFieldLabel(text: strings.fullNameLabel, isRequired: true),
          TextField(
            key: const Key('add_member_name_field'),
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: strings.fullNameHint,
              prefixIcon: Icon(Icons.person_outline_rounded, color: palette.muted),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: CivicFieldLabel(text: strings.bodyNumberLabel),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed:
                    (_loadingNextBody || _isSubmitting) ? null : _loadNextBodyNumber,
                icon: _loadingNextBody
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 15),
                label: Text(
                  strings.autoNextBodyNo,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          TextField(
            key: const Key('add_member_body_field'),
            controller: _bodyCtrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: strings.pick(
                'Auto-assigned if left blank (e.g. 042)',
                'Awtomatiko kung iiwang blangko (hal. 042)',
              ),
              prefixIcon: Icon(Icons.tag_rounded, color: palette.muted),
            ),
          ),
          const SizedBox(height: 12),

          CivicFieldLabel(
            text: strings.pick('Plate Number (Optional)', 'Plaka (Opsyonal)'),
          ),
          TextField(
            key: const Key('add_member_plate_field'),
            controller: _plateCtrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(hintText: 'e.g. ABC-1234'),
          ),
          const SizedBox(height: 12),

          CivicFieldLabel(
            text: strings.pick('Mobile Number (Optional)', 'Numero ng Cellphone (Opsyonal)'),
          ),
          TextField(
            controller: _contactCtrl,
            keyboardType: TextInputType.phone,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(hintText: '09171234567'),
          ),
          const SizedBox(height: 12),

          CivicFieldLabel(
            text: strings.pick('Remarks (Optional)', 'Tala (Opsyonal)'),
          ),
          TextField(
            controller: _remarksCtrl,
            maxLines: 2,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: strings.pick(
                'Optional membership note...',
                'Opsyonal na tala sa miyembro...',
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(strings.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CivicPrimaryButton(
                  key: const Key('add_member_submit_button'),
                  label: strings.addMemberAction,
                  icon: Icons.person_add_alt_1_outlined,
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
