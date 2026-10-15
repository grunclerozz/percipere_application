import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/app.dart';
import 'package:percipere_app/core/offline_voice/model_store.dart';
import 'package:percipere_app/core/offline_voice/offline_engines.dart';
import 'package:percipere_app/core/offline_voice/offline_voice_setup.dart';
import 'package:percipere_app/features/offline_voice/offline_voice_setup_screen.dart';
import 'package:percipere_app/features/welcome/welcome_screen.dart';

import '../helpers/pump_app.dart';

/// First launch: the offline voices are downloaded before Welcome.
void main() {
  testWidgets('no internet: says so once and goes on to Welcome',
      (tester) async {
    final env = await createEnv(tester)..online = false;
    final dir = Directory.systemTemp.createTempSync('voice_setup');
    addTearDown(() => dir.deleteSync(recursive: true));
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          modelStoreProvider.overrideWithValue(ModelStore(dir.path)),
          offlineVoiceSetupPendingProvider.overrideWithValue(true),
        ],
        child: const PercipereApp(),
      ),
    );
    // The screen opens first; offline it finishes within a few frames.
    expect(find.byType(OfflineVoiceSetupScreen), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(
      env.tts.transcript,
      contains('Pakihintay habang dina-download namin ang mga boses at wika.'),
    );
    expect(env.tts.transcript, contains('Walang internet ngayon'));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      'Walang internet ngayon'.allMatches(env.tts.transcript),
      hasLength(1),
    );
  });

  testWidgets('models already there: no download screen', (tester) async {
    final env = await createEnv(tester);
    await setSurface(tester, phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...env.overrides,
          offlineVoiceSetupPendingProvider.overrideWithValue(false),
        ],
        child: const PercipereApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OfflineVoiceSetupScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
