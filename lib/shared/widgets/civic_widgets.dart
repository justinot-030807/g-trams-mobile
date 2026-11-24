import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Crisp 1px-bordered Civic Ledger surface card (zero heavy drop-shadow haze).
class CivicCard extends StatelessWidget {
  const CivicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? palette.border, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Primary Heritage Maroon button with built-in loading state and 50dp touch height.
class CivicPrimaryButton extends StatelessWidget {
  const CivicPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: CivicColors.purePaper,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// WCAG AA semantic banner for inline errors, advisories, and confirmations.
class CivicBanner extends StatelessWidget {
  const CivicBanner({
    super.key,
    required this.message,
    this.tone = CivicStatusTone.danger,
    this.title,
    this.icon,
    this.action,
  });

  final String message;
  final CivicStatusTone tone;
  final String? title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color fg, Color bg, Color border, IconData defaultIcon) = switch (tone) {
      CivicStatusTone.active => (
          isDark ? const Color(0xFF86EFAC) : CivicColors.civicGreen,
          isDark ? CivicColors.civicGreenDarkBg : CivicColors.civicGreenLightBg,
          CivicColors.civicGreen.withValues(alpha: 0.35),
          Icons.verified_outlined,
        ),
      CivicStatusTone.inProgress => (
          isDark ? const Color(0xFFFCD34D) : CivicColors.amberOchre,
          isDark ? CivicColors.amberOchreDarkBg : CivicColors.amberOchreLightBg,
          CivicColors.amberOchre.withValues(alpha: 0.35),
          Icons.info_outline_rounded,
        ),
      CivicStatusTone.danger => (
          isDark ? const Color(0xFFFCA5A5) : CivicColors.crimsonAlert,
          isDark
              ? CivicColors.crimsonAlertDarkBg
              : CivicColors.crimsonAlertLightBg,
          CivicColors.crimsonAlert.withValues(alpha: 0.35),
          Icons.error_outline_rounded,
        ),
      CivicStatusTone.neutral => (
          context.civic.ink,
          context.civic.canvas,
          context.civic.border,
          Icons.article_outlined,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 19, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill status badge paired with tabular uppercase styling.
class CivicStatusBadge extends StatelessWidget {
  const CivicStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final CivicStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color fg, Color bg) = switch (tone) {
      CivicStatusTone.active => (
          isDark ? const Color(0xFF86EFAC) : CivicColors.civicGreen,
          isDark ? CivicColors.civicGreenDarkBg : CivicColors.civicGreenLightBg,
        ),
      CivicStatusTone.inProgress => (
          isDark ? const Color(0xFFFCD34D) : CivicColors.amberOchre,
          isDark ? CivicColors.amberOchreDarkBg : CivicColors.amberOchreLightBg,
        ),
      CivicStatusTone.danger => (
          isDark ? const Color(0xFFFCA5A5) : CivicColors.crimsonAlert,
          isDark
              ? CivicColors.crimsonAlertDarkBg
              : CivicColors.crimsonAlertLightBg,
        ),
      CivicStatusTone.neutral => (
          context.civic.muted,
          isDark ? CivicColors.neutralZincDarkBg : CivicColors.neutralZincLightBg,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CivicTheme.monoStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean field label with optional required indicator.
class CivicFieldLabel extends StatelessWidget {
  const CivicFieldLabel({
    super.key,
    required this.text,
    this.isRequired = false,
  });

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                color: CivicColors.gasanMaroon,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Official Civic notice blocking non-operator/TODA staff roles from the mobile APK.
Future<void> showStaffRoleGuardDialog(
  BuildContext context, {
  required String displayRole,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final palette = ctx.civic;
      return AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CivicColors.gasanMaroon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: CivicColors.gasanMaroon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Web Portal Required',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account is registered as $displayRole.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'G-TRAMS Mobile is only for Tricycle Operators and TODA Presidents. Sign in on the G-TRAMS Web Portal for municipal staff operations.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                AppConfig.webPortalUrl,
                style: CivicTheme.monoStyle(
                  fontSize: 11.5,
                  color: palette.brandAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 48),
            ),
            onPressed: () async {
              final uri = Uri.parse(AppConfig.webPortalUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Open Web Portal'),
          ),
        ],
      );
    },
  );
}
