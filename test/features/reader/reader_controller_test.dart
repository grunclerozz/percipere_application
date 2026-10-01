import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/announcer.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/db/daos/documents_dao.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/tts/language_detector.dart';
import 'package:percipere_app/core/tts/reading_rate.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/features/reader/reader_controller.dart';

import '../../helpers/fakes.dart';

/// The five sentences of [sampleText], in order.
const s1 = 'Ang Bataan ay isang lalawigan sa rehiyon ng Gitnang Luzon.';
const s2Start = 'Kilala ito';
const s3 = 'Ang pagbabasa ay karapatan ng lahat.';
const s4Start = 'Sa tulong ng Percipere';
const s5Start = 'Maaari mong i-pause';

const _file = FileSource(DocumentFile(path: 'x.pdf', kind: DocumentKind.pdf));

void main() {
  late TestEnv env;
  late ProviderContainer container;
  final provider = readerControllerProvider(_file);
  ReaderController reader() => container.read(provider.notifier);
  ReaderState state() => container.read(provider);

  Future<void> setUpWith({
    FakeTts? tts,
    NavMode? mode,
    ReaderSource source = _file,
  }) async {
    env = await TestEnv.create(
      tts: tts ?? FakeTts(autoComplete: false),
      mode: mode,
      permissions: FakePermissions(mic: PermissionAccess.granted),
    );
    container = ProviderContainer(overrides: env.overrides);
    addTearDown(container.dispose);
    container
      ..listen(readerControllerProvider(source), (_, _) {})
      ..listen(announcerProvider, (_, _) {})
      ..listen(voiceControllerProvider, (_, _) {});
    // Let extraction and auto-save finish.
    await pumpEventQueue();
  }

  /// Finishes the sentence being spoken and lets the loop move on.
  Future<void> finish() async {
    env.tts.finishCurrent();
    await pumpEventQueue();
  }

  test('loads, chunks, detects language and auto-saves to history', () async {
    await setUpWith();
    final s = state();
    expect(s.phase, ReaderPhase.ready);
    expect(s.sentences, hasLength(5));
    expect(s.paragraphCount, 3);
    expect(s.language, DocLanguage.filipino);
    expect(s.index, 0);
    expect(s.current!.range.start, 0);

    final saved = await DocumentsDao(env.database.db).get(s.documentId!);
    expect(saved!.title, startsWith('Ang Bataan ay isang lalawigan'));
    expect(saved.sourceType, 'pdf');
    expect(saved.language, 'fil');
  });

  test('reads sentence by sentence with the Filipino voice', () async {
    await setUpWith();
    unawaited(reader().play());
    await pumpEventQueue();

    expect(state().playing, isTrue);
    expect(container.read(announcerProvider).reading, isTrue);
    expect(env.tts.spoken.last, s1);
    expect(env.tts.tags.last, 'fil-PH');
    expect(env.tts.rates.last, 1.0);

    await finish();
    expect(state().index, 1);
    expect(env.tts.spoken.last, startsWith(s2Start));
  });

  test('pause stops, confirms, and saves the position', () async {
    await setUpWith();
    unawaited(reader().play());
    await pumpEventQueue();
    await finish(); // now on sentence 2
    unawaited(reader().pause());
    await pumpEventQueue();
    env.tts.finishCurrent(); // "Naka-pause."
    await pumpEventQueue();

    expect(state().playing, isFalse);
    expect(container.read(announcerProvider).reading, isFalse);
    expect(env.tts.spoken.last, 'Naka-pause.');
    final saved = await DocumentsDao(env.database.db).get(state().documentId!);
    expect(saved!.lastPosition, 1);
  });

  test('next while playing jumps and keeps reading', () async {
    await setUpWith();
    unawaited(reader().play());
    await pumpEventQueue();
    unawaited(reader().skipSentence(1));
    await pumpEventQueue();

    expect(state().index, 1);
    expect(state().playing, isTrue);
    expect(env.tts.spoken.last, startsWith(s2Start));
    await finish();
    expect(env.tts.spoken.last, s3);
  });

  test('next while paused reads just that sentence', () async {
    await setUpWith();
    unawaited(reader().skipSentence(1));
    await pumpEventQueue();
    expect(env.tts.spoken.last, startsWith(s2Start));
    await finish();
    expect(state().playing, isFalse);
    expect(state().index, 1, reason: 'stays on the sentence it read');
  });

  test('paragraph navigation', () async {
    await setUpWith();
    env.tts.autoComplete = true;
    await reader().skipParagraph(1);
    expect(state().index, 2);
    expect(env.tts.spoken.last, s3);
    await reader().skipParagraph(1);
    expect(state().index, 4);
    expect(env.tts.spoken.last, startsWith(s5Start));
    await reader().skipSentence(-1);
    expect(state().index, 3);
    await reader().skipParagraph(-1); // to the start of its own paragraph
    expect(state().index, 2);
    await reader().skipParagraph(-1); // then the previous paragraph
    expect(state().index, 0);
  });

  test('at the edges it says so, with an error pulse', () async {
    await setUpWith(tts: FakeTts());
    await reader().skipSentence(-1);
    expect(env.tts.spoken.last, 'Ito na ang simula.');
    expect(env.haptics.events.last, 'error');
    expect(state().index, 0);
  });

  test('faster: caption, spoken, saved, and used for reading', () async {
    await setUpWith(tts: FakeTts());
    await reader().changeRate(ReadingRate.step);
    expect(state().caption, 'Bilis: 1.25x');
    expect(env.tts.spoken.last, 'Bilis: 1.25x');
    expect(container.read(readingRateProvider), 1.25);
    expect(
      await PreferencesDao(env.database.db).get(PrefKeys.readingRate),
      1.25,
    );

    env.tts.autoComplete = false;
    unawaited(reader().play());
    await pumpEventQueue();
    expect(env.tts.rates.last, 1.25);
  });

  test('speed is bounded', () async {
    await setUpWith(tts: FakeTts());
    for (var i = 0; i < 20; i++) {
      await reader().changeRate(ReadingRate.step);
    }
    expect(container.read(readingRateProvider), ReadingRate.max);
    expect(env.haptics.events.last, 'error');
    expect(state().caption, 'Bilis: 2.0x');
  });

  test('a speed change while reading resumes reading afterwards', () async {
    await setUpWith();
    unawaited(reader().play());
    await pumpEventQueue();
    unawaited(reader().changeRate(-ReadingRate.step));
    await pumpEventQueue();
    expect(env.tts.spoken.last, 'Bilis: 0.75x');
    await finish(); // caption done
    expect(state().playing, isTrue);
    expect(env.tts.spoken.last, s1, reason: 'the interrupted sentence again');
    expect(env.tts.rates.last, 0.75);
  });

  test('reaching the end announces it and restarts next time', () async {
    await setUpWith(tts: FakeTts());
    await reader().play();
    await pumpEventQueue();
    expect(state().index, 5);
    expect(state().current, isNull);
    expect(env.tts.spoken.last, 'Tapos na ang dokumento.');

    env.tts.spoken.clear();
    env.tts.autoComplete = false;
    unawaited(reader().play());
    await pumpEventQueue();
    expect(env.tts.spoken.single, s1);
  });

  test(
    'any other speech pauses reading (e.g. help, stop all speech)',
    () async {
      await setUpWith();
      unawaited(reader().play());
      await pumpEventQueue();
      unawaited(container.read(announcerProvider.notifier).say('Tulong.'));
      await pumpEventQueue();
      expect(state().playing, isFalse);
      expect(env.tts.spoken.last, 'Tulong.');
    },
  );

  test('"mula sa simula" restarts from the first sentence', () async {
    await setUpWith(tts: FakeTts());
    await reader().skipParagraph(1);
    env.tts.autoComplete = false;
    unawaited(reader().readFromStart());
    await pumpEventQueue();
    expect(env.tts.spoken.last, 'Mula sa simula.');
    await finish();
    expect(env.tts.spoken.last, s1);
    expect(state().playing, isTrue);
  });

  test('English documents use the English voice', () async {
    const english = TextSource(
      'Please bring this form to the barangay hall. The office is open.',
    );
    await setUpWith(source: english);
    final c = container.read(readerControllerProvider(english).notifier);
    unawaited(c.play());
    await pumpEventQueue();
    expect(
      container.read(readerControllerProvider(english)).language,
      DocLanguage.english,
    );
    expect(env.tts.tags.last, 'en-US');
  });

  test(
    'Filipino document without a Filipino voice: English voice, flagged',
    () async {
      await setUpWith(
        tts: FakeTts(
          autoComplete: false,
          voices: const VoiceStatus(filipinoReady: false),
        ),
      );
      expect(reader().filipinoWithoutVoice, isTrue);
      unawaited(reader().play());
      await pumpEventQueue();
      expect(env.tts.tags.last, 'en-US');
    },
  );

  test('history: resumes at the saved position', () async {
    await setUpWith(tts: FakeTts());
    final dao = DocumentsDao(env.database.db);
    final id = await dao.insert(
      title: 'Liham',
      fullText: sampleText,
      sourceType: 'docx',
      language: 'fil',
    );
    await dao.updatePosition(id, 3);

    final history = HistorySource(id);
    container.listen(readerControllerProvider(history), (_, _) {});
    await pumpEventQueue();
    final s = container.read(readerControllerProvider(history));
    expect(s.index, 3);
    expect(s.resumedFrom, 3);
    expect(s.documentId, id);
    expect((await dao.get(id))!.lastOpenedAt, isNotNull);

    await container.read(readerControllerProvider(history).notifier).play();
    expect(env.tts.spoken.first, startsWith(s4Start));
  });

  test('voice mode never listens while a document is being read', () async {
    await setUpWith(mode: NavMode.voice);
    unawaited(reader().play());
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(env.speech.listening, isFalse);

    unawaited(reader().pause(quiet: true));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(env.speech.listening, isTrue, reason: 'listens once paused');
  });

  test('quality is kept from extraction', () async {
    await setUpWith(tts: FakeTts());
    expect(state().quality, TextQuality.good);
  });
}
