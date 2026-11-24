import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/features/settings/widgets/account_recovery_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/change_password_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/document_vault_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/edit_profile_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/helpdesk_tickets_sheet.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/features/wallet/views/digital_wallet_sheet.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Complete Phase 5 Settings Hub:
/// Profile & Photo, Account Recovery (OTP), Change Password (JWT + Socket rotation),
/// Document Vault, Helpdesk Tickets & LGU Hotlines, Display/Accessibility, and Offline Cache.
class SettingsHubTab extends ConsumerWidget {
  const SettingsHubTab({
    super.key,
    required this.user,
    required this.biometricSupported,
  });

  final MobileUser user;
  final bool biometricSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final garage = ref.watch(garageControllerProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;
    final authRepo = ref.read(authRepositoryProvider);
    final commRepo = ref.read(communicationRepositoryProvider);
    final captureService = ref.read(documentCaptureServiceProvider);

    final vaultDocs = extractVaultDocuments(garage.franchises);

    Future<void> openEditProfile() async {
      final updated = await showModalBottomSheet<MobileUser>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => EditProfileSheet(
          user: user,
          captureService: captureService,
          strings: strings,
          onSave: ({
            required name,
            required address,
            required emergencyContact,
            profilePic,
          }) =>
              authRepo.updateProfile(
            name: name,
            address: address,
            emergencyContact: emergencyContact,
            profilePic: profilePic,
          ),
        ),
      );
      if (updated != null && context.mounted) {
        ref.read(authControllerProvider.notifier).updateCachedUser(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.pick(
                'Profile updated successfully.',
                'Matagumpay na na-update ang profile.',
              ),
            ),
          ),
        );
      }
    }

    Future<void> openAccountRecovery() async {
      final updated = await showModalBottomSheet<MobileUser>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => AccountRecoverySheet(
          user: user,
          strings: strings,
          onRequestOtp: authRepo.requestRecoveryOtp,
          onSaveRecovery: ({
            recoveryEmail,
            recoveryPhone,
            clearRecovery = false,
            required currentPassword,
            verificationTarget,
            recoveryOtp,
          }) =>
              authRepo.updateProfile(
            recoveryEmail: recoveryEmail,
            recoveryPhone: recoveryPhone,
            clearRecovery: clearRecovery,
            currentPassword: currentPassword,
            verificationTarget: verificationTarget,
            recoveryOtp: recoveryOtp,
          ),
        ),
      );
      if (updated != null && context.mounted) {
        ref.read(authControllerProvider.notifier).updateCachedUser(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.pick(
                'Account recovery details updated.',
                'Na-update ang iyong account recovery details.',
              ),
            ),
          ),
        );
      }
    }

    Future<void> openChangePassword() async {
      final result = await showModalBottomSheet<ChangePasswordResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => ChangePasswordSheet(
          user: user,
          strings: strings,
          onChangePassword: authRepo.changePassword,
        ),
      );
      if (result != null && context.mounted) {
        if (result.newToken.isNotEmpty) {
          await ref
              .read(updatesControllerProvider.notifier)
              .connectSocket(overrideToken: result.newToken);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    }

    Future<void> openDocumentVault() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DocumentVaultSheet(
          documents: vaultDocs,
          strings: strings,
          onRefresh: () async {
            await ref
                .read(garageControllerProvider.notifier)
                .loadGarage(isPullToRefresh: true);
            return extractVaultDocuments(
              ref.read(garageControllerProvider).franchises,
            );
          },
        ),
      );
    }

    Future<void> openHelpdesk() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => HelpdeskTicketsSheet(
          user: user,
          strings: strings,
          onFetchTickets: commRepo.fetchMyTickets,
          onCreateTicket: commRepo.createTicket,
        ),
      );
    }

    Future<void> clearOfflineCache() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.civic.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: ctx.civic.border),
          ),
          title: Text(strings.clearOfflineCacheTitle),
          content: Text(
            strings.pick(
              'Clears cached offline MTOP wallet snapshots and saved application drafts on this device. Your server records remain safe.',
              'Buburahin nito ang offline MTOP cache at mga saved draft sa device na ito. Ligtas pa rin ang iyong mga rekord sa server.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 44),
                backgroundColor: CivicColors.crimsonAlert,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.pick('Clear Cache', 'Linisin')),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(offlineWalletCacheProvider).clearUser(user.id);
        await ref.read(wizardDraftCacheProvider).clearAllForUser(user.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.pick(
                  'Offline cache and drafts cleared.',
                  'Nalinis na ang offline cache at drafts.',
                ),
              ),
            ),
          );
        }
      }
    }

    return ListView(
      key: const Key('settings_hub_list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 1. Operator Profile Header
        CivicCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: CivicColors.gasanMaroon,
                backgroundImage: user.profilePic.isNotEmpty
                    ? NetworkImage(user.profilePic)
                    : null,
                child: user.profilePic.isEmpty
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'O',
                        style: const TextStyle(
                          color: CivicColors.purePaper,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.contact.isNotEmpty ? user.contact : user.email,
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        CivicStatusBadge(
                          label: user.roleDisplayTitle,
                          tone: CivicStatusTone.active,
                        ),
                        if (user.todaAssociation.isNotEmpty)
                          CivicStatusBadge(
                            label:
                                '${user.todaAssociation}${user.bodyNumber.isNotEmpty ? ' #${user.bodyNumber}' : ''}',
                            tone: CivicStatusTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Prominent Digital Operator ID & Offline Wallet Card (moved here from Dashboard/AppBar)
        Material(
          color: CivicColors.gasanMaroonDeep,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('settings_open_wallet_button'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => showDigitalWalletSheet(
              context,
              user: garage.cachedUser ?? user,
              units: garage.franchises,
              strings: strings,
              lastSyncedAt: garage.lastSyncedAt,
              isOfflineFallback: garage.isOfflineFallback,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 74),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CivicColors.gasanGold.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: CivicColors.gasanGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CivicColors.gasanGold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 24,
                      color: CivicColors.gasanGoldAccessible,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.pick(
                            'Digital Operator ID & Wallet',
                            'Digital Operator ID at Wallet',
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: CivicColors.purePaper,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.pick(
                            'LGU QR ID, MTOP E-Copy & receipts · Offline ready',
                            'LGU QR ID, MTOP E-Copy at resibo · Handa offline',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: CivicColors.gasanGoldAccessible,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: CivicColors.gasanGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: CivicColors.gasanGoldAccessible,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Account & Security
        _SettingsSectionHeader(
          title: strings.pick('Account & Security', 'Account at Seguridad'),
        ),
        const SizedBox(height: 8),
        CivicCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsActionTile(
                tileKey: const Key('settings_edit_profile_tile'),
                icon: Icons.person_outline_rounded,
                title: strings.editProfileTitle,
                subtitle: strings.pick(
                  'Name, address & photo',
                  'Pangalan, tirahan at larawan',
                ),
                onTap: openEditProfile,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: palette.border),
              _SettingsActionTile(
                tileKey: const Key('settings_recovery_tile'),
                icon: Icons.verified_user_outlined,
                title: strings.accountRecoveryTitle,
                subtitle: user.hasAnyRecoveryContact
                    ? strings.pick(
                        'Backup contact configured',
                        'May naka-set na recovery contact',
                      )
                    : strings.pick(
                        'Add backup email or mobile',
                        'Magdagdag ng backup email o mobile',
                      ),
                trailingBadge: user.hasAnyRecoveryContact
                    ? const CivicStatusBadge(
                        label: 'SET',
                        tone: CivicStatusTone.active,
                      )
                    : const CivicStatusBadge(
                        label: 'UNSET',
                        tone: CivicStatusTone.inProgress,
                      ),
                onTap: openAccountRecovery,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: palette.border),
              _SettingsActionTile(
                tileKey: const Key('settings_change_password_tile'),
                icon: Icons.lock_outline_rounded,
                title: strings.changePasswordTitle,
                subtitle: strings.pick(
                  'Update password & sign out other devices',
                  'Palitan ang password at i-sign out ang ibang device',
                ),
                onTap: openChangePassword,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Records & Helpdesk
        _SettingsSectionHeader(
          title: strings.pick('Records & Support', 'Rekord at Tulong'),
        ),
        const SizedBox(height: 8),
        CivicCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsActionTile(
                tileKey: const Key('settings_document_vault_tile'),
                icon: Icons.folder_copy_outlined,
                title: strings.documentVaultTitle,
                subtitle: strings.pick(
                  'OR/CR, License, Clearance & Cedula',
                  'OR/CR, Lisensya, Clearance at Cedula',
                ),
                trailingBadge: CivicStatusBadge(
                  label: '${vaultDocs.length}',
                  tone: vaultDocs.isNotEmpty
                      ? CivicStatusTone.active
                      : CivicStatusTone.neutral,
                ),
                onTap: openDocumentVault,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: palette.border),
              _SettingsActionTile(
                tileKey: const Key('settings_helpdesk_tile'),
                icon: Icons.support_agent_outlined,
                title: strings.helpdeskTitle,
                subtitle: strings.pick(
                  'Support tickets & OVM — LLSA I offices',
                  'Support ticket at tanggapan ng OVM',
                ),
                onTap: openHelpdesk,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. Display, Language & Accessibility
        _SettingsSectionHeader(
          title: strings.pick(
            'Display & Accessibility',
            'Display at Accessibility',
          ),
        ),
        const SizedBox(height: 8),
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Theme', 'Tema'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                  ],
                  selected: {prefs.themeMode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setThemeMode(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.pick('Language / Wika', 'Wika / Language'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'fil', label: Text('Filipino')),
                  ],
                  selected: {prefs.language},
                  onSelectionChanged: (selection) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setLanguage(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.pick('Outdoor Text Size', 'Laki ng Teksto'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppTextScaleOption>(
                  segments: AppTextScaleOption.values
                      .map(
                        (o) => ButtonSegment(value: o, label: Text(o.label)),
                      )
                      .toList(),
                  selected: {prefs.textScale},
                  onSelectionChanged: (selection) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setTextScale(selection.first);
                  },
                ),
              ),
              if (biometricSupported) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    strings.pick(
                      'Biometric Quick-Unlock',
                      'Biometric Quick-Unlock',
                    ),
                  ),
                  subtitle: Text(
                    strings.pick(
                      'Use Fingerprint or Face ID when opening app',
                      'Gamitin ang Fingerprint o Face ID sa pagbukas',
                    ),
                  ),
                  value: prefs.biometricEnabled,
                  onChanged: (val) => ref
                      .read(appPreferencesProvider.notifier)
                      .setBiometricEnabled(val),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 6. Offline Storage & Cache
        _SettingsSectionHeader(
          title: strings.pick('Offline Storage', 'Offline Storage'),
        ),
        const SizedBox(height: 8),
        CivicCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _SettingsActionTile(
            tileKey: const Key('settings_clear_cache_tile'),
            icon: Icons.cleaning_services_outlined,
            title: strings.clearOfflineCacheTitle,
            subtitle: garage.lastSyncedAt != null
                ? '${strings.lastSynced}: ${ManilaDateFormatter.formatTimestamp(garage.lastSyncedAt, isFil: strings.isFil)}'
                : strings.pick(
                    'Clear cached wallet & saved drafts',
                    'Burahin ang offline cache at mga draft',
                  ),
            onTap: clearOfflineCache,
          ),
        ),
        const SizedBox(height: 18),

        // 7. Sign Out
        OutlinedButton.icon(
          key: const Key('settings_sign_out_button'),
          icon: const Icon(Icons.logout_rounded, color: CivicColors.crimsonAlert),
          label: Text(
            strings.pick('Sign Out', 'Mag-Sign Out'),
            style: const TextStyle(color: CivicColors.crimsonAlert),
          ),
          onPressed: () async {
            ref.read(updatesControllerProvider.notifier).disconnectSocket();
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.civic.ink,
            ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingBadge,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return InkWell(
      key: tileKey,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Icon(icon, size: 19, color: palette.brandAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              trailingBadge!,
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
