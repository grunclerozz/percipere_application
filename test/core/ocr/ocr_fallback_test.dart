import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/extraction/extraction_exception.dart';
import 'package:percipere_app/core/ocr/ocr_fallback.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';

/// OCR that answers per file path and counts calls.
class _PathOcr implements OcrService {
  _PathOcr(this.pages);

  final Map<String, OcrPage> pages;
  final List<String> calls = [];

  @override
  Future<OcrPage> recognizeFile(String path) async {
    calls.add(path);
    final page = pages[path];
    if (page == null) throw StateError('no page for $path');
    return page;
  }

  @override
  Future<void> close() async {}
}

const _good =
    'Ang mabuting pagbabasa ay nagbibigay ng kaalaman at kasiyahan sa lahat.';

void main() {
  test('a strong first read is kept without a retry', () async {
    final ocr = _PathOcr({
      'a.jpg': const OcrPage(text: _good, confidence: 0.9),
    });
    var binarized = 0;
    final page = await recognizeWithOtsuFallback(
      ocr,
      'a.jpg',
      binarizer: (_) async {
        binarized++;
        return 'a.png';
      },
    );
    expect(page.text, _good);
    expect(binarized, 0);
    expect(ocr.calls, ['a.jpg']);
  });

  test(
    'weak first read: the binarized read wins when it has more words',
    () async {
      final ocr = _PathOcr({
        'a.jpg': const OcrPage(text: 'xq |||', confidence: 0.3),
        'a.png': const OcrPage(text: _good, confidence: 0.8),
      });
      final page = await recognizeWithOtsuFallback(
        ocr,
        'a.jpg',
        binarizer: (_) async => 'a.png',
      );
      expect(page.text, _good);
      expect(ocr.calls, ['a.jpg', 'a.png']);
    },
  );

  test('low confidence alone counts as weak', () async {
    final ocr = _PathOcr({
      'a.jpg': const OcrPage(text: _good, confidence: 0.2),
      'a.png': const OcrPage(text: '$_good Dagdag na salita.', confidence: 0.9),
    });
    final page = await recognizeWithOtsuFallback(
      ocr,
      'a.jpg',
      binarizer: (_) async => 'a.png',
    );
    expect(page.text, contains('Dagdag'));
  });

  test('the original is kept on a tie or when the retry is worse', () async {
    final ocr = _PathOcr({
      'a.jpg': const OcrPage(
        text: 'isang maikling pangungusap lang',
        confidence: 0.4,
      ),
      'a.png': const OcrPage(
        text: 'isang maikling pangungusap lang',
        confidence: 0.9,
      ),
    });
    final page = await recognizeWithOtsuFallback(
      ocr,
      'a.jpg',
      binarizer: (_) async => 'a.png',
    );
    expect(page.confidence, 0.4);
  });

  test('a failing retry or binarizer never loses the first read', () async {
    final first = const OcrPage(text: 'maikli', confidence: 0.5);
    final ocr = _PathOcr({'a.jpg': first});
    expect(
      await recognizeWithOtsuFallback(
        ocr,
        'a.jpg',
        binarizer: (_) async => 'missing.png',
      ),
      same(first),
    );
    expect(
      await recognizeWithOtsuFallback(
        ocr,
        'a.jpg',
        binarizer: (_) async => throw StateError('boom'),
      ),
      same(first),
    );
    expect(
      await recognizeWithOtsuFallback(
        ocr,
        'a.jpg',
        binarizer: (_) async => null,
      ),
      same(first),
    );
  });

  test('an engine failure on the first read still becomes ocrUnavailable', () {
    final ocr = _PathOcr({});
    expect(
      recognizeWithOtsuFallback(ocr, 'nope.jpg', binarizer: (_) async => null),
      throwsA(
        isA<ExtractionException>().having(
          (e) => e.failure,
          'failure',
          ExtractionFailure.ocrUnavailable,
        ),
      ),
    );
  });

  group('helpers', () {
    test('isWeakOcr', () {
      expect(isWeakOcr(const OcrPage(text: '')), isTrue);
      expect(isWeakOcr(const OcrPage(text: 'abc def')), isTrue);
      expect(isWeakOcr(const OcrPage(text: _good)), isFalse);
      expect(isWeakOcr(const OcrPage(text: _good, confidence: 0.59)), isTrue);
      expect(isWeakOcr(const OcrPage(text: _good, confidence: 0.6)), isFalse);
    });

    test('validWordCount ignores noise', () {
      expect(validWordCount('Ang bahay ay malaki.'), 4);
      expect(validWordCount('xqzt |||| ~^~ 1234 k'), 0);
      expect(validWordCount("don't mag-aral, po"), 3);
    });
  });
}
