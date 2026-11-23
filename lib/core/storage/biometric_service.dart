import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Platform-safe biometric authentication wrapper (Fingerprint / Face Unlock).
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String localizedReason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
