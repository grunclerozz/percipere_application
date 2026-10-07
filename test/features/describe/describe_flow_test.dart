import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/ids.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/focus_controller.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/describe/describe_screen.dart';
import 'package:percipere_app/features/describe/describe_source_screen.dart';
import 'package:percipere_app/features/library/item_details_screen.dart';
import 'package:percipere_app/features/library/library_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _explanation =
    'Ang Maglarawan ay para sa mga larawang walang teksto, o kung gusto mong '
    'malaman kung ano ang nasa larawan. Kumuha ng litrato gamit ang camera o '
    'mag-upload ng larawan, at sasabihin namin kung ano ang nakikita namin. '
    'Kung may internet, maaari kang humingi ng mas detalyadong paglalarawan.';

const _shortLine =
    'Pwede mo ring gamitin ang bago naming feature: Maglarawan. Sasabihin '
    'nito kung ano ang nasa isang larawan.';

const _offlineSentence = 'Mukhang may pagkain, plato, at mesa sa larawan.';

ProviderContainer _scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Lets the first-visit explanation finish: it reads a preference from the
/// real database, then waits (fake time) behind the screen announcement.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<TestEnv> _startOnCapture(WidgetTester tester) async {
  final env = await createEnv(
    tester,
    mode: NavMode.gestures,
    describeIntroSeen: false,
  );
  await pumpAppOnCapture(tester, env);
  expect(find.byType(CaptureScreen), findsOneWidget);
  await _settle(tester);
  return env;
}

int _occurrences(String text, String part) => part.allMatches(text).length;

/// Capture → Maglarawan → Mag-upload → the Description screen.
Future<TestEnv> _openDescription(WidgetTester tester) async {
  final env = await _startOnCapture(tester);
  await tester.tap(find.text('Maglarawan'));
  await tester.pumpAndSettle();
  expect(find.byType(DescribeSourceScreen), findsOneWidget);
  await tester.tap(find.text('Mag-upload'));
  await tester.pumpAndSettle();
  expect(find.byType(DescribeScreen), findsOneWidget);
  return env;
}

void main() {
  group('Capture screen', () {
    testWidgets('Maglarawan is the third button, after Mag-upload and Camera', (
      tester,
    ) async {
      await _startOnCapture(tester);
      final upload = tester.getTopLeft(find.text('Mag-upload')).dy;
      final camera = tester.getTopLeft(find.text('Gamit ang Camera')).dy;
      final describe = tester.getTopLeft(find.text('Maglarawan')).dy;
      expect(upload, lessThan(camera));
      expect(camera, lessThan(describe));
    });

    testWidgets('focus order: upload, camera, Maglarawan', (tester) async {
      await _startOnCapture(tester);
      final c = _scope(tester);
      final seen = <String?>[];
      for (var i = 0; i < 3; i++) {
        await c.read(commandBusProvider).dispatch(NavIntent.next);
        seen.add(c.read(focusControllerProvider));
      }
      expect(seen, [Ids.captureUpload, Ids.captureCamera, Ids.captureDescribe]);
      await tester.pumpAndSettle();
    });

    testWidgets('the announcement mentions Maglarawan; the full explanation '
        'is read once, on the first visit only', (tester) async {
      final env = await _startOnCapture(tester);
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains(_shortLine));
      expect(_occurrences(env.tts.transcript, _explanation), 1);

      // Leave and come back: only the short line this time.
      final c = _scope(tester);
      unawaited(c.read(routerProvider).push(AppRoutes.library));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);
      await c.read(commandBusProvider).back();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(_occurrences(env.tts.transcript, _shortLine), 2);
      expect(_occurrences(env.tts.transcript, _explanation), 1);
    });

    for (final phrase in ['maglarawan', 'ilarawan', 'describe', 'ano ito']) {
      testWidgets('saying "$phrase" opens Maglarawan', (tester) async {
        await _startOnCapture(tester);
        await _scope(tester).read(commandBusProvider).handleUtterance(phrase);
        await tester.pumpAndSettle();
        expect(find.byType(DescribeSourceScreen), findsOneWidget);
      });
    }

    for (final phrase in [
      'ano ang maglarawan?',
      'paliwanag',
      'explain',
      'tulong',
    ]) {
      testWidgets('"$phrase" while Maglarawan is focused explains it', (
        tester,
      ) async {
        final env = await _startOnCapture(tester);
        await tester.pumpAndSettle();
        final c = _scope(tester);
        c.read(focusControllerProvider.notifier).focus(Ids.captureDescribe);
        env.tts.spoken.clear();
        await c.read(commandBusProvider).handleUtterance(phrase);
        await tester.pumpAndSettle();
        expect(env.tts.transcript, contains(_explanation));
        expect(find.byType(CaptureScreen), findsOneWidget);
      });
    }

    testWidgets('"tulong" elsewhere is still the normal help', (tester) async {
      final env = await _startOnCapture(tester);
      await tester.pumpAndSettle();
      env.tts.spoken.clear();
      await _scope(tester).read(commandBusProvider).handleUtterance('tulong');
      await tester.pumpAndSettle();
      expect(env.tts.transcript, isNot(contains(_explanation)));
    });
  });

  group('Maglarawan flow', () {
    testWidgets('upload an image: described offline first', (tester) async {
      final env = await _openDescription(tester);
      expect(env.picker.imagePicks, 1);
      expect(env.picker.picks, 0, reason: 'images only, not documents');
      expect(env.labeler.labeled, ['picture.jpg']);
      expect(env.tts.transcript, contains(_offlineSentence));
      expect(find.text(_offlineSentence), findsOneWidget);
      expect(find.bySemanticsLabel('Ang larawan'), findsOneWidget);
      expect(find.byType(DocumentBox), findsOneWidget);
    });

    testWidgets('camera: the photo is described, not read', (tester) async {
      final env = await _startOnCapture(tester);
      await tester.tap(find.text('Maglarawan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        env.camera.frame(Frames.good);
      }
      await tester.pumpAndSettle();

      expect(env.camera.pictures, 1);
      expect(find.byType(DescribeScreen), findsOneWidget);
      expect(env.labeler.labeled, ['camera_1.jpg']);
      expect(
        env.extractor.extracted,
        isEmpty,
        reason: 'not sent to the Reader',
      );
      expect(env.tts.transcript, contains(_offlineSentence));
    });

    testWidgets('options by voice: save, then new picture', (tester) async {
      final env = await _openDescription(tester);
      final c = _scope(tester);

      await c.read(commandBusProvider).handleUtterance('i-save');
      await tester.pumpAndSettle();
      final docs = await tester.runAsync(
        () => LibraryDao(env.database.db).list(env.account!.id),
      );
      expect(docs!.single.source, LibrarySource.description);
      expect(env.tts.transcript, contains('Na-save sa Aklatan.'));

      await c.read(commandBusProvider).handleUtterance('bagong larawan');
      await tester.pumpAndSettle();
      expect(find.byType(DescribeSourceScreen), findsOneWidget);
    });

    testWidgets('repeat says the description again', (tester) async {
      final env = await _openDescription(tester);
      env.tts.spoken.clear();
      await _scope(tester).read(commandBusProvider).handleUtterance('ulitin');
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains(_offlineSentence));
    });

    testWidgets('options by gesture: swipe to an option, double-tap uses it', (
      tester,
    ) async {
      final env = await _openDescription(tester);
      final c = _scope(tester);
      env.tts.spoken.clear();
      final bus = c.read(commandBusProvider);
      await bus.handleUtterance('hindi'); // not now, to the detail offer
      await tester.pumpAndSettle();
      // ulitin → mas detalyado → i-save (no text found: that one is skipped).
      for (var i = 0; i < 3; i++) {
        await bus.dispatch(NavIntent.next);
      }
      expect(c.read(focusControllerProvider), Ids.describeSave);
      await bus.dispatch(NavIntent.activate);
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Na-save sa Aklatan.'));
    });

    testWidgets('text size: A+, A−, voice and pinch share one size', (
      tester,
    ) async {
      final env = await _openDescription(tester);
      final c = _scope(tester);
      double size() =>
          Theme.of(tester.element(find.byType(DocumentBox)))
              .textTheme
              .bodyLarge!
              .fontSize ??
          0;
      expect(size(), isNonZero);

      await tester.tap(find.bySemanticsLabel('Palakihin ang teksto'));
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Laki: 20'));

      await c.read(commandBusProvider).handleUtterance('palakihin');
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Laki: 22'));

      final center = tester.getCenter(find.byType(DocumentBox));
      final a = await tester.startGesture(center - const Offset(30, 0));
      final b = await tester.startGesture(center + const Offset(30, 0));
      for (var i = 1; i <= 6; i++) {
        await a.moveTo(center - Offset(30.0 + i * 12, 0));
        await b.moveTo(center + Offset(30.0 + i * 12, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Laki: 24'));

      await tester.tap(find.bySemanticsLabel('Paliitin ang teksto'));
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Laki: 22'));
    });

    testWidgets('a saved description reopens from the Library', (tester) async {
      final env = await _openDescription(tester);
      final c = _scope(tester);
      await c.read(commandBusProvider).handleUtterance('i-save');
      await tester.pumpAndSettle();
      c.read(routerProvider).go(AppRoutes.library);
      await tester.pumpAndSettle();

      expect(find.textContaining('larawan (Maglarawan)'), findsWidgets);
      await tester.tap(find.textContaining('Mukhang may pagkain').first);
      await tester.pumpAndSettle();
      expect(find.byType(ItemDetailsScreen), findsOneWidget);
      await tester.tap(find.text('Basahin'));
      await tester.pumpAndSettle();
      expect(find.byType(DescribeScreen), findsOneWidget);
      expect(env.labeler.labeled, hasLength(1), reason: 'not analysed again');
    });
  });
}
