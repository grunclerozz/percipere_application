import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../l10n/app_localizations.dart';
import '../startup/startup_tasks.dart';
import '../voice/noise_monitor.dart';
import '../voice/voice_activity.dart';

/// "Estado ng boses" (developer setting, off by default; debug builds and
/// developer builds only): a small label at the bottom of every screen with
/// what voice input is doing — loading, ready, speaking, listening or
/// processing — the microphone's turn state, the last cold start's load
/// time, which recognizer and audio source the last session used, the
/// microphone level, the room's measured noise and the speech threshold,
/// the last transcript with its confidence and what it matched, and the
/// app's output voice, so voice problems can be seen on the tablet. Touches
/// pass through it.
class VoiceStateOverlay extends ConsumerWidget {
  /// Creates the overlay.
  const VoiceStateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(voiceStateOverlayOnProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final activity = ref.watch(voiceActivityProvider);
    final startup = ref.watch(startupReportProvider);
    final name = switch (activity) {
      VoiceActivity.loading => l.voiceStateLoading,
      VoiceActivity.ready => l.voiceStateReady,
      VoiceActivity.speaking => l.voiceStateSpeaking,
      VoiceActivity.listening => l.voiceStateListening,
      VoiceActivity.processing => l.voiceStateProcessing,
    };
    final capture = ref.watch(voiceCaptureProvider);
    return ListenableBuilder(
      listenable: capture,
      builder: (context, _) {
        String shown(double? v) => v == null ? '–' : v.toStringAsFixed(0);
        final confidence = capture.confidence < 0
            ? '–'
            : capture.confidence.toStringAsFixed(2);
        final text = [
          [
            l.voiceStateLabel(name),
            l.voiceStateMic(capture.mic),
            if (startup != null)
              l.voiceStateStartup(
                (startup.inMilliseconds / 1000).toStringAsFixed(1),
              ),
          ].join(' · '),
          l.voiceStateSource(capture.source),
          [
            l.voiceStateNoise(shown(capture.level), shown(capture.floor)),
            l.voiceStateThreshold(shown(capture.threshold)),
            if (capture.noisy) l.voiceStateNoisy,
          ].join(' · '),
          l.voiceStateHeard(capture.heard, confidence),
          l.voiceStateMatch(capture.match),
          l.voiceStateOutput(capture.output),
        ].join('\n');
        return _label(context, text);
      },
    );
  }

  Widget _label(BuildContext context, String text) {
    final palette = context.palette;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: IgnorePointer(
          child: Semantics(
            label: text,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: palette.background.withValues(alpha: 0.94),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: palette.border, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.heading,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
