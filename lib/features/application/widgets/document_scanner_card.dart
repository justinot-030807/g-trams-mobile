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

    final String statusLabel;
    final CivicStatusTone statusTone;
    if (isScanning) {
      statusLabel = strings.pick('AI Scanning...', 'Nag-i-scan...');
      statusTone = CivicStatusTone.inProgress;
    } else if (hasNew && ocrFeedback?.success == true) {
      statusLabel = strings.pick('AI Auto-Filled', 'Na-auto-fill');
      statusTone = CivicStatusTone.active;
    } else if (hasNew) {
      statusLabel = strings.pick('Attached', 'Nakalakip');
      statusTone = CivicStatusTone.active;
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
                border: Border.all(color: palette.border),
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
                        'Previously uploaded copy on file. Scan or upload a new file only if replacing it.',
                        'May naka-save nang dokumento. Mag-scan o mag-upload lamang kung papalitan.',
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
                border: Border.all(color: palette.brandAccent.withValues(alpha: 0.4)),
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
                        'Running 3-Tier AI OCR to auto-fill details...',
                        'Sinusuri ng 3-Tier AI OCR upang awtomatikong punan ang detalye...',
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
          ] else if (ocrFeedback != null) ...[
            const SizedBox(height: 10),
            CivicBanner(
              tone: ocrFeedback!.success
                  ? CivicStatusTone.active
                  : CivicStatusTone.inProgress,
              icon: ocrFeedback!.success
                  ? Icons.auto_awesome_outlined
                  : Icons.edit_note_rounded,
              message: ocrFeedback!.message,
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
                    strings.pick('Smart Scan', 'Smart Scan'),
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
                  icon: const Icon(Icons.photo_camera_outlined, size: 17),
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
                  strings.pick('Upload Photo / PDF', 'Mag-upload ng File'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
