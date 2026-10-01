import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/features/account/account_repository.dart';
import 'package:percipere_app/features/account/pin_input.dart';

import '../../helpers/fakes.dart';

void main() {
  group('PIN hashing', () {
    test('same PIN + salt → same hash; different salt → different hash', () {
      expect(PinHash.hash('1234', 'abc'), PinHash.hash('1234', 'abc'));
      expect(PinHash.hash('1234', 'abc'), isNot(PinHash.hash('1234', 'abd')));
      expect(PinHash.hash('1234', 'abc'), isNot(PinHash.hash('1235', 'abc')));
      expect(PinHash.newSalt(), isNot(PinHash.newSalt()));
    });
  });

  group('AccountRepository', () {
    late TestEnv env;
    late AccountRepository repo;
    setUp(() async {
      env = await TestEnv.create();
      repo = AccountRepository(env.database.db);
    });

    test('create, verify, list (most recent login first)', () async {
      final ana = await repo.create(name: ' Ana ', email: '', pin: '1234');
      final ben = await repo.create(
        name: 'Ben',
        email: 'ben@example.com',
        pin: '9876',
      );
      expect(ana.name, 'Ana');
      expect(ana.email, isNull);
      expect(ben.email, 'ben@example.com');

      expect(await repo.verify(ana.id, '1234'), isTrue);
      expect(await repo.verify(ana.id, '4321'), isFalse);
      expect(await repo.verify('nobody', '1234'), isFalse);

      final raw = (await env.database.db.query('users')).first;
      expect(raw['secret_hash'], isNot(contains('1234')), reason: 'hashed');

      await repo.markLogin(ana.id);
      expect((await repo.list()).first.id, ana.id);
    });

    test('login switches to the profile\'s settings; logout back', () async {
      final container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      final ana = await repo.create(name: 'Ana', pin: '1234');

      await container.read(currentAccountProvider.notifier).login(ana);
      expect(container.read(currentAccountProvider), ana);
      expect(container.read(settingsProvider.notifier).scope, ana.id);
      expect(
        await PreferencesDao(env.database.db).get(PrefKeys.currentUser),
        ana.id,
      );

      await container.read(currentAccountProvider.notifier).logout();
      expect(container.read(currentAccountProvider), isNull);
      expect(
        container.read(settingsProvider.notifier).scope,
        PreferencesDao.deviceScope,
      );
      expect(
        await PreferencesDao(env.database.db).get(PrefKeys.currentUser),
        isNull,
      );
    });
  });

  group('spoken input', () {
    test('digits in Filipino, English, Spanish-derived words and numerals', () {
      expect(parseDigits('isa dalawa tatlo apat'), [1, 2, 3, 4]);
      expect(parseDigits('one two three four'), [1, 2, 3, 4]);
      expect(parseDigits('lima anim pito walo'), [5, 6, 7, 8]);
      expect(parseDigits('uno dos tres kwatro'), [1, 2, 3, 4]);
      expect(parseDigits('1 2 3 4'), [1, 2, 3, 4]);
      expect(parseDigits('1234'), [1, 2, 3, 4]);
      expect(parseDigits('siyam, sero!'), [9, 0]);
      expect(parseDigits('hello'), isEmpty);
    });

    test('dictated email', () {
      expect(
        normalizeSpokenEmail('Juan Dela Cruz at gmail dot com'),
        'juandelacruz@gmail.com',
      );
      expect(normalizeSpokenEmail('ana@yahoo.com'), 'ana@yahoo.com');
      expect(
        normalizeSpokenEmail('maria sa example tuldok ph'),
        'maria@example.ph',
      );
    });
  });
}
