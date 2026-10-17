// The capture quality check (Laplacian variance + brightness): a blurry or
// dark camera photo gets a spoken tip and an offer to retake; a good one
// goes straight to the Reader; an unreadable file never blocks the photo.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/library_ui.dart';
import '../../helpers/pump_app.dart';

Uint8List _flat(int value) {
  final image = img.Image(width: 120, height: 120);
  for (final p in image) {
    p.setRgb(value, value, value);
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _sharp() {
  final image = img.Image(width: 240, height: 240);
  for (final p in image) {
    final v = ((p.x ~/ 8) + (p.y ~/ 8)).isEven ? 235 : 20;
    p.setRgb(v, v, v);
  }
  return Uint8List.fromList(img.encodePng(image));
}

Future<(TestEnv, String)> _openCamera(
  WidgetTester tester,
  Uint8List photo,
) async {
  final env = await createEnv(tester, mode: NavMode.gestures);
  await pumpAppOnCapture(tester, env);
  final path = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('quality_test');
    final file = File('${dir.path}/photo.png');
    await file.writeAsBytes(photo);
    return file.path;
  }))!;
  env.camera.photoPath = path;
  await tester.tap(find.text('Gamit ang Camera'));
  await tester.pumpAndSettle();
  expect(find.byType(CameraScreen), findsOneWidget);
  return (env, path);
}

Future<void> _doubleTapCenter(WidgetTester tester) async {
  final at = tester.getCenter(find.byType(CameraScreen));
  for (var i = 0; i < 2; i++) {
    final g = await tester.startGesture(at);
    await tester.pump(const Duration(milliseconds: 60));
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _exists(WidgetTester tester, String path) async =>
    (await tester.runAsync(() => File(path).exists()))!;

void main() {
  testWidgets('a blurry photo: tip, offer, and a retake on yes', (
    tester,
  ) async {
    final (env, path) = await _openCamera(tester, _flat(128));
    await _doubleTapCenter(tester);
    await tester.settleUntil(
      () => env.tts.transcript.contains('Gusto mo bang kunan ulit?'),
    );
    expect(env.tts.transcript, contains('Malabo ang larawan.'));
    expect(env.tts.transcript, contains('Pakihawakan nang mas matatag'));
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.byType(ReaderScreen), findsNothing);

    // Double-tap answers yes: the photo is dropped, the camera stays.
    await _doubleTapCenter(tester);
    await tester.settleReal();
    expect(env.tts.transcript, contains('kunan natin ulit'));
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(await _exists(tester, path), isFalse);
    expect(env.camera.pictures, 1);
  });

  testWidgets('a dark photo gets the lighting tip', (tester) async {
    final (env, _) = await _openCamera(tester, _flat(8));
    await _doubleTapCenter(tester);
    await tester.settleUntil(
      () => env.tts.transcript.contains('Gusto mo bang kunan ulit?'),
    );
    expect(env.tts.transcript, contains('Masyadong madilim ang larawan.'));
    expect(env.tts.transcript, contains('mas maliwanag na lugar'));
  });

  testWidgets('a sharp, well-lit photo goes straight to the Reader', (
    tester,
  ) async {
    final (env, _) = await _openCamera(tester, _sharp());
    await _doubleTapCenter(tester);
    await tester.settleUntil(
      () => find.byType(ReaderScreen).evaluate().isNotEmpty,
    );
    await tester.settleReal();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(env.tts.transcript, isNot(contains('Gusto mo bang kunan ulit?')));
  });

  testWidgets('a photo that cannot be measured is not blocked', (tester) async {
    final env = await createEnv(tester, mode: NavMode.gestures);
    await pumpAppOnCapture(tester, env);
    expect(find.byType(CaptureScreen), findsOneWidget);
    await tester.tap(find.text('Gamit ang Camera'));
    await tester.pumpAndSettle();
    await _doubleTapCenter(tester);
    await tester.settleReal();
    expect(find.byType(ReaderScreen), findsOneWidget);
  });
}
