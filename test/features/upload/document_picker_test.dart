// Regression (2026-10-07): how the system picker's answer becomes a file
// the Reader can open. A real choice must never be reported as "no file
// was chosen", and Android's content:// answers must be read by bytes.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/features/upload/document_picker.dart';

import '../../helpers/fake_file_picker.dart';

void main() {
  late Directory tmp;
  late FakeFilePickerPlatform platform;
  late SystemDocumentPicker picker;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('percipere_pick_');
    platform = FakeFilePickerPlatform();
    FilePickerPlatform.instance = platform;
    picker = SystemDocumentPicker(tempDir: () async => tmp);
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<String> file(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  test('asks for ONE file of the supported kinds', () async {
    await picker.pickDocument();
    expect(platform.askedForOne, isTrue);
    expect(platform.allowed, ['jpg', 'jpeg', 'png', 'pdf', 'docx']);
  });

  test('a cached copy on disk is used as it is', () async {
    final path = await file('liham.docx', [1, 2, 3]);
    platform.next = FakePickedFile(name: 'liham.docx', path: path);
    final result = await picker.pickDocument();
    expect(result, isA<Picked>());
    final picked = (result as Picked).file;
    expect(picked.path, path);
    expect(picked.kind, DocumentKind.docx);
  });

  test('a content:// answer (no path) is read by bytes into a copy', () async {
    platform.next = FakePickedFile(
      name: 'Resibo Hunyo.PNG',
      bytes: Uint8List.fromList([9, 8, 7]),
    );
    final result = await picker.pickDocument();
    expect(result, isA<Picked>());
    final picked = (result as Picked).file;
    expect(picked.kind, DocumentKind.image, reason: 'kind from the name');
    expect(await File(picked.path).readAsBytes(), [9, 8, 7]);
  });

  test(
    'a missing or empty cached copy is a failure, not "cancelled"',
    () async {
      platform.next = FakePickedFile(
        name: 'kuwento.pdf',
        path: '${tmp.path}/gone/kuwento.pdf',
      );
      expect(await picker.pickDocument(), isA<PickFailed>());

      final empty = await file('kuwento.pdf', const []);
      platform.next = FakePickedFile(name: 'kuwento.pdf', path: empty);
      expect(await picker.pickDocument(), isA<PickFailed>());
    },
  );

  test('closing the picker is "cancelled"', () async {
    platform.next = null;
    expect(await picker.pickDocument(), isA<PickCancelled>());
  });

  test('a picker error is a failure, not "cancelled"', () async {
    platform.error = PlatformException(
      code: 'unknown_path',
      message: 'Failed to retrieve path.',
    );
    expect(await picker.pickDocument(), isA<PickFailed>());
  });

  test('a chosen file that cannot be read is a failure', () async {
    platform.next = FakePickedFile(name: 'liham.docx');
    expect(await picker.pickDocument(), isA<PickFailed>());
  });

  test('a chosen file with no content is a failure', () async {
    platform.next = FakePickedFile(name: 'liham.docx', bytes: Uint8List(0));
    expect(await picker.pickDocument(), isA<PickFailed>());
  });

  test('an unsupported kind is reported as such', () async {
    final path = await file('awit.mp3', [1]);
    platform.next = FakePickedFile(name: 'awit.mp3', path: path);
    expect(await picker.pickDocument(), isA<PickUnsupported>());
  });

  test('Maglarawan only accepts images', () async {
    final path = await file('liham.docx', [1]);
    platform.next = FakePickedFile(name: 'liham.docx', path: path);
    expect(await picker.pickImage(), isA<PickUnsupported>());
  });
}
