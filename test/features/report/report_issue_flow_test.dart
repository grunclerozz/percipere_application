import 'dart:async';

// "Mag-report ng problema" through the screens, by voice: every page,
// severity skipped for non-bugs, dictation read back, email, review, edit,
// ticket; offline then sent when the connection returns; cancel and back;
// "Aking mga report".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/router.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_repository.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/report/my_reports_screen.dart';
import 'package:percipere_app/features/report/report_issue_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

extension on WidgetTester {
  ProviderContainer get scope =>
      ProviderScope.containerOf(element(find.byType(Scaffold).first));

  Future<void> say(String words) async {
    await scope.read(commandBusProvider).handleUtterance(words);
    await pumpAndSettle();
  }
}

Future<(TestEnv, FakeIssueReportApi)> _start(
  WidgetTester tester, {
  bool loggedIn = true,
}) async {
  final env = await createEnv(
    tester,
    loggedIn: loggedIn,
    permissions: FakePermissions(micOnRequest: PermissionAccess.denied),
  );
  final api = FakeIssueReportApi();
  env.reportApi = api;
  await pumpApp(tester, env);
  return (env, api);
}

Future<List<IssueReport>> _saved(WidgetTester tester, TestEnv env) async =>
    (await tester.runAsync(() async {
      final repo = IssueReportRepository(env.database.db);
      final id = env.account?.id;
      return [...await repo.mine(id), if (id != null) ...await repo.mine(null)];
    }))!;

const _what = 'hindi bumubukas ang camera kapag pinindot ko';

void main() {
  testWidgets('a bug, by voice from Home: every page speaks its question and '
      'options, the description is read back, the account email is offered, '
      'the review reads it all, then the ticket', (tester) async {
    final (env, api) = await _start(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.say('mag-report');
    expect(find.byType(ReportIssueScreen), findsOneWidget);
    final t = env.tts.transcript;
    expect(t, contains('Sasagutin mo ang ilang tanong, isa-isa.'));
    expect(t, contains('Anong uri ng report ito?'));
    expect(t, contains('May sira (Bug)'));
    expect(t, contains('Mungkahi (Feature request)'));

    await tester.say('may sira');
    expect(env.tts.transcript, contains('Saang bahagi ng app?'));
    expect(env.tts.transcript, contains('Aklatan (Library)'));

    await tester.say('camera');
    expect(env.tts.transcript, contains('Gaano kalala ang problema?'));
    expect(
      env.tts.transcript,
      contains('Kritikal: nagsasara ang app o may nawalang data'),
    );

    await tester.say('kritikal');
    expect(
      env.tts.transcript,
      contains('Ano ang nangyari? Ikuwento sa boses, o i-type.'),
    );
    await tester.say(_what);
    expect(env.tts.transcript, contains('Narinig ko: $_what. Tama ba?'));
    await tester.say('oo');

    expect(
      env.tts.transcript,
      contains('Gamitin ang email na ito: ${TestEnv.testEmail}?'),
    );
    await tester.say('oo');

    final review = env.tts.transcript;
    expect(review, contains('Uri: May sira (Bug).'));
    expect(review, contains('Bahagi: Camera.'));
    expect(review, contains('Kalala: Kritikal.'));
    expect(review, contains('Nangyari: $_what.'));
    expect(review, contains('Email: ${TestEnv.testEmail}.'));
    expect(
      review,
      contains(
        'Kasama rin: bersyon ng app 0.1.1+2, Android 14 (SDK 34), '
        'Test Tablet, mula sa home,',
      ),
    );
    expect(review, contains('(RA 10173)'));

    await tester.say('ipadala');
    expect(env.tts.transcript, contains('Salamat sa iyong report.'));
    expect(env.tts.transcript, contains('Katayuan: Naipadala.'));

    final saved = (await _saved(tester, env)).single;
    expect(IssueRules.isTicket(saved.ticketNo), isTrue);
    expect(saved.status, IssueSyncStatus.sent);
    expect(
      env.tts.transcript,
      contains(IssueRules.spokenTicket(saved.ticketNo)),
    );
    expect(api.received[saved.ticketNo], {
      'ticket_no': saved.ticketNo,
      'type': 'Bug',
      'module': 'Camera',
      'severity': 'Critical',
      'description': _what,
      'email': TestEnv.testEmail,
      'app_version': '0.1.1+2',
      'os_version': 'Android 14 (SDK 34)',
      'device_model': 'Test Tablet',
      'source_screen': 'home',
      'created_at': saved.createdAt.toUtc().toIso8601String(),
    });

    await tester.say('tapos na');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a guest\'s feature request: no severity page, email skipped, '
      'sent later when the connection returns', (tester) async {
    final (env, api) = await _start(tester, loggedIn: false);
    api.offline = true;
    await tester.say('may problema');
    expect(find.byType(ReportIssueScreen), findsOneWidget);
    await tester.say('mungkahi');
    await tester.say('iba pa');
    expect(env.tts.transcript, isNot(contains('Gaano kalala ang problema?')));
    await tester.say('sana may mas malaking letra sa menu');
    await tester.say('oo');
    expect(
      env.tts.transcript,
      contains('Ano ang iyong email? Pwede mo itong laktawan.'),
    );
    await tester.say('laktawan');
    expect(env.tts.transcript, contains('Email: walang email.'));
    expect(env.tts.transcript, isNot(contains('Kalala:')));
    await tester.say('ipadala');
    expect(env.tts.transcript, contains('Katayuan: Naghihintay ipadala.'));
    expect(
      env.tts.transcript,
      contains('Naka-save ang report, at ipapadala ito kapag may internet.'),
    );
    var saved = (await _saved(tester, env)).single;
    expect(saved.status, IssueSyncStatus.pending);
    expect(saved.severity, isNull);
    expect(saved.email, isNull);

    api.offline = false;
    env.connectionRestored.add(null);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    saved = (await _saved(tester, env)).single;
    expect(saved.status, IssueSyncStatus.sent);
    expect(api.received[saved.ticketNo]!['severity'], isNull);
  });

  testWidgets('description: too short is refused; "hindi" asks again; '
      'a wrong email is caught', (tester) async {
    final (env, _) = await _start(tester, loggedIn: false);
    await tester.say('mag-report');
    await tester.say('puna');
    await tester.say('camera');
    await tester.say('sira');
    await tester.say('oo');
    expect(
      env.tts.transcript,
      contains('Masyadong maikli. Hindi bababa sa 10 titik.'),
    );
    await tester.say('nawawala ang boses');
    await tester.say('hindi');
    expect(
      env.tts.transcript,
      contains('Sige, sabihin ulit kung ano ang nangyari.'),
    );
    await tester.say('nawawala ang boses habang nagbabasa');
    await tester.say('oo');
    await tester.say('juan at example');
    expect(
      env.tts.transcript,
      contains('Mukhang mali ang email. Ulitin, o sabihin ang “laktawan”.'),
    );
    await tester.say('susunod');
    expect(env.tts.transcript, isNot(contains('Repasuhin')));
    await tester.say('juan at example dot com');
    expect(env.tts.transcript, contains('Email: juan@example.com.'));
    await tester.say('susunod');
    expect(env.tts.transcript, contains('Email: juan@example.com.'));
    expect(env.tts.transcript, contains('Repasuhin ang iyong report.'));
  });

  testWidgets('back goes to the previous page; cancel asks first; editing '
      'from the review returns to it', (tester) async {
    final (env, _) = await _start(tester);
    await tester.say('mag-report');
    await tester.say('may sira');
    await tester.say('bumalik');
    expect(env.tts.transcript.split('Anong uri ng report ito?'), hasLength(3));

    await tester.say('puna');
    await tester.say('kanselahin');
    expect(
      env.tts.transcript,
      contains('Kanselahin ang report? Mawawala ang iyong mga sagot.'),
    );
    await tester.say('hindi');
    expect(find.byType(ReportIssueScreen), findsOneWidget);

    await tester.say('camera');
    await tester.say('mali ang pagbasa ng resibo');
    await tester.say('oo');
    await tester.say('oo');
    expect(env.tts.transcript, contains('Bahagi: Camera.'));
    await tester.say('baguhin');
    expect(env.tts.transcript, contains('Alin ang babaguhin?'));
    await tester.say('bahagi');
    await tester.say('iba pa');
    expect(env.tts.transcript, contains('Bahagi: Iba pa (Other).'));
    expect(env.tts.transcript, isNot(contains('Gaano kalala')));

    await tester.say('kanselahin');
    await tester.say('oo');
    expect(env.tts.transcript, contains('Kinansela ang report.'));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await _saved(tester, env), isEmpty);
  });

  testWidgets('"Aking mga report" lists the reports; choosing one reads it', (
    tester,
  ) async {
    final (env, _) = await _start(tester);
    await tester.say('mag-report');
    await tester.say('mungkahi');
    await tester.say('percy');
    await tester.say('sana marunong si percy ng ingles');
    await tester.say('oo');
    await tester.say('oo');
    await tester.say('ipadala');
    await tester.say('tapos na');
    final saved = (await _saved(tester, env)).single;

    unawaited(tester.scope.read(routerProvider).push(AppRoutes.myReports));
    await tester.pumpAndSettle();
    expect(find.byType(MyReportsScreen), findsOneWidget);
    expect(
      env.tts.transcript,
      contains('Bilang ng report: 1. Pumili ng isa para marinig.'),
    );
    await tester.scope
        .read(commandBusProvider)
        .activate('myReports.${saved.id}');
    await tester.pumpAndSettle();
    expect(env.tts.transcript, contains('Bahagi: Percy.'));
    expect(env.tts.transcript, contains('Katayuan: Naipadala.'));
  });
}
