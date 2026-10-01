import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';

import '../../helpers/fakes.dart';

void main() {
  test('stores, reads, overwrites and removes JSON values per scope', () async {
    final db = await openTestDatabase();
    final dao = PreferencesDao(db.db);

    expect(await dao.get('nav.mode'), isNull);
    await dao.set('nav.mode', 'voice');
    await dao.set('tts.rate', 1.2, userId: 'u1');
    expect(await dao.get('nav.mode'), 'voice');
    expect(await dao.get('tts.rate', userId: 'u1'), 1.2);
    expect(await dao.get('tts.rate'), isNull, reason: 'scopes are separate');

    await dao.set('nav.mode', 'gestures');
    expect(await dao.get('nav.mode'), 'gestures');

    await dao.remove('nav.mode');
    expect(await dao.get('nav.mode'), isNull);
  });
}
