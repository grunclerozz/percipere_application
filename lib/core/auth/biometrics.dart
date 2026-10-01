import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a fingerprint check.
enum BiometricResult {
  /// The finger matched.
  success,

  /// Not recognized, or the user cancelled.
  failed,

  /// No sensor, nothing enrolled, or locked out by Android.
  unavailable,
}

/// Fingerprint login. Abstract so tests can script it.
abstract interface class Biometrics {
  /// Whether this phone has a fingerprint (or other biometric) enrolled.
  Future<bool> available();

  /// Shows Android's fingerprint prompt with [reason].
  Future<BiometricResult> authenticate(String reason);
}

/// [Biometrics] on `local_auth` (biometrics only — no device PIN fallback,
/// since our own password is the fallback).
class DeviceBiometrics implements Biometrics {
  /// Creates the service.
  DeviceBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object catch (e) {
      debugPrint('Biometrics check failed: $e');
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      debugPrint('Biometric auth: ${e.code.name}');
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.systemCanceled => BiometricResult.failed,
        _ => BiometricResult.unavailable,
      };
    } on Object catch (e) {
      debugPrint('Biometric auth failed: $e');
      return BiometricResult.unavailable;
    }
  }
}

/// Fingerprint service.
final biometricsProvider = Provider<Biometrics>((ref) => DeviceBiometrics());
