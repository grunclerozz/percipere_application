import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../l10n/app_localizations.dart';
import '../startup/startup_tasks.dart';
import '../voice/voice_activity.dart';

/// "Estado ng boses" (developer setting, off by default): a small label at
/// the bottom of every screen with what voice input is doing — loading,
/// ready, speaking, listening or processing — and the last cold start's
/// load time, so voice problems can be seen on the tablet. Touches pass
/// through it.
class VoiceStateOverlay extends ConsumerWidget {
  /// Creates the overlay.
  const VoiceStateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(voiceStateOverlayOnProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final activity = ref.watch(voiceActivityProvider);
    final startup = ref.watch(startupReportProvider);
    final palette = context.palette;
    final name = switch (activity) {
      VoiceActivity.loading => l.voiceStateLoading,
      VoiceActivity.ready => l.voiceStateReady,
      VoiceActivity.speaking => l.voiceStateSpeaking,
      VoiceActivity.listening => l.voiceStateListening,
      VoiceActivity.processing => l.voiceStateProcessing,
    };
    final text = [
      l.voiceStateLabel(name),
      if (startup != null)
        l.voiceStateStartup((startup.inMilliseconds / 1000).toStringAsFixed(1)),
    ].join(' · ');
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
