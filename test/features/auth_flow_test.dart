import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/auth/account.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/biometrics.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/features/auth/forgot_password_screen.dart';
import 'package:percipere_app/features/auth/login_screen.dart';
import 'package:percipere_app/features/auth/register_screen.dart';
import 'package:percipere_app/features/auth/security_question_screen.dart';
import 'package:percipere_app/features/capture/capture_screen.dart';
import 'package:percipere_app/features/setup/profiling_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  CommandBus get bus => scope.read(commandBusProvider);

  Future<void> say(String words) async {
    await bus.handleUtterance(words);
    await pumpAndSettle();
  }

  Future<void> doubleTapPad() async {
    final at = getCenter(find.byType(GesturePad));
    for (var i = 0; i < 2; i++) {
      final g = await startGesture(at);
      await pump(const Duration(milliseconds: 50));
      await g.up();
      await pump(const Duration(milliseconds: 100));
    }
    await pumpAndSettle();
  }
}

/// Welcome → [button].
Future<TestEnv> _open(WidgetTester tester, String button) async {
  final env = await createEnv(
    tester,
    loggedIn: false,
    // No microphone: the tests speak through the bus, and an open
    // recognizer keeps the waveform animating (pumpAndSettle never ends).
    permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
  );
  await pumpApp(tester, env);
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  return env;
}

/// A registered account that finished the setup, then Login is opened.
Future<TestEnv> _openLogin(WidgetTester tester, {bool done = true}) async {
  final env = await createEnv(
    tester,
    loggedIn: false,
    // No microphone: the test speaks through the bus, and an open
    // recognizer would keep the waveform animating through the countdown.
    permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
  );
  final repo = AccountRepository(env.database.db, TestEnv.testHasher);
  await tester.runAsync(() async {
    final a = await repo.register(
      firstName: 'Ana',
      lastName: 'Cruz',
      email: TestEnv.testEmail,
      password: TestEnv.testPassword,
    );
    if (done) await repo.setProfilingCompleted(a.id, true);
  });
  await pumpApp(tester, env);
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
  return env;
}

void main() {
  group('Register', () {
    testWidgets('every field by voice with read-back (password only by '
        'length); "tapos na" submits; then the security question', (
      tester,
    ) async {
      final env = await _open(tester, 'Register');
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(
        env.tts.transcript,
        contains('Register. Sagutin ang bawat tanong sa boses, o i-type ito.'),
      );
      expect(
        env.tts.transcript,
        contains('Ano ang iyong pangalan (first name)?'),
      );

      await tester.say('juan');
      expect(env.tts.transcript, contains('First Name: Juan.'));
      expect(
        env.tts.transcript,
        contains('Ano ang iyong apelyido (last name)?'),
      );
      await tester.say('dela cruz');
      expect(env.tts.transcript, contains('Last Name: Dela Cruz.'));
      await tester.say('juan at gmail dot com');
      expect(env.tts.transcript, contains('Email Address: juan@gmail.com.'));
      expect(
        env.tts.transcript,
        contains('Gumawa ng password na hindi bababa sa 8 titik.'),
      );
      await tester.say('mango tree 123');
      expect(env.tts.transcript, contains('Password: 12 titik.'));
      expect(env.tts.transcript, isNot(contains('mangotree')));
      // Never shown: only the obscured field holds it.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('mango'),
        ),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      expect(env.tts.transcript, contains('Kumpleto na.'));

      await tester.say('tapos na');
      expect(
        env.tts.transcript,
        contains('Nagawa na ang iyong account, Juan.'),
      );
      expect(find.byType(SecurityQuestionScreen), findsOneWidget);
      final account = tester.scope.read(currentAccountProvider)!;
      expect(account.email, 'juan@gmail.com');
      expect(env.sessions.userId, account.id);

      // Security question: chosen by voice, answered by voice.
      expect(env.tts.transcript, contains('Pumili ng tanong pangseguridad.'));
      await tester.say('bayan');
      expect(env.tts.transcript, contains('Saang bayan ka ipinanganak?'));
      await tester.say('Balanga');
      expect(env.tts.transcript, contains('Sagot: Balanga.'));
      await tester.say('submit');
      expect(
        env.tts.transcript,
        contains('Na-save ang iyong tanong pangseguridad.'),
      );

      // No fingerprint on this phone → straight to the setup.
      expect(find.byType(ProfilingScreen), findsOneWidget);
      final repo = AccountRepository(env.database.db, TestEnv.testHasher);
      expect(
        await tester.runAsync(
          () => repo.verifySecurityAnswer(account.id, 'balanga'),
        ),
        isTrue,
      );
      expect(
        (await tester.runAsync(
          () => repo.verifyPassword('juan@gmail.com', 'mangotree123'),
        ))?.id,
        account.id,
      );
    });

    testWidgets('validation is spoken: missing fields, email, short '
        'password, duplicate email', (tester) async {
      final env = await _open(tester, 'Register');
      await tester.doubleTapPad(); // submit with nothing filled
      expect(
        env.tts.transcript,
        contains('Kulang pa: First Name, Last Name, Email Address, Password.'),
      );
      expect(env.haptics.events, contains('error'));

      await tester.say('Ana');
      await tester.say('Cruz');
      await tester.say('ana at gmail');
      await tester.say('abc123');
      await tester.say('submit');
      expect(env.tts.transcript, contains('Mukhang mali ang email address.'));

      // Fix the email (focused after the error), then the password is short.
      await tester.say('ana at gmail dot com');
      await tester.say('submit');
      expect(
        env.tts.transcript,
        contains('Ang password ay dapat hindi bababa sa 8 titik. 6 pa lang'),
      );

      // An email already used on this phone.
      final repo = AccountRepository(env.database.db, TestEnv.testHasher);
      await tester.runAsync(
        () => repo.register(
          firstName: 'X',
          lastName: 'Y',
          email: 'ana@gmail.com',
          password: 'password9',
        ),
      );
      await tester.say('abc12345');
      await tester.say('submit');
      expect(
        env.tts.transcript,
        contains('May account na sa phone na ito ang email na iyan.'),
      );
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('typing works too, with the same read-back', (tester) async {
      final env = await _open(tester, 'Register');
      await tester.enterText(find.byType(TextField).first, 'Maria');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('First Name: Maria.'));
      expect(env.tts.transcript, contains('Ano ang iyong apelyido'));
    });
  });

  group('Login', () {
    testWidgets('wrong password, lockout with a spoken countdown, then the '
        'right one goes to Capture', (tester) async {
      final env = await _openLogin(tester);
      expect(
        env.tts.transcript,
        contains('Pindutin ng dalawang beses ang gesture area'),
      );
      await tester.say('ana at example dot com');
      expect(env.tts.transcript, contains('Email Address: ana@example.com.'));

      for (var i = 1; i <= 4; i++) {
        await tester.say('maling password');
        await tester.say('submit');
        expect(
          env.tts.transcript,
          contains('Mali ang email o password. ${5 - i} pang subok'),
        );
      }
      await tester.say('maling password');
      await tester.say('submit');
      expect(
        env.tts.transcript,
        contains('Masyadong maraming maling subok. Maghintay ng 30 segundo'),
      );
      expect(find.text('Maghintay ng 30 segundo.'), findsOneWidget);

      // The right password is refused while locked.
      await tester.say(TestEnv.testPassword);
      await tester.say('submit');
      expect(tester.scope.read(currentAccountProvider), isNull);
      expect(env.tts.spoken.last, 'Maghintay ng 30 segundo.');

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(env.tts.spoken, contains('20'));
      await tester.pump(const Duration(seconds: 21));
      env.now = env.now.add(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(env.tts.transcript, contains('Maaari ka nang sumubok muli.'));

      await tester.say(TestEnv.testPassword);
      await tester.say('tapos na');
      expect(env.tts.transcript, contains('Maligayang pagbabalik, Ana.'));
      expect(find.byType(CaptureScreen), findsOneWidget);
    });

    testWidgets('an account that never finished the setup goes to it', (
      tester,
    ) async {
      final env = await _openLogin(tester, done: false);
      await tester.say('ana at example dot com');
      await tester.say(TestEnv.testPassword);
      await tester.doubleTapPad();
      expect(find.byType(ProfilingScreen), findsOneWidget);
      expect(env.tts.transcript, contains('Hakbang 1 ng 10.'));
    });

    testWidgets('fingerprint first when enabled; the password is the '
        'fallback', (tester) async {
      final env = await createEnv(
        tester,
        loggedIn: false,
        permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
      );
      final repo = AccountRepository(env.database.db, TestEnv.testHasher);
      final id = (await tester.runAsync(() async {
        final a = await repo.register(
          firstName: 'Ana',
          lastName: 'Cruz',
          email: TestEnv.testEmail,
          password: TestEnv.testPassword,
        );
        await repo.setProfilingCompleted(a.id, true);
        await repo.setFingerprint(a.id, true);
        return a.id;
      }))!;
      env.sessions.fingerprintUserId = id;
      env.biometrics
        ..enrolled = true
        ..next = BiometricResult.failed;
      await pumpApp(tester, env);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(env.biometrics.prompts, 1);
      expect(env.tts.transcript, contains('Hindi nakilala ang fingerprint.'));
      // The email is filled in; the password is asked.
      expect(env.tts.transcript, contains('Ano ang iyong password?'));

      env.biometrics.next = BiometricResult.success;
      await tester.say('fingerprint');
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(tester.scope.read(currentAccountProvider)?.id, id);
    });
  });

  testWidgets('forgot password: security question → new password', (
    tester,
  ) async {
    final env = await createEnv(
      tester,
      loggedIn: false,
      permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
    );
    final repo = AccountRepository(env.database.db, TestEnv.testHasher);
    await tester.runAsync(() async {
      final a = await repo.register(
        firstName: 'Ana',
        lastName: 'Cruz',
        email: TestEnv.testEmail,
        password: TestEnv.testPassword,
      );
      await repo.setSecurityAnswer(
        a.id,
        SecurityQuestion.favoriteFood,
        'Adobo',
      );
    });
    await pumpApp(tester, env);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.say('nakalimutan');
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      env.tts.transcript,
      contains('Maaari ring i-reset ng administrator ang iyong account.'),
    );

    await tester.say('ana at example dot com');
    await tester.say('submit');
    expect(env.tts.transcript, contains('Ano ang paborito mong pagkain?'));
    await tester.say('sinigang');
    await tester.say('submit');
    expect(env.tts.transcript, contains('Mali ang sagot.'));
    await tester.say('ADOBO!');
    await tester.say('submit');
    expect(env.tts.transcript, contains('Gumawa ng password'));
    await tester.say('bagong password 1');
    await tester.say('submit');
    expect(env.tts.transcript, contains('Napalitan na ang password.'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      await tester.runAsync(
        () => repo.verifyPassword(TestEnv.testEmail, 'bagongpassword1'),
      ),
      isNotNull,
    );
  });
}
