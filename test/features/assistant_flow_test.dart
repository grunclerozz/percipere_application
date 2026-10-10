// The voice assistant ("Percy", ElevenLabs) inside the running app: started
// by gesture, operating the app through its tools, handing over to the
// app's own voice. Percy's side of the conversation is scripted.

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/assistant/assistant_config.dart';
import 'package:percipere_app/core/assistant/assistant_controller.dart';
import 'package:percipere_app/core/assistant/assistant_platform.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/library/library_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/library_seed.dart';
import '../helpers/library_ui.dart';
import '../helpers/pump_app.dart';

/// Home, with Percy set up, consent given and two documents saved.
Future<TestEnv> _start(WidgetTester tester) async {
  final env = await libraryEnv(tester);
  env.assistantConfig = const AssistantConfig(
    agentId: 'agent_test',
    voiceId: 'voice_x',
  );
  await tester.runAsync(() async {
    await PreferencesDao(env.database.db).set(
      AssistantController.consentKey,
      true,
      userId: env.account?.id ?? PreferencesDao.deviceScope,
    );
    await seedDocument(
      env,
      title: 'Bill ng Meralco',
      text: 'Babayaran: 1,245.50 piso. Due: Oktubre 15.',
      format: LibraryFormat.pdf,
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
    final a = await startGesture(pad, pointer: 51);
    final b = await startGesture(pad + const Offset(0, 40), pointer: 52);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(pad - Offset(30.0 * i, 0));
      await b.moveTo(pad + Offset(-30.0 * i, 40));
    }
    await a.up();
    await b.up();
    await pumpAndSettle();
  }

  /// Percy calls a tool; waits (in real time, for the database) for the
  /// app's answer.
  Future<(String, bool)> tool(
    TestEnv env,
    String name, [
    Map<String, Object?> params = const {},
  ]) async {
    final before = env.assistant.results.length;
    final answer = env.assistant.callTool(name, params);
    await settleUntil(() => env.assistant.results.length > before);
    await pump();
    return answer;
  }

  /// Percy ends the call; lets the hand-over run.
  Future<void> percyHangsUp(TestEnv env) async {
    env.assistant.emit(const AssistantDisconnected('agent'));
    await pump(const Duration(milliseconds: 500));
    await settleReal();
  }
}

void main() {
  testWidgets('two-finger swipe left calls Percy from Home', (tester) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    expect(env.tts.transcript, contains('Tinatawag si Percy.'));
    expect(env.assistant.starts, hasLength(1));
    env.assistant.emit(const AssistantConnected());
    await tester.pump();
    // Any gesture of the user's own ends it.
    await tester.doubleTapPad();
    await tester.pump(const Duration(milliseconds: 600));
    expect(env.assistant.ends, 1);
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'nothing else ran');
  });

  testWidgets('go_to library opens the Aklatan; list_library reads it', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    var (result, isError) = await tester.tool(env, 'go_to', {
      'destination': 'library',
    });
    await tester.pumpAndSettle();
    expect(isError, isFalse);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(result, contains('Aklatan'));

    (result, isError) = await tester.tool(env, 'list_library');
    expect(result, contains('Bill ng Meralco'));
    expect(result, contains('Liham kay Nanay'));
  });

  testWidgets('open_document hands over: the Reader opens after the call', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    final (result, isError) = await tester.tool(env, 'open_document', {
      'title': 'meralco',
    });
    expect(isError, isFalse);
    expect(result, contains('Opening "Bill ng Meralco"'));
    expect(
      find.byType(ReaderScreen),
      findsNothing,
      reason: 'not before the end',
    );

    await tester.percyHangsUp(env);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);

    // Now Percy can answer questions about it.
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    await tester.settleReal();
    final (text, _) = await tester.tool(env, 'get_document_text');
    expect(text, contains('1,245.50'));
  });

  testWidgets('an unknown title lists what there is', (tester) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    final (result, isError) = await tester.tool(env, 'open_document', {
      'title': 'sulat sa barangay kapitan',
    });
    expect(isError, isTrue);
    expect(result, contains('Liham kay Nanay'));
  });

  testWidgets('scan_document: the camera opens after the call', (tester) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    await tester.tool(env, 'scan_document');
    await tester.percyHangsUp(env);
    await tester.pumpAndSettle();
    expect(find.byType(CameraScreen), findsOneWidget);
  });

  testWidgets('if Percy forgets to hang up, the app ends the call', (
    tester,
  ) async {
    final env = await _start(tester);
    await tester.twoFingerSwipeLeft();
    env.assistant.emit(const AssistantConnected());
    await tester.tool(env, 'scan_document');
    await tester.pump(AssistantController.handoverTimeout);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(env.assistant.ends, 1);
    expect(find.byType(CameraScreen), findsOneWidget);
  });

  testWidgets('help mentions how to call Percy', (tester) async {
    final env = await _start(tester);
    await tester.say('tulong');
    expect(env.tts.transcript, contains('Para tawagin si Percy'));
  });
}
