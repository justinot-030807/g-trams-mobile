import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';

/// Crisp 5-Step horizontal Civic Ledger wizard progress indicator.
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({
    super.key,
    required this.currentStep,
    required this.strings,
    required this.onStepTapped,
  });

  final int currentStep;
  final AppStrings strings;
  final ValueChanged<int> onStepTapped;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = palette.brandAccent;

    final labels = [
      strings.wizardStep1,
      strings.wizardStep2,
      strings.wizardStep3,
      strings.wizardStep4,
      strings.wizardStep5,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.pick(
                    'STEP ${currentStep + 1} OF 5 — ${labels[currentStep].toUpperCase()}',
                    'HAKBANG ${currentStep + 1} SA 5 — ${labels[currentStep].toUpperCase()}',
                  ),
                  style: CivicTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${currentStep + 1}/5',
                style: CivicTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: activeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(labels.length, (idx) {
              final isCompleted = idx < currentStep;
              final isCurrent = idx == currentStep;
              final canTap = idx <= currentStep;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: canTap ? () => onStepTapped(idx) : null,
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
                                      color: idx <= currentStep
                                          ? activeColor
                                          : palette.border,
                                    ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted || isCurrent
                                    ? activeColor
                                    : palette.canvas,
                                border: Border.all(
                                  color: isCompleted || isCurrent
                                      ? activeColor
                                      : palette.border,
                                  width: 1.2,
                                ),
                              ),
                              child: isCompleted
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: isDark
                                          ? CivicColors.obsidianEarth
                                          : CivicColors.purePaper,
                                    )
                                  : Text(
                                      '${idx + 1}',
                                      style: CivicTheme.monoStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isCurrent
                                            ? (isDark
                                                ? CivicColors.obsidianEarth
                                                : CivicColors.purePaper)
                                            : palette.muted,
                                      ),
                                    ),
                            ),
                            Expanded(
                              child: idx == labels.length - 1
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: 2,
                                      color: idx < currentStep
                                          ? activeColor
                                          : palette.border,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          labels[idx],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
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
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
