import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/application/views/apply_renew_wizard_tab.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/garage/views/garage_dashboard_tab.dart';
import 'package:gtrams_mobile/features/settings/views/settings_hub_tab.dart';
import 'package:gtrams_mobile/features/toda/views/toda_governance_hub_tab.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/features/updates/views/updates_hub_tab.dart';

/// Role-Adaptive Shell (4 tabs for Operator, 5 tabs for TODA President):
/// - Operator: Home | Apply | Updates | Settings
/// - TODA President: Home | TODA | Apply | Updates | Settings
class MobileShellScreen extends ConsumerStatefulWidget {
  const MobileShellScreen({super.key});

  @override
  ConsumerState<MobileShellScreen> createState() => _MobileShellScreenState();
}

class _MobileShellScreenState extends ConsumerState<MobileShellScreen> {
  int _selectedIndex = 0;

  void _selectTab(int nextIndex, {required int updatesTabIndex}) {
    setState(() => _selectedIndex = nextIndex);
    ref
        .read(updatesControllerProvider.notifier)
        .setUpdatesTabActive(nextIndex == updatesTabIndex);
  }

  void _navigateToApplyTab({
    required bool isTodaPresident,
    FranchiseRecord? unit,
    String? actionLabel,
  }) {
    final wizardCtrl = ref.read(franchiseWizardControllerProvider.notifier);
    if (unit != null) {
      if (unit.isRejectedNeedsFix) {
        wizardCtrl.startFixReapply(unit);
      } else {
        wizardCtrl.startRenewal(unit);
      }
    } else {
      wizardCtrl.startNewApplication();
    }
    _selectTab(
      isTodaPresident ? 2 : 1,
      updatesTabIndex: isTodaPresident ? 3 : 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Redirect cleanly to /login whenever Socket.IO `session_revoked` or 401 signs out the user.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated && mounted) {
        context.go('/login');
      }
    });

    final auth = ref.watch(authControllerProvider);
    final updates = ref.watch(updatesControllerProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTodaPresident = user.isTodaPresident;
    final updatesTabIndex = isTodaPresident ? 3 : 2;
    final totalUpdatesBadge = updates.totalBadgeCount;
    final notifUnread = updates.unreadNotificationsCount;

    final tabs = isTodaPresident
        ? [
            (strings.navHome, Icons.home_outlined, Icons.home_rounded, 0),
            (strings.navToda, Icons.groups_outlined, Icons.groups_rounded, 0),
            (
              strings.navApply,
              Icons.add_circle_outline_rounded,
              Icons.add_circle_rounded,
              0,
            ),
            (
              strings.navUpdates,
              Icons.forum_outlined,
              Icons.forum_rounded,
              totalUpdatesBadge,
            ),
            (
              strings.navSettings,
              Icons.settings_outlined,
              Icons.settings_rounded,
              0,
            ),
          ]
        : [
            (strings.navHome, Icons.home_outlined, Icons.home_rounded, 0),
            (
              strings.navApply,
              Icons.add_circle_outline_rounded,
              Icons.add_circle_rounded,
              0,
            ),
            (
              strings.navUpdates,
              Icons.forum_outlined,
              Icons.forum_rounded,
              totalUpdatesBadge,
            ),
            (
              strings.navSettings,
              Icons.settings_outlined,
              Icons.settings_rounded,
              0,
            ),
          ];

    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);

    final homeTab = GarageDashboardTab(
      user: user,
      onNavigateToApply: ({unit, actionLabel}) => _navigateToApplyTab(
        isTodaPresident: isTodaPresident,
        unit: unit,
        actionLabel: actionLabel,
      ),
    );

    final applyTab = ApplyRenewWizardTab(
      onGoToGarage: () => _selectTab(0, updatesTabIndex: updatesTabIndex),
    );

    final updatesTab = UpdatesHubTab(user: user);

    final settingsTab = SettingsHubTab(
      user: user,
      biometricSupported: auth.biometricSupported,
    );

    final pages = isTodaPresident
        ? [
            homeTab,
            TodaGovernanceHubTab(user: user),
            applyTab,
            updatesTab,
            settingsTab,
          ]
        : [
            homeTab,
            applyTab,
            updatesTab,
            settingsTab,
          ];

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/gtrams-logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'G-TRAMS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: palette.brandAccent,
                        ),
                  ),
                  Text(
                    user.roleDisplayTitle.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: CivicTheme.monoStyle(
                      fontSize: 9.5,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('appbar_notifications_button'),
            tooltip: strings.updatesTabNotifications,
            onPressed: () {
              ref
                  .read(updatesControllerProvider.notifier)
                  .setSection(UpdatesSection.notifications);
              _selectTab(updatesTabIndex, updatesTabIndex: updatesTabIndex);
            },
            icon: Badge(
              isLabelVisible: notifUnread > 0,
              backgroundColor: CivicColors.crimsonAlert,
              textColor: CivicColors.purePaper,
              label: Text(
                notifUnread > 99 ? '99+' : '$notifUnread',
                style: CivicTheme.monoStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: CivicColors.purePaper,
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: palette.brandAccent,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Switch Language (EN / FIL)',
            onPressed: () =>
                ref.read(appPreferencesProvider.notifier).toggleLanguage(),
            icon: Text(
              prefs.language == 'fil' ? 'FIL' : 'EN',
              style: CivicTheme.monoStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.brandAccent,
              ),
            ),
          ),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          backgroundColor: palette.surface,
          indicatorColor: palette.brandAccent.withValues(alpha: 0.14),
          elevation: 0,
          onDestinationSelected: (idx) =>
              _selectTab(idx, updatesTabIndex: updatesTabIndex),
          destinations: tabs.map((t) {
            final badgeCount = t.$4;
            Widget buildIcon(IconData iconData, {Color? color}) {
              final icon = Icon(iconData, color: color);
              if (badgeCount <= 0) return icon;
              return Badge(
                backgroundColor: CivicColors.crimsonAlert,
                textColor: CivicColors.purePaper,
                label: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: CivicTheme.monoStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: CivicColors.purePaper,
                  ),
                ),
                child: icon,
              );
            }

            return NavigationDestination(
              icon: buildIcon(t.$2),
              selectedIcon: buildIcon(t.$3, color: palette.brandAccent),
              label: t.$1,
            );
          }).toList(),
        ),
      ),
    );
  }
}
