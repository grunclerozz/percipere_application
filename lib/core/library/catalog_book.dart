import 'package:flutter/foundation.dart';

import 'library_models.dart';

/// A book in the web app's catalog (`GET /api/v1/books`, see
/// `docs/api-contract.md`).
@immutable
class CatalogBook {
  /// Creates a catalog entry.
  const CatalogBook({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.category,
    required this.description,
    required this.format,
    required this.fileSize,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.coverUrl,
    this.active = true,
    this.checksum,
  });

  /// Reads one book of the API's reply.
  ///
  /// The server hides books an admin switched off, so every book it lists is
  /// active. Ids are numbers there and text here. `language` becomes `en` or
  /// `fil`, the two reading voices (a book in another language is read with
  /// the Filipino voice).
  factory CatalogBook.fromApi(Map<String, dynamic> json) {
    final language = json['language'];
    final category = json['category'];
    final code = language is Map
        ? '${language['code'] ?? ''}'.toLowerCase()
        : '';
    final name = language is Map
        ? '${language['name'] ?? ''}'.toLowerCase()
        : '';
    final format = '${json['format']}'.toLowerCase();
    return CatalogBook(
      id: '${json['id']}',
      title: (json['title'] as String?) ?? '',
      author: (json['author'] as String?) ?? '',
      language: code.startsWith('en') || name.contains('english')
          ? 'en'
          : 'fil',
      category: category is Map ? '${category['name'] ?? ''}' : '',
      description: (json['description'] as String?) ?? '',
      format: format == 'epub' ? LibraryFormat.epub : LibraryFormat.pdf,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
      coverUrl: json['cover_url'] as String?,
      checksum: _sha256Of(json['checksum']),
    );
  }

  /// The hex SHA-256 from `sha256:<hex>`, or null.
  static String? _sha256Of(Object? value) {
    final m = RegExp(r'^sha256:([0-9a-f]{64})$')
        .firstMatch('$value'.toLowerCase());
    return m?.group(1);
  }

  /// Server id.
  final String id;

  /// Title.
  final String title;

  /// Author.
  final String author;

  /// `fil` or `en`.
  final String language;

  /// Category name.
  final String category;

  /// Short description.
  final String description;

  /// `pdf` or `epub`.
  final LibraryFormat format;

  /// File size in bytes.
  final int fileSize;

  /// Increases whenever the admin replaces the file.
  final int version;

  /// When the admin added it.
  final DateTime createdAt;

  /// When it last changed.
  final DateTime updatedAt;

  /// Cover image URL, if any.
  final String? coverUrl;

  /// False once the admin removed it.
  final bool active;

  /// SHA-256 of the file (lowercase hex), to check a download. Null when the
  /// server did not say.
  final String? checksum;
}

/// What a catalog refresh changed for one user.
@immutable
class CatalogDiff {
  /// Creates a diff.
  const CatalogDiff({
    this.added = const [],
    this.removed = const [],
    this.updated = const [],
  });

  /// Titles of books new to this user.
  final List<String> added;

  /// Titles of books the admin removed.
  final List<String> removed;

  /// Titles of downloaded books with a newer version.
  final List<String> updated;

  /// Nothing changed.
  bool get isEmpty => added.isEmpty && removed.isEmpty && updated.isEmpty;
}
