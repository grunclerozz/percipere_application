import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/extraction/pdf_extractor.dart';
import 'package:percipere_app/core/library/book_content.dart';
import 'package:percipere_app/core/library/chaptered_text.dart';
import 'package:percipere_app/core/library/epub_parser.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/library/sample_books.dart';

Uint8List _withExtra(Uint8List epub, Map<String, String> extra) {
  final archive = ZipDecoder().decodeBytes(epub);
  extra.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  final bytes = SampleBooks.epub(
    title: 'Fables',
    author: 'Aesop',
    chapters: SampleBooks.fables,
    illustrated: true,
  );

  group('EPUB parser', () {
    test('reads the spine in order with titles from the navigation', () {
      final book = EpubParser.parse(bytes);
      expect(book.title, 'Fables');
      expect(book.author, 'Aesop');
      expect(book.text.chapters.map((c) => c.title), [
        'The Tortoise and the Hare',
        'The Ant and the Grasshopper',
        'The Lion and the Mouse',
      ]);
    });

    test('extracts paragraphs without markup, styles or scripts', () {
      final book = EpubParser.parse(bytes);
      final first = book.text.chapters.first.text;
      expect(first, isNot(contains('<')));
      expect(first, isNot(contains('margin')));
      expect(first, startsWith('The Tortoise and the Hare\n\nA hare once'));
      expect(first.split('\n\n'), hasLength(5)); // heading + 4 paragraphs
      expect(first, contains('Slow and steady wins the race.'));
    });

    test('records where each image appears, with the publisher alt text', () {
      final images = EpubParser.parse(bytes).text.images;
      expect(images, hasLength(3));
      expect(images[0].chapter, 0);
      expect(images[0].paragraph, 1, reason: 'after the heading');
      expect(images[0].src, 'OEBPS/images/i0.png');
      expect(images[0].alt, 'A tortoise and a hare at the start of a race');
      expect(images[1].alt, isNull, reason: 'alt="" means no alt text');
      expect(images[2].chapter, 2);
    });

    test('the book without illustrations has no images', () {
      final plain = EpubParser.parse(
        SampleBooks.epub(
          title: 'Tales',
          author: 'Folk',
          chapters: SampleBooks.kindness,
        ),
      );
      expect(plain.text.images, isEmpty);
      expect(plain.text.chapters, hasLength(2));
    });

    test('a chapter without a title in the navigation uses a fallback', () {
      final stripped = _withExtra(bytes, {});
      final archive = ZipDecoder().decodeBytes(stripped);
      final cleaned = Archive();
      for (final f in archive.files) {
        if (f.name == 'OEBPS/nav.xhtml') {
          final empty = utf8.encode(
            '<html xmlns="http://www.w3.org/1999/xhtml"><body></body></html>',
          );
          cleaned.addFile(ArchiveFile(f.name, empty.length, empty));
        } else {
          cleaned.addFile(f);
        }
      }
      final book = EpubParser.parse(
        Uint8List.fromList(ZipEncoder().encode(cleaned)),
        fallbackTitle: (n) => 'Kabanata $n',
      );
      // The first heading in the chapter is used before the fallback.
      expect(book.text.chapters.first.title, 'The Tortoise and the Hare');
    });

    test('DRM-protected EPUBs are reported', () {
      final drm = _withExtra(bytes, {
        'META-INF/encryption.xml':
            '<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<EncryptedData><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>'
            '</EncryptedData></encryption>',
      });
      expect(
        () => EpubParser.parse(drm),
        throwsA(
          isA<EpubException>().having(
            (e) => e.problem,
            'problem',
            EpubProblem.drm,
          ),
        ),
      );
    });

    test('font obfuscation is not DRM', () {
      final fonts = _withExtra(bytes, {
        'META-INF/encryption.xml':
            '<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<EncryptedData><EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>'
            '</EncryptedData></encryption>',
      });
      expect(EpubParser.parse(fonts).text.chapters, hasLength(3));
    });

    test('invalid files are reported', () {
      expect(
        () => EpubParser.parse(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<EpubException>().having(
            (e) => e.problem,
            'problem',
            EpubProblem.invalid,
          ),
        ),
      );
      final noContainer = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()..addFile(ArchiveFile('hello.txt', 2, utf8.encode('hi'))),
        ),
      );
      expect(
        () => EpubParser.parse(noContainer),
        throwsA(isA<EpubException>()),
      );
    });

    test('the text cache keeps chapters and image positions', () {
      final book = EpubParser.parse(bytes);
      final again = BookText.fromJsonString(book.text.toJsonString());
      expect(again.chapters.length, 3);
      expect(again.chapters.first.text, book.text.chapters.first.text);
      expect(again.images.first.alt, book.text.images.first.alt);
      expect(again.images.first.src, 'OEBPS/images/i0.png');
    });
  });

  group('ChapteredText', () {
    final chapters = [
      const ChapterText('Isa', 'Una. Ikalawa.\n\nIkatlo.'),
      const ChapterText('Wala', '   '),
      const ChapterText('Dalawa', 'Apat. Lima. Anim.'),
    ];

    test('drops empty chapters and counts sentences per chapter', () {
      final t = ChapteredText.build(chapters);
      expect(t.chapterTitles, ['Isa', 'Dalawa']);
      expect(t.chapterStarts, [0, 3]);
      expect(t.sentences, hasLength(6));
      expect(t.info, const [ChapterInfo('Isa', 3), ChapterInfo('Dalawa', 3)]);
      expect(t.hasChapters, isTrue);
    });

    test('maps global positions to chapter positions and back', () {
      final t = ChapteredText.build(chapters);
      expect(t.chapterOf(2), 0);
      expect(t.chapterOf(3), 1);
      expect(t.inChapter(4), 1);
      expect(t.globalOf(1, 2), 5);
      expect(t.globalOf(1, 99), 5, reason: 'clamped inside the chapter');
      expect(t.globalOf(9, 0), 3, reason: 'clamped to the last chapter');
    });

    test('sentence text matches the joined document', () {
      final t = ChapteredText.build(chapters);
      expect(t.sentences.first.textIn(t.text), 'Una.');
      expect(t.sentences[3].textIn(t.text), 'Apat.');
      expect(t.sentences.last.textIn(t.text), 'Anim.');
    });

    test('a one-chapter document is its own text', () {
      final t = ChapteredText.build([const ChapterText('x', 'Isa. Dalawa.')]);
      expect(t.text, 'Isa. Dalawa.');
      expect(t.hasChapters, isFalse);
    });

    test('favorite labels keep the first words', () {
      expect(favoriteLabel('Isa dalawa tatlo'), 'Isa dalawa tatlo');
      expect(favoriteLabel('a b c d e f g h i j', words: 4), 'a b c d…');
    });
  });

  group('PDF chapters', () {
    PdfExtraction pdf(
      List<String> pages,
      List<({String title, int page})> outline,
    ) => PdfExtraction(
      text: pages.join('\n\n'),
      pageCount: pages.length,
      ocrPageCount: 0,
      pageTexts: pages,
      outline: outline,
    );

    test('uses the outline for chapters', () async {
      final chapters = await chaptersFromPdf(
        pdf(
          ['Pabalat na pahina.', 'Unang pahina.', 'Pangalawa.', 'Pangatlo.'],
          [(title: 'Una', page: 2), (title: 'Ikalawa', page: 4)],
        ),
        chapterTitle: (n) => 'Kabanata $n',
      );
      expect(chapters.map((c) => c.title), ['Kabanata 1', 'Una', 'Ikalawa']);
      expect(chapters[1].text, contains('Pangalawa'));
      expect(chapters[2].text, contains('Pangatlo'));
    });

    test('without an outline the PDF is one chapter', () async {
      final chapters = await chaptersFromPdf(
        pdf(['Isa.', 'Dalawa.'], const []),
        chapterTitle: (n) => 'Kabanata $n',
      );
      expect(chapters, hasLength(1));
      expect(chapters.single.text, contains('Dalawa'));
    });

    test('an empty PDF gives no chapters', () async {
      final chapters = await chaptersFromPdf(
        pdf(['', '  '], const []),
        chapterTitle: (n) => 'Kabanata $n',
      );
      expect(chapters, isEmpty);
    });
  });
}
