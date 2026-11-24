import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

enum _LetterInputMode { type, upload }

/// Payload submitted by [VoluntaryCancellationSheet].
class VoluntaryCancellationPayload {
  const VoluntaryCancellationPayload({
    required this.reason,
    this.customReason = '',
    this.remarks = '',
    this.letterText,
    this.fileBytes,
    this.fileName,
    this.mimeType,
  });

  final String reason;
  final String customReason;
  final String remarks;
  final String? letterText;
  final Uint8List? fileBytes;
  final String? fileName;
  final String? mimeType;
}

/// Opens the Voluntary Franchise Cancellation Request sheet
/// (`PUT /api/v1/franchises/:id/request-cancellation`).
Future<bool?> showVoluntaryCancellationSheet(
  BuildContext context, {
  required FranchiseRecord unit,
  required AppStrings strings,
  required Future<void> Function(VoluntaryCancellationPayload payload) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: VoluntaryCancellationSheet(
          unit: unit,
          strings: strings,
          onSubmit: onSubmit,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class VoluntaryCancellationSheet extends StatefulWidget {
  const VoluntaryCancellationSheet({
    super.key,
    required this.unit,
    required this.strings,
    required this.onSubmit,
    this.scrollController,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final Future<void> Function(VoluntaryCancellationPayload payload) onSubmit;
  final ScrollController? scrollController;

  @override
  State<VoluntaryCancellationSheet> createState() =>
      _VoluntaryCancellationSheetState();
}

class _VoluntaryCancellationSheetState
    extends State<VoluntaryCancellationSheet> {
  static const int _maxFileBytes = 10 * 1024 * 1024; // 10MB

  String _reason = kVoluntaryCancellationReasons.first.value;
  _LetterInputMode _mode = _LetterInputMode.type;
  final TextEditingController _customReasonCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _letterCtrl = TextEditingController();

  bool _hasManuallyEditedLetter = false;
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  String? _pickedMimeType;

  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncTemplate(force: true);
    _customReasonCtrl.addListener(_onAutoTemplateDependencyChanged);
    _remarksCtrl.addListener(_onAutoTemplateDependencyChanged);
  }

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    _remarksCtrl.dispose();
    _letterCtrl.dispose();
    super.dispose();
  }

  void _onAutoTemplateDependencyChanged() {
    if (!_hasManuallyEditedLetter) {
      _syncTemplate();
    }
  }

  void _syncTemplate({bool force = false}) {
    if (!force && _hasManuallyEditedLetter) return;
    _letterCtrl.text = widget.unit.buildVoluntaryCancellationLetter(
      reason: _reason,
      customReason: _customReasonCtrl.text,
      remarks: _remarksCtrl.text,
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = widget.strings.pick(
            'Could not read the selected file. Please choose another image or PDF.',
            'Hindi mabasa ang napiling file. Pumili ng ibang larawan o PDF.',
          );
        });
        return;
      }
      if (bytes.length > _maxFileBytes) {
        setState(() {
          _error = widget.strings.pick(
            'File exceeds the 10 MB limit. Please upload a smaller photo or PDF.',
            'Lampas sa 10 MB ang file. Mag-upload ng mas maliit na larawan o PDF.',
          );
        });
        return;
      }

      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      setState(() {
        _pickedBytes = bytes;
        _pickedFileName = file.name;
        _pickedMimeType = mime;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = widget.strings.pick(
          'Unable to open file picker. You can still type your formal letter directly.',
          'Hindi mabuksan ang file picker. Maaari mong i-type nang direkta ang pormal na liham.',
        );
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);

    if (_reason == 'Other' && _customReasonCtrl.text.trim().isEmpty) {
      setState(() {
        _error = widget.strings.pick(
          'Please specify your custom reason for cancellation.',
          'Pakisulat ang partikular na dahilan ng pagkakansela.',
        );
      });
      return;
    }

    if (_mode == _LetterInputMode.type) {
      if (_letterCtrl.text.trim().length < 30) {
        setState(() {
          _error = widget.strings.pick(
            'Formal cancellation letter must be at least 30 characters.',
            'Ang pormal na liham ay dapat may hindi bababa sa 30 karakter.',
          );
        });
        return;
      }
    } else {
      if (_pickedBytes == null || _pickedBytes!.isEmpty) {
        setState(() {
          _error = widget.strings.pick(
            'Please upload a signed photo or PDF copy of your cancellation letter.',
            'Mag-upload ng litrato o PDF ng iyong nilagdaang liham ng pagkansela.',
          );
        });
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        VoluntaryCancellationPayload(
          reason: _reason,
          customReason: _customReasonCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim(),
          letterText:
              _mode == _LetterInputMode.type ? _letterCtrl.text.trim() : null,
          fileBytes: _mode == _LetterInputMode.upload ? _pickedBytes : null,
          fileName: _mode == _LetterInputMode.upload ? _pickedFileName : null,
          mimeType: _mode == _LetterInputMode.upload ? _pickedMimeType : null,
        ),
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
    final isImage = _pickedMimeType?.startsWith('image/') == true;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: palette.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CivicColors.crimsonAlert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_return_outlined,
                  color: CivicColors.crimsonAlert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.voluntaryCancelTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.unit.plateNo.isNotEmpty ? widget.unit.plateNo : 'PENDING'} • ${widget.unit.todaName}',
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
        ),
        Divider(height: 1, color: palette.border),

        Expanded(
          child: ListView(
            key: const Key('voluntary_cancel_list'),
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              CivicBanner(
                tone: CivicStatusTone.danger,
                icon: Icons.gavel_outlined,
                title: strings.pick(
                  'Surrender Notice',
                  'Abiso ng Pagsuko ng Prangkisa',
                ),
                message: strings.pick(
                  'Sets your franchise to "Cancellation Requested" for OVM — LLSA I review. No Cashier payment needed.',
                  'Ilalagay ang prangkisa sa "Cancellation Requested" para sa pagsusuri ng OVM — LLSA I. Walang bayarin.',
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                CivicBanner(tone: CivicStatusTone.danger, message: _error!),
              ],

              const SizedBox(height: 16),
              CivicFieldLabel(
                text: strings.pick(
                  'Reason for Cancellation',
                  'Dahilan ng Pagkakansela',
                ),
                isRequired: true,
              ),
              DropdownButtonFormField<String>(
                key: const Key('voluntary_reason_dropdown'),
                initialValue: _reason,
                isExpanded: true,
                items: kVoluntaryCancellationReasons
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt.value,
                        child: Text(
                          strings.isFil ? opt.labelFil : opt.labelEn,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val == null) return;
                        setState(() => _reason = val);
                        _syncTemplate();
                      },
              ),

              if (_reason == 'Other') ...[
                const SizedBox(height: 14),
                CivicFieldLabel(
                  text: strings.pick(
                    'Specific Reason Details',
                    'Partikular na Dahilan',
                  ),
                  isRequired: true,
                ),
                TextField(
                  key: const Key('voluntary_custom_reason_field'),
                  controller: _customReasonCtrl,
                  maxLength: 120,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: strings.pick(
                      'Specify your reason for surrendering this franchise...',
                      'Pakisulat ang partikular na dahilan ng pagkakansela...',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              CivicFieldLabel(
                text: strings.pick(
                  'Remarks / Additional Context (Optional)',
                  'Karagdagang Impormasyon (Opsyonal)',
                ),
              ),
              TextField(
                controller: _remarksCtrl,
                maxLines: 2,
                maxLength: 500,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: strings.pick(
                    'e.g. New owner name if sold, relocation date, or TODA transfer...',
                    'hal. Pangalan ng nakabili ng unit, petsa ng paghinto, o paglipat ng TODA...',
                  ),
                ),
              ),

              const SizedBox(height: 14),
              CivicFieldLabel(
                text: strings.pick(
                  'Formal Cancellation Letter to OVM',
                  'Pormal na Liham para sa OVM',
                ),
                isRequired: true,
              ),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_LetterInputMode>(
                  segments: [
                    ButtonSegment(
                      value: _LetterInputMode.type,
                      icon: const Icon(Icons.edit_note_rounded, size: 17),
                      label: Text(strings.typeLetterMode),
                    ),
                    ButtonSegment(
                      value: _LetterInputMode.upload,
                      icon: const Icon(Icons.upload_file_outlined, size: 17),
                      label: Text(strings.uploadLetterMode),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _isSubmitting
                      ? null
                      : (sel) => setState(() {
                            _mode = sel.first;
                            _error = null;
                          }),
                ),
              ),
              const SizedBox(height: 12),

              if (_mode == _LetterInputMode.type) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.pick(
                          'Auto-addressed to Hon. Lidany A. Lao-Baldo (OVM — LLSA I).',
                          'Naka-address kay Hon. Lidany A. Lao-Baldo (OVM — LLSA I).',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              _hasManuallyEditedLetter = false;
                              _syncTemplate(force: true);
                            },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: Text(strings.resetTemplate),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('voluntary_letter_text_field'),
                  controller: _letterCtrl,
                  minLines: 8,
                  maxLines: 14,
                  maxLength: 2000,
                  enabled: !_isSubmitting,
                  onChanged: (_) {
                    _hasManuallyEditedLetter = true;
                    setState(() {});
                  },
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.45, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: strings.pick(
                      'Type your formal franchise surrender letter here...',
                      'Isulat dito ang iyong pormal na liham ng pagkakansela...',
                    ),
                  ),
                ),
                Text(
                  strings.pick(
                    'Minimum 30 characters required (${_letterCtrl.text.trim().length}/2000).',
                    'Minimum na 30 karakter (${_letterCtrl.text.trim().length}/2000).',
                  ),
                  style: CivicTheme.monoStyle(
                    fontSize: 10,
                    color: _letterCtrl.text.trim().length >= 30
                        ? palette.muted
                        : CivicColors.crimsonAlert,
                  ),
                ),
              ] else ...[
                if (_pickedBytes == null)
                  InkWell(
                    key: const Key('voluntary_upload_picker_tile'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isSubmitting ? null : _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border, width: 1.4),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 36,
                            color: palette.brandAccent,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            strings.pick(
                              'Tap to Select Signed Letter Photo or PDF',
                              'Pindutin upang Pumili ng Litrato o PDF ng Liham',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'JPG, PNG, WEBP, or PDF • Max 10 MB',
                            style: CivicTheme.monoStyle(
                              fontSize: 10.5,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  CivicCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (isImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _pickedBytes!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: CivicColors.crimsonAlert
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: CivicColors.crimsonAlert,
                              size: 28,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickedFileName ?? 'letter',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(_pickedBytes!.length / 1024).toStringAsFixed(1)} KB',
                                style: CivicTheme.monoStyle(
                                  fontSize: 10.5,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: strings.pick('Remove file', 'Alisin ang file'),
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _pickedBytes = null;
                                    _pickedFileName = null;
                                    _pickedMimeType = null;
                                  }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: CivicColors.crimsonAlert,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 20),
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
                      key: const Key('voluntary_submit_button'),
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
                      label: Text(strings.submitCancellationRequest),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
