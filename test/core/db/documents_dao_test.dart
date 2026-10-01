import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/documents_dao.dart';

import '../../helpers/fakes.dart';

void main() {
  late DocumentsDao dao;

  setUp(() async {
    final db = await openTestDatabase();
    dao = DocumentsDao(db.db);
  });

  Future<int> add(String title, [String text = 'Teksto.']) => dao.insert(
    title: title,
    fullText: text,
    sourceType: 'pdf',
    language: 'fil',
  );

  test('insert and get', () async {
    final id = await add('Liham', 'Mahal na Ginoo.');
    final r = (await dao.get(id))!;
    expect(r.title, 'Liham');
    expect(r.fullText, 'Mahal na Ginoo.');
    expect(r.sourceType, 'pdf');
    expect(r.language, 'fil');
    expect(r.lastPosition, 0);
    expect(r.lastOpenedAt, isNull);
    expect(await dao.get(999), isNull);
  });

  test('position, reopen, rename, delete', () async {
    final id = await add('Resibo');
    await dao.updatePosition(id, 7);
    await dao.markOpened(id);
    await dao.rename(id, 'Resibo sa palengke');
    final r = (await dao.get(id))!;
    expect(r.lastPosition, 7);
    expect(r.lastOpenedAt, isNotNull);
    expect(r.title, 'Resibo sa palengke');

    await dao.delete(id);
    expect(await dao.get(id), isNull);
  });

  test(
    'list is newest first, reopened documents move up, search filters',
    () async {
      final a = await add('Liham kay Nanay', 'Kumusta po kayo.');
      final b = await add('Resibo', 'Bigas at asukal.');
      expect((await dao.list()).map((r) => r.id), [b, a]);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.markOpened(a);
      expect((await dao.list()).map((r) => r.id), [a, b]);

      expect((await dao.list(query: 'nanay')).map((r) => r.id), [a]);
      expect((await dao.list(query: 'asukal')).map((r) => r.id), [b]);
      expect(await dao.list(query: 'wala'), isEmpty);
    },
  );
}
