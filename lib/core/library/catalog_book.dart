import 'package:flutter/foundation.dart';

import 'library_models.dart';

/// A book in the web app's catalog (see `docs/api-contract.md`).
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
  });

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
