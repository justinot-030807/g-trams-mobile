import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/features/toda/view_models/toda_governance_controller.dart';
import 'package:gtrams_mobile/features/toda/widgets/qr_camera_scanner_stub.dart'
    if (dart.library.io) 'package:gtrams_mobile/features/toda/widgets/qr_camera_scanner_io.dart'
    as qr_camera;
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Built-in Operator QR, MTOP#, and Plate# Verifier (`GET /api/v1/auth/verify/:id`).
/// Supports live camera QR scanning on Android (`!kIsWeb`) and instant lookup on Chrome Web & Android.
class QrVerifierSection extends StatefulWidget {
  const QrVerifierSection({
    super.key,
    required this.state,
    required this.controller,
    required this.strings,
  });

  final TodaGovernanceState state;
  final TodaGovernanceController controller;
  final AppStrings strings;

  @override
  State<QrVerifierSection> createState() => _QrVerifierSectionState();
}

class _QrVerifierSectionState extends State<QrVerifierSection> {
  final _inputCtrl = TextEditingController();

  bool get _supportsLiveCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanWithCamera() async {
    final scanned = await qr_camera.openPlatformQrScanner(context);
    if (scanned != null && scanned.trim().isNotEmpty && mounted) {
      _inputCtrl.text = scanned.trim();
      await widget.controller.verifyQrPayload(scanned.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.verifyQrTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                strings.pick(
                  'Scan an operator\'s Digital ID QR code or enter a verify link, MTOP#, or Plate# to check live LGU franchise standing.',
                  'I-scan ang Digital Operator ID QR o ilagay ang verify link, MTOP#, o Plaka upang suriin ang live na status ng prangkisa.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),

              if (_supportsLiveCamera) ...[
                CivicPrimaryButton(
                  key: const Key('qr_open_camera_button'),
                  label: strings.scanQrCameraAction,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: state.isVerifyingQr ? null : _scanWithCamera,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Divider(color: palette.border)),
                    Flexible(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          strings.pick(
                            'OR LOOK UP BY ID / MTOP / PLATE',
                            'O MAGHANAP GAMIT ANG ID / MTOP / PLAKA',
                          ),
                          textAlign: TextAlign.center,
                          style: CivicTheme.monoStyle(
                            fontSize: 9.5,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: palette.border)),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                key: const Key('qr_manual_input_field'),
                controller: _inputCtrl,
                enabled: !state.isVerifyingQr,
                textInputAction: TextInputAction.search,
                onSubmitted: (val) => widget.controller.verifyQrPayload(val),
                decoration: InputDecoration(
                  hintText: strings.pick(
                    'Paste verify URL, MTOP# (2026-0186), or Plate No...',
                    'I-paste ang verify URL, MTOP# (2026-0186), o Plaka...',
                  ),
                  prefixIcon: Icon(Icons.qr_code_2_rounded, color: palette.muted),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('qr_verify_now_button'),
                      onPressed: state.isVerifyingQr
                          ? null
                          : () => widget.controller
                              .verifyQrPayload(_inputCtrl.text),
                      icon: state.isVerifyingQr
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CivicColors.purePaper,
                              ),
                            )
                          : const Icon(Icons.verified_user_outlined, size: 17),
                      label: Text(strings.verifyNowAction),
                    ),
                  ),
                  if (state.verificationResult != null ||
                      state.verificationError != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () {
                        _inputCtrl.clear();
                        widget.controller.clearVerification();
                      },
                      child: Text(strings.pick('Clear', 'Burahin')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        if (state.verificationError != null) ...[
          const SizedBox(height: 14),
          CivicBanner(
            tone: CivicStatusTone.danger,
            title: strings.pick('Verification Failed', 'Hindi Naberipika'),
            message: state.verificationError!,
          ),
        ],

        if (state.verificationResult != null) ...[
          const SizedBox(height: 14),
          _VerificationResultCard(
            result: state.verificationResult!,
            strings: strings,
          ),
        ],
      ],
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  const _VerificationResultCard({
    required this.result,
    required this.strings,
  });

  final OperatorVerificationResult result;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;

    final String verdictTitle;
    if (result.validityStatus == 'VALID' || result.isCurrentlyValid) {
      verdictTitle = strings.pick(
        'VERIFIED — ACTIVE FRANCHISE AUTHORIZED',
        'BERIPIKADO — AKTIBO ANG PRANGKISA',
      );
    } else if (result.validityStatus == 'PENDING') {
      verdictTitle = strings.pick(
        'PENDING APPLICATION IN PROGRESS',
        'MAY NAKABINBING APLIKASYON',
      );
    } else if (result.validityStatus == 'INACTIVE_OWNER') {
      verdictTitle = strings.pick(
        'ACCOUNT DEACTIVATED — NOT AUTHORIZED',
        'NAKA-DEACTIVATE ANG ACCOUNT',
      );
    } else {
      verdictTitle = strings.pick(
        'EXPIRED OR INACTIVE — NOT ROAD-AUTHORIZED',
        'EXPIRED O HINDI AKTIBO ANG PRANGKISA',
      );
    }

    return CivicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CivicBanner(
            tone: result.overallTone,
            icon: result.overallTone == CivicStatusTone.active
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            title: verdictTitle,
            message:
                '${result.todaAssociation} • ${strings.pick('Verified live against G-TRAMS LGU Registry', 'Bineripika nang live sa G-TRAMS LGU Registry')}',
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CivicColors.gasanMaroon,
                child: Text(
                  result.name.isNotEmpty ? result.name[0].toUpperCase() : 'O',
                  style: const TextStyle(
                    color: CivicColors.purePaper,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.todaAssociation}${result.contact.isNotEmpty ? ' • ${result.contact}' : ''}',
                      style: CivicTheme.monoStyle(
                        fontSize: 10.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 12),

          Text(
            strings.pick(
              'REGISTERED UNITS (${result.franchises.length})',
              'MGA REHISTRADONG UNIT (${result.franchises.length})',
            ),
            style: CivicTheme.monoStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 8),

          if (result.franchises.isEmpty)
            Text(
              strings.pick(
                'No active or pending franchise records found under this account.',
                'Walang aktibo o nakabinbing prangkisa sa ilalim ng account na ito.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...result.franchises.map(
              (unit) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.plateNo.isNotEmpty
                                ? unit.plateNo.toUpperCase()
                                : 'PENDING',
                            style: CivicTheme.monoStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        CivicStatusBadge(
                          label: unit.status,
                          tone: unit.tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (unit.mtopNo.isNotEmpty)
                          Text(
                            'MTOP #${unit.mtopNo}',
                            style: CivicTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.brandAccent,
                            ),
                          ),
                        if (unit.make.isNotEmpty)
                          Text(
                            unit.make.toUpperCase(),
                            style: CivicTheme.monoStyle(
                              fontSize: 10.5,
                              color: palette.muted,
                            ),
                          ),
                      ],
                    ),
                    if (unit.expiryDate != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${strings.validUntilLabel}: ${ManilaDateFormatter.formatLongDate(unit.expiryDate, isFil: strings.isFil)}',
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
