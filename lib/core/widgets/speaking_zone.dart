import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import 'fit_text.dart';
import 'waveform.dart';

/// The Speaking Zone: waveform plus a live subtitle of what TTS is saying.
///
/// Used on every screen without a loaded document. (The requirements also call
/// this the "InteractionPanel".) The subtitle is a live region, so TalkBack
/// users hear updates too. In voice mode, [heard] shows the recognized speech
/// briefly in a lighter, italic style.
class SpeakingZone extends StatelessWidget {
  /// Creates a Speaking Zone.
  const SpeakingZone({
    super.key,
    required this.subtitle,
    this.active = false,
    this.heard,
    this.subtitleLines = 3,
  });

  /// Exactly what TTS is currently saying (or last said).
  final String subtitle;

  /// Animate the waveform (TTS speaking or STT listening).
  final bool active;

  /// Recognized speech to echo, or null to hide the line.
  final String? heard;

  /// Lines the subtitle box holds before its text is shrunk to fit (forms
  /// use 2, as in their mockups).
  final int subtitleLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final heard = this.heard;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Waveform(active: active),
        const SizedBox(height: 14),
        // Fixed boxes: a long sentence shrinks to fit instead of pushing
        // the buttons down; the "Narinig" line has its slot reserved.
        Semantics(
          liveRegion: true,
          child: FitText(
            subtitle,
            lines: subtitleLines,
            style: textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: AppDurations.fade,
          child: FitText(
            heard == null ? '' : AppLocalizations.of(context).heardLabel(heard),
            key: ValueKey(heard),
            style: textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
