import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/features/garage/widgets/franchise_unit_card.dart';
import 'package:gtrams_mobile/features/garage/widgets/garage_skeleton.dart';
import 'package:gtrams_mobile/features/garage/widgets/unit_details_sheet.dart';
import 'package:gtrams_mobile/features/garage/widgets/violations_history_sheet.dart';
import 'package:gtrams_mobile/features/garage/widgets/voluntary_cancellation_sheet.dart';
import 'package:gtrams_mobile/features/garage/widgets/withdraw_application_sheet.dart';
import 'package:gtrams_mobile/features/wallet/views/digital_wallet_sheet.dart';
import 'package:gtrams_mobile/features/wallet/views/mtop_ecopy_receipt_sheet.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Phase 2 Operator Garage Dashboard (`Home` tab).
/// Connects to `GET /api/v1/franchises/my-franchises` and `GET /api/v1/settings`
/// with Hive offline caching for Digital Operator ID & MTOP E-Copy / E-Receipt.
class GarageDashboardTab extends ConsumerWidget {
  const GarageDashboardTab({
    super.key,
    required this.user,
    required this.onNavigateToApply,
  });

  final MobileUser user;
  final void Function({FranchiseRecord? unit, String? actionLabel})
      onNavigateToApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageControllerProvider);
    final controller = ref.read(garageControllerProvider.notifier);
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;
    final effectiveUser = garage.cachedUser ?? user;

    void openWallet() {
      showDigitalWalletSheet(
        context,
        user: effectiveUser,
        units: garage.franchises,
        strings: strings,
        lastSyncedAt: garage.lastSyncedAt,
        isOfflineFallback: garage.isOfflineFallback,
      );
    }

    void openECopy(FranchiseRecord unit, {int initialTab = 0}) {
      showMtopECopyReceiptSheet(
        context,
        unit: unit,
        user: effectiveUser,
        strings: strings,
        lastSyncedAt: garage.lastSyncedAt,
        isOfflineFallback: garage.isOfflineFallback,
        initialTabIndex: initialTab,
      );
    }

    void openViolations(FranchiseRecord unit) {
      showViolationsHistorySheet(
        context,
        unit: unit,
        strings: strings,
        onFetchHistory: () => controller.fetchViolationHistory(unit.id),
      );
    }

    void openDetails(FranchiseRecord unit) {
      showUnitDetailsSheet(
        context,
        unit: unit,
        strings: strings,
        onOpenECopy: (unit.hasApprovedECopy || unit.hasOfficialReceipt)
            ? () => openECopy(unit)
            : null,
        onOpenViolations: () => openViolations(unit),
      );
    }

    Future<void> openWithdraw(FranchiseRecord unit) async {
      final confirmed = await showWithdrawApplicationSheet(
        context,
        unit: unit,
        strings: strings,
        onSubmit: (reason) => controller.withdrawPendingApplication(
          franchiseId: unit.id,
          cancelReason: reason,
        ),
      );
      if (confirmed == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.pick(
                'Application for ${unit.plateNo.isNotEmpty ? unit.plateNo : 'unit'} has been withdrawn.',
                'Na-withdraw na ang aplikasyon para sa ${unit.plateNo.isNotEmpty ? unit.plateNo : 'unit'}.',
              ),
            ),
          ),
        );
      }
    }

    Future<void> openVoluntaryCancel(FranchiseRecord unit) async {
      final submitted = await showVoluntaryCancellationSheet(
        context,
        unit: unit,
        strings: strings,
        onSubmit: (payload) => controller.requestVoluntaryCancellation(
          franchiseId: unit.id,
          reason: payload.reason,
          customReason: payload.customReason,
          remarks: payload.remarks,
          letterText: payload.letterText,
          fileBytes: payload.fileBytes,
          fileName: payload.fileName,
          mimeType: payload.mimeType,
        ),
      );
      if (submitted == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.pick(
                'Voluntary cancellation request submitted to OVM — LLSA I.',
                'Naisumite na sa OVM — LLSA I ang iyong kahilingang pagkansela.',
              ),
            ),
          ),
        );
      }
    }

    final filtered = garage.filteredUnits;
    final hasBlockingError = garage.errorMessage != null &&
        !garage.isOfflineFallback &&
        garage.franchises.isEmpty &&
        !garage.isLoading;

    return RefreshIndicator(
      color: CivicColors.gasanMaroon,
      onRefresh: () => controller.loadGarage(isPullToRefresh: true),
      child: ListView(
        key: const Key('garage_dashboard_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // 1. Heritage Operator Header + Quick Offline Digital Wallet Trigger
          _OperatorHeroCard(
            user: effectiveUser,
            strings: strings,
            lastSyncedAt: garage.lastSyncedAt,
            isOfflineFallback: garage.isOfflineFallback,
            isRefreshing: garage.isRefreshing,
            onOpenWallet: openWallet,
          ),
          const SizedBox(height: 12),

          // 2. Offline Fallback Banner (when cached Hive data is displayed offline)
          if (garage.isOfflineFallback) ...[
            CivicBanner(
              tone: CivicStatusTone.inProgress,
              icon: Icons.cloud_off_rounded,
              title: strings.offlineModeBannerTitle,
              message:
                  '${strings.offlineModeBannerBody}\n${strings.lastSyncedLabel}: ${ManilaDateFormatter.formatSyncTimestamp(garage.lastSyncedAt, isFil: strings.isFil)}',
              action: TextButton.icon(
                onPressed: () => controller.loadGarage(isPullToRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(strings.retry),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Unit Quota Bar (activeCount / maxUnitsPerOperator)
          _UnitQuotaCard(
            occupiedCount: garage.slotOccupyingCount,
            maxUnits: garage.maxUnits,
            franchiseFee: garage.settings.franchiseFee,
            isLoading: garage.isLoading,
            strings: strings,
          ),
          const SizedBox(height: 12),

          // 4. Priority LGU Action Callout (only after initial load)
          if (!garage.isLoading && !hasBlockingError) ...[
            _PriorityActionCard(
              garage: garage,
              strings: strings,
              onOpenDetails: openDetails,
              onOpenViolations: openViolations,
              onNavigateToApply: onNavigateToApply,
            ),
            const SizedBox(height: 16),
          ],

          // 5. Garage Section Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.garageTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.garageSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '${garage.franchises.length} ${strings.pick('UNITS', 'UNIT')}',
                  style: CivicTheme.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. Filter Tabs (All / Active / In-Progress / Past & Archived)
          _GarageFilterBar(
            selected: garage.selectedFilter,
            allCount: garage.franchises.length,
            activeCount: garage.activeUnits.length,
            inProgressCount: garage.inProgressUnits.length,
            pastCount: garage.pastArchivedUnits.length,
            strings: strings,
            onSelected: controller.setFilter,
          ),
          const SizedBox(height: 14),

          // 7. Garage Body States (Loading / Error / Empty / Units List)
          if (garage.isLoading)
            const GarageSkeletonList(cardCount: 2)
          else if (hasBlockingError)
            _ErrorRetryCard(
              title: strings.loadErrorTitle,
              message: garage.errorMessage!,
              retryLabel: strings.retry,
              onRetry: () => controller.loadGarage(isPullToRefresh: true),
            )
          else if (garage.franchises.isEmpty)
            _EmptyGarageCard(
              title: strings.emptyGarageTitle,
              body: strings.emptyGarageBody,
              actionLabel: strings.applyNewAction,
              onAction: () => onNavigateToApply(),
            )
          else if (filtered.isEmpty)
            _EmptyGarageCard(
              title: strings.emptyFilterTitle,
              body: strings.emptyFilterBody,
              actionLabel: strings.showAllUnits,
              onAction: () => controller.setFilter(GarageFilter.all),
            )
          else
            ...filtered.map(
              (unit) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FranchiseUnitCard(
                  unit: unit,
                  strings: strings,
                  franchiseFee: garage.settings.franchiseFee,
                  renewalReminderDays: garage.settings.renewalReminderDays,
                  onViewECopy: () => openECopy(unit),
                  onViewViolations: () => openViolations(unit),
                  onViewDetails: () => openDetails(unit),
                  onWithdraw: () => openWithdraw(unit),
                  onRequestCancellation: () => openVoluntaryCancel(unit),
                  onFixAndReapply: () => onNavigateToApply(
                    unit: unit,
                    actionLabel: strings.fixReapplyAction,
                  ),
                  onRenew: () => onNavigateToApply(
                    unit: unit,
                    actionLabel: strings.renewAction,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OperatorHeroCard extends StatelessWidget {
  const _OperatorHeroCard({
    required this.user,
    required this.strings,
    required this.lastSyncedAt,
    required this.isOfflineFallback,
    required this.isRefreshing,
    required this.onOpenWallet,
  });

  final MobileUser user;
  final AppStrings strings;
  final DateTime? lastSyncedAt;
  final bool isOfflineFallback;
  final bool isRefreshing;
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final greeting = ManilaDateFormatter.manilaGreeting(isFil: strings.isFil);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CivicColors.gasanMaroonDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CivicColors.gasanGold.withValues(alpha: 0.55),
          width: 1.2,
        ),
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
                      greeting.toUpperCase(),
                      style: CivicTheme.monoStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.gasanGoldAccessible,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.name.isNotEmpty ? user.name : 'Operator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: CivicColors.purePaper,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Quick Offline Digital Operator ID Wallet Trigger (48dp touch height)
              Material(
                color: CivicColors.gasanGold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: const Key('hero_digital_id_button'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onOpenWallet,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CivicColors.gasanGold.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: CivicColors.gasanGoldAccessible,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.digitalWalletButton,
                          style: CivicTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: CivicColors.gasanGoldAccessible,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _HeroMetaChip(
                icon: Icons.groups_outlined,
                label: user.todaAssociation.isNotEmpty
                    ? user.todaAssociation
                    : 'NON-TODA',
              ),
              if (user.bodyNumber.isNotEmpty)
                _HeroMetaChip(
                  icon: Icons.tag_rounded,
                  label: 'BODY #${user.bodyNumber}',
                ),
              _HeroMetaChip(
                icon: isOfflineFallback
                    ? Icons.cloud_off_rounded
                    : Icons.offline_pin_outlined,
                label: isRefreshing
                    ? strings.pick('Syncing...', 'Nagsi-sync...')
                    : ManilaDateFormatter.formatSyncTimestamp(
                        lastSyncedAt,
                        isFil: strings.isFil,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: CivicColors.gasanGoldAccessible),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: CivicTheme.monoStyle(
              fontSize: 10.5,
              color: CivicColors.purePaper.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitQuotaCard extends StatelessWidget {
  const _UnitQuotaCard({
    required this.occupiedCount,
    required this.maxUnits,
    required this.franchiseFee,
    required this.isLoading,
    required this.strings,
  });

  final int occupiedCount;
  final int maxUnits;
  final num franchiseFee;
  final bool isLoading;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final safeMax = maxUnits < 1 ? 2 : maxUnits;
    final remaining = (safeMax - occupiedCount).clamp(0, safeMax);

    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.unitQuotaTitle,
                  style: CivicTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ),
              Text(
                '$occupiedCount / $safeMax ${strings.pick('UNITS', 'UNIT')}',
                key: const Key('unit_quota_ratio_text'),
                style: CivicTheme.monoStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: palette.brandAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(safeMax, (idx) {
              final filled = !isLoading && idx < occupiedCount;
              return Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: idx == safeMax - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: filled ? palette.brandAccent : palette.canvas,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: filled ? palette.brandAccent : palette.border,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                remaining == 0
                    ? strings.slotsFull
                    : strings.slotsAvailable(remaining),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
              ),
              Text(
                '${strings.franchiseFeeLabel}: ${ManilaDateFormatter.formatPhp(franchiseFee)}',
                style: CivicTheme.monoStyle(
                  fontSize: 10.5,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityActionCard extends StatelessWidget {
  const _PriorityActionCard({
    required this.garage,
    required this.strings,
    required this.onOpenDetails,
    required this.onOpenViolations,
    required this.onNavigateToApply,
  });

  final GarageState garage;
  final AppStrings strings;
  final void Function(FranchiseRecord) onOpenDetails;
  final void Function(FranchiseRecord) onOpenViolations;
  final void Function({FranchiseRecord? unit, String? actionLabel})
      onNavigateToApply;

  @override
  Widget build(BuildContext context) {
    final target = garage.priorityActionUnit;
    if (target == null) {
      if (!garage.hasAvailableSlot) return const SizedBox.shrink();
      return CivicBanner(
        tone: CivicStatusTone.neutral,
        icon: Icons.add_circle_outline_rounded,
        title: strings.pick(
          'Franchise Slot Available',
          'May Bakanteng Slot ng Prangkisa',
        ),
        message: strings.pick(
          'You may register up to ${garage.maxUnits} tricycle units under Municipal Ordinance Section 4.',
          'Maaari kang magparehistro ng hanggang ${garage.maxUnits} tricycle alinsunod sa Municipal Ordinance Section 4.',
        ),
        action: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => onNavigateToApply(),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
          label: Text(strings.applyNewAction),
        ),
      );
    }

    if (target.status == 'For Payment') {
      return CivicBanner(
        tone: CivicStatusTone.inProgress,
        icon: Icons.payments_outlined,
        title: strings.pick(
          'Payment Required — ${target.plateNo}',
          'Kailangan Magbayad — ${target.plateNo}',
        ),
        message: strings.pick(
          'Pay ${ManilaDateFormatter.formatPhp(garage.settings.franchiseFee)} at the Municipal Cashier / Treasury window so OVM can route your MTOP for signing.',
          'Magbayad ng ${ManilaDateFormatter.formatPhp(garage.settings.franchiseFee)} sa Municipal Cashier / Treasury upang mai-endorso sa lagdaan.',
        ),
        action: TextButton.icon(
          onPressed: () => onOpenDetails(target),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: Text(strings.detailsAction),
        ),
      );
    }

    if (target.status == 'Ready for Pickup') {
      return CivicBanner(
        tone: CivicStatusTone.active,
        icon: Icons.assignment_turned_in_outlined,
        title: strings.pick(
          'MTOP Signed & Ready for Pickup — ${target.plateNo}',
          'Handa na para Kunin ang MTOP — ${target.plateNo}',
        ),
        message: strings.pick(
          'Claim your official printed MTOP certificate and stickers at the Office of the Municipal Vice Mayor (OVM) — LLSA I.',
          'Kunin ang printed MTOP certificate at sticker sa Office of the Municipal Vice Mayor (OVM) — LLSA I.',
        ),
        action: TextButton.icon(
          onPressed: () => onOpenDetails(target),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: Text(strings.detailsAction),
        ),
      );
    }

    if (target.isRejectedNeedsFix || target.isRefilableRenewal) {
      return CivicBanner(
        tone: CivicStatusTone.danger,
        icon: Icons.build_circle_outlined,
        title: strings.pick(
          'Application Needs Attention — ${target.plateNo}',
          'Kailangan Ayusin ang Aplikasyon — ${target.plateNo}',
        ),
        message: target.cancelReason.isNotEmpty
            ? target.cancelReason
            : strings.pick(
                'Review OVM — LLSA I remarks and submit corrected details.',
                'Suriin ang puna ng OVM — LLSA I at isumite muli ang tamang detalye.',
              ),
        action: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: CivicColors.crimsonAlert,
            foregroundColor: CivicColors.purePaper,
          ),
          onPressed: () => onNavigateToApply(
            unit: target,
            actionLabel: strings.fixReapplyAction,
          ),
          icon: const Icon(Icons.build_circle_outlined, size: 17),
          label: Text(strings.fixReapplyAction),
        ),
      );
    }

    if (target.status == 'Suspended') {
      return CivicBanner(
        tone: CivicStatusTone.danger,
        icon: Icons.gavel_rounded,
        title: strings.pick(
          'Unit Suspended — ${target.plateNo}',
          'Suspendido ang Unit — ${target.plateNo}',
        ),
        message: strings.pick(
          'Review your 2nd Offense citation and coordinate with OVM — LLSA I & Municipal Treasury.',
          'Tingnan ang detalye ng 2nd Offense at makipag-ugnayan sa OVM — LLSA I at Municipal Treasury.',
        ),
        action: TextButton.icon(
          onPressed: () => onOpenViolations(target),
          icon: const Icon(Icons.gavel_outlined, size: 16),
          label: Text(strings.violationsAction),
        ),
      );
    }

    if (target.status == 'Expired' ||
        target.isWithinRenewalWindow(garage.settings.renewalReminderDays)) {
      return CivicBanner(
        tone: target.status == 'Expired'
            ? CivicStatusTone.danger
            : CivicStatusTone.inProgress,
        icon: Icons.autorenew_rounded,
        title: target.status == 'Expired'
            ? strings.pick(
                'Franchise Expired — ${target.plateNo}',
                'Nag-expire na ang Prangkisa — ${target.plateNo}',
              )
            : strings.pick(
                'Renewal Window Open — ${target.plateNo}',
                'Bukas na ang Renewal — ${target.plateNo}',
              ),
        message: strings.pick(
          'Renew your MTOP promptly to stay road-authorized and avoid late penalties.',
          'I-renew agad ang iyong MTOP upang manatiling awtorisado at makaiwas sa multa.',
        ),
        action: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => onNavigateToApply(
            unit: target,
            actionLabel: strings.renewAction,
          ),
          icon: const Icon(Icons.autorenew_rounded, size: 17),
          label: Text(strings.renewAction),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _GarageFilterBar extends StatelessWidget {
  const _GarageFilterBar({
    required this.selected,
    required this.allCount,
    required this.activeCount,
    required this.inProgressCount,
    required this.pastCount,
    required this.strings,
    required this.onSelected,
  });

  final GarageFilter selected;
  final int allCount;
  final int activeCount;
  final int inProgressCount;
  final int pastCount;
  final AppStrings strings;
  final ValueChanged<GarageFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      (GarageFilter.all, strings.filterAll, allCount),
      (GarageFilter.active, strings.filterActive, activeCount),
      (GarageFilter.inProgress, strings.filterInProgress, inProgressCount),
      (GarageFilter.pastArchived, strings.filterPastArchived, pastCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = selected == tab.$1;
          final activeBg =
              isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;
          final activeFg =
              isDark ? CivicColors.obsidianEarth : CivicColors.purePaper;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? activeBg : palette.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: Key('garage_filter_${tab.$1.name}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelected(tab.$1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? activeBg : palette.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? activeFg : palette.ink,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeFg.withValues(alpha: 0.16)
                              : palette.canvas,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${tab.$3}',
                          style: CivicTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? activeFg : palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyGarageCard extends StatelessWidget {
  const _EmptyGarageCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return CivicCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              Icons.electric_rickshaw_outlined,
              size: 30,
              color: palette.brandAccent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          CivicPrimaryButton(
            label: actionLabel,
            onPressed: onAction,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _ErrorRetryCard extends StatelessWidget {
  const _ErrorRetryCard({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 38,
            color: CivicColors.crimsonAlert,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          CivicPrimaryButton(
            label: retryLabel,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
