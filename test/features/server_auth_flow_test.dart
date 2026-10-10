// Accounts on the web app, through the screens: register → emailed code →
// setup; login (unverified, suspended, offline); forgot password by code;
// an account suspended in the dashboard is logged out with an explanation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/features/auth/login_screen.dart';
import 'package:percipere_app/features/auth/reset_password_screen.dart';
import 'package:percipere_app/features/auth/security_question_screen.dart';
import 'package:percipere_app/features/auth/verify_email_screen.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _email = 'juan@example.com';
const _password = 'mangotree123';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    await scope.read(commandBusProvider).handleUtterance(words);
    await pumpAndSettle();
  }
}

/// The app with web app accounts, opened at Welcome → [button].
Future<(TestEnv, FakeAccountApi)> _open(
  WidgetTester tester,
  String button, {
  void Function(FakeAccountApi api)? before,
}) async {
  final env = await createEnv(
    tester,
    loggedIn: false,
    permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
  );
  final api = FakeAccountApi();
  before?.call(api);
  env.accountApi = api;
  await pumpApp(tester, env);
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  return (env, api);
}

Future<void> _login(WidgetTester tester, String password) async {
  expect(find.byType(LoginScreen), findsOneWidget);
  await tester.say('juan at example dot com');
  await tester.say(password);
  await tester.say('tapos na');
}

void main() {
  testWidgets('register: created on the web app, the emailed code by '
      'voice (wrong, new code, right), then straight to the setup', (
    tester,
  ) async {
    final (env, api) = await _open(tester, 'Register');
    await tester.say('juan');
    await tester.say('dela cruz');
    await tester.say('juan at example dot com');
    await tester.say('mango tree 123');
    await tester.say('tapos na');

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(api.accounts[_email]!.fullName, 'Juan Dela Cruz');
    expect(api.accounts[_email]!.status, 'pending_verification');
    expect(
      env.tts.transcript,
      contains(
        'Nagpadala kami ng 6 na numerong code sa juan@example.com. '
        'Tingnan ang iyong email.',
      ),
    );
    expect(
      env.tts.transcript,
      contains('Ano ang 6 na numerong code na ipinadala sa iyong email?'),
    );
    expect(tester.scope.read(currentAccountProvider), isNull);

    await tester.say('isa dalawa tatlo apat lima anim');
    expect(env.tts.transcript, contains('Code: 1 2 3 4 5 6.'));
    await tester.say('tapos na');
    expect(
      env.tts.transcript,
      contains('Mali o luma na ang code. Subukan ulit.'),
    );

    await tester.say('ipadala ulit');
    expect(env.tts.transcript, contains('Nagpadala kami ng bagong code.'));
    expect(api.calls.where((c) => c == 'resend'), hasLength(1));

    await tester.say('2 4 6 8 1 0');
    await tester.say('tapos na');
    expect(env.tts.transcript, contains('Nagawa na ang iyong account, Juan.'));
    // The emailed code replaces the security question.
    expect(find.byType(SecurityQuestionScreen), findsNothing);
    expect(find.byType(ProfilingScreen), findsOneWidget);

    final account = tester.scope.read(currentAccountProvider)!;
    expect(account.firstName, 'Juan');
    expect(account.lastName, 'Dela Cruz');
    expect(account.serverId, '1');
    expect(env.sessions.apiTokens[account.id], startsWith('token-'));
    final repo = AccountRepository(env.database.db, TestEnv.testHasher);
    expect(
      (await tester.runAsync(() => repo.verifyPassword(_email, _password)))?.id,
      account.id,
      reason: 'kept for offline login',
    );
  });

  testWidgets('register with an email the web app already has', (tester) async {
    final (env, _) = await _open(
      tester,
      'Register',
      before: (api) => api.add(email: _email, password: 'other-pass1'),
    );
    await tester.say('juan');
    await tester.say('cruz');
    await tester.say('juan at example dot com');
    await tester.say('mango tree 123');
    await tester.say('tapos na');
    expect(find.byType(VerifyEmailScreen), findsNothing);
    expect(
      env.tts.transcript,
      contains(
        'May account na ang email na iyan. Mag-login ka, o gumamit ng '
        'ibang email.',
      ),
    );
  });

  testWidgets('login: the web app checks the password; the new account '
      'goes to the setup', (tester) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(
        email: _email,
        password: _password,
        fullName: 'Juan dela Cruz',
      ),
    );
    await _login(tester, 'wrong-pass1');
    expect(env.tts.transcript, contains('Mali ang email o password.'));
    expect(find.byType(LoginScreen), findsOneWidget);

    // The email stays; the cleared password is asked again.
    await tester.say(_password);
    await tester.say('tapos na');
    expect(env.tts.transcript, contains('Maligayang pagbabalik, Juan.'));
    expect(find.byType(ProfilingScreen), findsOneWidget);
    expect(api.calls, contains('login'));
  });

  testWidgets('login: suspended or waiting for approval is explained', (
    tester,
  ) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) =>
          api.add(email: _email, password: _password, status: 'suspended'),
    );
    await _login(tester, _password);
    expect(
      env.tts.transcript,
      contains(
        'Naka-suspend ang account na ito. Makipag-ugnayan sa administrator.',
      ),
    );
    expect(find.byType(LoginScreen), findsOneWidget);

    api.accounts[_email]!.status = 'pending_approval';
    await tester.say('tapos na');
    expect(
      env.tts.transcript,
      contains(
        'Hinihintay pa ang pag-apruba ng administrator sa iyong account.',
      ),
    );
    expect(tester.scope.read(currentAccountProvider), isNull);
  });

  testWidgets('login to an unverified account asks for the emailed code, '
      'then logs in', (tester) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(
        email: _email,
        password: _password,
        status: 'pending_verification',
      ),
    );
    await _login(tester, _password);
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(api.calls, ['login', 'resend']);
    await tester.say('246810');
    await tester.say('tapos na');
    expect(env.tts.transcript, contains('Maligayang pagbabalik, Ana.'));
    expect(tester.scope.read(currentAccountProvider)?.email, _email);
  });

  testWidgets('offline: an account used here before logs in with the copy '
      'on the phone; a new one needs the internet', (tester) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(email: _email, password: _password),
    );
    await _login(tester, _password);
    expect(find.byType(ProfilingScreen), findsOneWidget);
    await tester.runAsync(
      () => tester.scope.read(currentAccountProvider.notifier).logout(),
    );
    tester.scope.read(routerProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();

    api.offline = true;
    await _login(tester, _password);
    expect(
      env.tts.transcript,
      contains(
        'Walang internet, kaya ang naka-save sa tablet na ito ang ginamit.',
      ),
    );
    expect(tester.scope.read(currentAccountProvider)?.email, _email);
  });

  testWidgets('forgot password: email → code + new password → logged in', (
    tester,
  ) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(email: _email, password: 'old-password1'),
    );
    await tester.say('juan at example dot com');
    await tester.say('nakalimutan');
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(
      env.tts.transcript,
      contains(
        'Magpapadala kami ng code sa iyong email para makagawa ka ng bagong '
        'password.',
      ),
    );
    await tester.say('tapos na');
    expect(api.calls, contains('forgotPassword'));
    expect(
      env.tts.transcript,
      contains(
        'Kung may account ang juan@example.com, nagpadala na kami ng code. '
        'Sabihin ang code, pagkatapos ang bagong password.',
      ),
    );
    await tester.say('246810');
    await tester.say('bagong lihim 9');
    await tester.say('tapos na');
    expect(
      env.tts.transcript,
      contains('Napalitan na ang password, at naka-login ka na.'),
    );
    expect(api.accounts[_email]!.password, 'bagonglihim9');
    expect(tester.scope.read(currentAccountProvider)?.email, _email);
  });

  testWidgets('suspended in the dashboard while logged in: logged out with '
      'an explanation when the app comes back', (tester) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(email: _email, password: _password),
    );
    await _login(tester, _password);
    final account = tester.scope.read(currentAccountProvider)!;
    expect(env.sessions.apiTokens[account.id], isNotNull);

    api.accounts[_email]!.status = 'suspended';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      env.tts.transcript,
      contains(
        'Naka-suspend ang iyong account, kaya na-log out ka. '
        'Makipag-ugnayan sa administrator.',
      ),
    );
    expect(tester.scope.read(currentAccountProvider), isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(env.sessions.apiTokens[account.id], isNull);
  });

  testWidgets('logout ends the web session', (tester) async {
    final (env, api) = await _open(
      tester,
      'Login',
      before: (api) => api.add(email: _email, password: _password),
    );
    await _login(tester, _password);
    final account = tester.scope.read(currentAccountProvider)!;
    final token = env.sessions.apiTokens[account.id]!;
    await tester.runAsync(
      () => tester.scope.read(currentAccountProvider.notifier).logout(),
    );
    await tester.pumpAndSettle();
    expect(api.loggedOut, [token]);
    expect(env.sessions.apiTokens, isEmpty);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
