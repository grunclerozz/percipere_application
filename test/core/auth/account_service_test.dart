// AccountService: the web app decides who logs in; each server account is
// linked to a local account (settings, Library), the password is kept here
// for offline login, the token only in secure storage. Phone-only accounts
// move to the server; a suspension is noticed; logout ends the session.

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/account_api.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/account_service.dart';
import 'package:percipere_app/core/auth/session_store.dart';

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

  test('a phone-only account with the right password moves to the web '
      'app (same name and password), keeping its local data', () async {
    final local = await repo.register(
      firstName: 'Maria',
      lastName: 'Santos',
      email: _email,
      password: _password,
    );
    final outcome = await service.login(_email, _password) as LoggedIn;
    expect(api.accounts[_email]!.fullName, 'Maria Santos');
    expect(api.accounts[_email]!.password, _password);
    final account = outcome.account;
    expect(account.id, local.id, reason: 'same local account');
    expect(account.serverId, '1');
    expect(await sessions.readApiToken(account.id), isNotNull);

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

  test('register: an active account is created and logged in at once', () async {
    final result = await service.register(
      firstName: ' Juan ',
      lastName: 'dela Cruz',
      email: _email,
      password: _password,
    );
    expect(result.status, RegisterStatus.active);
    expect(result.loggedIn, isTrue);
    expect(api.accounts[_email]!.fullName, 'Juan dela Cruz');
    expect(result.account!.firstName, 'Juan');
    expect(result.account!.lastName, 'dela Cruz');
    expect(result.account!.serverId, isNotNull);
    expect(await sessions.readApiToken(result.account!.id), isNotNull);
    expect(api.calls, ['register', 'login'], reason: 'no code step');
  });

  test('register: waiting for approval is tried, and is not logged in '
      'when the login is refused', () async {
    api.approval = true;
    final result = await service.register(
      firstName: 'Juan',
      lastName: '',
      email: _email,
      password: _password,
    );
    expect(result.status, RegisterStatus.pendingApproval);
    expect(result.loggedIn, isFalse);
    expect(api.calls, ['register', 'login'], reason: 'it did try to log in');
    expect(await repo.findByEmail(_email), isNull);
  });

  test('register: approved at once (login works) is logged in even if the '
      'reply said pending', () async {
    // A server that answers "pending_approval" but already lets them in.
    final lenient = _LenientApi(api);
    final svc = AccountService(
      lenient,
      repo,
      sessions,
      () async => 'test device',
    );
    final result = await svc.register(
      firstName: 'Ana',
      lastName: '',
      email: 'x@example.com',
      password: _password,
    );
    expect(result.status, RegisterStatus.pendingApproval);
    expect(result.loggedIn, isTrue);
  });

  test('register: no connection after creating still ends without a crash',
      () async {
    final flaky = _FlakyLoginApi(api);
    final svc = AccountService(flaky, repo, sessions, () async => 'device');
    final result = await svc.register(
      firstName: 'Juan',
      lastName: '',
      email: _email,
      password: _password,
    );
    expect(result.status, RegisterStatus.active);
    expect(result.loggedIn, isFalse);
  });

  test('register: an email already on the server is refused', () async {
    api.add(email: _email, password: _password);
    await expectLater(
      service.register(
        firstName: 'Juan',
        lastName: '',
        email: _email,
        password: 'another-pass1',
      ),
      throwsA(
        isA<AccountApiException>().having(
          (e) => e.error,
          'error',
          AccountApiError.emailTaken,
        ),
      ),
    );
  });

  test('the register reply: only "active" is active; the status may sit '
      'under user; anything else waits', () {
    expect(RegisterStatus.fromReply({'status': 'active'}), RegisterStatus.active);
    expect(
      RegisterStatus.fromReply({
        'user': {'status': 'active'},
      }),
      RegisterStatus.active,
    );
    expect(
      RegisterStatus.fromReply({'status': 'pending_approval'}),
      RegisterStatus.pendingApproval,
    );
    expect(RegisterStatus.fromReply({}), RegisterStatus.pendingApproval);
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

  test('names', () {
    expect(AccountService.splitName('Juan'), ('Juan', ''));
    expect(AccountService.splitName('  Juan   dela  Cruz '), (
      'Juan',
      'dela Cruz',
    ));
  });
}

/// Says "pending_approval" for an account that can log in right away.
class _LenientApi extends _DelegatingApi {
  _LenientApi(super.inner);

  @override
  Future<RegisterStatus> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await inner.register(fullName: fullName, email: email, password: password);
    return RegisterStatus.pendingApproval;
  }
}

/// Registers, then the connection drops before the login.
class _FlakyLoginApi extends _DelegatingApi {
  _FlakyLoginApi(super.inner);

  @override
  Future<ServerSession> login({
    required String email,
    required String password,
    required String device,
  }) => throw const AccountApiException(AccountApiError.offline);
}

class _DelegatingApi implements AccountApi {
  _DelegatingApi(this.inner);

  final FakeAccountApi inner;

  @override
  Future<RegisterStatus> register({
    required String fullName,
    required String email,
    required String password,
  }) => inner.register(fullName: fullName, email: email, password: password);

  @override
  Future<ServerSession> login({
    required String email,
    required String password,
    required String device,
  }) => inner.login(email: email, password: password, device: device);

  @override
  Future<ServerUser> me(String token) => inner.me(token);

  @override
  Future<void> logout(String token) => inner.logout(token);
}
