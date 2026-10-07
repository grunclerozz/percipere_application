import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'library_models.dart';

/// Why an EPUB could not be read.
enum EpubProblem {
  /// Protected by DRM (Adobe, Apple, Kindle…).
  drm,

  /// Not a valid EPUB (bad zip, missing package, nothing to read).
  invalid,
}

/// Thrown when an EPUB cannot be read.
class EpubException implements Exception {
  /// Creates the exception.
  const EpubException(this.problem, [this.detail]);

  /// What is wrong.
  final EpubProblem problem;

  /// Technical detail, for logs only.
  final String? detail;

  @override
  String toString() =>
      'EpubException($problem${detail == null ? '' : ': $detail'})';
}

/// Where an image sits in the book text (kept for Phase 6E Part B).
@immutable
class BookImageRef {
  /// Creates an image record.
  const BookImageRef({
    required this.chapter,
    required this.paragraph,
    required this.src,
    this.alt,
    this.caption,
  });

  /// Chapter index (after empty chapters were dropped).
  final int chapter;

  /// The image comes before this paragraph of the chapter.
  final int paragraph;

  /// Path of the image inside the EPUB archive.
  final String src;

  /// The publisher's alt text, if any.
  final String? alt;

  /// The publisher's caption, if any.
  final String? caption;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'chapter': chapter,
    'paragraph': paragraph,
    'src': src,
    'alt': alt,
    'caption': caption,
  };

  /// Reads the JSON form.
  static BookImageRef fromJson(Map<String, Object?> j) => BookImageRef(
    chapter: j['chapter']! as int,
    paragraph: j['paragraph']! as int,
    src: j['src']! as String,
    alt: j['alt'] as String?,
    caption: j['caption'] as String?,
  );
}

/// The readable content of a book: chapters of text plus image positions.
@immutable
class BookText {
  /// Creates book text.
  const BookText(this.chapters, [this.images = const []]);

  /// Chapters in reading order.
  final List<ChapterText> chapters;

  /// Images, for Part B.
  final List<BookImageRef> images;

  /// The cache file format.
  String toJsonString() => jsonEncode({
    'v': 1,
    'chapters': [
      for (final c in chapters) {'title': c.title, 'text': c.text},
    ],
    'images': [for (final i in images) i.toJson()],
  });

  /// Reads the cache file format (also the older plain chapter list).
  static BookText fromJsonString(String raw) {
    final json = jsonDecode(raw);
    final chapterList = json is List ? json : (json as Map)['chapters'] as List;
    final imageList = json is Map
        ? (json['images'] as List? ?? const [])
        : const [];
    return BookText(
      [
        for (final c in chapterList)
          ChapterText((c as Map)['title']! as String, c['text']! as String),
      ],
      [
        for (final i in imageList)
          BookImageRef.fromJson((i as Map).cast<String, Object?>()),
      ],
    );
  }
}

/// A parsed EPUB.
@immutable
class EpubBook {
  /// Creates a parsed book.
  const EpubBook({
    required this.title,
    required this.author,
    required this.text,
  });

  /// Title from the package metadata.
  final String? title;

  /// Author from the package metadata.
  final String? author;

  /// Chapters and images.
  final BookText text;
}

/// Reads EPUB files: the OPF spine gives the chapter order, the table of
/// contents (EPUB 3 nav or EPUB 2 NCX) the chapter titles, and each XHTML
/// chapter is turned into plain paragraphs without markup, scripts or styles.
/// Images are skipped, but their positions are recorded.
abstract final class EpubParser {
  static const Set<String> _fontObfuscation = {
    'http://www.idpf.org/2008/embedding',
    'http://ns.adobe.com/pdf/enc#RC',
  };

  static const Set<String> _blocks = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'ul',
    'ol',
    'blockquote',
    'section',
    'article',
    'tr',
    'table',
    'pre',
    'figure',
    'figcaption',
    'dd',
    'dt',
    'dl',
    'header',
    'footer',
    'aside',
    'body',
  };

  /// Parses [bytes]. [fallbackTitle] names chapters that have no title
  /// (1-based number). Throws [EpubException].
  static EpubBook parse(
    Uint8List bytes, {
    String Function(int number)? fallbackTitle,
  }) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (e) {
      throw EpubException(EpubProblem.invalid, 'zip: $e');
    }
    final files = {
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };

    _checkDrm(files);

    final container = _xml(files, 'META-INF/container.xml');
    final rootfile = container?.findAllElements('rootfile').firstOrNull;
    final opfPath = rootfile?.getAttribute('full-path');
    if (opfPath == null) {
      throw const EpubException(EpubProblem.invalid, 'no package');
    }
    final opf = _xml(files, opfPath);
    if (opf == null) {
      throw const EpubException(EpubProblem.invalid, 'unreadable package');
    }
    final opfDir = p.posix.dirname(opfPath);
    String resolve(String base, String href) {
      final clean = Uri.decodeFull(href.split('#').first);
      final joined = base == '.' ? clean : p.posix.join(base, clean);
      return p.posix.normalize(joined);
    }

    // Manifest and spine.
    final manifest = <String, XmlElement>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      if (id != null) manifest[id] = item;
    }
    final spineElement = opf.findAllElements('spine').firstOrNull;
    final spine = <String>[
      for (final ref
          in spineElement?.findElements('itemref') ?? const <XmlElement>[])
        if (ref.getAttribute('idref') != null) ref.getAttribute('idref')!,
    ];
    if (spine.isEmpty) {
      throw const EpubException(EpubProblem.invalid, 'empty spine');
    }

    // Chapter titles from the table of contents.
    final titles = _tableOfContents(
      files,
      manifest,
      spineElement,
      opfDir,
      resolve,
    );

    final title = opf
        .findAllElements('title', namespaceUri: '*')
        .firstOrNull
        ?.innerText
        .trim();
    final author = opf
        .findAllElements('creator', namespaceUri: '*')
        .firstOrNull
        ?.innerText
        .trim();

    final chapters = <ChapterText>[];
    final images = <BookImageRef>[];
    for (final id in spine) {
      final item = manifest[id];
      final href = item?.getAttribute('href');
      if (item == null || href == null) continue;
      final type = item.getAttribute('media-type') ?? '';
      if (!type.contains('html') && !type.contains('xml')) continue;
      final path = resolve(opfDir, href);
      final file = files[path];
      if (file == null) continue;
      final extracted = _chapter(
        utf8.decode(file.content as List<int>, allowMalformed: true),
        p.posix.dirname(path),
      );
      if (extracted.paragraphs.isEmpty) continue;
      final index = chapters.length;
      final chapterTitle =
          titles[path] ??
          extracted.heading ??
          (fallbackTitle ?? (n) => 'Chapter $n')(index + 1);
      chapters.add(
        ChapterText(chapterTitle, extracted.paragraphs.join('\n\n')),
      );
      for (final img in extracted.images) {
        images.add(
          BookImageRef(
            chapter: index,
            paragraph: img.paragraph,
            src: img.src,
            alt: img.alt,
            caption: img.caption,
          ),
        );
      }
    }
    if (chapters.isEmpty) {
      throw const EpubException(EpubProblem.invalid, 'no text');
    }
    return EpubBook(
      title: title == null || title.isEmpty ? null : title,
      author: author == null || author.isEmpty ? null : author,
      text: BookText(chapters, images),
    );
  }

  static void _checkDrm(Map<String, ArchiveFile> files) {
    if (files.containsKey('META-INF/rights.xml') ||
        files.keys.any((k) => k.toLowerCase().endsWith('sinf.xml'))) {
      throw const EpubException(EpubProblem.drm, 'rights');
    }
    final enc = _xml(files, 'META-INF/encryption.xml');
    if (enc == null) return;
    for (final method in enc.findAllElements('EncryptionMethod')) {
      final algorithm = method.getAttribute('Algorithm');
      if (algorithm != null && !_fontObfuscation.contains(algorithm)) {
        throw EpubException(EpubProblem.drm, algorithm);
      }
    }
  }

  static XmlDocument? _xml(Map<String, ArchiveFile> files, String path) {
    final file = files[path];
    if (file == null) return null;
    try {
      return XmlDocument.parse(
        utf8.decode(file.content as List<int>, allowMalformed: true),
      );
    } on Object {
      return null;
    }
  }

  /// Archive path of a chapter file -> its title in the table of contents.
  static Map<String, String> _tableOfContents(
    Map<String, ArchiveFile> files,
    Map<String, XmlElement> manifest,
    XmlElement? spine,
    String opfDir,
    String Function(String base, String href) resolve,
  ) {
    final titles = <String, String>{};
    void add(String base, String? href, String text) {
      final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (href == null || clean.isEmpty) return;
      titles.putIfAbsent(resolve(base, href), () => clean);
    }

    // EPUB 3 navigation document.
    final navItem = manifest.values
        .where(
          (e) =>
              (e.getAttribute('properties') ?? '').split(' ').contains('nav'),
        )
        .firstOrNull;
    if (navItem != null) {
      final navPath = resolve(opfDir, navItem.getAttribute('href') ?? '');
      final nav = _xml(files, navPath);
      if (nav != null) {
        final navDir = p.posix.dirname(navPath);
        final tocNav =
            nav
                .findAllElements('nav')
                .where(
                  (n) => n.attributes.any(
                    (a) => a.name.local == 'type' && a.value.contains('toc'),
                  ),
                )
                .firstOrNull ??
            nav.findAllElements('nav').firstOrNull;
        for (final a in tocNav?.findAllElements('a') ?? const <XmlElement>[]) {
          add(navDir, a.getAttribute('href'), a.innerText);
        }
      }
    }
    if (titles.isNotEmpty) return titles;

    // EPUB 2 NCX.
    final ncxId = spine?.getAttribute('toc');
    final ncxItem =
        manifest[ncxId] ??
        manifest.values
            .where(
              (e) => e.getAttribute('media-type') == 'application/x-dtbncx+xml',
            )
            .firstOrNull;
    final ncxPath = ncxItem?.getAttribute('href');
    if (ncxPath != null) {
      final path = resolve(opfDir, ncxPath);
      final ncx = _xml(files, path);
      final ncxDir = p.posix.dirname(path);
      for (final point
          in ncx?.findAllElements('navPoint') ?? const <XmlElement>[]) {
        final label =
            point.findElements('navLabel').firstOrNull?.innerText ?? '';
        final src = point
            .findElements('content')
            .firstOrNull
            ?.getAttribute('src');
        add(ncxDir, src, label);
      }
    }
    return titles;
  }

  static _Extracted _chapter(String xhtml, String dir) {
    XmlDocument doc;
    try {
      doc = XmlDocument.parse(xhtml);
    } on Object {
      // Sloppy HTML: strip tags the blunt way, keep paragraphs.
      final text = xhtml
          .replaceAll(
            RegExp(
              r'<(script|style)[^>]*>.*?</\1>',
              dotAll: true,
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(
            RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false),
            '\n\n',
          )
          .replaceAll(RegExp(r'<[^>]+>'), ' ');
      return _Extracted(
        [
          for (final para in text.split(RegExp(r'\n\s*\n')))
            if (para.replaceAll(RegExp(r'\s+'), ' ').trim().isNotEmpty)
              para.replaceAll(RegExp(r'\s+'), ' ').trim(),
        ],
        null,
        const [],
      );
    }
    final paragraphs = <String>[];
    final images = <_Image>[];
    final current = StringBuffer();
    String? heading;
    _Image? figureImage;

    void flush() {
      final text = current.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      current.clear();
      if (text.isNotEmpty) paragraphs.add(text);
    }

    void walk(XmlNode node, {bool inHeading = false, bool inCaption = false}) {
      if (node is XmlText) {
        current.write(node.value);
        return;
      }
      if (node is! XmlElement) {
        for (final c in node.children) {
          walk(c, inHeading: inHeading, inCaption: inCaption);
        }
        return;
      }
      final name = node.name.local.toLowerCase();
      if (name == 'script' ||
          name == 'style' ||
          name == 'head' ||
          name == 'svg' && node.findAllElements('image').isEmpty) {
        return;
      }
      if (name == 'img' || name == 'image') {
        flush();
        final src =
            node.getAttribute('src') ??
            node.getAttribute('href') ??
            node.attributes
                .where((a) => a.name.local == 'href')
                .firstOrNull
                ?.value;
        if (src != null && !src.startsWith('data:')) {
          final alt = node.getAttribute('alt')?.trim();
          figureImage = _Image(
            paragraphs.length,
            p.posix.normalize(
              p.posix.join(dir == '.' ? '' : dir, Uri.decodeFull(src)),
            ),
            alt == null || alt.isEmpty ? null : alt,
          );
          images.add(figureImage!);
        }
        return;
      }
      if (name == 'br') {
        current.write(' ');
        return;
      }
      final block = _blocks.contains(name);
      if (block) flush();
      final isHeading = RegExp(r'^h[1-6]$').hasMatch(name);
      final isCaption = name == 'figcaption';
      if (name == 'figure') figureImage = null;
      for (final c in node.children) {
        walk(
          c,
          inHeading: inHeading || isHeading,
          inCaption: inCaption || isCaption,
        );
      }
      if (block) {
        final text = current.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (isHeading && heading == null && text.isNotEmpty) heading = text;
        if (isCaption && figureImage != null && text.isNotEmpty) {
          final i = images.indexOf(figureImage!);
          images[i] = _Image(
            figureImage!.paragraph,
            figureImage!.src,
            figureImage!.alt,
            text,
          );
        }
        flush();
      }
    }

    final body = doc.findAllElements('body').firstOrNull ?? doc.rootElement;
    walk(body);
    flush();
    return _Extracted(paragraphs, heading, images);
  }
}

class _Image {
  const _Image(this.paragraph, this.src, this.alt, [this.caption]);
  final int paragraph;
  final String src;
  final String? alt;
  final String? caption;
}

class _Extracted {
  const _Extracted(this.paragraphs, this.heading, this.images);
  final List<String> paragraphs;
  final String? heading;
  final List<_Image> images;
}
