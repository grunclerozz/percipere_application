import 'dart:io';

import 'package:percipere_app/core/db/daos/library_dao.dart';
import 'package:percipere_app/core/library/catalog_book.dart';
import 'package:percipere_app/core/library/chaptered_text.dart';
import 'package:percipere_app/core/library/epub_parser.dart';
import 'package:percipere_app/core/library/library_models.dart';

import 'fakes.dart';

/// Adds a document of the user's own to the Library, optionally half read
/// (resume at sentence [position]). Call inside `tester.runAsync`.
Future<LibraryItem> seedDocument(
  TestEnv env, {
  required String title,
  required String text,
  LibrarySource source = LibrarySource.upload,
  LibraryFormat format = LibraryFormat.docx,
  int position = 0,
  String language = 'fil',
}) async {
  final dao = LibraryDao(env.database.db);
  final layout = ChapteredText.build([ChapterText(title, text)]);
  final item = await dao.insertDocument(
    title: title,
    fullText: text,
    source: source,
    format: format,
    language: language,
    userId: env.account?.id,
    totalSentences: layout.sentences.length,
    wordCount: layout.wordCount,
  );
  if (position > 0) {
    await dao.updateProgress(
      item.id,
      chapterIndex: 0,
      sentenceIndex: position,
      globalSentence: position,
    );
  }
  return (await dao.get(item.id))!;
}

/// Adds a catalog book with its text already cached, as if it had been read
/// online once. Chapters are `(title, text)`.
Future<LibraryItem> seedBook(
  TestEnv env, {
  String bookId = 'bk-test',
  String title = 'Aklat',
  required List<ChapterText> chapters,
  bool downloaded = false,
}) async {
  final dao = LibraryDao(env.database.db);
  final userId = env.account?.id;
  await dao.syncCatalog(userId, [
    CatalogBook(
      id: bookId,
      title: title,
      author: 'May-akda',
      language: 'fil',
      category: 'Nobela',
      description: 'Isang aklat.',
      format: LibraryFormat.epub,
      fileSize: 4096,
      version: 1,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    ),
  ]);
  final item = (await dao.getBook(userId, bookId))!;
  final layout = ChapteredText.build(chapters);
  final path = '${env.libraryPaths.root.path}/${item.id}.json';
  File(path).writeAsStringSync(BookText(chapters).toJsonString());
  await dao.setTextCache(
    item.id,
    textPath: path,
    chapters: layout.info,
    totalSentences: layout.sentences.length,
    wordCount: layout.wordCount,
  );
  if (downloaded) {
    await dao.setDownloaded(
      item.id,
      filePath: '${env.libraryPaths.root.path}/$bookId.epub',
      version: 1,
      textPath: path,
    );
  }
  return (await dao.get(item.id))!;
}

/// Three chapters of three sentences each.
const List<ChapterText> threeChapters = [
  ChapterText('Unang Kabanata', 'Isa. Dalawa. Tatlo.'),
  ChapterText('Ikalawang Kabanata', 'Apat. Lima. Anim.'),
  ChapterText('Ikatlong Kabanata', 'Pito. Walo. Siyam.'),
];
