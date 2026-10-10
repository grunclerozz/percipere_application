import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../accessibility/announcer.dart';
import '../accessibility/haptics.dart';
import '../settings/settings_controller.dart';
import 'reading_rate.dart';
import 'speech_language.dart';

/// The speed strip's logic: steps the reading speed (0.25x, 0.5x–2.0x),
/// saves it at once, ticks on every step and speaks the final value once
/// the finger stops ([AppDurations.speedSpeakDelay]), so fast drags never
/// queue speech.
///
/// While a document is read aloud, the Reader sets [reader]: it then
/// speaks the value between sentences and carries on at the new speed.
class SpeedControl {
  /// Creates the control.
  SpeedControl(this._ref);

  final Ref _ref;
  Timer? _settle;

  /// Set by the open Reader: speaks [note] around its own reading (pausing
  /// and resuming at the new speed). Null when no Reader is open.
  Future<void> Function(String note)? reader;

  /// One step faster ([direction] 1) or slower (−1). At the limit it
  /// buzzes and still speaks the value.
  Future<void> step(int direction) async {
    final before = _ref.read(settingsProvider).readingRate;
    final after =
        (await _ref
                .read(settingsProvider.notifier)
                .update(
                  (s) => s.copyWith(
                    readingRate: before + direction * ReadingRate.step,
                  ),
                ))
            .readingRate;
    final haptics = _ref.read(hapticsProvider);
    unawaited(after == before ? haptics.error() : haptics.tick());
    _settle?.cancel();
    _settle = Timer(AppDurations.speedSpeakDelay, () => unawaited(speak()));
  }

  /// The finger left the strip: speak now if a value is waiting.
  void release() {
    final waiting = _settle?.isActive ?? false;
    _settle?.cancel();
    if (waiting) unawaited(speak());
  }

  /// Speaks the current speed ("Bilis 1.5"), at that speed.
  Future<void> speak() async {
    _settle?.cancel();
    final rate = _ref.read(settingsProvider).readingRate;
    final note = _ref
        .read(speechLanguageProvider)
        .strings
        .speedSpoken(ReadingRate.label(rate));
    final reader = this.reader;
    if (reader != null) return reader(note);
    await _ref.read(announcerProvider.notifier).say(note, rate: rate);
  }

  /// Cancels a pending announcement.
  void dispose() => _settle?.cancel();
}

/// The speed strip's controller.
final speedControlProvider = Provider<SpeedControl>((ref) {
  final control = SpeedControl(ref);
  ref.onDispose(control.dispose);
  return control;
});
