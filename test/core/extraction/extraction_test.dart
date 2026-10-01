import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/extraction/docx_extractor.dart';
import 'package:percipere_app/core/extraction/extraction_exception.dart';
import 'package:percipere_app/core/extraction/pdf_extractor.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';

/// Builds a minimal .docx with [bodyXml] inside `<w:body>`.
Uint8List makeDocx(String bodyXml) {
  const ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  final xml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="$ns"><w:body>$bodyXml</w:body></w:document>';
  final data = utf8.encode(xml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class _FakeOcr implements OcrService {
  _FakeOcr(this.page);
  final OcrPage page;
  final List<String> paths = [];

  @override
  Future<OcrPage> recognizeFile(String path) async {
    paths.add(path);
    return page;
  }

  @override
  Future<void> close() async {}
}

class _FakePdf implements PdfReader {
  _FakePdf(this.result);
  final PdfExtraction result;

  @override
  Future<PdfExtraction> read(
    String path,
    OcrService ocr, {
    void Function(int page, int pageCount)? onPage,
  }) async {
    for (var i = 1; i <= result.pageCount; i++) {
      onPage?.call(i, result.pageCount);
    }
    return result;
  }
}

void main() {
  group('DOCX', () {
    test('paragraphs, runs, tabs and breaks', () {
      final bytes = makeDocx(
        '<w:p><w:r><w:t>Mahal na </w:t></w:r><w:r><w:t>Ginoo,</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Pangalan:</w:t><w:tab/><w:t>Juan</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Una</w:t><w:br/><w:t>Ikalawa</w:t></w:r></w:p>',
      );
      expect(
        extractDocxText(bytes),
        'Mahal na Ginoo,\nPangalan:\tJuan\nUna\nIkalawa\n',
      );
    });

    test('keeps Filipino characters (UTF-8)', () {
      final bytes = makeDocx(
        '<w:p><w:r><w:t>Señor, salamat po — ñ</w:t></w:r></w:p>',
      );
      expect(extractDocxText(bytes), contains('Señor, salamat po — ñ'));
    });

    test('corrupt or non-Word files are unreadable', () {
      expect(
        () => extractDocxText(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<ExtractionException>().having(
            (e) => e.failure,
            'failure',
            ExtractionFailure.unreadable,
          ),
        ),
      );
      final notWord = Archive()..addFile(ArchiveFile('x.txt', 1, [65]));
      expect(
        () => extractDocxText(Uint8List.fromList(ZipEncoder().encode(notWord))),
        throwsA(isA<ExtractionException>()),
      );
    });
  });

  test('DocumentKind from file name', () {
    expect(DocumentKind.forPath('/a/Resibo.JPG'), DocumentKind.image);
    expect(DocumentKind.forPath('x.png'), DocumentKind.image);
    expect(DocumentKind.forPath('x.pdf'), DocumentKind.pdf);
    expect(DocumentKind.forPath('x.docx'), DocumentKind.docx);
    expect(DocumentKind.forPath('x.doc'), isNull);
    expect(DocumentKind.forPath('x'), isNull);
  });

  group('DefaultDocumentExtractor', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('percipere'));
    tearDown(() => dir.deleteSync(recursive: true));

    String file(String name, [List<int> bytes = const [0]]) {
      final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
      return f.path;
    }

    test('image → OCR → cleaned text with quality', () async {
      final ocr = _FakeOcr(
        const OcrPage(
          text: 'Paunawa sa lahat ng resi-\ndente ng barangay\n-----',
          confidence: 0.92,
        ),
      );
      final result = await DefaultDocumentExtractor(ocr)
          .extract(DocumentFile(path: file('p.jpg'), kind: DocumentKind.image));
      expect(result.text, 'Paunawa sa lahat ng residente ng barangay');
      expect(result.quality, TextQuality.good);
      expect(result.usedOcr, isTrue);
      expect(ocr.paths, hasLength(1));
    });

    test('DOCX keeps paragraph lines separate', () async {
      final path = file(
        'd.docx',
        makeDocx(
          '<w:p><w:r><w:t>Pamagat</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Isang mahabang talata ng liham.</w:t></w:r></w:p>',
        ),
      );
      final result = await DefaultDocumentExtractor(
        _FakeOcr(const OcrPage(text: '')),
      ).extract(DocumentFile(path: path, kind: DocumentKind.docx));
      expect(result.text, 'Pamagat\n\nIsang mahabang talata ng liham.');
      expect(result.usedOcr, isFalse);
    });

    test('PDF reports pages and OCR use', () async {
      final pages = <int>[];
      final result =
          await DefaultDocumentExtractor(
            _FakeOcr(const OcrPage(text: '')),
            _FakePdf(
              const PdfExtraction(
                text: 'Unang pahina ng ulat na ito.\n\nIkalawang pahina.',
                pageCount: 2,
                ocrPageCount: 1,
                ocrConfidence: 0.8,
              ),
            ),
          ).extract(
            DocumentFile(path: file('r.pdf'), kind: DocumentKind.pdf),
            onPage: (p, _) => pages.add(p),
          );
      expect(pages, [1, 2]);
      expect(result.pageCount, 2);
      expect(result.usedOcr, isTrue);
    });

    test('missing file is unreadable', () async {
      await expectLater(
        DefaultDocumentExtractor(_FakeOcr(const OcrPage(text: ''))).extract(
          DocumentFile(path: '${dir.path}/gone.jpg', kind: DocumentKind.image),
        ),
        throwsA(isA<ExtractionException>()),
      );
    });

    test('engine errors become unreadable', () async {
      final path = file('bad.docx', [9, 9, 9]);
      await expectLater(
        DefaultDocumentExtractor(_FakeOcr(const OcrPage(text: '')))
            .extract(DocumentFile(path: path, kind: DocumentKind.docx)),
        throwsA(
          isA<ExtractionException>().having(
            (e) => e.failure,
            'failure',
            ExtractionFailure.unreadable,
          ),
        ),
      );
    });
  });
}
