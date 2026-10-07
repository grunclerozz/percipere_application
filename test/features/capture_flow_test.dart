import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/extraction/extraction_exception.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/upload/document_picker.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

Future<TestEnv> _startOnCapture(
  WidgetTester tester, {
  PermissionAccess camera = PermissionAccess.granted,
  PermissionAccess cameraOnRequest = PermissionAccess.granted,
}) async {
  final env = await createEnv(
    tester,
    mode: NavMode.gestures,
    permissions: FakePermissions(
      camera: camera,
      cameraOnRequest: cameraOnRequest,
    ),
  );
  await pumpAppOnCapture(tester, env);
  expect(find.byType(CaptureScreen), findsOneWidget);
  return env;
}

Future<void> _doubleTapCenter(WidgetTester tester) async {
  final at = tester.getCenter(find.byType(CameraScreen));
  for (var i = 0; i < 2; i++) {
    final g = await tester.startGesture(at);
    await tester.pump(const Duration(milliseconds: 60));
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('camera', () {
    testWidgets('guides, auto-captures, and reads the photo', (tester) async {
      final env = await _startOnCapture(tester);
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();

      expect(find.byType(CameraScreen), findsOneWidget);
      expect(env.camera.started, isTrue);
      expect(env.tts.transcript, contains('Itutok ang camera'));

      env.tts.spoken.clear();
      env.camera
        ..frame(Frames.empty)
        ..frame(Frames.empty);
      await tester.pumpAndSettle();
      expect(env.tts.spoken, contains('Walang nakikitang teksto.'));

      for (var i = 0; i < 4; i++) {
        env.camera.frame(Frames.good);
      }
      await tester.pumpAndSettle();

      expect(env.camera.pictures, 1);
      expect(find.byType(ReaderScreen), findsOneWidget);
      final file = env.extractor.extracted.single;
      expect(file.fromCamera, isTrue);
      expect(file.sourceType, 'camera');
      expect(env.tts.transcript, contains('Kinukunan na.'));
      expect(
        env.tts.transcript,
        contains('Handa na ang dokumento, may 3 talata.'),
      );
      expect(env.camera.disposed, isTrue);
    });

    testWidgets('double-tap takes the photo', (tester) async {
      final env = await _startOnCapture(tester);
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      await _doubleTapCenter(tester);
      expect(env.camera.pictures, 1);
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    testWidgets('asks for the camera after explaining; refusal is explained', (
      tester,
    ) async {
      final env = await _startOnCapture(
        tester,
        camera: PermissionAccess.denied,
        cameraOnRequest: PermissionAccess.denied,
      );
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      expect(
        env.tts.transcript,
        contains('pahintulot na gamitin ng Percipere ang camera'),
      );
      expect(env.permissions.cameraRequests, 1);
      expect(env.camera.started, isFalse);
      expect(env.tts.spoken.last, contains('mag-upload ng litrato'));
    });

    testWidgets('broken camera: offers the phone camera app', (tester) async {
      final env = await _startOnCapture(tester);
      env.camera = FakeCameraSession(failOnStart: true);
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Hindi mabuksan ang camera'));

      await _doubleTapCenter(tester);
      expect(env.picker.photos, 1);
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    testWidgets('poor photo: explains, suggests, and offers a retake', (
      tester,
    ) async {
      final env = await _startOnCapture(tester);
      env.extractor.result = const ExtractionResult(
        text: 'x7 %',
        quality: TextQuality.low,
        pageCount: 1,
        usedOcr: true,
      );
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      await _doubleTapCenter(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(env.tts.transcript, contains('mas maliwanag na lugar'));
      expect(env.tts.transcript, contains('kumuha ulit ng litrato'));

      // Double-tap accepts the retake.
      final pad = tester.getCenter(find.byType(GesturePad));
      final g1 = await tester.startGesture(pad);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 100));
      final g2 = await tester.startGesture(pad);
      await g2.up();
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsOneWidget);
    });
  });

  group('upload', () {
    testWidgets('shows scanning progress, then the text', (tester) async {
      final env = await _startOnCapture(tester);
      env.extractor
        ..pages = 3
        ..hold = true;
      await tester.tap(find.text('Mag-upload'));
      await tester.pump();
      // Held extraction: the spinner animates, so pump frames, not settle.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(env.picker.picks, 1);
      expect(env.tts.transcript, contains('Pumili ng larawan, PDF, o Word'));
      expect(find.byType(ReaderScreen), findsOneWidget);
      final box = tester.widget<DocumentBox>(find.byType(DocumentBox));
      expect(box.isLoading, isTrue);
      expect(find.text('Binabasa ang pahina 3 sa 3.'), findsOneWidget);
      expect(env.tts.transcript, contains('Binabasa ang dokumento'));
      expect(env.tts.transcript, contains('Binabasa ang pahina 3 sa 3.'));

      env.extractor.release();
      await tester.pumpAndSettle();
      expect(
        tester.widget<DocumentBox>(find.byType(DocumentBox)).text,
        sampleText,
      );
      expect(
        env.tts.transcript,
        contains('Handa na ang dokumento, may 3 talata.'),
      );
      expect(env.extractor.extracted.single.kind, DocumentKind.pdf);
    });

    testWidgets('cancelled picker is announced', (tester) async {
      final env = await _startOnCapture(tester);
      env.picker.nextPick = const PickCancelled();
      await tester.tap(find.text('Mag-upload'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(env.tts.spoken.last, 'Walang napiling file.');
    });

    testWidgets('damaged file is explained on screen and aloud', (
      tester,
    ) async {
      final env = await _startOnCapture(tester);
      env.extractor.failure = ExtractionFailure.unreadable;
      await tester.tap(find.text('Mag-upload'));
      await tester.pumpAndSettle();
      const message = 'Hindi mabuksan ang file na ito. Maaaring sira ito.';
      expect(find.text(message), findsOneWidget);
      expect(env.tts.transcript, contains(message));
    });
  });
}
