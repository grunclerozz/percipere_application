// The startup loading screen (2026-10-17, fix/voice-startup-ptt).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/config/startup_config.dart';
import 'package:percipere_app/core/startup/startup_tasks.dart';
import 'package:percipere_app/core/voice/voice_readiness.dart';
import 'package:percipere_app/features/offline_voice/offline_voice_setup_screen.dart';
import 'package:percipere_app/features/startup/startup_screen.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  late Map<StartupStep, Completer<void>> gates;
  late ProviderContainer container;

  Future<TestEnv> pumpStartup(WidgetTester tester) async {
    final env = await createEnv(tester);
    gates = {for (final s in StartupStep.values) s: Completer<void>()};
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, _) =>
              const StartupScreen(next: OfflineVoiceNext('/first')),
        ),
        GoRoute(
          path: '/first',
          builder: (_, _) => const Scaffold(body: Text('first screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          startupScreenProvider.overrideWithValue(true),
          startupTasksProvider.overrideWithValue({
            for (final s in StartupStep.values) s: () => gates[s]!.future,
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              routerConfig: router,
              locale: AppLocales.filipino,
              supportedLocales: AppLocales.supported,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            );
          },
        ),
      ),
    );
    await tester.pump();
    return env;
  }

  testWidgets('speaks the wait message, shows progress, and opens the first '
      'screen with "Handa na po" and a tone once everything is ready', (
    tester,
  ) async {
    final env = await pumpStartup(tester);
    await tester.pump();
    expect(
      env.tts.transcript,
      contains(
        'Pakihintay po, inihahanda ang '
        'Percipere.',
      ),
    );
    expect(find.text('0 sa 5 ang handa na'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Inihahanda ang Percipere: 0 sa 5')),
      findsOneWidget,
    );
    expect(container.read(voiceReadinessProvider).starting, isTrue);

    gates[StartupStep.settings]!.complete();
    gates[StartupStep.voice]!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('2 sa 5 ang handa na'), findsOneWidget);
    expect(find.text('Boses ng app: handa na'), findsOneWidget);
    expect(find.text('Si Percy: naglo-load'), findsOneWidget);
    expect(find.text('first screen'), findsNothing);

    gates[StartupStep.recognizer]!.complete();
    gates[StartupStep.percy]!.completeError(StateError('no model'));
    gates[StartupStep.mlkit]!.complete();
    await tester.pump();
    await tester.pump(StartupConfig.afterReady);
    await tester.pumpAndSettle();
    expect(env.tts.transcript, contains('Handa na po.'));
    expect(env.tts.transcript, isNot(contains('naglo-load, pero')));
    expect(env.earcon.played, 1, reason: 'the ready tone');
    expect(find.text('first screen'), findsOneWidget);
    expect(container.read(voiceReadinessProvider).busy, isEmpty);
    expect(container.read(startupReportProvider), isNotNull);
  });

  testWidgets('after the time limit it goes on, says once that some parts '
      'are still loading, and the rest finishes in the background', (
    tester,
  ) async {
    final env = await pumpStartup(tester);
    for (final s in StartupStep.values) {
      if (s != StartupStep.recognizer) gates[s]!.complete();
    }
    await tester.pump();
    await tester.pump(StartupConfig.timeout);
    await tester.pump(StartupConfig.afterReady);
    await tester.pumpAndSettle();
    expect(find.text('first screen'), findsOneWidget);
    expect(
      'May ilang bahagi pa pong naglo-load'.allMatches(env.tts.transcript),
      hasLength(1),
    );
    expect(env.tts.transcript, isNot(contains('Handa na po.')));
    final busy = container.read(voiceReadinessProvider).busy;
    expect(busy, isNot(contains(VoiceBusy.startup)), reason: 'voice works');
    expect(busy, contains(VoiceBusy.loading), reason: 'still loading');

    gates[StartupStep.recognizer]!.complete();
    await tester.pumpAndSettle();
    expect(container.read(voiceReadinessProvider).busy, isEmpty);
  });
}
