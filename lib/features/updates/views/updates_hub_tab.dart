import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/features/updates/widgets/announcements_section.dart';
import 'package:gtrams_mobile/features/updates/widgets/live_support_chat_section.dart';
import 'package:gtrams_mobile/features/updates/widgets/notifications_section.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Unified Updates Hub hosting Live Socket.IO Support Chat,
/// Official Gasan LGU Announcements, and the Real-Time Notifications Center.
class UpdatesHubTab extends ConsumerWidget {
  const UpdatesHubTab({
    super.key,
    required this.user,
  });

  final MobileUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updatesControllerProvider);
    final controller = ref.read(updatesControllerProvider.notifier);
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;
    final activeFg = isDark ? CivicColors.obsidianEarth : CivicColors.purePaper;

    final tabs = [
      (
        UpdatesSection.supportChat,
        strings.updatesTabChat,
        state.unreadChatCount,
        Icons.chat_bubble_outline_rounded,
      ),
      (
        UpdatesSection.announcements,
        strings.updatesTabAnnouncements,
        state.unreadAnnouncementsCount,
        Icons.campaign_outlined,
      ),
      (
        UpdatesSection.notifications,
        strings.updatesTabNotifications,
        state.unreadNotificationsCount,
        Icons.notifications_outlined,
      ),
    ];

    return Column(
      children: [
        // Section Selector Pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((item) {
                final isSelected = state.section == item.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: isSelected ? activeBg : palette.surface,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      key: Key('updates_section_${item.$1.name}'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => controller.setSection(item.$1),
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
                            Icon(
                              item.$4,
                              size: 16,
                              color: isSelected ? activeFg : palette.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? activeFg : palette.ink,
                                  ),
                            ),
                            if (item.$3 > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? activeFg.withValues(alpha: 0.2)
                                      : CivicColors.crimsonAlert,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${item.$3}',
                                  style: CivicTheme.monoStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? activeFg
                                        : CivicColors.purePaper,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        if (state.errorMessage != null && !state.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: CivicBanner(
              tone: CivicStatusTone.danger,
              title: strings.pick(
                'Connection Notice',
                'Paalala sa Koneksyon',
              ),
              message: state.errorMessage!,
              action: TextButton.icon(
                onPressed: () => controller.loadAll(isPullToRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(strings.retry),
              ),
            ),
          ),

        // Body
        Expanded(
          child: state.isLoading &&
                  state.supportMessages.isEmpty &&
                  state.notifications.isEmpty &&
                  state.portalAnnouncements.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : switch (state.section) {
                  UpdatesSection.supportChat => LiveSupportChatSection(
                      currentUserId: user.id,
                      state: state,
                      controller: controller,
                      strings: strings,
                    ),
                  UpdatesSection.announcements => AnnouncementsSection(
                      state: state,
                      controller: controller,
                      strings: strings,
                    ),
                  UpdatesSection.notifications => NotificationsSection(
                      state: state,
                      controller: controller,
                      strings: strings,
                    ),
                },
        ),
      ],
    );
  }
}
