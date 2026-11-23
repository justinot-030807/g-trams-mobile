import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/wallet/views/mtop_ecopy_receipt_sheet.dart';
import 'package:gtrams_mobile/features/wallet/widgets/digital_operator_id_card.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens the unified Offline Digital Wallet (3D-Flip Operator ID + Cached MTOP E-Copies & E-Receipts).
Future<void> showDigitalWalletSheet(
  BuildContext context, {
  required MobileUser user,
  required List<FranchiseRecord> units,
  required AppStrings strings,
  DateTime? lastSyncedAt,
  bool isOfflineFallback = false,
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
      builder: (_, scrollController) => DigitalWalletSheet(
        user: user,
        units: units,
        strings: strings,
        lastSyncedAt: lastSyncedAt,
        isOfflineFallback: isOfflineFallback,
        scrollController: scrollController,
      ),
    ),
  );
}

class DigitalWalletSheet extends StatelessWidget {
  const DigitalWalletSheet({
    super.key,
    required this.user,
    required this.units,
    required this.strings,
    this.lastSyncedAt,
    this.isOfflineFallback = false,
    this.scrollController,
  });

  final MobileUser user;
  final List<FranchiseRecord> units;
  final AppStrings strings;
  final DateTime? lastSyncedAt;
  final bool isOfflineFallback;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final walletUnits = units
        .where((f) => f.hasApprovedECopy || f.hasOfficialReceipt)
        .toList();

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
                      strings.digitalWalletTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.offlineReadyLabel} · ${ManilaDateFormatter.formatSyncTimestamp(lastSyncedAt, isFil: strings.isFil)}',
                      style: CivicTheme.monoStyle(
                        fontSize: 10,
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
        Divider(height: 1, color: palette.border),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              if (isOfflineFallback) ...[
                CivicBanner(
                  tone: CivicStatusTone.inProgress,
                  icon: Icons.cloud_off_rounded,
                  title: strings.offlineModeBannerTitle,
                  message: strings.pick(
                    'This Digital ID and your MTOP E-Copies are securely cached on this device.',
                    'Naka-save sa device na ito ang iyong Digital ID at mga MTOP E-Copy kahit walang signal.',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3D-Flip Digital Operator ID Card
              DigitalOperatorIdCard(
                user: user,
                strings: strings,
                lastSyncedAt: lastSyncedAt,
              ),
              const SizedBox(height: 22),

              // Cached MTOP E-Copies & E-Receipts List
              Text(
                strings.pick(
                  'CACHED MTOP E-COPIES & RECEIPTS (${walletUnits.length})',
                  'NAKA-SAVE NA MTOP E-COPY AT RESIBO (${walletUnits.length})',
                ),
                style: CivicTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 10),
              if (walletUnits.isEmpty)
                CivicCard(
                  child: Text(
                    strings.pick(
                      'Approved MTOP E-Copies and Municipal Treasury Official Receipts (OR#) will automatically cache here for offline viewing.',
                      'Awtomatikong mase-save dito ang iyong aprubadong MTOP E-Copy at Official Receipt (OR#) upang matingnan kahit walang signal.',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.45),
                  ),
                )
              else
                ...walletUnits.map(
                  (unit) => Padding(
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
                                  unit.plateNo.isNotEmpty
                                      ? unit.plateNo.toUpperCase()
                                      : 'PENDING',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                              CivicStatusBadge(
                                label: unit.status,
                                tone: unit.statusTone,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (unit.displayMtopNo.isNotEmpty)
                                Text(
                                  'MTOP #${unit.displayMtopNo}',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                ),
                              if (unit.officialReceiptNo.isNotEmpty)
                                Text(
                                  'OR# ${unit.officialReceiptNo}',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 11,
                                    color: CivicColors.civicGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: () {
                                    showMtopECopyReceiptSheet(
                                      context,
                                      unit: unit,
                                      user: user,
                                      strings: strings,
                                      lastSyncedAt: lastSyncedAt,
                                      isOfflineFallback: isOfflineFallback,
                                      initialTabIndex: 0,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.verified_outlined,
                                    size: 16,
                                  ),
                                  label: Text(strings.mtopECopyTab),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: () {
                                    showMtopECopyReceiptSheet(
                                      context,
                                      unit: unit,
                                      user: user,
                                      strings: strings,
                                      lastSyncedAt: lastSyncedAt,
                                      isOfflineFallback: isOfflineFallback,
                                      initialTabIndex: 1,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 16,
                                  ),
                                  label: Text(strings.paymentReceiptTab),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
