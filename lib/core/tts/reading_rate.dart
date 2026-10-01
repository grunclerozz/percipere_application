import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// Reading speed as a multiplier of normal speech (1.0 = normal).
abstract final class ReadingRate {
  /// Slowest.
  static const double min = 0.5;

  /// Fastest.
  static const double max = 2.0;

  /// One "bilisan"/"bagalan" step.
  static const double step = 0.1;

  /// Clamps and rounds to one decimal (avoids 1.2000000002).
  static double normalize(double rate) =>
      (rate.clamp(min, max) * 10).round() / 10;

  /// "1.2" — for "Bilis: 1.2x".
  static String label(double rate) => normalize(rate).toStringAsFixed(1);
}

/// The user's reading speed; a view of [settingsProvider].
final readingRateProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider.select((s) => s.readingRate)),
);
