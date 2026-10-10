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
      'documents_legacy',
      'library_items',
      'library_favorites',
      'library_collections',
      'library_collection_items',
      'usage_logs',
      'outbox',
      'sus_responses',
      'wer_results',
      'login_attempts',
      'percy_turns',
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
    Map<String, Object?> item(String id, String? user, String source) => {
      'id': id,
      'user_id': user,
      'source': source,
      'format': 'pdf',
      'title': 'Liham',
      'full_text': 'Magandang araw.',
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('library_items', item('i1', 'u1', 'camera'));
    await db.insert('library_favorites', {
      'id': 'f1',
      'item_id': 'i1',
      'sentence_index': 0,
      'label': 'Magandang',
      'created_at': now,
      'updated_at': now,
    });

    await expectLater(
      db.insert('library_items', item('i2', 'missing', 'upload')),
      throwsA(isA<DatabaseException>()),
    );

    await db.delete('users', where: 'id = ?', whereArgs: ['u1']);
    expect(await db.query('library_items'), isEmpty);
    expect(await db.query('library_favorites'), isEmpty);
  });

  test('check constraints reject invalid enum values', () async {
    const now = 1700000000000;
    await expectLater(
      database.db.insert('library_items', {
        'id': 'x',
        'title': 'x',
        'source': 'fax',
        'format': 'pdf',
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

  test('v1 → v2: PIN accounts become legacy, history follows the logged-in '
      'profile, emails are unique', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, _) => Migrations.migrate(db, 0, 1),
      ),
    );
    addTearDown(db.close);
    const now = 1700000000000;
    for (final id in ['u1', 'u2']) {
      await db.insert('users', {
        'id': id,
        'display_name': id == 'u1' ? 'Ana' : 'Ben',
        'email': 'same@example.com',
        'secret_hash': 'h',
        'secret_salt': 's',
        'remote_id': id == 'u1' ? 'r1' : null,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.insert('preferences', {
      'user_id': 'device',
      'key': 'account.currentUser',
      'value': '"u1"',
      'updated_at': now,
    });
    await db.insert('documents', {
      'title': 'Liham',
      'full_text': 'Magandang araw.',
      'source_type': 'camera',
      'created_at': now,
      'updated_at': now,
    });

    await db.transaction((txn) => Migrations.migrate(txn, 1, 2));

    final ana = (await db.query(
      'users',
      where: 'id = ?',
      whereArgs: ['u1'],
    )).single;
    expect(ana['secret_kind'], 'pin');
    expect(ana['first_name'], 'Ana');
    expect(ana['server_id'], 'r1');
    expect(ana['email'], isNull, reason: 'set again when upgrading');
    expect(ana['synced'], 0);
    expect(ana['is_guest'], 0);
    expect(ana['profiling_completed'], 0);
    expect((await db.query('documents')).single['user_id'], 'u1');

    // The email is now a unique username (case-insensitive).
    await db.update(
      'users',
      {'email': 'ana@example.com'},
      where: 'id = ?',
      whereArgs: ['u1'],
    );
    await expectLater(
      db.update(
        'users',
        {'email': 'ANA@example.com'},
        where: 'id = ?',
        whereArgs: ['u2'],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'v2 → v3: history keeps its rows and accepts described images',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          singleInstance: false,
          onCreate: (db, _) => Migrations.migrate(db, 0, 2),
        ),
      );
      addTearDown(db.close);
      const now = 1700000000000;
      await db.insert('documents', {
        'title': 'Liham',
        'full_text': 'Magandang araw.',
        'source_type': 'camera',
        'created_at': now,
        'updated_at': now,
        'last_position': 3,
      });
      await expectLater(
        db.insert('documents', {
          'title': 'Larawan',
          'full_text': 'Mukhang may mesa.',
          'source_type': 'description',
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
        reason: 'not allowed before the migration',
      );

      await db.transaction((txn) => Migrations.migrate(txn, 2, 3));

      final old = (await db.query('documents')).single;
      expect(old['title'], 'Liham');
      expect(old['last_position'], 3);
      expect(old['thumbnail_path'], isNull);
      await db.insert('documents', {
        'title': 'Larawan',
        'full_text': 'Mukhang may mesa.',
        'source_type': 'description',
        'thumbnail_path': 'thumbs/t.jpg',
        'created_at': now,
        'updated_at': now,
      });
      expect(await db.query('documents'), hasLength(2));
      await expectLater(
        db.insert('documents', {
          'title': 'x',
          'full_text': 'x',
          'source_type': 'video',
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'v3 → v4: every history entry becomes a library item, nothing lost',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          singleInstance: false,
          onCreate: (db, _) => Migrations.migrate(db, 0, 3),
        ),
      );
      addTearDown(db.close);
      const now = 1700000000000;
      await db.insert('users', {
        'id': 'u1',
        'display_name': 'Ana',
        'secret_hash': 'h',
        'secret_salt': 's',
        'created_at': now,
        'updated_at': now,
      });
      final types = ['camera', 'image', 'pdf', 'docx', 'description'];
      for (var i = 0; i < types.length; i++) {
        await db.insert('documents', {
          'user_id': i == 4 ? null : 'u1',
          'title': 'Title $i',
          'full_text': 'Text $i.',
          'source_type': types[i],
          'language': i.isEven ? 'fil' : 'en',
          'created_at': now + i,
          'updated_at': now + i,
          'last_opened_at': i == 1 ? now + 99 : null,
          'last_position': i * 2,
          'thumbnail_path': i == 4 ? 'thumbs/t.jpg' : null,
        });
      }

      await db.transaction((txn) => Migrations.migrate(txn, 3, 4));

      final items = await db.query('library_items', orderBy: 'legacy_id');
      expect(items, hasLength(5), reason: 'no entry lost');
      expect(await db.query('documents_legacy'), hasLength(5));
      final expectedSource = [
        'camera',
        'upload',
        'upload',
        'upload',
        'description',
      ];
      final expectedFormat = ['image', 'image', 'pdf', 'docx', 'image'];
      for (var i = 0; i < 5; i++) {
        final r = items[i];
        expect(r['title'], 'Title $i');
        expect(r['full_text'], 'Text $i.');
        expect(r['source'], expectedSource[i]);
        expect(r['format'], expectedFormat[i]);
        expect(r['language'], i.isEven ? 'fil' : 'en');
        expect(r['created_at'], now + i);
        expect(r['sentence_index'], i * 2);
        expect(r['chapter_index'], 0);
        expect(r['text_ref'], 'db');
        expect(r['local_only'], 1);
        expect(r['user_id'], i == 4 ? null : 'u1');
        expect((r['id']! as String).length, 36, reason: 'a real uuid');
      }
      expect(items[1]['last_opened_at'], now + 99);
      expect(items[4]['cover_path'], 'thumbs/t.jpg');
      expect(items.map((r) => r['id']).toSet(), hasLength(5));
    },
  );
}
