import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// Reading speed (and pitch) as a multiplier of normal speech (1.0 = normal).
abstract final class ReadingRate {
  /// Slowest.
  static const double min = 0.5;

  /// Fastest.
  static const double max = 2.0;

  /// One "bilisan"/"bagalan" (or "taasan"/"babaan") step.
  static const double step = 0.25;

  /// Clamps and rounds to whole steps (avoids 1.2500000002).
  static double normalize(double rate) =>
      (rate.clamp(min, max) / step).round() * step;

  /// "1.25", "1.5", "1.0" — for "Bilis: 1.25x".
  static String label(double rate) {
    final s = normalize(rate).toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}

/// The user's reading speed; a view of [settingsProvider].
final readingRateProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider.select((s) => s.readingRate)),
);
