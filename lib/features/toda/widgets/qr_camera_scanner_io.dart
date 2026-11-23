import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Launches the native Android/iOS live QR camera scanner sheet (`mobile_scanner`).
Future<String?> openPlatformQrScanner(BuildContext context) async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return null;
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CivicColors.obsidianEarth,
    builder: (_) => const _LiveQrCameraScannerSheet(),
  );
}

class _LiveQrCameraScannerSheet extends StatefulWidget {
  const _LiveQrCameraScannerSheet();

  @override
  State<_LiveQrCameraScannerSheet> createState() =>
      _LiveQrCameraScannerSheetState();
}

class _LiveQrCameraScannerSheetState extends State<_LiveQrCameraScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isNotEmpty) {
        _hasScanned = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: CivicColors.gasanGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SCAN DIGITAL OPERATOR ID QR',
                    style: CivicTheme.monoStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.purePaper,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Toggle Flash',
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(
                    Icons.flashlight_on_outlined,
                    color: CivicColors.gasanGold,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: CivicColors.purePaper,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleCapture,
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CivicColors.gasanGold,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Point the camera at the QR code on the back of the G-TRAMS Digital Operator ID or MTOP E-Copy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CivicColors.darkAsh,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
