import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../settings/settings_controller.dart';

/// Haptic cues. Abstract so tests can record them.
abstract interface class Haptics {
  /// Very light tick: finger landed on a gesture surface, focus moved.
  Future<void> tick();

  /// Short pulse: an action was confirmed.
  Future<void> confirm();

  /// Distinct triple buzz: something failed or isn't available.
  Future<void> error();
}

/// [Haptics] on the device vibrator. [enabled] follows the Settings toggle
/// (Phase 6).
class DeviceHaptics implements Haptics {
  /// Creates device haptics.
  DeviceHaptics({this.enabled = true});

  /// Whether haptics are on.
  bool enabled;

  bool? _hasVibrator;

  Future<bool> _canVibrate() async =>
      _hasVibrator ??= await Vibration.hasVibrator().catchError((_) => false);

  @override
  Future<void> tick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  @override
  Future<void> confirm() async {
    if (!enabled) return;
    if (await _canVibrate()) {
      await Vibration.vibrate(duration: 45);
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  @override
  Future<void> error() async {
    if (!enabled) return;
    if (await _canVibrate()) {
      await Vibration.vibrate(pattern: const [0, 70, 90, 70, 90, 70]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }
}

/// App haptics; follows the Settings toggle.
final hapticsProvider = Provider<Haptics>(
  (ref) => DeviceHaptics(
    enabled: ref.watch(settingsProvider.select((s) => s.haptics)),
  ),
);
