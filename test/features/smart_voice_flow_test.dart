// Smarter voice, end to end (2026-10-07): documents opened by name from
// any screen, choosing between two, "the last one", and questions on the
// Reader.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/command_bus.dart';
import 'package:percipere_app/features/home/home_screen.dart';
import 'package:percipere_app/features/reader/reader_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/library_seed.dart';
import '../helpers/library_ui.dart';
import '../helpers/pump_app.dart';

extension on WidgetTester {
  CommandBus get _bus => ProviderScope.containerOf(
    element(
      find.byType(HomeScreen).evaluate().isNotEmpty
          ? find.byType(HomeScreen)
          : find.byType(ReaderScreen),
    ),
  ).read(commandBusProvider);

  /// Says [phrase] with real time for the Library lookup, then settles.
  Future<void> sayReal(String phrase) async {
    final bus = _bus;
    await runAsync(() => bus.handleUtterance(phrase));
    await settleReal();
  }
}

void main() {
  testWidgets('"basahin ang …" on Home opens the document and reads it', (
    tester,
  ) async {
    final env = await withLibrary(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.sayReal('pakibasa nga ang liham kay nanay');
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Binubuksan ang Liham kay Nanay.'));
    bool readAloud() =>
        env.tts.spoken.any((s) => s.length > 10 && sampleText.contains(s));
    await tester.settleUntil(readAloud);
    // Reading started by itself: a sentence of the document was spoken.
    expect(readAloud(), isTrue);
  });

  testWidgets('two close titles: asks which one, "pangalawa" opens it', (
    tester,
  ) async {
    final env = await libraryEnv(tester);
    await tester.runAsync(() async {
      await seedDocument(env, title: 'Liham kay Nanay', text: sampleText);
      await seedDocument(env, title: 'Liham sa Barangay', text: sampleText);
    });
    env.books.offline = true;
    await pumpApp(tester, env);
    await tester.sayReal('buksan ang liham');
    expect(env.tts.transcript, contains('Alin sa dalawa:'));
    expect(find.byType(HomeScreen), findsOneWidget);
    final first = env.tts.transcript.contains('dalawa: Liham kay Nanay, o')
        ? 'Liham kay Nanay'
        : 'Liham sa Barangay';
    final second = first == 'Liham kay Nanay'
        ? 'Liham sa Barangay'
        : 'Liham kay Nanay';
    await tester.sayReal('pangalawa');
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(env.tts.transcript, contains('Binubuksan ang $second.'));
  });

  testWidgets('"ituloy ang pagbasa" opens the most recent one', (tester) async {
    final env = await withLibrary(tester);
    await tester.sayReal('ituloy ang pagbasa');
    expect(env.tts.transcript, contains('Binubuksan ang Florante at Laura.'));
  });

  testWidgets('an unknown title says it is not in the Library', (tester) async {
    final env = await withLibrary(tester);
    await tester.sayReal('basahin ang kalendaryo');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      env.tts.spoken.last,
      'Hindi ko nahanap ang “kalendaryo” sa Aklatan.',
    );
  });

  testWidgets('"buksan ang aklatan" is still the Library command', (
    tester,
  ) async {
    final env = await withLibrary(tester);
    await tester.sayReal('buksan ang aklatan');
    expect(env.tts.transcript, contains('Aklatan.'));
    expect(env.tts.transcript, isNot(contains('Hindi ko nahanap')));
  });

  testWidgets('Reader: "nasaan ako?" tells how far, "ilan pa?" too', (
    tester,
  ) async {
    final env = await withLibrary(tester);
    await tester.sayReal('buksan ang liham kay nanay');
    expect(find.byType(ReaderScreen), findsOneWidget);
    await tester.sayReal('nasaan ako');
    expect(env.tts.spoken.last, contains('Nasa pangungusap'));
    await tester.sayReal('ilan pa');
    expect(env.tts.spoken.last, contains('porsiyento'));
  });
}
