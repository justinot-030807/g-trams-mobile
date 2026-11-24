import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/features/toda/view_models/toda_governance_controller.dart';
import 'package:gtrams_mobile/features/toda/widgets/add_member_sheet.dart';
import 'package:gtrams_mobile/features/toda/widgets/qr_verifier_section.dart';
import 'package:gtrams_mobile/features/toda/widgets/request_removal_sheet.dart';
import 'package:gtrams_mobile/features/toda/widgets/roster_ocr_section.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Phase 4 — TODA President Governance Hub (`TODA` tab).
/// Provides KPI Member Directory, Individual Registration (+ Auto-Next Body#),
/// AI OCR Roster Scan/Editor + History, Member Removal Tracker, and Built-in QR Verifier.
class TodaGovernanceHubTab extends ConsumerWidget {
  const TodaGovernanceHubTab({
    super.key,
    required this.user,
  });

  final MobileUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(todaGovernanceControllerProvider);
    final controller = ref.read(todaGovernanceControllerProvider.notifier);
    final captureService = ref.watch(documentCaptureServiceProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;

    final todaName = hub.directory.todaName.isNotEmpty
        ? hub.directory.todaName
        : user.todaAssociation;

    Future<void> openAddMember() async {
      final msg = await showAddTodaMemberSheet(
        context,
        todaName: todaName,
        strings: strings,
        onFetchNextBodyNumber: controller.fetchNextBodyNumber,
        onSubmit: controller.addIndividualMember,
      );
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }

    Future<void> openRequestRemoval(TodaMemberProfile member) async {
      final submitted = await showRequestRemovalSheet(
        context,
        member: member,
        todaName: todaName,
        strings: strings,
        onSubmit: ({
          required String memberId,
          required String reason,
          required String details,
        }) =>
            controller.submitRemovalRequest(
          memberId: memberId,
          reason: reason,
          details: details,
        ),
      );
      if (submitted == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.pick(
                'Removal request for ${member.name} routed to OVM — LLSA I.',
                'Naipadala na sa OVM — LLSA I ang kahilingang pag-alis para kay ${member.name}.',
              ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      color: CivicColors.gasanMaroon,
      onRefresh: () => controller.loadHubData(isPullToRefresh: true),
      child: ListView(
        key: const Key('toda_hub_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // 1. Clean Heritage Maroon TODA Governance Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: CivicColors.gasanMaroonDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CivicColors.gasanGold.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todaName.isNotEmpty ? todaName : 'TODA Association',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: CivicColors.purePaper,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        strings.pick(
                          'TODA President Console',
                          'TODA President Console',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CivicColors.gasanGoldAccessible,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: CivicColors.gasanGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: const Key('toda_add_member_hero_button'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: openAddMember,
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
                            Icons.person_add_alt_1_outlined,
                            size: 17,
                            color: CivicColors.gasanGoldAccessible,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            strings.pick('Add', 'Dagdag'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
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
          ),
          const SizedBox(height: 12),

          // 2. 4-Card KPI Strip (Tabular JetBrains Mono)
          _TodaKpiGrid(stats: hub.directory.stats, strings: strings),
          const SizedBox(height: 14),

          // 3. Section Switcher Pills (Members | Roster OCR | Removals | QR Verify)
          _TodaSectionBar(
            selected: hub.section,
            membersCount: hub.directory.members.length,
            submissionsCount: hub.submissions.length,
            removalsCount: hub.removalRequests.length,
            strings: strings,
            onSelected: controller.setSection,
          ),
          const SizedBox(height: 14),

          if (hub.errorMessage != null && hub.directory.members.isEmpty) ...[
            CivicBanner(
              tone: CivicStatusTone.danger,
              title: strings.pick(
                'Could Not Load TODA Directory',
                'Hindi Ma-load ang Direktoryo ng TODA',
              ),
              message: hub.errorMessage!,
              action: TextButton.icon(
                onPressed: () => controller.loadHubData(isPullToRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(strings.retry),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 4. Active Section Body
          if (hub.section == TodaHubSection.directory)
            _MemberDirectorySection(
              state: hub,
              controller: controller,
              strings: strings,
              onAddMember: openAddMember,
              onRequestRemoval: openRequestRemoval,
            )
          else if (hub.section == TodaHubSection.rosterScan)
            RosterOcrSection(
              state: hub,
              controller: controller,
              captureService: captureService,
              strings: strings,
            )
          else if (hub.section == TodaHubSection.removals)
            _RemovalsTrackerSection(
              requests: hub.removalRequests,
              strings: strings,
              palette: palette,
            )
          else
            QrVerifierSection(
              state: hub,
              controller: controller,
              strings: strings,
            ),
        ],
      ),
    );
  }
}

class _TodaKpiGrid extends StatelessWidget {
  const _TodaKpiGrid({
    required this.stats,
    required this.strings,
  });

  final TodaDirectoryStats stats;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: strings.pick('Members', 'Miyembro'),
                value: '${stats.totalMembers}',
                color: palette.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: strings.pick('Active', 'Aktibo'),
                value: '${stats.activeUnits}',
                color: CivicColors.civicGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: strings.pick('Pending', 'Nakabinbin'),
                value: '${stats.pendingUnits}',
                color: CivicColors.amberOchre,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: strings.pick('Expired', 'Expired'),
                value: '${stats.expiredUnits}',
                color: CivicColors.crimsonAlert,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return CivicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: CivicTheme.monoStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaSectionBar extends StatelessWidget {
  const _TodaSectionBar({
    required this.selected,
    required this.membersCount,
    required this.submissionsCount,
    required this.removalsCount,
    required this.strings,
    required this.onSelected,
  });

  final TodaHubSection selected;
  final int membersCount;
  final int submissionsCount;
  final int removalsCount;
  final AppStrings strings;
  final ValueChanged<TodaHubSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;
    final activeFg = isDark ? CivicColors.obsidianEarth : CivicColors.purePaper;

    final items = [
      (TodaHubSection.directory, strings.todaTabDirectory, '$membersCount', Icons.groups_outlined),
      (TodaHubSection.rosterScan, strings.todaTabRoster, '$submissionsCount', Icons.document_scanner_outlined),
      (TodaHubSection.removals, strings.todaTabRemovals, '$removalsCount', Icons.person_remove_outlined),
      (TodaHubSection.qrVerifier, strings.todaTabQrVerify, 'QR', Icons.qr_code_scanner_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = selected == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? activeBg : palette.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: Key('toda_section_${item.$1.name}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelected(item.$1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
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
                      Icon(
                        item.$4,
                        size: 16,
                        color: isSelected ? activeFg : palette.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? activeFg : palette.ink,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeFg.withValues(alpha: 0.16)
                              : palette.canvas,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.$3,
                          style: CivicTheme.monoStyle(
                            fontSize: 10,
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

class _MemberDirectorySection extends StatelessWidget {
  const _MemberDirectorySection({
    required this.state,
    required this.controller,
    required this.strings,
    required this.onAddMember,
    required this.onRequestRemoval,
  });

  final TodaGovernanceState state;
  final TodaGovernanceController controller;
  final AppStrings strings;
  final VoidCallback onAddMember;
  final ValueChanged<TodaMemberProfile> onRequestRemoval;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final members = state.filteredMembers;

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('toda_member_search_field'),
          onChanged: controller.setSearchQuery,
          decoration: InputDecoration(
            hintText: strings.searchMembersHint,
            prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
          ),
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
          CivicCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(Icons.groups_outlined, size: 40, color: palette.brandAccent),
                const SizedBox(height: 10),
                Text(
                  strings.pick('No Matching TODA Members', 'Walang Nahanap na Miyembro'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  strings.pick(
                    'Add members individually or scan a roster sheet under Roster OCR.',
                    'Magdagdag ng miyembro o i-scan ang roster sa Roster OCR.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                CivicPrimaryButton(
                  label: strings.addMemberAction,
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: onAddMember,
                ),
              ],
            ),
          )
        else
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
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
                                m.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Body ${m.bodyNumber.isNotEmpty ? '#${m.bodyNumber}' : '—'}',
                                    style: CivicTheme.monoStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: palette.brandAccent,
                                    ),
                                  ),
                                  if (m.primaryPlateNo.isNotEmpty)
                                    Text(
                                      m.primaryPlateNo,
                                      style: CivicTheme.monoStyle(
                                        fontSize: 11,
                                        color: palette.ink,
                                      ),
                                    ),
                                  if (m.contact.isNotEmpty && m.contact != 'N/A')
                                    Text(
                                      m.contact,
                                      style: CivicTheme.monoStyle(
                                        fontSize: 10.5,
                                        color: palette.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CivicStatusBadge(
                          label: m.isPresident
                              ? 'President'
                              : (m.registeredInApp ? 'App User' : 'Roster Only'),
                          tone: m.isPresident || m.registeredInApp
                              ? CivicStatusTone.active
                              : CivicStatusTone.neutral,
                        ),
                      ],
                    ),
                    if (m.units.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: m.units
                            .map(
                              (u) => CivicStatusBadge(
                                label:
                                    '${u.plateNo.isNotEmpty ? u.plateNo : 'UNIT'} • ${u.status}',
                                tone: u.statusTone,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (m.canRequestRemoval) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            foregroundColor: CivicColors.crimsonAlert,
                            side: BorderSide(
                              color: CivicColors.crimsonAlert.withValues(alpha: 0.45),
                            ),
                          ),
                          onPressed: () => onRequestRemoval(m),
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            size: 16,
                            color: CivicColors.crimsonAlert,
                          ),
                          label: Text(strings.requestRemovalAction),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RemovalsTrackerSection extends StatelessWidget {
  const _RemovalsTrackerSection({
    required this.requests,
    required this.strings,
    required this.palette,
  });

  final List<TodaRemovalRequestRecord> requests;
  final AppStrings strings;
  final CivicPalette palette;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return CivicCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: palette.brandAccent,
            ),
            const SizedBox(height: 10),
            Text(
              strings.pick(
                'No Removal Requests',
                'Walang Kahilingang Pag-alis',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              strings.pick(
                'Open the Members tab and tap Request Removal on any member.',
                'Buksan ang tab na Miyembro at pindutin ang Hilingin ang Pag-alis.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      children: requests
          .map(
            (r) => Padding(
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
                            r.memberName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        CivicStatusBadge(
                          label: r.status,
                          tone: r.statusTone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.reason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.details,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ManilaDateFormatter.formatShortDate(
                        r.createdAt,
                        isFil: strings.isFil,
                      ),
                      style: CivicTheme.monoStyle(
                        fontSize: 10,
                        color: palette.muted,
                      ),
                    ),
                    if (r.adminRemarks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CivicBanner(
                        tone: CivicStatusTone.neutral,
                        title: strings.pick('OVM — LLSA I Remarks', 'Puna ng OVM — LLSA I'),
                        message: r.adminRemarks,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
