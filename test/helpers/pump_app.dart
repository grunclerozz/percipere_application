import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/app.dart';
import 'package:percipere_app/app/locale_provider.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/app/theme/app_theme.dart';
import 'package:percipere_app/app/theme/theme_settings.dart';
import 'package:percipere_app/config/voice_config.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/l10n/app_localizations.dart';

import 'fakes.dart';

/// Phone-sized test surface (logical pixels).
const Size phoneSize = Size(390, 844);

/// Pumps [child] inside a themed, localized MaterialApp on a phone-sized
/// surface. Screens get a fresh [TestEnv] unless [overrides] are given.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocales.filipino,
  ThemeId theme = ThemeId.creamNavy,
  Size size = phoneSize,
  List<Override>? overrides,
}) async {
  await setSurface(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? (await createEnv(tester)).overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(ThemeSettings(theme: theme)),
        locale: locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

/// Creates a [TestEnv] on the real clock: the first native SQLite load must
/// not run inside the widget tester's fake-async zone.
Future<TestEnv> createEnv(
  WidgetTester tester, {
  FakeTts? tts,
  FakeSpeechInput? speech,
  FakePermissions? permissions,
  NavMode? mode,
  AppSettings? appSettings,
  bool? loggedIn,
  bool setupDone = true,
  bool describeIntroSeen = true,
}) async => (await tester.runAsync(
  () => TestEnv.create(
    loggedIn: loggedIn,
    setupDone: setupDone,
    describeIntroSeen: describeIntroSeen,
    tts: tts,
    speech: speech,
    permissions: permissions,
    mode: mode,
    appSettings: appSettings,
  ),
))!;

/// Pumps the whole app (router, host, announcements) with [env].
Future<void> pumpApp(WidgetTester tester, TestEnv env) async {
  await setSurface(tester, phoneSize);
  await tester.pumpWidget(
    ProviderScope(overrides: env.overrides, child: const PercipereApp()),
  );
  await tester.pumpAndSettle();
}

/// Sets the test surface size and resets it after the test.
Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps the whole app and opens Capture from Home ("Magbasa ng bago"), the
/// way a user gets there now.
Future<void> pumpAppOnCapture(WidgetTester tester, TestEnv env) async {
  await pumpApp(tester, env);
  await tester.tap(find.text('Magbasa ng bago'));
  await tester.pumpAndSettle();
}

/// Lets the answer wait after a question pass without an answer, so the
/// instructions held back after it (how to answer, the mode hint, queued
/// notices) are spoken.
extension AnswerWait on WidgetTester {
  Future<void> waitOutQuestion() async {
    await pump(VoiceConfig.answerWait + const Duration(milliseconds: 100));
    // Fixed steps, not pumpAndSettle: the listening animation never settles.
    for (var i = 0; i < 10; i++) {
      await pump(const Duration(milliseconds: 100));
    }
  }
}
