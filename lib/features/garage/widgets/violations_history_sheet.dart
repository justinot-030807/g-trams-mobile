import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/violation_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Opens the per-unit Violations & 3-Tier Sanctions History modal bottom sheet.
Future<void> showViolationsHistorySheet(
  BuildContext context, {
  required FranchiseRecord unit,
  required AppStrings strings,
  required Future<ViolationHistoryResponse> Function() onFetchHistory,
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
      builder: (_, scrollController) => ViolationsHistorySheet(
        unit: unit,
        strings: strings,
        onFetchHistory: onFetchHistory,
        scrollController: scrollController,
      ),
    ),
  );
}

class ViolationsHistorySheet extends StatefulWidget {
  const ViolationsHistorySheet({
    super.key,
    required this.unit,
    required this.strings,
    required this.onFetchHistory,
    this.scrollController,
  });

  final FranchiseRecord unit;
  final AppStrings strings;
  final Future<ViolationHistoryResponse> Function() onFetchHistory;
  final ScrollController? scrollController;

  @override
  State<ViolationsHistorySheet> createState() => _ViolationsHistorySheetState();
}

class _ViolationsHistorySheetState extends State<ViolationsHistorySheet> {
  bool _isLoading = true;
  String? _error;
  ViolationHistoryResponse? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.onFetchHistory();
      if (!mounted) return;
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.mapDioError(err).message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final activeStatus = _data?.franchiseStatus.isNotEmpty == true
        ? _data!.franchiseStatus
        : widget.unit.status;
    final suspensionEnd = _data?.suspensionEndDate ?? widget.unit.suspensionEndDate;

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
                      strings.violationsSheetTitle,
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
        Divider(height: 1, color: palette.border),

        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              // Prominent Sanction Status Banner (Active Warning / Suspended / Revoked)
              ..._buildSanctionBanner(activeStatus, suspensionEnd, strings),

              // 3-Tier Progressive Discipline Ladder
              _ThreeTierLadderCard(
                activeCount: _data?.activeViolationsCount ??
                    widget.unit.activeViolationCount,
                policy: _data?.policy ?? const ViolationPolicySummary(),
                strings: strings,
              ),
              const SizedBox(height: 16),

              // Body: Loading / Error / Empty / Citations List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                CivicBanner(
                  tone: CivicStatusTone.danger,
                  title: strings.pick(
                    'Could Not Load Violation History',
                    'Hindi Ma-load ang Kasaysayan ng Paglabag',
                  ),
                  message: _error!,
                  action: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(strings.retry),
                  ),
                )
              else if (_data == null || _data!.history.isEmpty)
                CivicCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 40,
                        color: CivicColors.civicGreen,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.cleanStandingTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.cleanStandingBody,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      strings.pick(
                        'Recorded Citations (${_data!.totalViolationsCount})',
                        'Mga Naitalang Paglabag (${_data!.totalViolationsCount})',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      strings.pick(
                        'Active: ${_data!.activeViolationsCount}',
                        'Aktibo: ${_data!.activeViolationsCount}',
                      ),
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _data!.activeViolationsCount > 0
                            ? CivicColors.crimsonAlert
                            : CivicColors.civicGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._data!.history.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ViolationRecordCard(
                      record: record,
                      strings: strings,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSanctionBanner(
    String status,
    DateTime? suspensionEnd,
    AppStrings strings,
  ) {
    if (status == 'Active - Under Warning') {
      return [
        CivicBanner(
          tone: CivicStatusTone.inProgress,
          icon: Icons.warning_amber_rounded,
          title: strings.pick(
            'Active Warning (1st Offense)',
            'Aktibong Babala (Unang Paglabag)',
          ),
          message: strings.pick(
            'Unit remains authorized under warning. A 2nd active offense triggers suspension and a fine.',
            'Maaari pa ring bumiyahe habang may babala. Ang ikalawang paglabag ay may suspensiyon at multa.',
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    if (status == 'Suspended') {
      final untilStr = suspensionEnd != null
          ? ' ${strings.pick('until', 'hanggang')} ${ManilaDateFormatter.formatLongDate(suspensionEnd, isFil: strings.isFil)}'
          : '';
      return [
        CivicBanner(
          tone: CivicStatusTone.danger,
          icon: Icons.gpp_maybe_outlined,
          title: strings.pick(
            'Franchise Suspended (2nd Offense)$untilStr',
            'Suspendido ang Prangkisa (Ikalawang Paglabag)$untilStr',
          ),
          message: strings.pick(
            'Visit OVM — LLSA I and settle your fine at Municipal Cashier to lift this suspension.',
            'Pumunta sa OVM — LLSA I at bayaran ang multa sa Municipal Cashier upang maalis ang suspensiyon.',
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    if (status == 'Revoked') {
      return [
        CivicBanner(
          tone: CivicStatusTone.danger,
          icon: Icons.block_rounded,
          title: strings.pick(
            'Franchise Revoked (3rd / Grave Offense)',
            'Binawi ang Prangkisa (Ikatlo / Mabigat na Paglabag)',
          ),
          message: strings.pick(
            'Revoked by the Municipality of Gasan. Coordinate with OVM — LLSA I for inquiries.',
            'Binawi na ng Munisipyo ng Gasan. Makipag-ugnayan sa OVM — LLSA I para sa katanungan.',
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    return const [];
  }
}

class _ThreeTierLadderCard extends StatelessWidget {
  const _ThreeTierLadderCard({
    required this.activeCount,
    required this.policy,
    required this.strings,
  });

  final int activeCount;
  final ViolationPolicySummary policy;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final fineStr = ManilaDateFormatter.formatPhp(policy.secondOffenseFine);

    final tiers = [
      (
        1,
        strings.pick('1st Offense', '1st Offense'),
        strings.pick('Official Warning', 'Opisyal na Babala'),
        CivicStatusTone.inProgress,
      ),
      (
        2,
        strings.pick('2nd Offense', '2nd Offense'),
        strings.pick(
          '${policy.secondOffenseSuspensionDays}-Day Suspension + $fineStr',
          '${policy.secondOffenseSuspensionDays} Araw na Suspensiyon + $fineStr',
        ),
        CivicStatusTone.danger,
      ),
      (
        3,
        strings.pick('3rd / Grave', '3rd / Grave'),
        strings.pick('Permanent Revocation', 'Permanenteng Pagbawi'),
        CivicStatusTone.danger,
      ),
    ];

    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.threeTierPolicyTitle,
            style: CivicTheme.monoStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...tiers.map((tier) {
            final reached = activeCount >= tier.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached
                          ? (tier.$1 == 1
                              ? CivicColors.amberOchre
                              : CivicColors.crimsonAlert)
                          : palette.canvas,
                      border: Border.all(
                        color: reached ? Colors.transparent : palette.border,
                      ),
                    ),
                    child: Text(
                      '${tier.$1}',
                      style: CivicTheme.monoStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: reached ? CivicColors.purePaper : palette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.$2,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                        ),
                        Text(
                          tier.$3,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (reached)
                    CivicStatusBadge(
                      label: strings.pick('Triggered', 'Naitala'),
                      tone: tier.$4,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ViolationRecordCard extends StatelessWidget {
  const _ViolationRecordCard({
    required this.record,
    required this.strings,
  });

  final ViolationRecord record;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final tone = record.status == 'Settled' || record.status == 'Lifted'
        ? CivicStatusTone.active
        : (record.sanction.type == 'Warning'
            ? CivicStatusTone.inProgress
            : CivicStatusTone.danger);

    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CivicStatusBadge(
                label: record.isGrave
                    ? 'GRAVE • ${record.sanction.type}'
                    : '${record.offenseLabel} • ${record.sanction.type}',
                tone: tone,
              ),
              CivicStatusBadge(
                label: record.status,
                tone: record.isActive
                    ? CivicStatusTone.danger
                    : CivicStatusTone.active,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.violationType,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                ManilaDateFormatter.formatShortDate(
                  record.createdAt,
                  isFil: strings.isFil,
                ),
                style: CivicTheme.monoStyle(fontSize: 10.5, color: palette.muted),
              ),
              if (record.sanction.fineAmount > 0)
                Text(
                  'FINE: ${ManilaDateFormatter.formatPhp(record.sanction.fineAmount)}',
                  style: CivicTheme.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.crimsonAlert,
                  ),
                ),
              if (record.sanction.suspensionDays > 0)
                Text(
                  '${record.sanction.suspensionDays}D SUSPENSION',
                  style: CivicTheme.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.crimsonAlert,
                  ),
                ),
            ],
          ),
          if (record.remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.remarks,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${strings.pick('Recorded by', 'Itinala ni')}: ${record.recordedByName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          if (!record.isActive && record.settledAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${strings.pick('Settled', 'Nabayaran/Naayos')}: ${ManilaDateFormatter.formatShortDate(record.settledAt, isFil: strings.isFil)}${record.settledNotes.isNotEmpty ? ' — ${record.settledNotes}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: CivicColors.civicGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
