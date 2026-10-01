import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// The app's single SQLite database.
///
/// Opening runs [Migrations] to bring the schema to
/// [Migrations.latestVersion]. DAOs (added per feature phase) take an
/// [AppDatabase] and use [db].
class AppDatabase {
  AppDatabase._(this.db);

  /// File name inside the platform databases directory.
  static const String fileName = 'percipere.db';

  /// The raw sqflite handle, for DAOs.
  final Database db;

  /// Opens (creating/migrating as needed) the database.
  ///
  /// Tests pass `databaseFactoryFfi` as [factory], `inMemoryDatabasePath` as
  /// [path] and `singleInstance: false` (otherwise every in-memory open
  /// shares one database).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    bool singleInstance = true,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: Migrations.latestVersion,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => Migrations.migrate(db, 0, version),
        onUpgrade: Migrations.migrate,
      ),
    );
    return AppDatabase._(db);
  }

  /// Closes the database.
  Future<void> close() => db.close();
}

/// The opened database, shared app-wide. Opened once in `bootstrap()` and
/// provided by override.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider is set in bootstrap'),
);
