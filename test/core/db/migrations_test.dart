import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/app_database.dart';
import 'package:percipere_app/core/db/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
  });

  tearDown(() => database.close());

  test('migration versions are contiguous from 1', () {
    for (var i = 0; i < Migrations.all.length; i++) {
      expect(Migrations.all[i].version, i + 1);
    }
  });

  test('fresh database is at the latest version with all tables', () async {
    expect(await database.db.getVersion(), Migrations.latestVersion);

    final rows = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name <> 'android_metadata'",
    );
    expect(rows.map((r) => r['name']).toSet(), {
      'users',
      'preferences',
      'documents',
      'usage_logs',
      'outbox',
      'sus_responses',
      'wer_results',
    });
  });

  test('foreign keys are enforced and cascade', () async {
    final db = database.db;
    const now = 1700000000000;
    await db.insert('users', {
      'id': 'u1',
      'display_name': 'Ana',
      'secret_hash': 'h',
      'secret_salt': 's',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('documents', {
      'user_id': 'u1',
      'title': 'Liham',
      'full_text': 'Magandang araw.',
      'source_type': 'camera',
      'created_at': now,
      'updated_at': now,
    });

    await expectLater(
      db.insert('documents', {
        'user_id': 'missing',
        'title': 'x',
        'full_text': 'x',
        'source_type': 'pdf',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );

    await db.delete('users', where: 'id = ?', whereArgs: ['u1']);
    expect(await db.query('documents'), isEmpty);
  });

  test('check constraints reject invalid enum values', () async {
    const now = 1700000000000;
    await expectLater(
      database.db.insert('documents', {
        'title': 'x',
        'full_text': 'x',
        'source_type': 'fax',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.db.insert('outbox', {
        'type': 'report',
        'payload': '{}',
        'status': 'lost',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('outbox rows default to pending with zero attempts', () async {
    const now = 1700000000000;
    final id = await database.db.insert('outbox', {
      'type': 'feedback',
      'payload': '{"message":"ok"}',
      'created_at': now,
      'updated_at': now,
    });
    final row = (await database.db.query(
      'outbox',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['status'], 'pending');
    expect(row['attempts'], 0);
  });
}
