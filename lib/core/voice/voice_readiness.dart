import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/voice_config.dart';
import '../offline_voice/offline_voice_setup.dart';

/// Why the app is too busy for voice input to be judged fairly.
enum VoiceBusy {
  /// The startup loading screen is open: nothing listens or speaks prompts
  /// until it is done.
  startup,

  /// Engines are still loading in the background (after the loading screen
  /// timed out, or after the first model download). Listening works.
  loading,

  /// A document is being read into text (OCR, PDF, DOCX). Listening works.
  processing,
}

/// What is keeping voice input busy now.
@immutable
class VoiceReadiness {
  /// Creates the state.
  const VoiceReadiness({this.busy = const {}, this.busyEndedAt});

  /// The reasons in force.
  final Set<VoiceBusy> busy;

  /// When the last reason ended.
  final DateTime? busyEndedAt;

  /// The loading screen is open: no listening, no prompts.
  bool get starting => busy.contains(VoiceBusy.startup);

  /// Whether failed listening sessions must not count toward giving up:
  /// something is loading or processing, or was until
  /// [VoiceConfig.busyGrace] ago.
  bool lenient(DateTime now) {
    if (busy.isNotEmpty) return true;
    final ended = busyEndedAt;
    return ended != null && now.difference(ended) < VoiceConfig.busyGrace;
  }
}

/// Whether the app starts on the loading screen. Set by `bootstrap()`;
/// false in tests that don't open it.
final startupScreenProvider = Provider<bool>((ref) => false);

/// Tracks [VoiceBusy] reasons; each [begin] needs its own [end].
class VoiceReadinessNotifier extends Notifier<VoiceReadiness> {
  final Map<VoiceBusy, int> _counts = {};

  @override
  VoiceReadiness build() {
    // On first launch the model download screen comes first and works as
    // before; the loading screen begins [VoiceBusy.startup] itself then.
    if (!ref.read(startupScreenProvider) ||
        ref.read(offlineVoiceSetupPendingProvider)) {
      return const VoiceReadiness();
    }
    _counts[VoiceBusy.startup] = 1;
    return const VoiceReadiness(busy: {VoiceBusy.startup});
  }

  /// [reason] starts.
  void begin(VoiceBusy reason) {
    _counts[reason] = (_counts[reason] ?? 0) + 1;
    _publish();
  }

  /// [reason] ends (once per [begin]).
  void end(VoiceBusy reason) {
    final n = _counts[reason] ?? 0;
    if (n <= 0) return;
    if (n == 1) {
      _counts.remove(reason);
    } else {
      _counts[reason] = n - 1;
    }
    _publish(ended: true);
  }

  void _publish({bool ended = false}) {
    final busy = {..._counts.keys};
    if (setEquals(busy, state.busy)) return;
    debugPrint(
      '[VOICE STATE] busy: ${busy.isEmpty ? 'none' : busy.map((b) => b.name).join(', ')}',
    );
    state = VoiceReadiness(
      busy: busy,
      busyEndedAt: ended ? DateTime.now() : state.busyEndedAt,
    );
  }
}

/// What is keeping voice input busy.
final voiceReadinessProvider =
    NotifierProvider<VoiceReadinessNotifier, VoiceReadiness>(
      VoiceReadinessNotifier.new,
    );
