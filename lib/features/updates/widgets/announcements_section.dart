import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Displays Official LGU Broadcast Advisories (targeted by TODA / Status)
/// plus Gasan Municipal Portal Announcements from `GET /api/v1/settings`.
class AnnouncementsSection extends StatelessWidget {
  const AnnouncementsSection({
    super.key,
    required this.state,
    required this.controller,
    required this.strings,
  });

  final UpdatesState state;
  final UpdatesController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final broadcasts = state.announcementMessages.reversed.toList();
    final advisories = state.portalAnnouncements;

    return RefreshIndicator(
      color: palette.brandAccent,
      onRefresh: () => controller.loadAll(isPullToRefresh: true),
      child: ListView(
        key: const Key('announcements_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          // 1. Live Broadcasts Header
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.pick(
                    'OFFICIAL OVM BROADCASTS (${broadcasts.length})',
                    'OPISYAL NA ANUNSYO NG OVM (${broadcasts.length})',
                  ),
                  style: CivicTheme.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ),
              if (state.unreadAnnouncementsCount > 0)
                TextButton(
                  key: const Key('announcements_mark_read_button'),
                  onPressed: controller.markAnnouncementsRead,
                  child: Text(strings.markAllRead),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (broadcasts.isEmpty)
            CivicCard(
              child: Text(
                strings.pick(
                  'No live OVM broadcast bulletins for your TODA or franchise status yet.',
                  'Wala pang bagong broadcast bulletin mula sa OVM — LLSA I para sa iyong TODA.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...broadcasts.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BroadcastCard(item: item, isFil: strings.isFil),
              ),
            ),

          const SizedBox(height: 16),

          // 2. Municipal Portal Advisories (`SystemSettings.announcements`)
          Text(
            strings.pick(
              'GASAN MUNICIPAL PORTAL ADVISORIES (${advisories.length})',
              'MGA PAALALA NG MUNISIPYO NG GASAN (${advisories.length})',
            ),
            style: CivicTheme.monoStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 8),

          if (advisories.isEmpty)
            CivicCard(
              child: Text(
                strings.pick(
                  'No active municipal portal advisories at the moment.',
                  'Walang aktibong paalala sa portal sa ngayon.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...advisories.map(
              (adv) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PortalAdvisoryCard(advisory: adv),
              ),
            ),
        ],
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.item, required this.isFil});

  final ChatMessageItem item;
  final bool isFil;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final hasTargetToda =
        item.targetToda.isNotEmpty && item.targetToda.toUpperCase() != 'ALL';
    final hasTargetStatus = item.targetStatus.isNotEmpty &&
        item.targetStatus.toUpperCase() != 'ALL';

    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CivicStatusBadge(
                label: item.isRead ? 'OFFICIAL BULLETIN' : 'NEW BULLETIN',
                tone: item.isRead
                    ? CivicStatusTone.neutral
                    : CivicStatusTone.inProgress,
              ),
              if (hasTargetToda)
                CivicStatusBadge(
                  label: item.targetToda,
                  tone: CivicStatusTone.active,
                ),
              if (hasTargetStatus)
                CivicStatusBadge(
                  label: item.targetStatus,
                  tone: CivicStatusTone.inProgress,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.cleanBroadcastBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 14,
                color: palette.brandAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OVM — LLSA I • ${ManilaDateFormatter.formatTimestamp(item.createdAt, isFil: isFil)}',
                  style: CivicTheme.monoStyle(
                    fontSize: 10,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortalAdvisoryCard extends StatelessWidget {
  const _PortalAdvisoryCard({required this.advisory});

  final PortalAnnouncement advisory;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final tone = switch (advisory.type) {
      'alert' => CivicStatusTone.danger,
      'event' => CivicStatusTone.inProgress,
      _ => CivicStatusTone.active,
    };
    final badgeLabel = switch (advisory.type) {
      'alert' => 'URGENT',
      'event' => 'SCHEDULE',
      _ => 'ADVISORY',
    };

    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CivicStatusBadge(label: badgeLabel, tone: tone),
              Text(
                advisory.date.toUpperCase(),
                style: CivicTheme.monoStyle(
                  fontSize: 10,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sanitizeCivicCopy(advisory.title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (advisory.desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sanitizeCivicCopy(advisory.desc),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.ink.withValues(alpha: 0.85),
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
