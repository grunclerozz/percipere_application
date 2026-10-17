// The hidden speech-recognition test (Word Error Rate): reads a reference
// sentence, listens once, scores what was heard and saves it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/config/wer_phrases.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/db/daos/wer_dao.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/settings/wer_test_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));
}

Future<TestEnv> _open(WidgetTester tester) async {
  final env = await createEnv(
    tester,
    loggedIn: true,
    permissions: FakePermissions(mic: PermissionAccess.granted),
  );
  await pumpApp(tester, env);
  expect(find.byType(HomeScreen), findsOneWidget);
  unawaited(tester.scope.read(routerProvider).push(AppRoutes.werTest));
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('announces itself with the first sentence', (tester) async {
    final env = await _open(tester);
    expect(find.byType(WerTestScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Sabihin: ${werReferencePhrases[0]}'));
  });

  testWidgets('listening scores the answer and saves it', (tester) async {
    final env = await _open(tester);
    final bus = tester.scope.read(commandBusProvider);
    unawaited(bus.activate('werTest.listen'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(env.speech.listening, isTrue);

    // "basahin mo": heard "basahin" only -> one deletion out of two words.
    env.speech.hearWith('basahin', const [], confidence: 0.9);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(env.tts.transcript, contains('Narinig: basahin. WER 50 porsyento.'));
    final saved = await tester.runAsync(
      () => tester.scope.read(werDaoProvider).all(),
    );
    expect(saved, hasLength(1));
    expect(saved!.single.reference, 'basahin mo');
    expect(saved.single.result.deletions, 1);
  });

  testWidgets('next sentence moves on and says it', (tester) async {
    final env = await _open(tester);
    final bus = tester.scope.read(commandBusProvider);
    unawaited(bus.activate('werTest.next'));
    await tester.pumpAndSettle();
    expect(env.tts.transcript, contains('Sabihin: ${werReferencePhrases[1]}'));
  });
}
