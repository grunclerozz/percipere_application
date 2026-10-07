import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Where a library item came from.
enum LibrarySource {
  /// Photographed with the camera.
  camera,

  /// Uploaded from the phone (image, PDF, DOCX).
  upload,

  /// A saved Maglarawan description.
  description,

  /// An admin book from the web app.
  book;

  /// Parses the stored name.
  static LibrarySource parse(String name) => LibrarySource.values.firstWhere(
    (s) => s.name == name,
    orElse: () => LibrarySource.upload,
  );
}

/// File format of a library item.
enum LibraryFormat {
  /// Text read from a photo or image (or a description).
  image,

  /// PDF.
  pdf,

  /// Word document.
  docx,

  /// EPUB book.
  epub;

  /// Parses the stored name.
  static LibraryFormat parse(String name) => LibraryFormat.values.firstWhere(
    (s) => s.name == name,
    orElse: () => LibraryFormat.image,
  );
}

/// One chapter of an item: its title and how many sentences it has.
@immutable
class ChapterInfo {
  /// Creates a chapter.
  const ChapterInfo(this.title, this.sentences);

  /// Chapter title.
  final String title;

  /// Sentence count, for progress.
  final int sentences;

  /// JSON form.
  Map<String, Object?> toJson() => {'t': title, 'n': sentences};

  /// Reads the JSON form.
  static ChapterInfo fromJson(Map<String, Object?> j) =>
      ChapterInfo(j['t']! as String, j['n']! as int);

  /// Encodes a chapter list for the database.
  static String encode(List<ChapterInfo> chapters) =>
      jsonEncode([for (final c in chapters) c.toJson()]);

  /// Decodes a stored chapter list (empty for null or bad data).
  static List<ChapterInfo> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List<dynamic>)
          fromJson((e as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChapterInfo &&
      other.title == title &&
      other.sentences == sentences;

  @override
  int get hashCode => Object.hash(title, sentences);
}

/// A shelf item: an own document or an admin book. The text itself is not
/// loaded with the item (see `LibraryDao.loadText`).
@immutable
class LibraryItem {
  /// Creates an item.
  const LibraryItem({
    required this.id,
    required this.source,
    required this.format,
    required this.language,
    required this.title,
    required this.createdAt,
    this.userId,
    this.author,
    this.coverPath,
    this.filePath,
    this.textRef = 'db',
    this.textPath,
    this.chapters = const [],
    this.totalSentences,
    this.wordCount,
    this.chapterIndex = 0,
    this.sentenceIndex = 0,
    this.percent = 0,
    this.finished = false,
    this.lastOpenedAt,
    this.bookId,
    this.bookVersion,
    this.remoteVersion,
    this.category,
    this.description,
    this.coverUrl,
    this.fileSize,
    this.downloaded = false,
    this.isNew = false,
    this.unavailable = false,
    this.localOnly = false,
  });

  /// UUID.
  final String id;

  /// Owner (account or guest id); null before any account existed.
  final String? userId;

  /// Where it came from.
  final LibrarySource source;

  /// File format.
  final LibraryFormat format;

  /// `fil` or `en`.
  final String language;

  /// Title (renamable for own documents).
  final String title;

  /// Author (books).
  final String? author;

  /// Cover/thumbnail file in private storage.
  final String? coverPath;

  /// The downloaded/cached book file.
  final String? filePath;

  /// `db` (text in the database) or `file` (JSON in [textPath]).
  final String textRef;

  /// Text cache file when [textRef] is `file`.
  final String? textPath;

  /// Chapters; empty means one unnamed chapter.
  final List<ChapterInfo> chapters;

  /// Sentences in the whole item; null until counted.
  final int? totalSentences;

  /// Words in the whole item, for the reading-time estimate.
  final int? wordCount;

  /// Resume chapter.
  final int chapterIndex;

  /// Resume sentence, counted inside the chapter.
  final int sentenceIndex;

  /// Progress 0..100.
  final double percent;

  /// Whether the last sentence was read.
  final bool finished;

  /// When it was last opened.
  final DateTime? lastOpenedAt;

  /// When it was added.
  final DateTime createdAt;

  /// Catalog id (books).
  final String? bookId;

  /// Version of the downloaded file.
  final int? bookVersion;

  /// Latest version in the catalog.
  final int? remoteVersion;

  /// Catalog category.
  final String? category;

  /// Short description (books).
  final String? description;

  /// Cover URL on the web app.
  final String? coverUrl;

  /// File size in bytes (books).
  final int? fileSize;

  /// Whether the book file is saved for offline reading.
  final bool downloaded;

  /// Added to the catalog since the user last looked ("Bago").
  final bool isNew;

  /// Removed from the catalog by the admin.
  final bool unavailable;

  /// Never leaves the device (own documents).
  final bool localOnly;

  /// Whether this is an admin book.
  bool get isBook => source == LibrarySource.book;

  /// Started but not finished.
  bool get inProgress =>
      !finished && (percent > 0 || chapterIndex > 0 || sentenceIndex > 0);

  /// A downloaded book whose catalog version is newer.
  bool get updateAvailable =>
      downloaded &&
      bookVersion != null &&
      remoteVersion != null &&
      remoteVersion! > bookVersion!;

  /// Position counted over the whole item (sentences in earlier chapters plus
  /// the sentence in this one).
  int get globalSentence {
    var n = sentenceIndex;
    for (var i = 0; i < chapterIndex && i < chapters.length; i++) {
      n += chapters[i].sentences;
    }
    return n;
  }
}

/// A saved spot inside an item.
@immutable
class Favorite {
  /// Creates a favorite.
  const Favorite({
    required this.id,
    required this.itemId,
    required this.chapterIndex,
    required this.sentenceIndex,
    required this.label,
    required this.createdAt,
  });

  /// UUID.
  final String id;

  /// The item it belongs to.
  final String itemId;

  /// Chapter of the spot.
  final int chapterIndex;

  /// Sentence of the spot, inside the chapter.
  final int sentenceIndex;

  /// First words of the sentence.
  final String label;

  /// When it was saved.
  final DateTime createdAt;
}

/// A user-made group of items.
@immutable
class LibraryCollection {
  /// Creates a collection.
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.itemCount,
  });

  /// UUID.
  final String id;

  /// Name.
  final String name;

  /// How many items it holds.
  final int itemCount;
}

/// One chapter's text.
@immutable
class ChapterText {
  /// Creates chapter text.
  const ChapterText(this.title, this.text);

  /// Chapter title.
  final String title;

  /// Clean text, paragraphs separated by a blank line.
  final String text;
}
