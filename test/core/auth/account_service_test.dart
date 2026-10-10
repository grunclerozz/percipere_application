// AccountService: the web app decides who logs in; each server account is
// linked to a local account (settings, Library), the password is kept here
// for offline login, the token only in secure storage. Phone-only accounts
// move to the server; a suspension is noticed; logout ends the session.

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_api.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/account_service.dart';
import 'package:percipere_app/core/auth/session_store.dart';
import 'package:percipere_app/core/auth/validators.dart';

import '../../helpers/fakes.dart';

const _email = 'juan@example.com';
const _password = 'lihim1234';

void main() {
  late AccountRepository repo;
  late MemorySessionStore sessions;
  late FakeAccountApi api;
  late AccountService service;

  setUp(() async {
    final db = await openTestDatabase();
    repo = AccountRepository(db.db, TestEnv.testHasher);
    sessions = MemorySessionStore();
    api = FakeAccountApi();
    service = AccountService(api, repo, sessions, () async => 'Test tablet');
  });

  test('login: a new local account is made and linked, the token kept '
      'only in the session store, the password kept for offline', () async {
    api.add(email: _email, password: _password, fullName: 'Juan dela Cruz');
    final outcome = await service.login(_email, _password);
    final account = (outcome as LoggedIn).account;
    expect(outcome.offline, isFalse);
    expect(account.firstName, 'Juan');
    expect(account.lastName, 'dela Cruz');
    expect(account.email, _email);
    expect(account.serverId, '1');
    expect(account.synced, isTrue);
    expect(await sessions.readApiToken(account.id), startsWith('token-'));
    expect((await repo.verifyPassword(_email, _password))?.id, account.id);

    // Again: the same local account, not a second one.
    final again = await service.login(_email, _password) as LoggedIn;
    expect(again.account.id, account.id);
  });

  test('login links an account that already exists on the phone (same '
      'email) and takes its new password', () async {
    final local = await repo.register(
      firstName: 'Juan',
      lastName: 'Cruz',
      email: _email,
      password: 'old-password',
    );
    api.add(email: _email, password: _password);
    final outcome = await service.login(_email, _password) as LoggedIn;
    expect(outcome.account.id, local.id);
    expect(outcome.account.serverId, isNotNull);
    expect(await repo.verifyPassword(_email, 'old-password'), isNull);
    expect(await repo.verifyPassword(_email, _password), isNotNull);
  });

  test('wrong password, suspended and pending approval are refused with '
      'their reason', () async {
    api.add(email: _email, password: _password);
    expect(
      (await service.login(_email, 'wrong-pass') as LoginRefused).reason,
      AccountApiError.invalidCredentials,
    );
    api.accounts[_email]!.status = 'suspended';
    expect(
      (await service.login(_email, _password) as LoginRefused).reason,
      AccountApiError.accountSuspended,
    );
    api.accounts[_email]!.status = 'pending_approval';
    expect(
      (await service.login(_email, _password) as LoginRefused).reason,
      AccountApiError.pendingApproval,
    );
    expect(await repo.findByEmail(_email), isNull, reason: 'nothing linked');
  });

  test('an unverified account: a fresh code is sent and the code is '
      'asked for', () async {
    await api.register(fullName: 'Juan', email: _email, password: _password);
    api.calls.clear();
    final outcome = await service.login(_email, _password);
    expect(outcome, isA<NeedsEmailCode>());
    expect((outcome as NeedsEmailCode).moved, isFalse);
    expect(api.calls, ['login', 'resend']);

    final account = await service.verifyEmail(
      email: _email,
      code: FakeAccountApi.code,
      password: _password,
    );
    expect(account!.serverId, isNotNull);
    expect(await sessions.readApiToken(account.id), isNotNull);
  });

  test('a phone-only account with the right password moves to the web '
      'app (same name and password), keeping its local data', () async {
    final local = await repo.register(
      firstName: 'Maria',
      lastName: 'Santos',
      email: _email,
      password: _password,
    );
    final outcome = await service.login(_email, _password) as NeedsEmailCode;
    expect(outcome.moved, isTrue);
    expect(api.accounts[_email]!.fullName, 'Maria Santos');
    expect(api.accounts[_email]!.password, _password);

    final account = await service.verifyEmail(
      email: _email,
      code: FakeAccountApi.code,
      password: _password,
    );
    expect(account!.id, local.id, reason: 'same local account');
    expect(account.serverId, '1');

    // A wrong local password never moves anything.
    final other = await repo.register(
      firstName: 'Pedro',
      lastName: '',
      email: 'pedro@example.com',
      password: _password,
    );
    expect(
      (await service.login(other.email!, 'not-it-123') as LoginRefused).reason,
      AccountApiError.invalidCredentials,
    );
    expect(api.accounts.containsKey('pedro@example.com'), isFalse);
  });

  test('offline: the copy on the phone logs in; never-seen accounts need '
      'the internet; a wrong password is still wrong', () async {
    api.add(email: _email, password: _password);
    final first = await service.login(_email, _password) as LoggedIn;
    api.offline = true;

    final offline = await service.login(_email, _password) as LoggedIn;
    expect(offline.offline, isTrue);
    expect(offline.account.id, first.account.id);
    expect(
      (await service.login(_email, 'wrong-pass') as LoginRefused).reason,
      AccountApiError.invalidCredentials,
    );
    expect(
      (await service.login(
        'new@example.com',
        _password,
      ) as LoginRefused).reason,
      AccountApiError.offline,
    );
  });

  test('register sends the full name; verify with approval on waits', () async {
    api.approval = true;
    expect(
      await service.register(
        firstName: ' Juan ',
        lastName: 'dela Cruz',
        email: _email,
        password: _password,
      ),
      isTrue,
    );
    expect(api.accounts[_email]!.fullName, 'Juan dela Cruz');
    expect(
      await service.verifyEmail(
        email: _email,
        code: FakeAccountApi.code,
        password: _password,
        firstName: 'Juan',
        lastName: 'dela Cruz',
      ),
      isNull,
    );
    expect(await repo.findByEmail(_email), isNull);
  });

  test('wrong codes: invalid, then the 5th voids it', () async {
    await service.register(
      firstName: 'Juan',
      lastName: '',
      email: _email,
      password: _password,
    );
    for (var i = 0; i < 4; i++) {
      await expectLater(
        service.verifyEmail(email: _email, code: '000000', password: _password),
        throwsA(
          isA<AccountApiException>().having(
            (e) => e.error,
            'error',
            AccountApiError.invalidCode,
          ),
        ),
      );
    }
    await expectLater(
      service.verifyEmail(email: _email, code: '000000', password: _password),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.tooManyAttempts,
        ),
      ),
    );
  });

  test('password reset: new password on the server and the phone, '
      'other sessions ended, logged in', () async {
    api.add(email: _email, password: _password);
    final before = await service.login(_email, _password) as LoggedIn;
    final oldToken = await sessions.readApiToken(before.account.id);
    await service.forgotPassword(_email);
    final account = await service.resetPassword(
      email: _email,
      code: FakeAccountApi.code,
      password: 'bagongLihim9',
    );
    expect(account.id, before.account.id);
    expect(api.tokens.containsKey(oldToken), isFalse);
    expect(await sessions.readApiToken(account.id), isNot(oldToken));
    expect(await repo.verifyPassword(_email, 'bagongLihim9'), isNotNull);
    expect(await repo.verifyPassword(_email, _password), isNull);
  });

  test('session check: fine, suspended, token gone (forgotten), or '
      'unknown offline', () async {
    api.add(email: _email, password: _password);
    final account =
        (await service.login(_email, _password) as LoggedIn).account;
    expect(await service.check(account), SessionCheck.ok);

    api.offline = true;
    expect(await service.check(account), SessionCheck.unknown);
    api.offline = false;

    api.accounts[_email]!.status = 'suspended';
    expect(await service.check(account), SessionCheck.suspended);
    api.accounts[_email]!.status = 'active';

    api.tokens.clear();
    expect(await service.check(account), SessionCheck.tokenGone);
    expect(await sessions.readApiToken(account.id), isNull);
    expect(await service.check(account), SessionCheck.unknown);
  });

  test('sign out forgets the token and ends the web session; offline it '
      'still finishes at once', () async {
    api.add(email: _email, password: _password);
    final account =
        (await service.login(_email, _password) as LoggedIn).account;
    final token = (await sessions.readApiToken(account.id))!;
    await service.signOut(account);
    await pumpEventQueue();
    expect(await sessions.readApiToken(account.id), isNull);
    expect(api.loggedOut, [token]);

    await service.login(_email, _password);
    api.offline = true;
    await service.signOut(account);
    expect(await sessions.readApiToken(account.id), isNull);
  });

  test('accounts on the phone only: no server', () {
    final local = AccountService(null, repo, sessions, () async => 'x');
    expect(local.usesServer, isFalse);
  });

  test('names and spoken codes', () {
    expect(AccountService.splitName('Juan'), ('Juan', ''));
    expect(AccountService.splitName('  Juan   dela  Cruz '), (
      'Juan',
      'dela Cruz',
    ));
    expect(AuthRules.spokenCode('2 4 6 8 1 0'), '246810');
    expect(AuthRules.spokenCode('246-810'), '246810');
    expect(AuthRules.spokenCode('dalawa apat anim walo isa sero'), '246810');
    expect(AuthRules.spokenCode('two four six eight one zero'), '246810');
    expect(AuthRules.spokenCode('ang code ay 24 68 10'), '246810');
    expect(AuthRules.isValidCode('246810'), isTrue);
    expect(AuthRules.isValidCode('24681'), isFalse);
  });
}
