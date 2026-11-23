import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Real-Time Notifications Center backed by `/api/v1/notifications` and Socket.IO sync events.
class NotificationsSection extends StatelessWidget {
  const NotificationsSection({
    super.key,
    required this.state,
    required this.controller,
    required this.strings,
  });

  final UpdatesState state;
  final UpdatesController controller;
  final AppStrings strings;

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.civic.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ctx.civic.border),
        ),
        title: Text(
          strings.pick('Clear All Notifications?', 'Burahin Lahat ng Notipikasyon?'),
        ),
        content: Text(
          strings.pick(
            'This removes all notifications from your inbox across your devices.',
            'Buburahin nito ang lahat ng notipikasyon sa iyong inbox.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_notifications_button'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 44),
              backgroundColor: CivicColors.crimsonAlert,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final list = state.notifications;

    return RefreshIndicator(
      color: palette.brandAccent,
      onRefresh: () => controller.loadAll(isPullToRefresh: true),
      child: ListView(
        key: const Key('notifications_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                strings.pick(
                  'INBOX (${state.unreadNotificationsCount} UNREAD)',
                  'INBOX (${state.unreadNotificationsCount} HINDI PA NABASA)',
                ),
                style: CivicTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  if (state.unreadNotificationsCount > 0)
                    TextButton(
                      key: const Key('notifications_mark_all_read_button'),
                      onPressed: controller.markAllNotificationsRead,
                      child: Text(strings.markAllRead),
                    ),
                  if (list.isNotEmpty)
                    TextButton(
                      key: const Key('notifications_clear_all_button'),
                      onPressed: () => _confirmClearAll(context),
                      child: Text(
                        strings.clearAll,
                        style: const TextStyle(color: CivicColors.crimsonAlert),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (state.actionError != null) ...[
            CivicBanner(
              tone: CivicStatusTone.danger,
              message: state.actionError!,
            ),
            const SizedBox(height: 10),
          ],

          if (list.isEmpty)
            CivicCard(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 36,
                    color: palette.muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.pick(
                      'All caught up — no notifications yet.',
                      'Wala pang bagong notipikasyon.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            ...list.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationTile(
                  item: item,
                  isFil: strings.isFil,
                  onTap: () {
                    if (!item.isRead) {
                      controller.markNotificationRead(item.id);
                    }
                    if (item.type == 'chat' && item.threadId.isNotEmpty) {
                      controller.setSection(UpdatesSection.supportChat);
                    }
                  },
                  onDelete: () => controller.deleteNotification(item.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isFil,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotificationItem item;
  final bool isFil;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('notification_item_${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isRead
                  ? palette.border
                  : palette.brandAccent.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isRead
                        ? palette.border
                        : palette.brandAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CivicStatusBadge(
                          label: item.categoryLabel,
                          tone: item.tone,
                        ),
                        if (item.relatedPlateNo.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.canvas,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              item.relatedPlateNo.toUpperCase(),
                              style: CivicTheme.monoStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14.5,
                            fontWeight:
                                item.isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.ink.withValues(alpha: 0.84),
                            height: 1.4,
                          ),
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        ManilaDateFormatter.formatTimestamp(
                          item.createdAt,
                          isFil: isFil,
                        ),
                        style: CivicTheme.monoStyle(
                          fontSize: 9.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: Key('delete_notification_${item.id}'),
                tooltip: 'Delete notification',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onDelete,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
