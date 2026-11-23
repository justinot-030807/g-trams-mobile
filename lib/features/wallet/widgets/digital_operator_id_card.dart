import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Interactive 3D-Flip Digital Operator ID Card cached offline via Hive.
///
/// Front: Municipal seal, operator photo (offline-safe fallback), legal name,
/// role badge, TODA, Body#, contact.
/// Back: Scannable `https://g-trams-official.vercel.app/verify/:id` QR code,
/// emergency contact, and last-synced timestamp.
class DigitalOperatorIdCard extends StatefulWidget {
  const DigitalOperatorIdCard({
    super.key,
    required this.user,
    required this.strings,
    this.lastSyncedAt,
  });

  final MobileUser user;
  final AppStrings strings;
  final DateTime? lastSyncedAt;

  /// Canonical public verification URL embedded inside the QR code.
  static String verificationUrlFor(String userId) {
    final safeId = userId.trim().isEmpty ? 'unknown' : userId.trim();
    return '${AppConfig.webPortalUrl}/verify/$safeId';
  }

  @override
  State<DigitalOperatorIdCard> createState() => _DigitalOperatorIdCardState();
}

class _DigitalOperatorIdCardState extends State<DigitalOperatorIdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flipAnim;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flipAnim = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final qrUrl = DigitalOperatorIdCard.verificationUrlFor(widget.user.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('digital_id_flip_area'),
          onTap: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipAnim,
            builder: (context, _) {
              final angle = _flipAnim.value;
              final showBack = angle > (math.pi / 2);

              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle);

              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _IdCardBack(
                          qrUrl: qrUrl,
                          user: widget.user,
                          strings: widget.strings,
                          lastSyncedAt: widget.lastSyncedAt,
                        ),
                      )
                    : _IdCardFront(
                        user: widget.user,
                        strings: widget.strings,
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('digital_id_flip_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: palette.ink,
              side: BorderSide(color: palette.border),
            ),
            onPressed: _toggleFlip,
            icon: Icon(
              Icons.flip_rounded,
              size: 18,
              color: palette.brandAccent,
            ),
            label: Text(
              _isFront
                  ? '${widget.strings.flipCard} (${widget.strings.pick('Show QR', 'Ipakita ang QR')})'
                  : '${widget.strings.flipCard} (${widget.strings.pick('Show Front', 'Ipakita ang Harap')})',
            ),
          ),
        ),
      ],
    );
  }
}

class _IdCardFront extends StatelessWidget {
  const _IdCardFront({
    required this.user,
    required this.strings,
  });

  final MobileUser user;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final initials =
        user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : 'O';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 372),
      decoration: BoxDecoration(
        color: CivicColors.darkStone,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CivicColors.gasanGold, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heritage Maroon Civic Header Crest
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: CivicColors.gasanMaroon,
              border: Border(
                bottom: BorderSide(color: CivicColors.gasanGold, width: 2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: CivicColors.gasanGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LGU GASAN • MARINDUQUE',
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.purePaper,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'DIGITAL OPERATOR ID',
                        style: CivicTheme.monoStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: CivicColors.gasanGoldAccessible,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CivicColors.purePaper.withValues(alpha: 0.12),
                    border: Border.all(
                      color: CivicColors.gasanGold.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/gasan-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // Center Portrait, Full Legal Name & Role Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CivicColors.obsidianEarth,
                    border: Border.all(color: CivicColors.gasanGold, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user.profilePic.trim().isNotEmpty
                      ? Image.network(
                          user.profilePic.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: CivicColors.gasanGold,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: CivicColors.gasanGold,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.name.isNotEmpty ? user.name : 'Registered Operator',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CivicColors.darkParchment,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: CivicColors.gasanGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: CivicColors.gasanGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 14,
                        color: CivicColors.gasanGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.roleDisplayTitle.toUpperCase(),
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: CivicColors.gasanGold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Obsidian Metadata Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: CivicColors.obsidianEarth,
              border: Border(
                top: BorderSide(color: CivicColors.darkUmber, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardMetaRow(
                        icon: Icons.groups_outlined,
                        text: user.todaAssociation.isNotEmpty
                            ? user.todaAssociation
                            : 'NON-TODA',
                        isBold: true,
                      ),
                      if (user.bodyNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _CardMetaRow(
                          icon: Icons.tag_rounded,
                          text: 'BODY #${user.bodyNumber}',
                        ),
                      ],
                      const SizedBox(height: 4),
                      _CardMetaRow(
                        icon: Icons.phone_android_outlined,
                        text: user.contact.isNotEmpty
                            ? user.contact
                            : (user.email.isNotEmpty ? user.email : '—'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      strings.tapCardToFlip.toUpperCase(),
                      style: CivicTheme.monoStyle(
                        fontSize: 9,
                        color: CivicColors.darkAsh,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: CivicColors.gasanGold,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdCardBack extends StatelessWidget {
  const _IdCardBack({
    required this.qrUrl,
    required this.user,
    required this.strings,
    this.lastSyncedAt,
  });

  final String qrUrl;
  final MobileUser user;
  final AppStrings strings;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 372),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CivicColors.gasanGold, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.officialQrTitle,
            textAlign: TextAlign.center,
            style: CivicTheme.monoStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.ink,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.officialQrSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // High-contrast Pure White QR backing for reliable roadside scanning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CivicColors.purePaper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border, width: 1),
            ),
            child: QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 156,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              backgroundColor: CivicColors.purePaper,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: CivicColors.inkCharcoal,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: CivicColors.inkCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            qrUrl,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CivicTheme.monoStyle(
              fontSize: 9.5,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 14),

          // Emergency Contact Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Text(
                  strings.emergencyContactLabel,
                  style: CivicTheme.monoStyle(
                    fontSize: 9.5,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_in_talk_outlined,
                      size: 14,
                      color: CivicColors.crimsonAlert,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        user.emergencyContact.isNotEmpty
                            ? user.emergencyContact
                            : strings.notProvided,
                        overflow: TextOverflow.ellipsis,
                        style: CivicTheme.monoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (lastSyncedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              '${strings.lastSyncedLabel}: ${ManilaDateFormatter.formatSyncTimestamp(lastSyncedAt, isFil: strings.isFil)}',
              textAlign: TextAlign.center,
              style: CivicTheme.monoStyle(
                fontSize: 9.5,
                color: palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardMetaRow extends StatelessWidget {
  const _CardMetaRow({
    required this.icon,
    required this.text,
    this.isBold = false,
  });

  final IconData icon;
  final String text;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: CivicColors.gasanGold),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CivicTheme.monoStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? CivicColors.darkParchment : CivicColors.darkAsh,
            ),
          ),
        ),
      ],
    );
  }
}
