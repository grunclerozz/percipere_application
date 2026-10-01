import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../accessibility/announcer.dart';
import '../voice/voice_controller.dart';
import 'speaking_zone.dart';

/// A [SpeakingZone] bound to the [Announcer] and the voice controller.
///
/// - Speaking: the subtitle is the sentence being spoken for this screen.
/// - Listening: "Nakikinig…" (or the words heard so far), waveform moving.
/// - After a command: "Narinig: “…”" appears briefly under the subtitle.
///
/// Before anything is spoken for [screenId] (or while speech belongs to
/// another screen during a transition), it shows [fallback].
class LiveSpeakingZone extends ConsumerWidget {
  /// Creates a live Speaking Zone for [screenId].
  const LiveSpeakingZone({
    super.key,
    required this.screenId,
    required this.fallback,
  });

  /// The screen this zone belongs to.
  final String screenId;

  /// Subtitle shown until speech for this screen starts.
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(announcerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final mine = speech.screenId == screenId && speech.text != null;

    final String subtitle;
    if (voice.listening && !speech.speaking) {
      final partial = voice.partial;
      subtitle = partial == null || partial.isEmpty
          ? AppLocalizations.of(context).listening
          : '“$partial”';
    } else {
      subtitle = mine ? speech.text! : fallback;
    }

    return SpeakingZone(
      subtitle: subtitle,
      active: (mine && speech.speaking) || voice.listening,
      heard: voice.heard,
    );
  }
}
