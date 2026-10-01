import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/bootstrap.dart';
import 'package:percipere_app/core/auth/account.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/account_sync_repository.dart';
import 'package:percipere_app/core/auth/login_throttle.dart';
import 'package:percipere_app/core/auth/password_hasher.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/auth/session_store.dart';
import 'package:percipere_app/core/auth/validators.dart';
import 'package:percipere_app/core/db/daos/documents_dao.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  group('PasswordHasher', () {
    String b64(String s) => base64Encode(utf8.encode(s));

    test('PBKDF2-HMAC-SHA256 matches the published test vectors', () {
      String hex(String b) =>
          base64Decode(b)
              .map((x) => x.toRadixString(16).padLeft(2, '0'))
              .join();
      expect(
        hex(PasswordHasher.pbkdf2('password', b64('salt'), 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        hex(PasswordHasher.pbkdf2('password', b64('salt'), 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        hex(PasswordHasher.pbkdf2('password', b64('salt'), 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('hash → verify; wrong password fails; salts differ', () async {
      const hasher = PasswordHasher(iterations: 500, useIsolate: false);
      final a = await hasher.hash('mabuhay-bataan');
      final b = await hasher.hash('mabuhay-bataan');
      expect(a.kind, 'pbkdf2-sha256:500');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.hash, isNot(contains('mabuhay')));
      expect(await hasher.verify('mabuhay-bataan', a), isTrue);
      expect(await hasher.verify('Mabuhay-bataan', a), isFalse);
      // A hash made with other iterations still verifies (stored with it).
      const stronger = PasswordHasher(iterations: 800, useIsolate: false);
      expect(await stronger.verify('mabuhay-bataan', a), isTrue);
    });

    test('the default is 100 000 iterations', () {
      expect(PasswordHasher.defaultIterations, 100000);
      expect(PasswordHasher.iterationsOf('pbkdf2-sha256:100000'), 100000);
      expect(PasswordHasher.iterationsOf('pin'), isNull);
    });
  });

  group('AuthRules', () {
    test('email format', () {
      expect(AuthRules.isValidEmail('juan@gmail.com'), isTrue);
      expect(AuthRules.isValidEmail(' Juan.Dela-Cruz@yahoo.com.ph '), isTrue);
      expect(AuthRules.isValidEmail('juan@gmail'), isFalse);
      expect(AuthRules.isValidEmail('juan gmail.com'), isFalse);
      expect(AuthRules.isValidEmail(''), isFalse);
    });

    test('password length', () {
      expect(AuthRules.isValidPassword('1234567'), isFalse);
      expect(AuthRules.isValidPassword('12345678'), isTrue);
    });

    test('spelled emails: "at" → @, "dot"/"tuldok" → .', () {
      expect(
        AuthRules.spokenEmail('juan dela cruz at gmail dot com'),
        'juandelacruz@gmail.com',
      );
      expect(
        AuthRules.spokenEmail('Ana at yahoo tuldok com tuldok ph'),
        'ana@yahoo.com.ph',
      );
      expect(AuthRules.spokenEmail('ana@gmail.com'), 'ana@gmail.com');
      expect(
        AuthRules.spokenEmail('ana underscore b at x dot org'),
        'ana_b@x.org',
      );
    });

    test('spoken passwords and names', () {
      expect(AuthRules.spokenPassword('Mango 123 Sweet'), 'mango123sweet');
      expect(AuthRules.spokenName('  juan   carlos '), 'Juan Carlos');
    });

    test('security answers are normalized', () {
      expect(AuthRules.normalizeAnswer('  Sto. Niño!  '), 'sto nino');
      expect(AuthRules.normalizeAnswer('STO NINO'), 'sto nino');
    });
  });

  group('AccountRepository', () {
    late TestEnv env;
    late AccountRepository repo;

    setUp(() async {
      env = await TestEnv.create();
      repo = AccountRepository(env.database.db, TestEnv.testHasher);
    });

    Future<Account> register([String email = 'juan@gmail.com']) =>
        repo.register(
          firstName: 'Juan',
          lastName: 'dela Cruz',
          email: email,
          password: 'sikretong-pass',
        );

    test('register stores a salted hash, a UUID and sync fields', () async {
      final a = await register('Juan@Gmail.com');
      expect(a.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.email, 'juan@gmail.com');
      expect(a.name, 'Juan dela Cruz');
      expect(a.synced, isFalse);
      expect(a.serverId, isNull);
      final row = (await env.database.db.query('users')).single;
      expect(row.values.whereType<String>(), isNot(contains('sikretong-pass')));
      expect(row['secret_kind'], 'pbkdf2-sha256:1000');
      expect(row['created_at'], isA<int>());
    });

    test('no duplicate email on the device (any case)', () async {
      await register();
      expect(
        () => register('JUAN@gmail.com'),
        throwsA(isA<EmailTakenException>()),
      );
      expect(await repo.emailTaken('juan@GMAIL.com'), isTrue);
    });

    test('verifyPassword', () async {
      final a = await register();
      expect(
        (await repo.verifyPassword('JUAN@gmail.com', 'sikretong-pass'))?.id,
        a.id,
      );
      expect(await repo.verifyPassword('juan@gmail.com', 'mali'), isNull);
      expect(
        await repo.verifyPassword('iba@gmail.com', 'sikretong-pass'),
        isNull,
      );
    });

    test(
      'security question: answer normalized and hashed; new password',
      () async {
        final a = await register();
        await repo.setSecurityAnswer(
          a.id,
          SecurityQuestion.birthTown,
          'Balanga!',
        );
        expect((await repo.get(a.id))!.securityQuestion, 'birthTown');
        final row = (await env.database.db.query('users')).single;
        expect(row['security_answer_hash'], isNot(contains('balanga')));
        expect(await repo.verifySecurityAnswer(a.id, ' balanga '), isTrue);
        expect(await repo.verifySecurityAnswer(a.id, 'Orani'), isFalse);

        await repo.setPassword(a.id, 'bagong-password');
        expect(
          await repo.verifyPassword('juan@gmail.com', 'sikretong-pass'),
          isNull,
        );
        expect(
          await repo.verifyPassword('juan@gmail.com', 'bagong-password'),
          isNotNull,
        );
      },
    );

    test(
      'changes mark the account unsynced; guests are never synced',
      () async {
        final a = await register();
        await repo.markSynced(a.id, 'srv-1');
        expect((await repo.get(a.id))!.synced, isTrue);
        await repo.setProfilingCompleted(a.id, true);
        expect((await repo.get(a.id))!.synced, isFalse);
        await repo.guest(name: 'Bisita');
        expect((await repo.unsynced()).map((x) => x.id), [a.id]);
      },
    );

    test('one guest profile per device, reused', () async {
      final g1 = await repo.guest(name: 'Bisita');
      final g2 = await repo.guest(name: 'Bisita');
      expect(g1.id, g2.id);
      expect(g1.isGuest, isTrue);
      expect(g1.email, isNull);
      expect(await repo.verifyPassword('', ''), isNull);
    });

    test('legacy PIN account: verify the old PIN once, then upgrade', () async {
      const now = 1700000000000;
      await env.database.db.insert('users', {
        'id': 'old-1',
        'display_name': 'Lola',
        'first_name': 'Lola',
        'secret_hash': LegacyPinHash.hash('2468', 'c2FsdA=='),
        'secret_salt': 'c2FsdA==',
        'secret_kind': 'pin',
        'created_at': now,
        'updated_at': now,
      });
      expect((await repo.legacyAccounts()).single.isLegacy, isTrue);
      expect(await repo.verifyLegacyPin('old-1', '1234'), isFalse);
      expect(await repo.verifyLegacyPin('old-1', '2468'), isTrue);

      final up = await repo.upgradeLegacy(
        'old-1',
        firstName: 'Lola',
        lastName: 'Basyang',
        email: 'lola@example.com',
        password: 'bagong-pass',
      );
      expect(up.isLegacy, isFalse);
      expect(up.id, 'old-1', reason: 'settings and history keep their owner');
      expect(await repo.legacyAccounts(), isEmpty);
      expect(await repo.verifyLegacyPin('old-1', '2468'), isFalse);
      expect(
        (await repo.verifyPassword('lola@example.com', 'bagong-pass'))?.id,
        'old-1',
      );
    });
  });

  group('LoginThrottle (lockout)', () {
    late TestEnv env;
    late DateTime now;
    late LoginThrottle throttle;

    setUp(() async {
      env = await TestEnv.create();
      now = DateTime(2026, 10, 1, 9);
      throttle = LoginThrottle(env.database.db, clock: () => now);
    });

    test('delays: 5 free, then 30 s doubling', () {
      expect(LoginThrottle.delayAfter(4), Duration.zero);
      expect(LoginThrottle.delayAfter(5), const Duration(seconds: 30));
      expect(LoginThrottle.delayAfter(6), const Duration(seconds: 60));
      expect(LoginThrottle.delayAfter(7), const Duration(seconds: 120));
      expect(LoginThrottle.delayAfter(40), LoginThrottle.maxDelay);
    });

    test(
      'locks after the 5th failure, per email, and survives a restart',
      () async {
        const email = 'juan@gmail.com';
        for (var i = 0; i < 4; i++) {
          expect(
            await throttle.recordFailure(ThrottleKind.login, email),
            Duration.zero,
          );
        }
        expect(
          await throttle.recordFailure(ThrottleKind.login, 'JUAN@gmail.com'),
          const Duration(seconds: 30),
        );
        // Another email and the reset counter are separate.
        expect(
          await throttle.remaining(ThrottleKind.login, 'ana@x.com'),
          Duration.zero,
        );
        expect(
          await throttle.remaining(ThrottleKind.reset, email),
          Duration.zero,
        );

        // "Restart": a new throttle over the same database.
        now = now.add(const Duration(seconds: 10));
        final again = LoginThrottle(env.database.db, clock: () => now);
        expect(
          await again.remaining(ThrottleKind.login, email),
          const Duration(seconds: 20),
        );
        now = now.add(const Duration(seconds: 21));
        expect(await again.remaining(ThrottleKind.login, email), Duration.zero);
        expect(
          await again.recordFailure(ThrottleKind.login, email),
          const Duration(seconds: 60),
        );

        await again.reset(ThrottleKind.login, email);
        expect(await again.failures(ThrottleKind.login, email), 0);
        expect(await again.remaining(ThrottleKind.login, email), Duration.zero);
      },
    );
  });

  group('Session and guest migration', () {
    late TestEnv env;
    late ProviderContainer container;

    setUp(() async {
      env = await TestEnv.create();
      container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
    });

    test('login remembers the session and switches settings; logout keeps '
        'the look on the device', () async {
      final repo = container.read(accountRepositoryProvider);
      final a = await repo.register(
        firstName: 'Ana',
        lastName: 'Reyes',
        email: 'ana@x.com',
        password: 'password1',
      );
      await container.read(currentAccountProvider.notifier).login(a);
      expect(env.sessions.userId, a.id);
      expect(container.read(settingsProvider.notifier).scope, a.id);
      await container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(textSize: 30));

      await container.read(currentAccountProvider.notifier).logout();
      expect(env.sessions.userId, isNull);
      expect(container.read(currentAccountProvider), isNull);
      expect(
        container.read(settingsProvider.notifier).scope,
        PreferencesDao.deviceScope,
      );
      expect(container.read(settingsProvider).textSize, 30);
    });

    test('guest → account: settings, history and finished setup steps move; '
        'the guest profile is deleted', () async {
      final session = container.read(currentAccountProvider.notifier);
      final guest = await session.startGuest('Bisita');
      await container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(readingRate: 1.5));
      final prefs = PreferencesDao(env.database.db);
      await prefs.set(PrefKeys.setupDone, [
        'navMode',
        'speed',
      ], userId: guest.id);
      final docs = DocumentsDao(env.database.db);
      await docs.insert(
        title: 'Resibo',
        fullText: 'Bigas',
        sourceType: 'camera',
        language: 'fil',
        userId: guest.id,
      );

      final repo = container.read(accountRepositoryProvider);
      final a = await repo.register(
        firstName: 'Ana',
        lastName: 'Reyes',
        email: 'ana@x.com',
        password: 'password1',
      );
      await session.completeRegistration(a);

      expect(container.read(currentAccountProvider)?.id, a.id);
      expect(container.read(settingsProvider).readingRate, 1.5);
      expect((await docs.list(userId: a.id)).single.title, 'Resibo');
      expect(await docs.list(userId: guest.id), isEmpty);
      expect(await prefs.get(PrefKeys.setupDone, userId: a.id), [
        'navMode',
        'speed',
      ]);
      expect(await repo.get(guest.id), isNull);
      expect(await prefs.getAll(userId: guest.id), isEmpty);
      expect(
        (container.read(
          accountSyncRepositoryProvider,
        ) as MockAccountSyncRepository).queued,
        [a.id],
      );
    });
  });

  group('restoreSession (startup)', () {
    test('a pre-6B logged-in PIN profile moves to secure storage', () async {
      final env = await TestEnv.create();
      const now = 1700000000000;
      await env.database.db.insert('users', {
        'id': 'old-1',
        'display_name': 'Lola',
        'first_name': 'Lola',
        'secret_hash': 'h',
        'secret_salt': 's',
        'created_at': now,
        'updated_at': now,
      });
      final prefs = PreferencesDao(env.database.db);
      await prefs.set(PrefKeys.currentUser, 'old-1');
      final store = MemorySessionStore();

      final r = await restoreSession(env.database, prefs, store);
      expect(r.account?.isLegacy, isTrue);
      expect(store.userId, 'old-1');
      expect(await prefs.get(PrefKeys.currentUser), isNull);
    });

    test('"stay logged in" off: the session expires at launch, the look '
        'stays', () async {
      final env = await TestEnv.create(loggedIn: true);
      final prefs = PreferencesDao(env.database.db);
      await prefs.set(PrefKeys.stayLoggedIn, false, userId: env.account!.id);
      await prefs.set(PrefKeys.textSize, 40, userId: env.account!.id);
      final store = MemorySessionStore(userId: env.account!.id);

      final r = await restoreSession(env.database, prefs, store);
      expect(r.account, isNull);
      expect(r.expired, isTrue);
      expect(store.userId, isNull);
      expect(r.scope, PreferencesDao.deviceScope);
      expect(r.settings.textSize, 40);
    });

    test('a saved session restores the account and its settings', () async {
      final env = await TestEnv.create(loggedIn: true);
      final prefs = PreferencesDao(env.database.db);
      await prefs.set(PrefKeys.readingRate, 1.75, userId: env.account!.id);
      final r = await restoreSession(
        env.database,
        prefs,
        MemorySessionStore(userId: env.account!.id),
      );
      expect(r.account?.id, env.account!.id);
      expect(r.scope, env.account!.id);
      expect(r.settings.readingRate, 1.75);
    });
  });
}
