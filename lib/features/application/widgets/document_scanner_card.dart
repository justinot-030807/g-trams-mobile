import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Civic Ledger document capture card with Android ML Kit Smart Camera Scanner,
/// Camera / Gallery photo pickers, PDF upload, and live 3-Tier AI OCR status badge.
class DocumentScannerCard extends StatelessWidget {
  const DocumentScannerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.captureService,
    required this.strings,
    required this.onFileCaptured,
    required this.onRemove,
    this.attachment,
    this.existingUrl = '',
    this.isRequired = false,
    this.isScanning = false,
    this.ocrFeedback,
  });

  final String title;
  final String subtitle;
  final DocumentCaptureService captureService;
  final AppStrings strings;
  final ValueChanged<ScannedDocumentAttachment> onFileCaptured;
  final VoidCallback onRemove;
  final ScannedDocumentAttachment? attachment;
  final String existingUrl;
  final bool isRequired;
  final bool isScanning;
  final OcrDocumentFeedback? ocrFeedback;

  Future<void> _runCapture(
    BuildContext context,
    Future<ScannedDocumentAttachment?> Function() action,
  ) async {
    try {
      final file = await action();
      if (file != null) {
        onFileCaptured(file);
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

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final hasNew = attachment != null;
    final hasExisting = !hasNew && existingUrl.isNotEmpty;
    final feedback = ocrFeedback;
    final isRejected = hasNew && feedback?.isRejected == true;
    final isVerified = hasNew && feedback?.success == true;
    final isUnavailable = hasNew && feedback?.isServiceUnavailable == true;

    final String statusLabel;
    final CivicStatusTone statusTone;
    if (isScanning) {
      statusLabel = strings.pick('Scanning...', 'Sinusuri...');
      statusTone = CivicStatusTone.inProgress;
    } else if (isRejected) {
      statusLabel = strings.pick('Wrong Document', 'Maling Dokumento');
      statusTone = CivicStatusTone.danger;
    } else if (isVerified) {
      statusLabel = strings.pick('Scanned', 'Na-scan');
      statusTone = CivicStatusTone.active;
    } else if (isUnavailable) {
      statusLabel = strings.pick('Verify Manually', 'I-verify');
      statusTone = CivicStatusTone.inProgress;
    } else if (hasNew) {
      statusLabel = strings.pick('Attached', 'Nakalakip');
      statusTone = CivicStatusTone.neutral;
    } else if (hasExisting) {
      statusLabel = strings.pick('On File', 'Naka-save');
      statusTone = CivicStatusTone.active;
    } else if (isRequired) {
      statusLabel = strings.pick('Required', 'Kailangan');
      statusTone = CivicStatusTone.inProgress;
    } else {
      statusLabel = strings.pick('Optional', 'Opsyonal');
      statusTone = CivicStatusTone.neutral;
    }

    return CivicCard(
      padding: const EdgeInsets.all(14),
      borderColor: isRejected
          ? CivicColors.crimsonAlert.withValues(alpha: 0.55)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14.5,
                          ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CivicStatusBadge(label: statusLabel, tone: statusTone),
            ],
          ),

          if (hasNew) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRejected
                      ? CivicColors.crimsonAlert.withValues(alpha: 0.45)
                      : palette.border,
                ),
              ),
              child: Row(
                children: [
                  if (attachment!.isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        attachment!.bytes,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: palette.surface,
                          child: Icon(
                            Icons.image_outlined,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: CivicColors.crimsonAlert.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: CivicColors.crimsonAlert,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment!.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${attachment!.sourceLabel} • ${(attachment!.sizeBytes / 1024).toStringAsFixed(1)} KB',
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
                    onPressed: isScanning ? null : onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: CivicColors.crimsonAlert,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (hasExisting) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 16,
                    color: CivicColors.civicGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.pick(
                        'Saved on file. Upload again only to replace.',
                        'Naka-save na. Mag-upload lamang kung papalitan.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isScanning) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: palette.brandAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.brandAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.pick(
                        'Reading document details...',
                        'Binabasa ang detalye ng dokumento...',
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
          ] else if (feedback != null) ...[
            const SizedBox(height: 10),
            if (feedback.isRejected)
              CivicBanner(
                key: const Key('ocr_feedback_rejected'),
                tone: CivicStatusTone.danger,
                icon: Icons.error_outline_rounded,
                title: feedback.title.isNotEmpty
                    ? feedback.title
                    : strings.pick(
                        'Wrong or Unreadable Document',
                        'Maling Dokumento o Malabo',
                      ),
                message: feedback.message,
              )
            else if (feedback.isServiceUnavailable)
              CivicBanner(
                key: const Key('ocr_feedback_unavailable'),
                tone: CivicStatusTone.inProgress,
                icon: Icons.warning_amber_rounded,
                title: feedback.title.isNotEmpty
                    ? feedback.title
                    : strings.pick(
                        'OCR Unavailable — Verify Manually',
                        'Hindi Magamit ang OCR — I-verify',
                      ),
                message: feedback.message,
              )
            else
              CivicBanner(
                key: const Key('ocr_feedback_verified'),
                tone: CivicStatusTone.active,
                icon: Icons.check_circle_outline_rounded,
                message: feedback.message,
              ),
          ],

          const SizedBox(height: 12),
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
                  onPressed: isScanning
                      ? null
                      : () => _runCapture(
                            context,
                            captureService.scanWithSmartCamera,
                          ),
                  icon: const Icon(Icons.document_scanner_outlined, size: 17),
                  label: Text(
                    strings.pick('Scan', 'I-scan'),
                  ),
                ),
              if (captureService.supportsDirectCamera)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                  ),
                  onPressed: isScanning
                      ? null
                      : () => _runCapture(
                            context,
                            captureService.captureFromCamera,
                          ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 17),
                  label: Text(strings.pick('Camera', 'Kamera')),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                ),
                onPressed: isScanning
                    ? null
                    : () => _runCapture(
                          context,
                          captureService.pickDocumentFile,
                        ),
                icon: const Icon(Icons.upload_file_outlined, size: 17),
                label: Text(
                  strings.pick('Upload File', 'Mag-upload'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
