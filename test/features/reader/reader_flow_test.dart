import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/documents_dao.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_controller.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

extension on WidgetTester {
  Offset get pad => getCenter(find.byType(GesturePad));

  Future<void> tapPad() async {
    final g = await startGesture(pad);
    await pump(const Duration(milliseconds: 60));
    await g.up();
    await pump(const Duration(milliseconds: 400)); // double-tap window
  }

  Future<void> doubleTapPad() async {
    for (var i = 0; i < 2; i++) {
      final g = await startGesture(pad);
      await pump(const Duration(milliseconds: 50));
      await g.up();
      await pump(const Duration(milliseconds: 100));
    }
    await pump();
  }

  Future<void> swipePad(Offset delta) async {
    final g = await startGesture(pad);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await g.moveTo(pad + delta * (i / 5));
    }
    await g.up();
    await pump();
  }

  Future<void> twoFingerSwipe(Offset delta) async {
    final a = await startGesture(pad, pointer: 31);
    final b = await startGesture(pad + const Offset(40, 0), pointer: 32);
    for (var i = 1; i <= 5; i++) {
      await pump(const Duration(milliseconds: 20));
      await a.moveTo(pad + delta * (i / 5));
      await b.moveTo(pad + const Offset(40, 0) + delta * (i / 5));
    }
    await a.up();
    await b.up();
    await pump();
  }

  DocumentBox get box => widget<DocumentBox>(find.byType(DocumentBox));

  /// Lets queued speech and the Reader loop run without settling (reading
  /// may keep going).
  Future<void> run() async {
    for (var i = 0; i < 5; i++) {
      await pump(const Duration(milliseconds: 50));
    }
  }
}

Future<TestEnv> _openReader(
  WidgetTester tester, {
  bool autoRead = false,
}) async {
  final env = await createEnv(
    tester,
    mode: NavMode.gestures,
    appSettings: AppSettings(autoRead: autoRead),
  );
  await pumpApp(tester, env);
  // Capture → Mag-upload → Reader (fake picker + extractor).
  await tester.tap(find.text('Mag-upload'));
  await tester.pumpAndSettle();
  expect(find.byType(ReaderScreen), findsOneWidget);
  return env;
}

void main() {
  testWidgets('auto-read off: announces the document and how to start', (
    tester,
  ) async {
    final env = await _openReader(tester);
    expect(
      env.tts.transcript,
      contains('Handa na ang dokumento, may 3 talata.'),
    );
    expect(
      env.tts.transcript,
      contains(
        'Mag-double-tap para simulan ang pagbasa, o sabihin ang “basahin”.',
      ),
    );
    expect(env.tts.transcript, isNot(contains('Ang Bataan ay isang')));
    // The first sentence is highlighted as the starting point.
    const first = 'Ang Bataan ay isang lalawigan sa rehiyon ng Gitnang Luzon.';
    expect(tester.box.highlight, const TextRange(start: 0, end: first.length));
  });

  testWidgets('auto-read on: reading starts after the announcement', (
    tester,
  ) async {
    final env = await createEnv(tester, mode: NavMode.gestures);
    await pumpApp(tester, env);
    env.tts.autoComplete = false;
    await tester.tap(find.text('Mag-upload'));
    for (var i = 0; i < 30 && !env.tts.isSpeaking; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Finish the announcement sentences until the document starts.
    for (var i = 0; i < 20; i++) {
      if (env.tts.spoken.last.startsWith('Ang Bataan')) break;
      env.tts.finishCurrent();
      await tester.run();
    }
    expect(env.tts.spoken.last, startsWith('Ang Bataan ay isang lalawigan'));
    expect(
      env.tts.transcript,
      isNot(contains('Mag-double-tap para simulan ang pagbasa')),
    );
    await tester.doubleTapPad(); // pause
    env.tts.autoComplete = true;
    env.tts.finishCurrent();
    await tester.pumpAndSettle();
  });

  testWidgets('double-tap reads and highlights; double-tap again pauses', (
    tester,
  ) async {
    final env = await _openReader(tester);
    env.tts
      ..spoken.clear()
      ..autoComplete = false;
    await tester.doubleTapPad();
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Ang Bataan ay isang lalawigan'));

    env.tts.finishCurrent();
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Kilala ito'));
    final second = tester.box.highlight!;
    expect(
      sampleText.substring(second.start, second.end),
      startsWith('Kilala ito'),
    );

    await tester.doubleTapPad();
    await tester.run();
    expect(env.tts.spoken.last, 'Naka-pause.');
    env.tts.finishCurrent();
    await tester.run();

    // A single tap repeats the current sentence.
    await tester.tapPad();
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Kilala ito'));
    env.tts.finishCurrent();
    await tester.run();
  });

  testWidgets('swipes move by sentence and paragraph; swipe up shows the '
      'speed caption', (tester) async {
    final env = await _openReader(tester);

    await tester.swipePad(const Offset(150, 0));
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Kilala ito'));

    await tester.twoFingerSwipe(const Offset(0, 150)); // down = next
    await tester.run();
    expect(env.tts.spoken.last, 'Ang pagbabasa ay karapatan ng lahat.');

    await tester.twoFingerSwipe(const Offset(0, -150)); // up = previous
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Ang Bataan ay isang'));

    await tester.swipePad(const Offset(0, -150));
    await tester.run();
    expect(tester.box.caption, 'Bilis: 1.25x');
    expect(find.text('Bilis: 1.25x'), findsOneWidget);

    // The caption fades after about two seconds.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.box.caption, isNull);
  });

  testWidgets('back while reading stops, saves the position and returns to '
      'Capture', (tester) async {
    final env = await _openReader(tester);
    env.tts.autoComplete = false;
    await tester.doubleTapPad(); // read
    await tester.run();
    env.tts.finishCurrent(); // first sentence done → second
    await tester.run();
    expect(env.tts.spoken.last, startsWith('Kilala ito'));

    await tester.twoFingerSwipe(const Offset(150, 0)); // back
    await tester.run();
    env.tts.autoComplete = true;
    env.tts.finishCurrent();
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Bumalik sa Pagkuha ng dokumento.'));
    final docs = await tester.runAsync(
      () => DocumentsDao(env.database.db).list(userId: env.account!.id),
    );
    expect(docs!.single.lastPosition, 1);
  });

  testWidgets('reopening from history resumes and says where', (tester) async {
    final env = await createEnv(tester, mode: NavMode.gestures);
    final dao = DocumentsDao(env.database.db);
    final id = await tester.runAsync(
      () => dao.insert(
        title: 'Liham',
        fullText: sampleText,
        sourceType: 'docx',
        language: 'fil',
        userId: env.account!.id,
      ),
    );
    await tester.runAsync(() => dao.updatePosition(id!, 2));
    await pumpApp(tester, env);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureScreen)),
    );
    unawaited(
      container
          .read(routerProvider)
          .push(AppRoutes.reader, extra: HistorySource(id!)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Magpapatuloy sa pangungusap 3 sa 5.'));
    final h = tester.box.highlight!;
    expect(
      sampleText.substring(h.start, h.end),
      'Ang pagbabasa ay karapatan ng lahat.',
    );
  });
}
