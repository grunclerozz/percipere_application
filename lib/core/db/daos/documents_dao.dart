import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// A Reading History entry.
@immutable
class DocumentRecord {
  /// Creates a record.
  const DocumentRecord({
    required this.id,
    required this.title,
    required this.fullText,
    required this.sourceType,
    required this.language,
    required this.createdAt,
    required this.lastPosition,
    this.thumbnailPath,
    this.lastOpenedAt,
  });

  /// Row id.
  final int id;

  /// Title (first line by default; renamable).
  final String title;

  /// Clean document text.
  final String fullText;

  /// `camera`, `image`, `pdf`, `docx` or `description` (Maglarawan).
  final String sourceType;

  /// `fil` or `en`.
  final String language;

  /// When it was first read.
  final DateTime createdAt;

  /// When it was last opened, if ever reopened.
  final DateTime? lastOpenedAt;

  /// Thumbnail file of a described image (`description` only).
  final String? thumbnailPath;

  /// Sentence index to resume from.
  final int lastPosition;

  static DocumentRecord _from(Map<String, Object?> r) => DocumentRecord(
    id: r['id']! as int,
    title: r['title']! as String,
    fullText: r['full_text']! as String,
    sourceType: r['source_type']! as String,
    language: r['language']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    lastOpenedAt: r['last_opened_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r['last_opened_at']! as int),
    lastPosition: r['last_position']! as int,
    thumbnailPath: r['thumbnail_path'] as String?,
  );
}

/// Reads and writes Reading History (`documents` table).
class DocumentsDao {
  /// Creates the DAO.
  DocumentsDao(this._db);

  final DatabaseExecutor _db;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Saves a newly read document; returns its id.
  Future<int> insert({
    required String title,
    required String fullText,
    required String sourceType,
    required String language,
    String? userId,
    String? thumbnailPath,
  }) {
    final now = _now;
    return _db.insert('documents', {
      'user_id': userId,
      'thumbnail_path': thumbnailPath,
      'title': title,
      'full_text': fullText,
      'source_type': sourceType,
      'language': language,
      'created_at': now,
      'updated_at': now,
      'last_position': 0,
    });
  }

  /// Loads one document, or null.
  Future<DocumentRecord?> get(int id) async {
    final rows = await _db.query('documents', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DocumentRecord._from(rows.single);
  }

  /// [userId]'s documents, newest first; [query] filters by title or text.
  Future<List<DocumentRecord>> list({String? userId, String? query}) async {
    final q = query?.trim();
    final search = q != null && q.isNotEmpty;
    final rows = await _db.query(
      'documents',
      where: search
          ? 'user_id IS ? AND (title LIKE ? OR full_text LIKE ?)'
          : 'user_id IS ?',
      whereArgs: search ? [userId, '%$q%', '%$q%'] : [userId],
      orderBy: 'COALESCE(last_opened_at, created_at) DESC, id DESC',
    );
    return rows.map(DocumentRecord._from).toList();
  }

  /// Stores the resume position.
  Future<void> updatePosition(int id, int position) => _db.update(
    'documents',
    {'last_position': position, 'updated_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Replaces the text of a saved description (a detailed one arrived).
  Future<void> updateText(int id, String fullText) => _db.update(
    'documents',
    {'full_text': fullText, 'updated_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Records that the document was reopened.
  Future<void> markOpened(int id) => _db.update(
    'documents',
    {'last_opened_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Renames a document.
  Future<void> rename(int id, String title) => _db.update(
    'documents',
    {'title': title, 'updated_at': _now},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Deletes a document.
  Future<void> delete(int id) =>
      _db.delete('documents', where: 'id = ?', whereArgs: [id]);
}

/// Reading History access.
final documentsDaoProvider = Provider<DocumentsDao>(
  (ref) => DocumentsDao(ref.watch(appDatabaseProvider).db),
);
