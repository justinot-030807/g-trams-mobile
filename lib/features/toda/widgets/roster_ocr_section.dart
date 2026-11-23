import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/features/toda/view_models/toda_governance_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// AI OCR TODA Roster Scanner, Interactive Member Row Editor, Official OVM Upload,
/// and Historical Submissions Tracker.
class RosterOcrSection extends StatelessWidget {
  const RosterOcrSection({
    super.key,
    required this.state,
    required this.controller,
    required this.captureService,
    required this.strings,
  });

  final TodaGovernanceState state;
  final TodaGovernanceController controller;
  final DocumentCaptureService captureService;
  final AppStrings strings;

  Future<void> _captureAndScan(
    BuildContext context,
    Future<ScannedDocumentAttachment?> Function() picker,
  ) async {
    try {
      final file = await picker();
      if (file != null) {
        await controller.scanRosterFile(file);
      }
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString().replaceFirst('FormatException: ', '')),
        ),
      );
    }
  }

  Future<void> _showRowEditorDialog(
    BuildContext context, {
    int? editIndex,
    ExtractedRosterMember? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.operatorName ?? '');
    final bodyCtrl = TextEditingController(text: existing?.bodyNumber ?? '');
    final plateCtrl = TextEditingController(text: existing?.plateNo ?? '');

    final saved = await showDialog<ExtractedRosterMember>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.civic.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ctx.civic.border),
        ),
        title: Text(
          editIndex == null
              ? strings.pick('Add Roster Member Row', 'Magdagdag ng Row sa Roster')
              : strings.pick('Edit Roster Row', 'I-edit ang Row sa Roster'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CivicFieldLabel(text: strings.fullNameLabel, isRequired: true),
              TextField(
                key: const Key('roster_row_name_field'),
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: strings.fullNameHint),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(text: strings.bodyNumberLabel),
              TextField(
                key: const Key('roster_row_body_field'),
                controller: bodyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(hintText: strings.bodyNumberHint),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(
                text: strings.pick('Plate Number (Optional)', 'Plaka (Opsyonal)'),
              ),
              TextField(
                controller: plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'e.g. ABC-1234'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            key: const Key('roster_row_save_button'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () {
              final cleanName = nameCtrl.text.trim();
              if (cleanName.isEmpty) return;
              Navigator.of(ctx).pop(
                ExtractedRosterMember(
                  operatorName: cleanName,
                  bodyNumber: bodyCtrl.text.trim().toUpperCase(),
                  plateNo: plateCtrl.text.trim().toUpperCase(),
                  confidence: 1.0,
                ),
              );
            },
            child: Text(strings.pick('Save', 'I-save')),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    bodyCtrl.dispose();
    plateCtrl.dispose();

    if (saved == null) return;
    if (editIndex == null) {
      controller.addRosterRow(
        operatorName: saved.operatorName,
        bodyNumber: saved.bodyNumber,
        plateNo: saved.plateNo,
      );
    } else {
      controller.updateRosterRow(editIndex, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final file = state.selectedRosterFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Capture / Upload Roster Document Card
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick(
                  'AI OCR ROSTER MASTERLIST SCANNER',
                  'AI OCR SCANNER NG TODA MASTERLIST',
                ),
                style: CivicTheme.monoStyle(fontSize: 10, color: palette.muted),
              ),
              const SizedBox(height: 6),
              Text(
                strings.pick(
                  'Scan a printed/handwritten TODA roster sheet or upload JPG, PNG, PDF, Excel (.xlsx), or CSV (<= 15 MB) for automatic extraction.',
                  'I-scan ang nakalimbag o sulat-kamay na TODA roster o mag-upload ng JPG, PNG, PDF, Excel (.xlsx), o CSV (<= 15 MB) para sa awtomatikong pagkuha ng pangalan.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 12),

              if (file != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        file.isImage
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                        color: palette.brandAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB • ${file.sourceLabel}',
                              style: CivicTheme.monoStyle(
                                fontSize: 10,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: strings.pick('Clear file', 'Alisin'),
                        onPressed: (state.isScanningRoster || state.isUploadingRoster)
                            ? null
                            : controller.clearRosterDraft,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: CivicColors.crimsonAlert,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (state.isScanningRoster) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.brandAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.brandAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.pick(
                            'Extracting member names & body numbers with AI OCR...',
                            'Kinukuha ang pangalan at body number gamit ang AI OCR...',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (state.rosterFeedbackMessage != null) ...[
                CivicBanner(
                  tone: state.rosterFeedbackIsError
                      ? CivicStatusTone.inProgress
                      : CivicStatusTone.active,
                  message: state.rosterFeedbackMessage!,
                ),
                const SizedBox(height: 10),
              ],

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (captureService.supportsSmartCameraScanner)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: (state.isScanningRoster || state.isUploadingRoster)
                          ? null
                          : () => _captureAndScan(
                                context,
                                captureService.scanWithSmartCamera,
                              ),
                      icon: const Icon(Icons.document_scanner_outlined, size: 17),
                      label: const Text('Smart Scan'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('roster_upload_file_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: (state.isScanningRoster || state.isUploadingRoster)
                        ? null
                        : () => _captureAndScan(
                              context,
                              captureService.pickRosterFile,
                            ),
                    icon: const Icon(Icons.upload_file_outlined, size: 17),
                    label: Text(strings.scanRosterAction),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Extracted Members Editor (shown whenever a roster file is loaded or rows exist)
        if (file != null || state.rosterMembers.isNotEmpty) ...[
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.pick(
                          'EXTRACTED ROSTER EDITOR (${state.rosterMembers.length})',
                          'EDITOR NG ROSTER (${state.rosterMembers.length})',
                        ),
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('roster_add_row_button'),
                      onPressed: state.isUploadingRoster
                          ? null
                          : () => _showRowEditorDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(strings.pick('Add Row', 'Magdagdag')),
                    ),
                  ],
                ),
                if (state.rosterOcrNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.rosterOcrNotes,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 10),
                if (state.rosterMembers.isEmpty)
                  Text(
                    strings.pick(
                      'No rows yet. Tap "Add Row" to enter members manually before submitting.',
                      'Wala pang row. Pindutin ang "Magdagdag" upang maglagay ng miyembro.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ...List.generate(state.rosterMembers.length, (idx) {
                    final row = state.rosterMembers[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.operatorName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    Text(
                                      'BODY: ${row.bodyNumber.isNotEmpty ? '#${row.bodyNumber}' : '—'}',
                                      style: CivicTheme.monoStyle(
                                        fontSize: 10.5,
                                        color: palette.brandAccent,
                                      ),
                                    ),
                                    if (row.plateNo.isNotEmpty)
                                      Text(
                                        'PLATE: ${row.plateNo}',
                                        style: CivicTheme.monoStyle(
                                          fontSize: 10.5,
                                          color: palette.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit row',
                            onPressed: state.isUploadingRoster
                                ? null
                                : () => _showRowEditorDialog(
                                      context,
                                      editIndex: idx,
                                      existing: row,
                                    ),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: palette.muted,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete row',
                            onPressed: state.isUploadingRoster
                                ? null
                                : () => controller.removeRosterRow(idx),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: CivicColors.crimsonAlert,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                CivicPrimaryButton(
                  key: const Key('roster_submit_ovm_button'),
                  label: strings.submitRosterToOvm,
                  icon: Icons.cloud_upload_outlined,
                  isLoading: state.isUploadingRoster,
                  onPressed: (file == null ||
                          state.rosterMembers.isEmpty ||
                          state.isScanningRoster)
                      ? null
                      : () => controller.submitRosterToOvm(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 3. Historical Submissions Tracker (`GET /toda/my-submissions`)
        Text(
          strings.pick(
            'PAST ROSTER SUBMISSIONS (${state.submissions.length})',
            'MGA NAISUMITENG ROSTER (${state.submissions.length})',
          ),
          style: CivicTheme.monoStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 10),
        if (state.submissions.isEmpty)
          CivicCard(
            child: Text(
              strings.pick(
                'No historical roster submissions yet.',
                'Wala pang naisumiteng roster sa OVM — LLSA I.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...state.submissions.map(
            (sub) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CivicStatusBadge(
                          label: sub.status,
                          tone: sub.statusTone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${sub.extractedCount} ${strings.pick('MEMBERS', 'MIYEMBRO')}',
                          style: CivicTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: palette.brandAccent,
                          ),
                        ),
                        Text(
                          ManilaDateFormatter.formatShortDate(
                            sub.createdAt,
                            isFil: strings.isFil,
                          ),
                          style: CivicTheme.monoStyle(
                            fontSize: 10.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                    if (sub.ocrNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        sub.ocrNotes,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
