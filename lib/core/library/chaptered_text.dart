import 'package:flutter/foundation.dart';

import '../tts/chunker.dart';
import 'library_models.dart';

/// The whole text of an item laid out for the Reader: one string, its
/// sentences, and where each chapter starts.
///
/// Chapters are separated by a blank line, so no sentence runs across a
/// chapter. A one-chapter document is exactly its own text.
@immutable
class ChapteredText {
  /// Creates a layout.
  const ChapteredText({
    required this.text,
    required this.sentences,
    required this.chapterStarts,
    required this.chapterTitles,
  });

  /// All chapters joined.
  final String text;

  /// Sentences of [text].
  final List<Sentence> sentences;

  /// Index of the first sentence of each chapter.
  final List<int> chapterStarts;

  /// Chapter titles, parallel to [chapterStarts].
  final List<String> chapterTitles;

  /// Whether there is more than one chapter to move between.
  bool get hasChapters => chapterStarts.length > 1;

  /// Sentences per chapter, for progress.
  List<ChapterInfo> get info => [
    for (var i = 0; i < chapterStarts.length; i++)
      ChapterInfo(
        chapterTitles[i],
        (i + 1 < chapterStarts.length
                ? chapterStarts[i + 1]
                : sentences.length) -
            chapterStarts[i],
      ),
  ];

  /// Words in [text].
  int get wordCount => countWords(text);

  /// Chapter that sentence [index] belongs to.
  int chapterOf(int index) {
    var chapter = 0;
    for (var i = 0; i < chapterStarts.length; i++) {
      if (chapterStarts[i] <= index) chapter = i;
    }
    return chapter;
  }

  /// Sentence index counted inside its chapter.
  int inChapter(int index) => index - chapterStarts[chapterOf(index)];

  /// Global sentence index of [sentence] in [chapter], clamped to the text.
  int globalOf(int chapter, int sentence) {
    if (chapterStarts.isEmpty) return 0;
    final c = chapter.clamp(0, chapterStarts.length - 1);
    final end = c + 1 < chapterStarts.length
        ? chapterStarts[c + 1]
        : sentences.length;
    return (chapterStarts[c] + sentence).clamp(chapterStarts[c], end - 1);
  }

  /// Lays out [chapters]; empty chapters are dropped.
  static ChapteredText build(List<ChapterText> chapters) {
    final buffer = StringBuffer();
    final sentences = <Sentence>[];
    final starts = <int>[];
    final titles = <String>[];
    var paragraphs = 0;
    for (final chapter in chapters) {
      final parts = chunkText(chapter.text);
      if (parts.isEmpty) continue;
      final offset = buffer.length;
      buffer.write(chapter.text);
      starts.add(sentences.length);
      titles.add(chapter.title);
      for (final s in parts) {
        sentences.add(
          Sentence(s.start + offset, s.end + offset, s.paragraph + paragraphs),
        );
      }
      paragraphs += parts.last.paragraph + 1;
      buffer.write('\n\n');
    }
    final text = buffer.toString().trimRight();
    return ChapteredText(
      text: text,
      sentences: sentences,
      chapterStarts: starts,
      chapterTitles: titles,
    );
  }

  /// [build] for long books, in a background isolate.
  static Future<ChapteredText> buildAsync(List<ChapterText> chapters) {
    final size = chapters.fold<int>(0, (n, c) => n + c.text.length);
    if (size < 60000) return Future.value(build(chapters));
    return compute(_buildFromPairs, [
      for (final c in chapters) (c.title, c.text),
    ]);
  }
}

ChapteredText _buildFromPairs(List<(String, String)> pairs) =>
    ChapteredText.build([for (final (t, x) in pairs) ChapterText(t, x)]);

/// Number of whitespace-separated words in [text].
int countWords(String text) => RegExp(r'\S+').allMatches(text).length;

/// The first few words of a sentence, for a favorite's label.
String favoriteLabel(String sentence, {int words = 8}) {
  final parts = sentence.trim().split(RegExp(r'\s+'));
  if (parts.length <= words) return parts.join(' ');
  return '${parts.take(words).join(' ')}…';
}
