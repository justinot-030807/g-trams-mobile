import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';

/// Official 5-Stage Gasan LGU Franchise Processing Pipeline Stepper:
/// `Pending` -> `For Payment` -> `For Signing` -> `Ready for Pickup` -> `Active`.
class LguPipelineStepper extends StatelessWidget {
  const LguPipelineStepper({
    super.key,
    required this.unit,
    required this.strings,
    required this.franchiseFee,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final num franchiseFee;

  @override
  Widget build(BuildContext context) {
    final stage = unit.pipelineStage;
    if (stage == null) return const SizedBox.shrink();

    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = palette.brandAccent;
    final currentIndex = stage.stepIndex;

    final steps = [
      (LguPipelineStage.pending, strings.stagePending),
      (LguPipelineStage.forPayment, strings.stageForPayment),
      (LguPipelineStage.forSigning, strings.stageForSigning),
      (LguPipelineStage.readyForPickup, strings.stageReadyPickup),
      (LguPipelineStage.active, strings.stageActive),
    ];

    final stageGuidance = _buildGuidanceText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.pick('Application Progress', 'Progreso ng Aplikasyon'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                ),
              ),
              Text(
                '${currentIndex + 1}/5',
                style: CivicTheme.monoStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nodes + connecting tracks
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(steps.length, (idx) {
              final step = steps[idx];
              final isCompleted = idx < currentIndex ||
                  (stage == LguPipelineStage.active && idx == 4);
              final isCurrent =
                  idx == currentIndex && stage != LguPipelineStage.active;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          Expanded(
                            child: idx == 0
                                ? const SizedBox.shrink()
                                : Container(
                                    height: 2,
                                    color: idx <= currentIndex
                                        ? activeColor
                                        : palette.border,
                                  ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? activeColor
                                  : palette.surface,
                              border: Border.all(
                                color: isCompleted || isCurrent
                                    ? activeColor
                                    : palette.border,
                                width: isCurrent ? 2 : 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: isCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: isDark
                                        ? CivicColors.obsidianEarth
                                        : CivicColors.purePaper,
                                  )
                                : isCurrent
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: activeColor,
                                        ),
                                      )
                                    : Text(
                                        '${idx + 1}',
                                        style: CivicTheme.monoStyle(
                                          fontSize: 9.5,
                                          color: palette.muted,
                                        ),
                                      ),
                          ),
                          Expanded(
                            child: idx == steps.length - 1
                                ? const SizedBox.shrink()
                                : Container(
                                    height: 2,
                                    color: idx < currentIndex
                                        ? activeColor
                                        : palette.border,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        step.$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: isCurrent || isCompleted
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? activeColor
                                  : isCompleted
                                      ? palette.ink
                                      : palette.muted,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          if (stageGuidance != null) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: palette.border),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  stageGuidance.$1,
                  size: 16,
                  color: stageGuidance.$2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stageGuidance.$3,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                          height: 1.38,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color, String)? _buildGuidanceText() {
    switch (unit.pipelineStage) {
      case LguPipelineStage.pending:
        final applied = unit.dateApplied != null
            ? ' (${ManilaDateFormatter.formatShortDate(unit.dateApplied, isFil: strings.isFil)})'
            : '';
        return (
          Icons.hourglass_top_rounded,
          CivicColors.amberOchre,
          strings.pick(
            'Under review by OVM — LLSA I$applied.',
            'Sinusuri ng OVM — LLSA I$applied.',
          ),
        );
      case LguPipelineStage.forPayment:
        final feeText = ManilaDateFormatter.formatPhp(franchiseFee);
        if (unit.paymentStatus == 'Paid' && unit.officialReceiptNo.isNotEmpty) {
          return (
            Icons.receipt_long_rounded,
            CivicColors.civicGreen,
            strings.pick(
              'Paid (OR# ${unit.officialReceiptNo}). Routing for signing.',
              'Bayad na (OR# ${unit.officialReceiptNo}). Papunta na sa lagdaan.',
            ),
          );
        }
        return (
          Icons.payments_outlined,
          CivicColors.amberOchre,
          strings.pick(
            'Pay $feeText at Municipal Cashier using Plate ${unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING'}.',
            'Magbayad ng $feeText sa Municipal Cashier gamit ang Plaka ${unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING'}.',
          ),
        );
      case LguPipelineStage.forSigning:
        final orNote = unit.officialReceiptNo.isNotEmpty
            ? ' (OR# ${unit.officialReceiptNo})'
            : '';
        return (
          Icons.draw_outlined,
          CivicColors.amberOchre,
          strings.pick(
            'Payment recorded$orNote. Routing for OVM / Sangguniang Bayan signatures.',
            'Naitala ang bayad$orNote. Pinapipirmahan sa OVM / Sangguniang Bayan.',
          ),
        );
      case LguPipelineStage.readyForPickup:
        return (
          Icons.assignment_turned_in_outlined,
          CivicColors.civicGreen,
          strings.pick(
            'MTOP signed! Claim your printed permit and stickers at OVM — LLSA I.',
            'Nilagdaan na ang MTOP! Kunin ang permit at sticker sa OVM — LLSA I.',
          ),
        );
      case LguPipelineStage.active:
        return null;
      case null:
        return null;
    }
  }
}
