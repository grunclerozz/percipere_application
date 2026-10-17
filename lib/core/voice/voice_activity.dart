import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/announcer.dart';
import '../offline_voice/offline_engines.dart';
import '../settings/settings_controller.dart';
import 'voice_controller.dart';
import 'voice_readiness.dart';

/// What voice input is doing now, for the developer overlay and the
/// `[VOICE STATE]` log line.
enum VoiceActivity {
  /// The loading screen is open, or engines are still loading.
  loading,

  /// Waiting for the user (or listening is off): nothing in the way.
  ready,

  /// The app is speaking (a prompt or the document).
  speaking,

  /// A listening session is open.
  listening,

  /// A document is being read into text (OCR).
  processing,
}

/// The current [VoiceActivity]: listening first, then speaking, processing
/// and loading.
final voiceActivityProvider = Provider<VoiceActivity>((ref) {
  final voice = ref.watch(voiceControllerProvider);
  final speech = ref.watch(announcerProvider);
  final busy = ref.watch(voiceReadinessProvider).busy;
  // Rebuilt when an engine finishes loading.
  final engines = ref.watch(_engineChangesProvider);
  if (busy.contains(VoiceBusy.startup)) return VoiceActivity.loading;
  if (voice.listening) return VoiceActivity.listening;
  if (speech.speaking || speech.reading) return VoiceActivity.speaking;
  if (busy.contains(VoiceBusy.processing)) return VoiceActivity.processing;
  if (busy.contains(VoiceBusy.loading) || engines) {
    return VoiceActivity.loading;
  }
  return VoiceActivity.ready;
});

/// Whether an offline engine is loading, refreshed when one finishes.
final _engineChangesProvider = Provider<bool>((ref) {
  final engines = ref.watch(offlineEnginesProvider);
  void changed() => ref.invalidateSelf();
  engines.changes.addListener(changed);
  ref.onDispose(() => engines.changes.removeListener(changed));
  return engines.loading;
});

/// Whether the voice-state overlay is shown: the developer setting, in a
/// developer build only (`PERCIPERE_DEV=true`).
final voiceStateOverlayOnProvider = Provider<bool>(
  (ref) =>
      ref.watch(devBuildProvider) &&
      ref.watch(settingsProvider.select((s) => s.voiceStateOverlay)),
);
