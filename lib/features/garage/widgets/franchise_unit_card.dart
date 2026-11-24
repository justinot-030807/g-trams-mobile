import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/garage/widgets/lgu_pipeline_stepper.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Crisp Civic Ledger card for a single registered tricycle franchise unit.
/// Strictly flat 1px hairline border, tabular monospace identifiers, zero
/// `border-l-4` side stripes, and full responsive/Extra-Large text-scale support.
class FranchiseUnitCard extends StatelessWidget {
  const FranchiseUnitCard({
    super.key,
    required this.unit,
    required this.strings,
    required this.franchiseFee,
    required this.renewalReminderDays,
    required this.onViewECopy,
    required this.onViewViolations,
    required this.onViewDetails,
    required this.onWithdraw,
    required this.onRequestCancellation,
    required this.onFixAndReapply,
    required this.onRenew,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final num franchiseFee;
  final int renewalReminderDays;
  final VoidCallback onViewECopy;
  final VoidCallback onViewViolations;
  final VoidCallback onViewDetails;
  final VoidCallback onWithdraw;
  final VoidCallback onRequestCancellation;
  final VoidCallback onFixAndReapply;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final daysRemaining = unit.effectiveDaysRemaining();
    final showValidityBox = unit.status == 'Active' ||
        unit.status == 'Active - Under Warning' ||
        unit.status == 'Expired' ||
        unit.issuedPermit != null;

    final hasSanctionAlert = unit.status == 'Active - Under Warning' ||
        unit.status == 'Suspended' ||
        unit.status == 'Revoked' ||
        unit.activeViolationCount > 0;

    return CivicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: TODA + Zone metadata + Status Badge
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 15,
                    color: palette.brandAccent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${unit.todaName.isNotEmpty ? unit.todaName : 'Non-TODA'} · ${unit.formattedZone}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                    ),
                  ),
                ],
              ),
              CivicStatusBadge(
                label: _statusDisplayLabel(unit),
                tone: unit.statusTone,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plate / MTOP / Body# Tabular Ledger Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
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
                            strings.pick('Plate No.', 'Plaka'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  color: palette.muted,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unit.plateNo.isNotEmpty
                                ? unit.plateNo.toUpperCase()
                                : 'PENDING',
                            style: CivicTheme.monoStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: palette.ink,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            unit.make.isNotEmpty ? unit.make : 'Tricycle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                          ),
                          if (unit.made.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              unit.made,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CivicTheme.monoStyle(
                                fontSize: 11,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: palette.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LedgerMiniCell(
                        label: strings.pick('MTOP No.', 'MTOP #'),
                        value: unit.displayMtopNo.isNotEmpty
                            ? unit.displayMtopNo
                            : strings.pick('Pending', 'Wala pa'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LedgerMiniCell(
                        label: strings.pick('Body #', 'Body #'),
                        value: unit.bodyNumber.isNotEmpty
                            ? '#${unit.bodyNumber}'
                            : '—',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5-Stage LGU Pipeline Stepper (for pipeline states)
          if (unit.pipelineStage != null) ...[
            const SizedBox(height: 12),
            LguPipelineStepper(
              unit: unit,
              strings: strings,
              franchiseFee: franchiseFee,
            ),
          ],

          // Contextual Sanction / Rejection / Cancellation Callout Banners
          ..._buildStatusCallouts(context),

          // Server-Authoritative Asia/Manila Days-Remaining Validity Box
          if (showValidityBox) ...[
            const SizedBox(height: 12),
            _ValidityCountdownBox(
              unit: unit,
              daysRemaining: daysRemaining,
              renewalReminderDays: renewalReminderDays,
              strings: strings,
              onRenew: onRenew,
            ),
          ],

          const SizedBox(height: 14),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 12),

          // Responsive Action Strip (48dp minimum height targets)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (unit.hasApprovedECopy || unit.hasOfficialReceipt)
                _ActionChipButton(
                  label: strings.viewECopyAction,
                  icon: Icons.verified_outlined,
                  isPrimaryAccent: true,
                  onPressed: onViewECopy,
                ),
              if (unit.isRejectedNeedsFix)
                _ActionChipButton(
                  label: strings.fixReapplyAction,
                  icon: Icons.build_circle_outlined,
                  isDangerFilled: true,
                  onPressed: onFixAndReapply,
                ),
              if (unit.isRefilableRenewal || unit.status == 'Expired')
                _ActionChipButton(
                  label: strings.renewAction,
                  icon: Icons.autorenew_rounded,
                  isPrimaryAccent: true,
                  onPressed: onRenew,
                ),
              _ActionChipButton(
                label: unit.activeViolationCount > 0
                    ? '${strings.violationsAction} (${unit.activeViolationCount})'
                    : strings.violationsAction,
                icon: Icons.gavel_outlined,
                isWarningBorder: hasSanctionAlert,
                onPressed: onViewViolations,
              ),
              _ActionChipButton(
                label: strings.detailsAction,
                icon: Icons.description_outlined,
                onPressed: onViewDetails,
              ),
              if (unit.isWithdrawable)
                _ActionChipButton(
                  label: strings.withdrawAction,
                  icon: Icons.cancel_outlined,
                  isDangerOutline: true,
                  onPressed: onWithdraw,
                ),
              if (unit.canRequestVoluntaryCancellation)
                _ActionChipButton(
                  label: strings.requestCancelAction,
                  icon: Icons.assignment_return_outlined,
                  isDangerOutline: true,
                  onPressed: onRequestCancellation,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusDisplayLabel(FranchiseRecord f) {
    if (f.status == 'Cancelled') {
      if (f.isVoluntarilyCancelled) {
        return strings.pick('Voluntarily Cancelled', 'Kusang Kinansela');
      }
      if (f.isWithdrawn) {
        return strings.pick('Withdrawn', 'Na-withdraw');
      }
      if (f.isRejectedNeedsFix || f.isRefilableRenewal) {
        return strings.pick('Needs Correction', 'Kailangan Ayusin');
      }
    }
    return f.status;
  }

  List<Widget> _buildStatusCallouts(BuildContext context) {
    final widgets = <Widget>[];

    if (unit.status == 'Active - Under Warning') {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        CivicBanner(
          tone: CivicStatusTone.inProgress,
          icon: Icons.warning_amber_rounded,
          title: strings.pick(
            '1st Offense — Active Warning',
            'Unang Babala — Aktibo',
          ),
          message: strings.pick(
            'Tap Violations to review this notice and avoid suspension.',
            'Pindutin ang Mga Paglabag upang makita ang detalye ng babala.',
          ),
        ),
      );
    } else if (unit.status == 'Suspended') {
      final untilStr = unit.suspensionEndDate != null
          ? ' (${strings.pick('until', 'hanggang')} ${ManilaDateFormatter.formatShortDate(unit.suspensionEndDate, isFil: strings.isFil)})'
          : '';
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        CivicBanner(
          tone: CivicStatusTone.danger,
          icon: Icons.gpp_maybe_outlined,
          title: strings.pick(
            'Suspended — 2nd Offense$untilStr',
            'Suspendido — Ikalawang Paglabag$untilStr',
          ),
          message: unit.suspensionReason.isNotEmpty
              ? '${unit.suspensionReason}. ${strings.pick('Settle the fine at Municipal Cashier via OVM — LLSA I.', 'Bayaran ang multa sa Municipal Cashier sa tulong ng OVM — LLSA I.')}'
              : strings.pick(
                  'Temporarily suspended. Coordinate with OVM — LLSA I to settle the fine.',
                  'Pansamantalang suspendido. Makipag-ugnayan sa OVM — LLSA I.',
                ),
        ),
      );
    } else if (unit.status == 'Revoked') {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        CivicBanner(
          tone: CivicStatusTone.danger,
          icon: Icons.block_rounded,
          title: strings.pick(
            'Franchise Revoked',
            'Binawi ang Prangkisa',
          ),
          message: unit.cancelReason.isNotEmpty
              ? unit.cancelReason
              : strings.pick(
                  'Revoked due to accumulated or grave ordinance violations.',
                  'Binawi dahil sa paulit-ulit o mabigat na paglabag sa ordinansa.',
                ),
        ),
      );
    } else if (unit.status == 'Cancellation Requested') {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        CivicBanner(
          tone: CivicStatusTone.inProgress,
          icon: Icons.hourglass_bottom_rounded,
          title: strings.pick(
            'Cancellation Under OVM Review',
            'Sinusuri ng OVM ang Pagkansela',
          ),
          message: strings.pick(
            'Surrender letter received by OVM — LLSA I. No Cashier payment needed.',
            'Natanggap ng OVM — LLSA I ang iyong liham. Walang bayarin sa Cashier.',
          ),
        ),
      );
    } else if (unit.status == 'Cancelled') {
      widgets.add(const SizedBox(height: 12));
      if (unit.isRejectedNeedsFix || unit.isRefilableRenewal) {
        final fieldChip = unit.rejectedField.isNotEmpty
            ? '\n${strings.pick('Flagged Field', 'Kailangang Ayusin')}: ${unit.rejectedField}'
            : '';
        widgets.add(
          CivicBanner(
            tone: CivicStatusTone.danger,
            icon: Icons.error_outline_rounded,
            title: strings.pick(
              'Returned — Action Needed',
              'Ibinalik — Kailangan Ayusin',
            ),
            message:
                '${unit.cancelReason.isNotEmpty ? unit.cancelReason : strings.pick('Correct the flagged remarks and resubmit.', 'Pakitama ang mga nabanggit na kulang at isumite muli.')}$fieldChip',
          ),
        );
      } else {
        final reasonText = unit.isVoluntarilyCancelled
            ? (unit.cancellationDetails?.effectiveReason.isNotEmpty == true
                ? unit.cancellationDetails!.effectiveReason
                : strings.pick('Voluntary Surrender', 'Kusang Pagsuko'))
            : (unit.cancelReason.isNotEmpty
                ? unit.cancelReason
                : strings.pick(
                    'Withdrawn by operator.',
                    'Na-withdraw ng operator.',
                  ));
        final dateStr = ManilaDateFormatter.formatShortDate(
          unit.cancellationDetails?.reviewedAt ??
              unit.archivedAt ??
              unit.updatedAt,
          isFil: strings.isFil,
        );
        widgets.add(
          CivicBanner(
            tone: CivicStatusTone.neutral,
            icon: Icons.archive_outlined,
            title: unit.isVoluntarilyCancelled
                ? strings.pick(
                    'Voluntarily Surrendered ($dateStr)',
                    'Kusang Ipinakansela ($dateStr)',
                  )
                : strings.pick(
                    'Withdrawn ($dateStr)',
                    'Na-withdraw ($dateStr)',
                  ),
            message: reasonText,
          ),
        );
      }
    }

    return widgets;
  }
}

class _LedgerMiniCell extends StatelessWidget {
  const _LedgerMiniCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: palette.muted,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CivicTheme.monoStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}

class _ValidityCountdownBox extends StatelessWidget {
  const _ValidityCountdownBox({
    required this.unit,
    required this.daysRemaining,
    required this.renewalReminderDays,
    required this.strings,
    required this.onRenew,
  });

  final FranchiseRecord unit;
  final int? daysRemaining;
  final int renewalReminderDays;
  final AppStrings strings;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expDate = unit.expiryDate ?? unit.issuedPermit?.expiryDate;
    final isExpired =
        unit.isEffectivelyExpired() || (daysRemaining != null && daysRemaining! <= 0);
    final isExpiringSoon = !isExpired &&
        daysRemaining != null &&
        daysRemaining! <= renewalReminderDays;

    final Color fg;
    final Color bg;
    final Color border;
    if (isExpired) {
      fg = isDark ? const Color(0xFFFCA5A5) : CivicColors.crimsonAlert;
      bg = isDark
          ? CivicColors.crimsonAlertDarkBg
          : CivicColors.crimsonAlertLightBg;
      border = CivicColors.crimsonAlert.withValues(alpha: 0.35);
    } else if (isExpiringSoon) {
      fg = isDark ? const Color(0xFFFCD34D) : CivicColors.amberOchre;
      bg = isDark
          ? CivicColors.amberOchreDarkBg
          : CivicColors.amberOchreLightBg;
      border = CivicColors.amberOchre.withValues(alpha: 0.35);
    } else {
      fg = isDark ? const Color(0xFF86EFAC) : CivicColors.civicGreen;
      bg = isDark
          ? CivicColors.civicGreenDarkBg
          : CivicColors.civicGreenLightBg;
      border = CivicColors.civicGreen.withValues(alpha: 0.35);
    }

    final totalSpanDays = unit.applicationType == 'Renewal' ? 365 : 1095;
    final progress = isExpired
        ? 1.0
        : daysRemaining == null
            ? 0.0
            : (daysRemaining! / totalSpanDays).clamp(0.08, 1.0);

    final countdownLabel = daysRemaining == null
        ? unit.status
        : daysRemaining! <= 0
            ? strings.overdueDaysText(daysRemaining!.abs())
            : isExpiringSoon
                ? '${strings.renewalWindowOpen} • ${strings.daysLeftText(daysRemaining!)}'
                : strings.daysLeftText(daysRemaining!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                strings.pick('Valid until', 'Balido hanggang'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ManilaDateFormatter.formatLongDate(
                    expDate,
                    isFil: strings.isFil,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: CivicTheme.monoStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            countdownLabel,
            style: CivicTheme.monoStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: fg.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          if (isExpiringSoon && unit.status != 'Expired') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: CivicColors.gasanMaroon,
                  foregroundColor: CivicColors.purePaper,
                ),
                onPressed: onRenew,
                icon: const Icon(Icons.autorenew_rounded, size: 17),
                label: Text(strings.renewAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimaryAccent = false,
    this.isDangerOutline = false,
    this.isDangerFilled = false,
    this.isWarningBorder = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimaryAccent;
  final bool isDangerOutline;
  final bool isDangerFilled;
  final bool isWarningBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPrimaryAccent || isDangerFilled) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: isDangerFilled
              ? CivicColors.crimsonAlert
              : CivicColors.gasanMaroon,
          foregroundColor: CivicColors.purePaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    final fgColor = isDangerOutline
        ? (isDark ? const Color(0xFFFCA5A5) : CivicColors.crimsonAlert)
        : isWarningBorder
            ? (isDark ? const Color(0xFFFCD34D) : CivicColors.amberOchre)
            : palette.ink;

    final borderColor = isDangerOutline
        ? CivicColors.crimsonAlert.withValues(alpha: 0.45)
        : isWarningBorder
            ? CivicColors.amberOchre.withValues(alpha: 0.5)
            : palette.border;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        foregroundColor: fgColor,
        backgroundColor: palette.surface,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: fgColor),
      label: Text(label),
    );
  }
}
