import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../percy/percy_analysis.dart';
import '../tts/language_detector.dart';

/// "Percy analysis" (developer setting, off by default): a panel over the
/// top of every screen showing, for the last sentence said to Percy, what
/// was heard, its language, the predicted intent with its confidence, the
/// top 3 intents and the action taken. For testing and the Intelligent
/// Systems demonstration. Touches pass through it, so gestures and buttons
/// underneath keep working.
class PercyAnalysisPanel extends ConsumerWidget {
  /// Creates the panel.
  const PercyAnalysisPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(percyAnalysisOnProvider)) return const SizedBox.shrink();
    final entries = ref.watch(percyAnalysisProvider);
    final l = AppLocalizations.of(context);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final small = textTheme.bodySmall?.copyWith(color: palette.body);
    final last = entries.isEmpty ? null : entries.first;

    final lines = <String>[
      if (last == null)
        l.percyAnalysisEmpty
      else ...[
        l.percyAnalysisHeard('“${last.heard}”'),
        l.percyAnalysisLanguage(
          _languageName(l, last.language),
          last.language.filipinoHits,
          last.language.englishHits,
        ),
        if (last.intent == null)
          l.percyAnalysisNoIntent
        else
          l.percyAnalysisIntent(last.intent!, _percent(last.confidence)),
        if (last.top.isNotEmpty)
          l.percyAnalysisTop(
            last.top
                .map((s) => '${s.label} ${_percent(s.probability)}')
                .join(' · '),
          ),
        l.percyAnalysisAction(last.action),
      ],
    ];

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Semantics(
              container: true,
              label: '${l.percyAnalysisTitle}. ${lines.join('. ')}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: palette.background.withValues(alpha: 0.94),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: palette.border, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l.percyAnalysisTitle} · '
                          '${l.percyAnalysisCount(entries.length)}',
                          style: textTheme.labelLarge?.copyWith(
                            color: palette.heading,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        for (final line in lines)
                          Text(
                            line,
                            style: small,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
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

  static String _percent(double? p) =>
      p == null ? '—' : '${(p * 100).round()}%';

  static String _languageName(AppLocalizations l, LanguageGuess guess) {
    if (guess.mixed) return l.percyAnalysisLangTaglish;
    return switch (guess.language) {
      DocLanguage.filipino => l.percyAnalysisLangFilipino,
      DocLanguage.english => l.percyAnalysisLangEnglish,
    };
  }
}
