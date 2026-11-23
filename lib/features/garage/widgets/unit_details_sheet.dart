import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens a full Civic Ledger unit specifications sheet (RA 10173 compliant:
/// strictly excludes driver blood type and OCR signatory fields).
Future<void> showUnitDetailsSheet(
  BuildContext context, {
  required FranchiseRecord unit,
  required AppStrings strings,
  VoidCallback? onOpenECopy,
  VoidCallback? onOpenViolations,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _UnitDetailsSheetBody(
        unit: unit,
        strings: strings,
        scrollController: scrollController,
        onOpenECopy: onOpenECopy,
        onOpenViolations: onOpenViolations,
      ),
    ),
  );
}

class _UnitDetailsSheetBody extends StatelessWidget {
  const _UnitDetailsSheetBody({
    required this.unit,
    required this.strings,
    required this.scrollController,
    this.onOpenECopy,
    this.onOpenViolations,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final ScrollController scrollController;
  final VoidCallback? onOpenECopy;
  final VoidCallback? onOpenViolations;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final hasCr = unit.crUrl.isNotEmpty || unit.orCrUrl.isNotEmpty;
    final hasOr = unit.orUrl.isNotEmpty || unit.orCrUrl.isNotEmpty;

    final docs = [
      (strings.pick('LTO Certificate of Registration (CR)', 'LTO CR'), hasCr),
      (strings.pick('LTO Official Receipt (OR)', 'LTO OR'), hasOr),
      (strings.pick("Driver's License (Front)", "Driver's License (Harap)"), unit.licenseUrl.isNotEmpty),
      (strings.pick("Driver's License (Back)", "Driver's License (Likod)"), unit.licenseBackUrl.isNotEmpty),
      (strings.pick('Barangay Clearance', 'Barangay Clearance'), unit.brgyClearanceUrl.isNotEmpty),
      (strings.pick('Community Tax Certificate (Cedula)', 'Cedula (CTC)'), unit.cedulaUrl.isNotEmpty),
    ];

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.pick('Unit Specifications', 'Detalye ng Tricycle Unit'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING'} • ${unit.todaName}',
                      style: CivicTheme.monoStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
              CivicStatusBadge(label: unit.status, tone: unit.statusTone),
              const SizedBox(width: 4),
              IconButton(
                tooltip: strings.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.border),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.pick('FRANCHISE & VEHICLE LEDGER', 'TALAAN NG PRANGKISA AT SASAKYAN'),
                      style: CivicTheme.monoStyle(fontSize: 10, color: palette.muted),
                    ),
                    const SizedBox(height: 10),
                    _SpecRow(label: strings.plateNumberLabel, value: unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING', mono: true),
                    _SpecRow(label: strings.mtopNumberLabel, value: unit.displayMtopNo.isNotEmpty ? unit.displayMtopNo : '—', mono: true),
                    _SpecRow(label: strings.bodyNumberShort, value: unit.bodyNumber.isNotEmpty ? '#${unit.bodyNumber}' : '—', mono: true),
                    _SpecRow(label: 'TODA / ${strings.zoneLabel}', value: '${unit.todaName} (${unit.formattedZone})'),
                    _SpecRow(label: strings.pick('Make & Year', 'Taták at Taon'), value: '${unit.make} ${unit.made}'.trim()),
                    _SpecRow(label: strings.motorNumberLabel, value: unit.motorNo.isNotEmpty ? unit.motorNo : '—', mono: true),
                    _SpecRow(label: strings.chassisNumberLabel, value: unit.chassisNo.isNotEmpty ? unit.chassisNo : '—', mono: true),
                    if (unit.color.isNotEmpty)
                      _SpecRow(label: strings.pick('Color', 'Kulay'), value: unit.color),
                    _SpecRow(
                      label: strings.pick('Date Applied', 'Petsa ng Aplikasyon'),
                      value: ManilaDateFormatter.formatLongDate(unit.dateApplied, isFil: strings.isFil),
                      mono: true,
                    ),
                    _SpecRow(
                      label: strings.validUntilLabel,
                      value: ManilaDateFormatter.formatLongDate(
                        unit.expiryDate ?? unit.issuedPermit?.expiryDate,
                        isFil: strings.isFil,
                      ),
                      mono: true,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.pick('OPERATOR & TREASURY INFO', 'OPERATOR AT TREASURY'),
                      style: CivicTheme.monoStyle(fontSize: 10, color: palette.muted),
                    ),
                    const SizedBox(height: 10),
                    _SpecRow(label: strings.pick('Operator', 'Operator'), value: unit.fullName),
                    _SpecRow(label: strings.pick('Address', 'Tirahan'), value: unit.address.isNotEmpty ? unit.address : '—'),
                    if (unit.driverName.isNotEmpty)
                      _SpecRow(label: strings.pick('Assigned Driver', 'Driver'), value: unit.driverName),
                    if (unit.driverLicenseNo.isNotEmpty)
                      _SpecRow(label: strings.pick("Driver's License", 'Lisensya'), value: unit.driverLicenseNo, mono: true),
                    if (unit.cedulaSerialNo.isNotEmpty)
                      _SpecRow(label: 'Cedula (CTC) #', value: unit.cedulaSerialNo, mono: true),
                    _SpecRow(
                      label: strings.pick('Payment Status', 'Bayad'),
                      value: unit.officialReceiptNo.isNotEmpty
                          ? '${unit.paymentStatus} (OR# ${unit.officialReceiptNo})'
                          : unit.paymentStatus,
                      mono: true,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.pick('ATTACHED REQUIREMENTS', 'NAKALAKIP NA DOKUMENTO'),
                      style: CivicTheme.monoStyle(fontSize: 10, color: palette.muted),
                    ),
                    const SizedBox(height: 10),
                    ...docs.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                doc.$1,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                              ),
                            ),
                            CivicStatusBadge(
                              label: doc.$2
                                  ? strings.pick('Attached', 'Mayroon')
                                  : strings.pick('Missing', 'Wala'),
                              tone: doc.$2
                                  ? CivicStatusTone.active
                                  : CivicStatusTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (onOpenECopy != null || onOpenViolations != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onOpenECopy != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onOpenECopy!();
                          },
                          icon: const Icon(Icons.verified_outlined, size: 17),
                          label: Text(strings.viewECopyAction),
                        ),
                      ),
                    if (onOpenECopy != null && onOpenViolations != null)
                      const SizedBox(width: 10),
                    if (onOpenViolations != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onOpenViolations!();
                          },
                          icon: const Icon(Icons.gavel_outlined, size: 17),
                          label: Text(strings.violationsAction),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: mono
                  ? CivicTheme.monoStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    )
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
