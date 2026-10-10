// Regression (2026-10-07): every document input failed on the tablet with
// "Hindi mabuksan ang file na ito" — the release build's shrinker broke ML
// Kit, and the extractor turned every error into "the file is damaged".
//
// These tests run each input type through the REAL extractor (only the
// native OCR and PDF engines are faked, they can't run in `flutter test`)
// to the Library save and the Reader, and check that each failure gets its
// own message. The shrinker itself is guarded by
// test/android_release_rules_test.dart.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/extraction/pdf_extractor.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/camera/camera_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';
import 'package:percipere_app/features/upload/document_picker.dart';

import '../helpers/fake_file_picker.dart';
import '../helpers/fakes.dart';
import '../helpers/library_ui.dart';
import '../helpers/pump_app.dart';

const _ocrText = 'Paalala sa barangay. Walang pasok bukas dahil sa bagyo.';
const _pdfText = 'Ang mga bata ay naglalaro sa labas. Masaya sila.';
const _docxText = 'Liham para kay Nanay. Mahal na mahal kita.';

Uint8List _docx(String text) => _docxLines([text]);

Uint8List _docxLines(List<String> lines) {
  const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  final paragraphs = [
    for (final line in lines) '<w:p><w:r><w:t>$line</w:t></w:r></w:p>',
  ].join();
  final xml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="$ns"><w:body>$paragraphs</w:body></w:document>';
  final data = utf8.encode(xml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class _TextPdf implements PdfReader {
  @override
  Future<PdfExtraction> read(
    String path,
    OcrService ocr, {
    void Function(int page, int pageCount)? onPage,
  }) async {
    onPage?.call(1, 1);
    return const PdfExtraction(text: _pdfText, pageCount: 1, ocrPageCount: 0);
  }
}

/// A PDF engine failing for a reason that has nothing to do with the file.
class _CrashingPdf implements PdfReader {
  @override
  Future<PdfExtraction> read(
    String path,
    OcrService ocr, {
    void Function(int page, int pageCount)? onPage,
  }) async => throw StateError('plugin not initialised');
}

/// ML Kit failing the way the shrunk release build did.
class _BrokenOcr implements OcrService {
  @override
  Future<OcrPage> recognizeFile(String path) async =>
      throw Exception('NullPointerException: Object.getClass() on null');

  @override
  Future<void> close() async {}
}

/// Real files on disk, made outside fake async.
class _Files {
  late Directory dir;
  late String image;
  late String photo;
  late String pdf;
  late String docx;

  Future<void> create() async {
    dir = await Directory.systemTemp.createTemp('percipere_capture_');
    image = '${dir.path}/resibo.png';
    photo = '${dir.path}/camera_photo.jpg';
    pdf = '${dir.path}/kuwento.pdf';
    docx = '${dir.path}/liham.docx';
    await File(image).writeAsBytes([1, 2, 3]);
    await File(photo).writeAsBytes([4, 5, 6]);
    await File(pdf).writeAsBytes(utf8.encode('%PDF-1.4'));
    await File(docx).writeAsBytes(_docx(_docxText));
  }
}

Future<(TestEnv, _Files)> _start(
  WidgetTester tester, {
  OcrService? ocr,
  PdfReader? pdf,
}) async {
  final env = await createEnv(
    tester,
    mode: NavMode.gestures,
    permissions: FakePermissions(camera: PermissionAccess.granted),
  );
  final files = _Files();
  await tester.runAsync(files.create);
  addTearDown(() => files.dir.delete(recursive: true));
  env.ocr.page = const OcrPage(text: _ocrText, confidence: 0.95);
  env.extractor.real = DefaultDocumentExtractor(
    ocr ?? env.ocr,
    pdf ?? _TextPdf(),
  );
  await pumpAppOnCapture(tester, env);
  expect(find.byType(CaptureScreen), findsOneWidget);
  return (env, files);
}

Future<void> _upload(WidgetTester tester, TestEnv env, DocumentFile f) async {
  env.picker.nextPick = Picked(f);
  await tester.tap(find.text('Mag-upload'));
  await tester.pump();
  await tester.settleUntil(
    () =>
        env.tts.transcript.contains('Handa na') ||
        env.tts.transcript.contains('Hindi') ||
        env.tts.transcript.contains('Nawala'),
  );
  await tester.settleReal();
}

Future<List<LibraryItem>> _saved(WidgetTester tester, TestEnv env) async =>
    (await tester.runAsync(
      () => LibraryDao(env.database.db).list(env.account!.id),
    ))!;

/// The text stored in the Library for [item].
Future<String> _text(WidgetTester tester, TestEnv env, LibraryItem item) async {
  final chapters = (await tester.runAsync(
    () => LibraryDao(env.database.db).loadText(item),
  ))!;
  return chapters.map((c) => c.text).join(' ');
}

void main() {
  group('every input reaches the Library and the Reader', () {
    testWidgets('gallery image (OCR)', (tester) async {
      final (env, files) = await _start(tester);
      await _upload(
        tester,
        env,
        DocumentFile(path: files.image, kind: DocumentKind.image),
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Handa na ang dokumento'));
      expect(env.tts.transcript, isNot(contains('Hindi mabuksan')));
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.image);
      expect(items.single.source, LibrarySource.upload);
      expect(
        await _text(tester, env, items.single),
        contains('Walang pasok bukas'),
      );
    });

    testWidgets('PDF', (tester) async {
      final (env, files) = await _start(tester);
      await _upload(
        tester,
        env,
        DocumentFile(path: files.pdf, kind: DocumentKind.pdf),
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.pdf);
      expect(
        await _text(tester, env, items.single),
        contains('naglalaro sa labas'),
      );
    });

    testWidgets('DOCX (real parsing)', (tester) async {
      final (env, files) = await _start(tester);
      await _upload(
        tester,
        env,
        DocumentFile(path: files.docx, kind: DocumentKind.docx),
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.docx);
      expect(
        await _text(tester, env, items.single),
        contains('Mahal na mahal kita'),
      );
    });

    testWidgets('camera photo', (tester) async {
      final (env, files) = await _start(tester);
      env.camera.photoPath = files.photo;
      await tester.tap(find.text('Gamit ang Camera'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsOneWidget);
      // Double-tap anywhere takes the photo.
      final at = tester.getCenter(find.byType(CameraScreen));
      for (var i = 0; i < 2; i++) {
        final g = await tester.startGesture(at);
        await tester.pump(const Duration(milliseconds: 60));
        await g.up();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      await tester.settleUntil(() => env.tts.transcript.contains('Handa na'));
      await tester.settleReal();
      expect(find.byType(ReaderScreen), findsOneWidget);
      final items = await _saved(tester, env);
      expect(items.single.source, LibrarySource.camera);
      expect(
        await _text(tester, env, items.single),
        contains('Walang pasok bukas'),
      );
      final photoGone = await tester.runAsync(
        () async => !await File(files.photo).exists(),
      );
      expect(photoGone, isTrue, reason: 'camera photos are deleted');
    });
  });

  group('each failure has its own message', () {
    testWidgets('OCR engine failure is not called a damaged file', (
      tester,
    ) async {
      final (env, files) = await _start(tester, ocr: _BrokenOcr());
      await _upload(
        tester,
        env,
        DocumentFile(path: files.image, kind: DocumentKind.image),
      );
      const message =
          'Hindi gumana ang pagbasa ng teksto sa phone na ito ngayon.';
      expect(env.tts.transcript, contains(message));
      expect(env.tts.transcript, isNot(contains('Maaaring sira ito')));
      expect(await _saved(tester, env), isEmpty);
    });

    testWidgets('a file that disappeared', (tester) async {
      final (env, files) = await _start(tester);
      await _upload(
        tester,
        env,
        DocumentFile(
          path: '${files.dir.path}/wala.pdf',
          kind: DocumentKind.pdf,
        ),
      );
      expect(
        env.tts.transcript,
        contains('Nawala ang file bago ko ito nabasa.'),
      );
    });

    testWidgets('a damaged DOCX is still "damaged"', (tester) async {
      final (env, files) = await _start(tester);
      await tester.runAsync(() => File(files.docx).writeAsString('sira'));
      await _upload(
        tester,
        env,
        DocumentFile(path: files.docx, kind: DocumentKind.docx),
      );
      expect(
        env.tts.transcript,
        contains('Hindi mabuksan ang file na ito. Maaaring sira ito.'),
      );
    });

    testWidgets('a chosen file that could not be read is not "no file"', (
      tester,
    ) async {
      final (env, _) = await _start(tester);
      env.picker.nextPick = PickFailed(Exception('copy failed'));
      await tester.tap(find.text('Mag-upload'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Hindi ko makuha ang file na pinili mo.'),
      );
      expect(env.tts.transcript, isNot(contains('Walang napiling file')));
    });

    testWidgets('cancelling the picker still says no file was chosen', (
      tester,
    ) async {
      final (env, _) = await _start(tester);
      env.picker.nextPick = const PickCancelled();
      await tester.tap(find.text('Mag-upload'));
      await tester.pumpAndSettle();
      expect(env.tts.spoken.last, 'Walang napiling file.');
    });

    testWidgets('a Library failure keeps the text readable and says so', (
      tester,
    ) async {
      final (env, files) = await _start(tester);
      await tester.runAsync(
        () => env.database.db.execute('DROP TABLE library_items'),
      );
      await _upload(
        tester,
        env,
        DocumentFile(path: files.docx, kind: DocumentKind.docx),
      );
      await tester.settleUntil(
        () => env.tts.transcript.contains('hindi ko ito na-save'),
      );
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Handa na ang dokumento'));
      expect(
        env.tts.transcript,
        contains('Mababasa mo ito, pero hindi ko ito na-save sa Aklatan.'),
      );
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('through the real picker code (system picker answer → Reader)', () {
    late FakeFilePickerPlatform platform;

    Future<(TestEnv, _Files)> startWithPicker(WidgetTester tester) async {
      final (env, files) = await _start(tester);
      platform = FakeFilePickerPlatform();
      FilePickerPlatform.instance = platform;
      env.picker.real = SystemDocumentPicker(tempDir: () async => files.dir);
      return (env, files);
    }

    Future<void> choose(WidgetTester tester, TestEnv env) async {
      await tester.tap(find.text('Mag-upload'));
      await tester.pump();
      await tester.settleUntil(
        () =>
            env.tts.transcript.contains('Handa na') ||
            env.tts.transcript.contains('Hindi') ||
            env.tts.transcript.contains('Walang'),
      );
      await tester.settleReal();
    }

    testWidgets('gallery image given as content:// only', (tester) async {
      final (env, files) = await startWithPicker(tester);
      final bytes = await tester.runAsync(
        () => File(files.image).readAsBytes(),
      );
      platform.next = FakePickedFile(name: 'IMG_2031.jpg', bytes: bytes);
      await choose(tester, env);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(env.tts.transcript, isNot(contains('Walang napiling file')));
      expect(env.tts.transcript, contains('Handa na ang dokumento'));
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.image);
      expect(
        await _text(tester, env, items.single),
        contains('Walang pasok bukas'),
      );
    });

    testWidgets('PDF given as a cached copy', (tester) async {
      final (env, files) = await startWithPicker(tester);
      platform.next = FakePickedFile(name: 'kuwento.pdf', path: files.pdf);
      await choose(tester, env);
      expect(find.byType(ReaderScreen), findsOneWidget);
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.pdf);
    });

    testWidgets('DOCX given as content:// only (real parsing)', (tester) async {
      final (env, files) = await startWithPicker(tester);
      final bytes = await tester.runAsync(() => File(files.docx).readAsBytes());
      platform.next = FakePickedFile(
        name: 'Liham kay Nanay.docx',
        bytes: bytes,
      );
      await choose(tester, env);
      expect(find.byType(ReaderScreen), findsOneWidget);
      final items = await _saved(tester, env);
      expect(items.single.format, LibraryFormat.docx);
      expect(
        await _text(tester, env, items.single),
        contains('Mahal na mahal kita'),
      );
    });

    testWidgets('a picker error says the file could not be got', (
      tester,
    ) async {
      final (env, _) = await startWithPicker(tester);
      platform.error = Exception('unknown_path');
      await choose(tester, env);
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Hindi ko makuha ang file na pinili mo.'),
      );
      expect(env.tts.transcript, isNot(contains('Walang napiling file')));
    });
  });

  testWidgets('an unexpected error is not blamed on the file', (tester) async {
    final (env, files) = await _start(tester, pdf: _CrashingPdf());
    await _upload(
      tester,
      env,
      DocumentFile(path: files.pdf, kind: DocumentKind.pdf),
    );
    expect(
      env.tts.transcript,
      contains('Nagkaproblema habang binabasa ko ang file.'),
    );
    expect(env.tts.transcript, isNot(contains('Maaaring sira ito')));
  });

  testWidgets('a receipt: its kind and total come first; questions answered', (
    tester,
  ) async {
    final (env, files) = await _start(tester);
    await tester.runAsync(
      () => File(files.docx).writeAsBytes(
        _docxLines(const [
          'Tindahan ni Aling Rosa',
          'Official Receipt No. 00123',
          'Bigas 5kg 1 x 250.00',
          'Asukal 1kg 1 x 85.50',
          'Subtotal 335.50',
          'TOTAL 375.76',
          'Cash 500.00',
          'Change 124.24',
          'Salamat po sa pagbili.',
        ]),
      ),
    );
    await _upload(
      tester,
      env,
      DocumentFile(path: files.docx, kind: DocumentKind.docx),
    );
    final t = env.tts.transcript;
    expect(t, contains('Mukhang resibo ito.'));
    expect(t, contains('Mula sa: Tindahan ni Aling Rosa.'));
    expect(t, contains('Kabuuan: 375.76 piso.'));
    expect(
      t.indexOf('Kabuuan'),
      lessThan(t.indexOf('Handa na ang dokumento')),
      reason: 'key facts first',
    );

    final bus = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    ).read(commandBusProvider);
    await bus.handleUtterance('magkano ang total');
    await tester.settleReal();
    expect(env.tts.spoken.last, 'Kabuuan: 375.76 piso.');
    await bus.handleUtterance('kailan ang due');
    await tester.settleReal();
    expect(env.tts.spoken.last, contains('Wala akong nakitang due date'));
    await bus.handleUtterance('ano ito');
    await tester.settleReal();
    expect(env.tts.transcript, endsWith('Mula sa: Tindahan ni Aling Rosa.'));
  });

  testWidgets('ordinary text gets no guessed kind', (tester) async {
    final (env, files) = await _start(tester);
    // A story: no letter, receipt, bill or label words (the shared sample
    // "Liham para kay Nanay…" is, rightly, recognized as a letter).
    await tester.runAsync(
      () => File(
        files.docx,
      ).writeAsBytes(_docx('Ang mga bata ay naglalaro sa labas. Masaya sila.')),
    );
    await _upload(
      tester,
      env,
      DocumentFile(path: files.docx, kind: DocumentKind.docx),
    );
    expect(env.tts.transcript, isNot(contains('Mukhang')));
    expect(env.tts.transcript, contains('Handa na ang dokumento'));
  });
}
