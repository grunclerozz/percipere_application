// The "Percy analysis" developer panel (revisions 2026-10-13, item 7).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/core/percy/intent_classifier.dart';
import 'package:percipere_app/core/percy/percy_analysis.dart';
import 'package:percipere_app/core/tts/language_detector.dart';
import 'package:percipere_app/core/widgets/percy_analysis_panel.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool on,
  }) async {
    final container = ProviderContainer(
      overrides: [percyAnalysisOnProvider.overrideWithValue(on)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: AppLocales.filipino,
          supportedLocales: AppLocales.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: PercyAnalysisPanel()),
        ),
      ),
    );
    return container;
  }

  testWidgets('hidden while the developer setting is off', (tester) async {
    await pump(tester, on: false);
    expect(find.textContaining('Percy analysis'), findsNothing);
  });

  testWidgets('shows the last utterance: heard, language, intent, '
      'confidence, top 3 and action', (tester) async {
    final container = await pump(tester, on: true);
    expect(find.textContaining('Wala pang sinabi kay Percy'), findsOneWidget);

    container
        .read(percyAnalysisProvider.notifier)
        .add(
          PercyAnalysisEntry(
            heard: 'buksan ang aklatan',
            language: detectLanguage('buksan ang aklatan'),
            intent: 'open_library',
            confidence: 0.87,
            top: const [
              IntentScore('open_library', 0.87),
              IntentScore('open_home', 0.05),
              IntentScore('back', 0.02),
            ],
            action: 'run:library',
            at: DateTime(2026, 10, 13),
          ),
        );
    await tester.pump();

    expect(find.textContaining('“buksan ang aklatan”'), findsOneWidget);
    expect(find.textContaining('Wika: Filipino'), findsOneWidget);
    expect(
      find.textContaining('open_library · kumpiyansa 87%'),
      findsOneWidget,
    );
    expect(
      find.textContaining('open_library 87% · open_home 5% · back 2%'),
      findsOneWidget,
    );
    expect(find.text('Ginawa: run:library'), findsOneWidget);
    // Touches go through to the screen underneath.
    expect(
      find.ancestor(
        of: find.textContaining('Ginawa'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });
}
