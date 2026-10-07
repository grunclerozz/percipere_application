import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the Library keeps its files (all in the app's private storage).
abstract interface class LibraryPaths {
  /// Downloaded books (kept until the user removes them).
  Future<Directory> books();

  /// Extracted text of downloaded books.
  Future<Directory> texts();

  /// Book covers.
  Future<Directory> covers();

  /// Temporary files: books read online and their text. May be cleared by
  /// Android at any time.
  Future<Directory> cache();
}

/// [LibraryPaths] under the app's support and cache directories.
class DeviceLibraryPaths implements LibraryPaths {
  /// Creates the device paths.
  const DeviceLibraryPaths();

  Future<Directory> _sub(Directory base, String name) =>
      Directory(p.join(base.path, 'library', name)).create(recursive: true);

  @override
  Future<Directory> books() async =>
      _sub(await getApplicationSupportDirectory(), 'books');

  @override
  Future<Directory> texts() async =>
      _sub(await getApplicationSupportDirectory(), 'texts');

  @override
  Future<Directory> covers() async =>
      _sub(await getApplicationSupportDirectory(), 'covers');

  @override
  Future<Directory> cache() async =>
      _sub(await getTemporaryDirectory(), 'cache');
}

/// The Library's folders; overridden in tests with a temporary directory.
final libraryPathsProvider = Provider<LibraryPaths>(
  (ref) => const DeviceLibraryPaths(),
);
