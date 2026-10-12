// Percy (self-built, Phase 9) inside the running app: started by gesture or
// by name, understanding sentences with the real bundled model, acting
// through the CommandBus, ended by a swipe or tap (long-press, single tap
// and two-finger double tap keep it). ElevenLabs stays off.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/percy_log_dao.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/library/library_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/settings/settings_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/library_seed.dart';
import '../helpers/library_ui.dart';
import '../helpers/pump_app.dart';

/// Either of Percy's greetings (persona.json has variations).
final _greeting = RegExp('ako si Percy|Si Percy po ito');

Future<TestEnv> _start(
  WidgetTester tester, {
  NavMode mode = NavMode.gestures,
}) async {
  final env = await libraryEnv(tester, mode: mode);
  await tester.runAsync(() async {
    await seedDocument(
      env,
      title: 'Bill ng Meralco',
      text: 'Babayaran: 1,245.50 piso. Due: Oktubre 15.',
    );
    await seedDocument(env, title: 'Liham kay Nanay', text: sampleText);
  });
  env.books.offline = true;
  await pumpApp(tester, env);
  expect(find.byType(HomeScreen), findsOneWidget);
  return env;
}

extension on WidgetTester {
  Future<void> twoFingerSwipeLeft() async {
    final pad = getCenter(find.byType(GesturePad));
    final a = await startGesture(pad, pointer: 61);
    final b = await startGesture(pad + const Offset(0, 40), pointer: 62);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(pad - Offset(30.0 * i, 0));
      await b.moveTo(pad + Offset(-30.0 * i, 40));
    }
    await a.up();
    await b.up();
    await pumpAndSettle();
  }

  /// The user says [words] (Percy is listening) and the app reacts.
  Future<void> tell(TestEnv env, String words) async {
    await settleUntil(() => env.speech.listening);
    env.speech.hear(words);
    await settleReal();
  }
}

void main() {
  testWidgets('two-finger swipe left starts the self-built Percy, offline; '
      'ElevenLabs is never used', (tester) async {
    final env = await _start(tester);
    env.online = false;
    await tester.twoFingerSwipeLeft();
    await tester.settleReal();
    expect(env.tts.transcript, contains(_greeting));
    expect(env.assistant.starts, isEmpty);
    // Gesture mode, yet Percy listens for the answer.
    await tester.settleUntil(() => env.speech.listening);
    expect(env.speech.listening, isTrue);
  });

  testWidgets('a natural sentence opens the Library through the CommandBus', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    await tester.tell(env, 'dalhin mo ako sa library');
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('"Percy, …" in one breath; a document named by title opens', (
    tester,
  ) async {
    final env = await _start(tester, mode: NavMode.voice);
    await tester.settleUntil(() => env.speech.listening);
    env.speech.hear('Percy, buksan mo yung liham kay nanay');
    await tester.settleReal();
    await tester.settleReal();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Liham kay Nanay'));
  });

  testWidgets('a swipe ends Percy with a goodbye and does nothing else', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    await tester.settleReal();
    final before = env.tts.transcript.length;
    // A swipe right would normally move the focus ("Aklatan, 2 sa 3").
    await tester.fling(find.byType(GesturePad), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.settleReal();
    final said = env.tts.transcript.substring(before);
    expect(said, contains('Sige po, paalam! Tawagin lang po ako ulit.'));
    expect(said, isNot(contains('Tapos na po ang usapan')));
    expect(said, isNot(contains('sa 3')));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('"paalam" ends the session; later speech is a normal command', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    await tester.tell(env, 'paalam na percy');
    expect(env.tts.transcript, contains('aalam'));
    // Percy is off; the gesture starts a new session.
    await tester.twoFingerSwipeLeft();
    await tester.settleReal();
    expect(env.tts.transcript, contains(_greeting));
  });

  testWidgets('the app\'s own yes/no question is spoken and answered '
      'through Percy (destructive actions stay confirmed)', (tester) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    await tester.tell(env, 'punta tayo sa settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    final bus = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    ).read(commandBusProvider);
    var deleted = 0;
    unawaited(bus.offer('Burahin ito?', () => deleted++));
    await tester.settleReal();
    expect(env.tts.transcript, contains('Burahin ito?')); // spoken, not muted
    await tester.tell(env, 'hindi');
    expect(deleted, 0);
    unawaited(bus.offer('Burahin ito?', () => deleted++));
    await tester.settleReal();
    await tester.tell(env, 'oo sige');
    expect(deleted, 1);
  });

  testWidgets('each turn is logged locally (no document text)', (tester) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    await tester.tell(env, 'dalhin mo ako sa library');
    final log = await tester.runAsync(() => PercyLogDao(env.database.db).all());
    expect(log, isNotEmpty);
    final turn = log!.last;
    expect(turn.text, 'dalhin mo ako sa library');
    expect(turn.intent, 'open_library');
    expect(turn.outcome, 'acted');
    expect(turn.confidence, greaterThan(0.6));
    final csv = PercyLogDao.toCsv(log);
    expect(csv, startsWith('text,intent,author,source,notes\n'));
    expect(csv, contains('dalhin mo ako sa library,open_library,,STT log,'));
  });
}
