import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// A chapter of a sample book.
class SampleChapter {
  /// Creates a chapter.
  const SampleChapter(this.title, this.paragraphs, {this.imageAlt});

  /// Chapter title.
  final String title;

  /// Paragraphs of plain text.
  final List<String> paragraphs;

  /// When set, the chapter opens with an illustration; this is its alt text
  /// (empty string = an illustration with no alt text).
  final String? imageAlt;
}

/// Public-domain sample content for the mocked web app. The fables are
/// Aesop's, retold in our own words so no modern translation is reused; swap
/// in real Project Gutenberg files when the web app exists.
abstract final class SampleBooks {
  /// Chapters of "Aesop's Fables, Selected" (EPUB with illustrations).
  static const List<SampleChapter> fables = [
    SampleChapter('The Tortoise and the Hare', [
      'A hare once laughed at a tortoise for walking so slowly. '
          '"I can run circles around you," he said.',
      'The tortoise answered quietly, "Let us race, and we shall see." '
          'The animals gathered along the road to watch.',
      'At the signal the hare dashed far ahead. He was so sure of winning '
          'that he lay down under a tree and fell asleep.',
      'The tortoise kept walking, one step after another. When the hare '
          'woke up, the tortoise was already touching the finish line. '
          'Slow and steady wins the race.',
    ], imageAlt: 'A tortoise and a hare at the start of a race'),
    SampleChapter('The Ant and the Grasshopper', [
      'All summer long, a grasshopper sang and played in the sun. '
          'Nearby, an ant carried grains of wheat to her nest.',
      '"Why work so hard?" asked the grasshopper. "Come and sing with me." '
          'The ant replied, "I am storing food for the winter."',
      'When winter came, the grasshopper had nothing to eat. '
          'He knocked on the ant\'s door and begged for a little food.',
      'The ant said, "You sang all summer. Now you may dance in the cold." '
          'It is wise to prepare today for the needs of tomorrow.',
    ], imageAlt: ''),
    SampleChapter('The Lion and the Mouse', [
      'A lion was sleeping in the forest when a little mouse ran across '
          'his paw. The lion woke up and caught the mouse in his great claws.',
      '"Please let me go," squeaked the mouse. "One day I will repay you." '
          'The lion laughed, but he let the mouse go.',
      'Some days later, hunters trapped the lion in a strong net. '
          'He roared, and the mouse heard him.',
      'The mouse gnawed the ropes until the lion was free. '
          'No kindness is ever wasted, however small the helper.',
    ], imageAlt: 'A small mouse gnawing a rope net around a lion'),
  ];

  /// "The Tortoise and the Hare", a short PDF with an outline.
  static const List<SampleChapter> hare = [
    SampleChapter('The Race', [
      'A hare once laughed at a tortoise for walking so slowly. '
          '"I can run circles around you," he said.',
      'The tortoise answered quietly, "Let us race, and we shall see."',
    ]),
    SampleChapter('The Finish', [
      'The hare dashed far ahead and fell asleep under a tree. '
          'The tortoise kept walking, one step after another.',
      'When the hare woke up, the tortoise was already at the finish line. '
          'Slow and steady wins the race.',
    ]),
  ];

  /// Short stories about kindness (EPUB, no images).
  static const List<SampleChapter> kindness = [
    SampleChapter('The Honest Woodcutter', [
      'A poor woodcutter dropped his axe into a deep river. He sat on the '
          'bank and wept, for it was his only tool.',
      'A kind spirit rose from the water holding a golden axe. '
          '"Is this yours?" she asked. "No," said the woodcutter.',
      'She showed him a silver axe, and again he said no. '
          'At last she held up his plain iron axe, and he thanked her gladly.',
      'Pleased by his honesty, the spirit gave him all three axes. '
          'Honesty is its own reward.',
    ]),
    SampleChapter('The Crow and the Pitcher', [
      'On a hot day, a thirsty crow found a pitcher with a little water '
          'at the bottom. His beak could not reach it.',
      'He did not give up. He picked up small stones and dropped them in, '
          'one by one, until the water rose to the top.',
      'The crow drank at last. Where there is a will, there is a way.',
    ]),
  ];

  /// A tiny valid PNG illustration (a solid colored square).
  static Uint8List illustration(int seed) {
    final image = img.Image(width: 96, height: 96);
    final colors = [
      img.ColorRgb8(46, 125, 50),
      img.ColorRgb8(21, 101, 192),
      img.ColorRgb8(198, 40, 40),
    ];
    img.fill(image, color: colors[seed % colors.length]);
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Builds an EPUB 3 file. With [illustrated], chapters that have
  /// [SampleChapter.imageAlt] open with an `<img>`.
  static Uint8List epub({
    required String title,
    required String author,
    required List<SampleChapter> chapters,
    bool illustrated = false,
  }) {
    final archive = Archive();
    void add(String name, List<int> bytes, {bool compress = true}) {
      archive.addFile(
        compress
            ? ArchiveFile(name, bytes.length, bytes)
            : ArchiveFile.noCompress(name, bytes.length, bytes),
      );
    }

    String esc(String s) => const HtmlEscape().convert(s);

    add('mimetype', utf8.encode('application/epub+zip'), compress: false);
    add(
      'META-INF/container.xml',
      utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
    );

    final manifest = StringBuffer();
    final spine = StringBuffer();
    final nav = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      manifest.writeln(
        '<item id="c$i" href="c$i.xhtml" media-type="application/xhtml+xml"/>',
      );
      spine.writeln('<itemref idref="c$i"/>');
      nav.writeln('<li><a href="c$i.xhtml">${esc(c.title)}</a></li>');
      final body = StringBuffer('<h1>${esc(c.title)}</h1>\n');
      if (illustrated && c.imageAlt != null) {
        final alt = c.imageAlt!.isEmpty ? '' : ' alt="${esc(c.imageAlt!)}"';
        body.writeln('<img src="images/i$i.png"$alt/>');
        add('OEBPS/images/i$i.png', illustration(i));
        manifest.writeln(
          '<item id="i$i" href="images/i$i.png" media-type="image/png"/>',
        );
      }
      for (final para in c.paragraphs) {
        body.writeln('<p>${esc(para)}</p>');
      }
      add(
        'OEBPS/c$i.xhtml',
        utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>${esc(c.title)}</title>
<style>p { margin: 1em; }</style></head><body>$body</body></html>'''),
      );
    }
    add(
      'OEBPS/nav.xhtml',
      utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head>
<body><nav epub:type="toc"><ol>$nav</ol></nav></body></html>'''),
    );
    add(
      'OEBPS/content.opf',
      utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">urn:percipere:${esc(title)}</dc:identifier>
    <dc:title>${esc(title)}</dc:title>
    <dc:creator>${esc(author)}</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
$manifest  </manifest>
  <spine>
$spine  </spine>
</package>'''),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Builds a small PDF with a text layer and, if [outline], a bookmark per
  /// chapter. Text must be plain ASCII (the built-in Helvetica font).
  static Uint8List pdf({
    required String title,
    required List<SampleChapter> chapters,
    bool outline = true,
  }) {
    // One page per chapter, up to ~40 wrapped lines each.
    final pages = <List<String>>[];
    for (final c in chapters) {
      final lines = <String>[c.title.toUpperCase(), ''];
      for (final para in c.paragraphs) {
        lines.addAll(_wrap(para, 78));
        lines.add('');
      }
      pages.add(lines.take(46).toList());
    }

    // Object numbers: 1 catalog, 2 pages, 3 font, [4 outlines + items],
    // then a page + content object per page.
    final outlineCount = outline ? 1 + chapters.length : 0;
    final firstPageObj = 4 + outlineCount;
    final objects = <int, String>{};
    objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
    final kids = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final pageObj = firstPageObj + i * 2;
      final contentObj = pageObj + 1;
      kids.add('$pageObj 0 R');
      final stream = StringBuffer('BT /F1 12 Tf 14 TL 50 750 Td\n');
      for (final line in pages[i]) {
        stream.writeln('(${_pdfEscape(line)}) Tj T*');
      }
      stream.write('ET');
      final length = stream.length;
      objects[pageObj] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /Font << /F1 3 0 R >> >> /Contents $contentObj 0 R >>';
      objects[contentObj] = '<< /Length $length >>\nstream\n$stream\nendstream';
    }
    objects[2] =
        '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>';
    if (outline) {
      objects[1] = '<< /Type /Catalog /Pages 2 0 R /Outlines 4 0 R >>';
      final first = 5;
      final last = 4 + chapters.length;
      objects[4] =
          '<< /Type /Outlines /First $first 0 R /Last $last 0 R '
          '/Count ${chapters.length} >>';
      for (var i = 0; i < chapters.length; i++) {
        final obj = 5 + i;
        final prev = i > 0 ? ' /Prev ${obj - 1} 0 R' : '';
        final next = i < chapters.length - 1 ? ' /Next ${obj + 1} 0 R' : '';
        objects[obj] =
            '<< /Title (${_pdfEscape(chapters[i].title)}) /Parent 4 0 R$prev$next '
            '/Dest [${firstPageObj + i * 2} 0 R /Fit] >>';
      }
    } else {
      objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    }

    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int, int>{};
    final maxObj = objects.keys.reduce((a, b) => a > b ? a : b);
    for (var n = 1; n <= maxObj; n++) {
      final body = objects[n];
      if (body == null) continue;
      offsets[n] = out.length;
      out.write('$n 0 obj\n$body\nendobj\n');
    }
    final xref = out.length;
    out.write('xref\n0 ${maxObj + 1}\n0000000000 65535 f \n');
    for (var n = 1; n <= maxObj; n++) {
      final o = offsets[n];
      out.write(
        o == null
            ? '0000000000 65535 f \n'
            : '${o.toString().padLeft(10, '0')} 00000 n \n',
      );
    }
    out.write(
      'trailer\n<< /Size ${maxObj + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF',
    );
    return Uint8List.fromList(latin1.encode(out.toString()));
  }

  static String _pdfEscape(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');

  static List<String> _wrap(String text, int width) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(' ')) {
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= width) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }
}
