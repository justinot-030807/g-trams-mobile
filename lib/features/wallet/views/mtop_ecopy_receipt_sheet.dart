import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/wallet/widgets/digital_operator_id_card.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Opens the offline-cached Watermarked MTOP E-Copy & Payment E-Receipt (`OR#`) sheet.
Future<void> showMtopECopyReceiptSheet(
  BuildContext context, {
  required FranchiseRecord unit,
  required MobileUser user,
  required AppStrings strings,
  DateTime? lastSyncedAt,
  bool isOfflineFallback = false,
  int initialTabIndex = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scrollController) => MtopECopyReceiptSheet(
        unit: unit,
        user: user,
        strings: strings,
        lastSyncedAt: lastSyncedAt,
        isOfflineFallback: isOfflineFallback,
        initialTabIndex: initialTabIndex,
        scrollController: scrollController,
      ),
    ),
  );
}

class MtopECopyReceiptSheet extends StatefulWidget {
  const MtopECopyReceiptSheet({
    super.key,
    required this.unit,
    required this.user,
    required this.strings,
    this.lastSyncedAt,
    this.isOfflineFallback = false,
    this.initialTabIndex = 0,
    this.scrollController,
  });

  final FranchiseRecord unit;
  final MobileUser user;
  final AppStrings strings;
  final DateTime? lastSyncedAt;
  final bool isOfflineFallback;
  final int initialTabIndex;
  final ScrollController? scrollController;

  @override
  State<MtopECopyReceiptSheet> createState() => _MtopECopyReceiptSheetState();
}

class _MtopECopyReceiptSheetState extends State<MtopECopyReceiptSheet> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;

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
                      strings.pick(
                        'Official E-Copy & E-Receipt',
                        'Opisyal na E-Copy at E-Resibo',
                      ),
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
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        // Offline-ready timestamp strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isOfflineFallback
                      ? Icons.cloud_off_rounded
                      : Icons.offline_pin_outlined,
                  size: 15,
                  color: widget.isOfflineFallback
                      ? CivicColors.amberOchre
                      : CivicColors.civicGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${strings.offlineReadyLabel} · ${strings.lastSyncedLabel}: ${ManilaDateFormatter.formatSyncTimestamp(widget.lastSyncedAt, isFil: strings.isFil)}',
                    style: CivicTheme.monoStyle(
                      fontSize: 10,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Segmented Switch: MTOP E-Copy | Payment E-Receipt
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: Text(strings.mtopECopyTab),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: Text(strings.paymentReceiptTab),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (sel) => setState(() => _tabIndex = sel.first),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: palette.border),

        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              if (_tabIndex == 0)
                _WatermarkedMtopCertificateCard(
                  unit: widget.unit,
                  user: widget.user,
                  strings: strings,
                )
              else
                _PaymentEReceiptSection(
                  unit: widget.unit,
                  strings: strings,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WatermarkedMtopCertificateCard extends StatelessWidget {
  const _WatermarkedMtopCertificateCard({
    required this.unit,
    required this.user,
    required this.strings,
  });

  final FranchiseRecord unit;
  final MobileUser user;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final qrUrl = DigitalOperatorIdCard.verificationUrlFor(
      user.id.isNotEmpty ? user.id : unit.operatorId,
    );
    final issueDate = unit.approvalDate ?? unit.issuedPermit?.approvalDate ?? unit.dateApplied;
    final expDate = unit.expiryDate ?? unit.issuedPermit?.expiryDate;

    final watermarkTitle = unit.status == 'Active - Under Warning'
        ? 'ACTIVE · UNDER WARNING'
        : unit.status == 'Ready for Pickup'
            ? 'SIGNED · FOR PICKUP'
            : 'APPROVED';

    final watermarkColor = unit.status == 'Active - Under Warning'
        ? CivicColors.amberOchre
        : CivicColors.civicGreen;

    // Certificate always uses crisp warm-paper ledger ink for high-legibility official presentation.
    return Container(
      decoration: BoxDecoration(
        color: CivicColors.purePaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CivicColors.gasanGold, width: 1.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle Municipal Seal Center Watermark
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/images/gasan-logo.png',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Rotated Official E-Copy Watermark Stamp
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -22 * math.pi / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: watermarkColor.withValues(alpha: 0.28),
                        width: 3,
                      ),
                      color: watermarkColor.withValues(alpha: 0.03),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          watermarkTitle,
                          textAlign: TextAlign.center,
                          style: CivicTheme.monoStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: watermarkColor.withValues(alpha: 0.3),
                            letterSpacing: 2.2,
                          ),
                        ),
                        Text(
                          'ELECTRONIC COPY • VALID ISSUANCE',
                          textAlign: TextAlign.center,
                          style: CivicTheme.monoStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: watermarkColor.withValues(alpha: 0.35),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Official Foreground Certificate Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Official LGU Gasan Header
                Row(
                  children: [
                    Image.asset(
                      'assets/images/gasan-logo.png',
                      width: 44,
                      height: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPUBLIC OF THE PHILIPPINES',
                            style: CivicTheme.monoStyle(
                              fontSize: 9,
                              color: CivicColors.slateTaupe,
                            ),
                          ),
                          Text(
                            'MUNICIPALITY OF GASAN, MARINDUQUE',
                            style: CivicTheme.monoStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.gasanMaroon,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            GasanConstants.licensingOfficeName,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: CivicColors.inkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CivicColors.gasanMaroon,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "MOTORIZED TRICYCLE OPERATOR'S PERMIT",
                        textAlign: TextAlign.center,
                        style: CivicTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.purePaper,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MUNICIPAL (TRICYCLE) FRANCHISE • E-COPY',
                        textAlign: TextAlign.center,
                        style: CivicTheme.monoStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: CivicColors.gasanGoldAccessible,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Key Identifiers Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CivicColors.warmAlabaster,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CivicColors.sandHairline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CertField(
                              label: 'MTOP NO.',
                              value: unit.displayMtopNo.isNotEmpty
                                  ? unit.displayMtopNo
                                  : 'PENDING',
                              highlight: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CertField(
                              label: 'PLATE NO.',
                              value: unit.plateNo.isNotEmpty
                                  ? unit.plateNo.toUpperCase()
                                  : 'PENDING',
                              highlight: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _CertField(
                              label: 'BODY / SIDECAR #',
                              value: unit.bodyNumber.isNotEmpty
                                  ? '#${unit.bodyNumber}'
                                  : '—',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CertField(
                              label: 'APPLICATION TYPE',
                              value: unit.applicationType.toUpperCase(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Structured Ledger Rows
                _CertDetailRow(
                  label: 'Registered Operator',
                  value: unit.fullName.isNotEmpty
                      ? unit.fullName.toUpperCase()
                      : user.name.toUpperCase(),
                ),
                _CertDetailRow(
                  label: 'Address',
                  value: unit.address.isNotEmpty
                      ? unit.address.toUpperCase()
                      : 'GASAN, MARINDUQUE',
                ),
                _CertDetailRow(
                  label: 'TODA Association',
                  value: unit.todaName.isNotEmpty ? unit.todaName : 'NON-TODA',
                ),
                _CertDetailRow(
                  label: 'Authorized Route Zone',
                  value: '${unit.formattedZone.toUpperCase()} ZONE',
                ),
                _CertDetailRow(
                  label: 'Make / Year Model',
                  value:
                      '${unit.make.isNotEmpty ? unit.make : '—'} ${unit.made.isNotEmpty ? '(${unit.made})' : ''}'
                          .trim()
                          .toUpperCase(),
                ),
                _CertDetailRow(
                  label: 'Motor Number',
                  value: unit.motorNo.isNotEmpty
                      ? unit.motorNo.toUpperCase()
                      : 'N/A',
                  mono: true,
                ),
                _CertDetailRow(
                  label: 'Chassis Number',
                  value: unit.chassisNo.isNotEmpty
                      ? unit.chassisNo.toUpperCase()
                      : 'N/A',
                  mono: true,
                ),
                _CertDetailRow(
                  label: 'Date Issued (PHT)',
                  value: ManilaDateFormatter.formatLongDate(
                    issueDate,
                    isFil: strings.isFil,
                  ),
                  mono: true,
                ),
                _CertDetailRow(
                  label: 'Valid Until (PHT)',
                  value: ManilaDateFormatter.formatLongDate(
                    expDate,
                    isFil: strings.isFil,
                  ),
                  mono: true,
                  isLast: true,
                ),
                const SizedBox(height: 16),

                // Signatory + Scannable QR Stamp Footer
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APPROVED BY AUTHORITY OF:',
                            style: CivicTheme.monoStyle(
                              fontSize: 8.5,
                              color: CivicColors.slateTaupe,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            GasanConstants.municipalSignatory,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.inkCharcoal,
                            ),
                          ),
                          const Text(
                            'Municipal Vice Mayor • OVM',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: CivicColors.slateTaupe,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CivicColors.purePaper,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CivicColors.sandHairline),
                      ),
                      child: QrImageView(
                        data: qrUrl,
                        size: 74,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        backgroundColor: CivicColors.purePaper,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertField extends StatelessWidget {
  const _CertField({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CivicTheme.monoStyle(
            fontSize: 9,
            color: CivicColors.slateTaupe,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CivicTheme.monoStyle(
            fontSize: highlight ? 14 : 12,
            fontWeight: FontWeight.w800,
            color:
                highlight ? CivicColors.gasanMaroon : CivicColors.inkCharcoal,
          ),
        ),
      ],
    );
  }
}

class _CertDetailRow extends StatelessWidget {
  const _CertDetailRow({
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: CivicColors.sandHairline, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: CivicColors.slateTaupe,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? CivicTheme.monoStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: CivicColors.inkCharcoal,
                    )
                  : const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CivicColors.inkCharcoal,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentEReceiptSection extends StatelessWidget {
  const _PaymentEReceiptSection({
    required this.unit,
    required this.strings,
  });

  final FranchiseRecord unit;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final orNo = unit.officialReceiptNo.isNotEmpty
        ? unit.officialReceiptNo
        : (unit.issuedPermit?.officialReceiptNo ?? '');
    final amountPaid = unit.amountPaid > 0
        ? unit.amountPaid
        : (unit.issuedPermit?.amountPaid ?? 0);
    final payDate = unit.paymentDate ?? unit.issuedPermit?.paymentDate;
    final payMethod = unit.paymentMethod.isNotEmpty
        ? unit.paymentMethod
        : (unit.issuedPermit?.paymentMethod ?? '');
    final cashier = unit.cashierName.isNotEmpty
        ? unit.cashierName
        : (unit.issuedPermit?.cashierName ?? '');

    final hasCurrentReceipt =
        orNo.isNotEmpty || unit.paymentStatus == 'Paid' || amountPaid > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCurrentReceipt)
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: palette.brandAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.pick(
                          'MUNICIPAL TREASURY E-RECEIPT',
                          'OPISYAL NA E-RESIBO NG TREASURY',
                        ),
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    CivicStatusBadge(
                      label: unit.paymentStatus.isNotEmpty
                          ? unit.paymentStatus
                          : 'Paid',
                      tone: unit.paymentStatus == 'Paid' || orNo.isNotEmpty
                          ? CivicStatusTone.active
                          : CivicStatusTone.inProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFICIAL RECEIPT NO. (OR#)',
                        style: CivicTheme.monoStyle(
                          fontSize: 9.5,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        orNo.isNotEmpty ? orNo : 'RECORDED',
                        style: CivicTheme.monoStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: palette.brandAccent,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, color: palette.border),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AMOUNT PAID',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 9.5,
                                    color: palette.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ManilaDateFormatter.formatPhp(amountPaid),
                                  style: CivicTheme.monoStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'METHOD',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 9.5,
                                    color: palette.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  payMethod.isNotEmpty ? payMethod : 'Cash',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReceiptMetaRow(
                  label: strings.pick('Date Paid (PHT)', 'Petsa ng Bayad'),
                  value: ManilaDateFormatter.formatLongDate(
                    payDate,
                    isFil: strings.isFil,
                  ),
                ),
                _ReceiptMetaRow(
                  label: strings.pick('Payer Name', 'Pangalan ng Nagbayad'),
                  value: unit.payerName.isNotEmpty
                      ? unit.payerName
                      : unit.fullName,
                ),
                _ReceiptMetaRow(
                  label: strings.pick('Plate / MTOP', 'Plaka / MTOP'),
                  value:
                      '${unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING'}${unit.displayMtopNo.isNotEmpty ? ' • ${unit.displayMtopNo}' : ''}',
                  mono: true,
                ),
                if (cashier.isNotEmpty)
                  _ReceiptMetaRow(
                    label: strings.pick('Treasury Cashier', 'Cashier'),
                    value: cashier,
                  ),
                if (unit.paymentRemarks.isNotEmpty)
                  _ReceiptMetaRow(
                    label: strings.pick('Remarks', 'Tala'),
                    value: unit.paymentRemarks,
                  ),
              ],
            ),
          )
        else
          CivicBanner(
            tone: CivicStatusTone.inProgress,
            icon: Icons.payments_outlined,
            title: strings.pick(
              'No Official Receipt Recorded Yet',
              'Wala Pang Naitalang Official Receipt',
            ),
            message: strings.pick(
              'Once your franchise fee is settled at the Municipal Cashier / Treasury window, your Official Receipt (OR#) will appear here and cache offline.',
              'Kapag nabayaran na ang franchise fee sa Municipal Cashier / Treasury, lalabas dito ang iyong Official Receipt (OR#) kahit offline.',
            ),
          ),

        // Prior Term / Renewal Payment History
        if (unit.paymentHistory.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            strings.pick(
              'PRIOR TERM / RENEWAL RECEIPTS (${unit.paymentHistory.length})',
              'MGA NAKARAANG RESIBO AT RENEWAL (${unit.paymentHistory.length})',
            ),
            style: CivicTheme.monoStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...unit.paymentHistory.map(
            (term) => Padding(
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
                            term.officialReceiptNo.isNotEmpty
                                ? 'OR# ${term.officialReceiptNo}'
                                : 'OR# —',
                            style: CivicTheme.monoStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: palette.brandAccent,
                            ),
                          ),
                        ),
                        CivicStatusBadge(
                          label: term.applicationType,
                          tone: CivicStatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          ManilaDateFormatter.formatPhp(term.amountPaid),
                          style: CivicTheme.monoStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        if (term.mtopNo.isNotEmpty)
                          Text(
                            'MTOP #${term.mtopNo}',
                            style: CivicTheme.monoStyle(
                              fontSize: 11.5,
                              color: palette.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${ManilaDateFormatter.formatShortDate(term.approvalDate ?? term.paymentDate, isFil: strings.isFil)} → ${ManilaDateFormatter.formatShortDate(term.expiryDate, isFil: strings.isFil)}',
                      style: CivicTheme.monoStyle(
                        fontSize: 10.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReceiptMetaRow extends StatelessWidget {
  const _ReceiptMetaRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? CivicTheme.monoStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    )
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
