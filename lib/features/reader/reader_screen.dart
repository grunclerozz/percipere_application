import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/assistant/reader_snapshot.dart';
import '../../core/extraction/extraction_exception.dart';
import '../../core/library/library_models.dart';
import '../../core/ocr/text_cleanup.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/understanding/document_insights.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/understanding.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/document_box.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import '../library/favorites_screen.dart';
import 'reader_controller.dart';

/// Screen C — Reader: the Document Box replaces the Speaking Zone, and the
/// Gesture Pad carries all reading controls.
///
/// Gestures (via intents): double-tap = read/pause, swipe right/left =
/// next/previous sentence, two-finger swipe down/up = next/previous
/// paragraph, swipe up/down = faster/slower, tap = repeat sentence,
/// two-finger double-tap = stop (pause), two-finger swipe right = back
/// (reading stops and the position is saved first). With auto-read on,
/// a new document starts reading as soon as its text is ready. Voice adds "basahin", "i-pause", "ituloy",
/// "mula sa simula", "i-save", and "palakihin" / "paliitin" (text size, also
/// the A+/A− buttons and pinching the Document Box). The sentence being read is highlighted and
/// kept in view; system messages appear as a caption strip.
class ReaderScreen extends ConsumerStatefulWidget {
  /// Creates the Reader for [source].
  const ReaderScreen({super.key, required this.source});

  /// Screen id.
  static const String screenId = Ids.reader;

  /// What to read.
  final ReaderSource source;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final _provider = readerControllerProvider(widget.source);

  late final ReaderSnapshotNotifier _snapshots = ref.read(
    readerSnapshotProvider.notifier,
  );
  ReaderSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_provider, _onChange);
    // What the voice assistant can see (providers can't change mid-build).
    ref.listenManual(
      _provider,
      (_, s) => scheduleMicrotask(() => _publish(s)),
      fireImmediately: true,
    );
  }

  void _publish(ReaderState s) {
    if (!mounted) return;
    final snapshot = _lastSnapshot = ReaderSnapshot(
      title: s.title,
      text: s.text,
      sentence: s.index,
      sentenceCount: s.sentences.length,
      playing: s.playing,
      canRead: s.canRead,
    );
    _snapshots.set(snapshot);
  }

  @override
  void dispose() {
    final last = _lastSnapshot;
    final snapshots = _snapshots;
    // Only clear what this Reader published (a newer Reader may be open).
    scheduleMicrotask(() => snapshots.clearIf(last));
    super.dispose();
  }

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);
  ReaderController get _controller => ref.read(_provider.notifier);

  void _onChange(ReaderState? previous, ReaderState next) {
    if (next.phase == ReaderPhase.loading &&
        next.page != previous?.page &&
        next.pageCount > 1 &&
        (next.pageCount <= 10 || next.page % 5 == 1)) {
      // Queued: progress never cuts off the screen's own announcement.
      unawaited(
        ref
            .read(announcerProvider.notifier)
            .say(
              _l.readerExtractingPage(next.page, next.pageCount),
              interrupt: false,
            ),
      );
    }
    if (previous?.phase == ReaderPhase.loading &&
        next.phase != ReaderPhase.loading) {
      final text = _outcome(next, _l);
      if (_offersRetake(next)) {
        unawaited(_bus.offer('$text ${_l.readerRetakeOffer}', _retake));
      } else if (_autoReads(next)) {
        unawaited(_announceThenRead(text));
      } else {
        unawaited(_bus.say(text));
      }
    }
  }

  /// New documents (camera or upload) start reading by themselves when
  /// auto-read is on and the text is usable.
  bool _autoReads(ReaderState s) {
    if (!s.canRead || _offersRetake(s)) return false;
    final source = widget.source;
    // "Basahin ang …" asked for reading now.
    if (source is ItemSource && source.play) return true;
    return source is FileSource && ref.read(settingsProvider).autoRead;
  }

  Future<void> _announceThenRead(String text) async {
    final asked = DateTime.now();
    await _bus.say(text);
    if (!mounted) return;
    final s = ref.read(_provider);
    // Not if the user already started, paused or left meanwhile â€” nor if
    // they held the gesture area to speak (or gave a command) while it was
    // being said: reading would close their listening session (2026-10-17
    // tablet test: "voice not working" right after an upload).
    if (s.playing ||
        ref.read(activeScreenProvider)?.id != ReaderScreen.screenId) {
      return;
    }
    if (ref.read(voiceControllerProvider.notifier).userTurnSince(asked)) {
      debugPrint('[VOICE] auto-read skipped: the user is talking');
      return;
    }
    await _controller.play();
  }

  static bool _offersRetake(ReaderState s) =>
      s.fromCamera &&
      s.phase == ReaderPhase.ready &&
      s.quality != TextQuality.good;

  /// What to say once loading ends (and to show when there's no text).
  String _outcome(ReaderState s, AppLocalizations l) {
    if (s.phase == ReaderPhase.failed) {
      return switch (s.failure) {
        ExtractionFailure.unsupported => l.readerUnsupported,
        ExtractionFailure.passwordProtected => l.readerPasswordProtected,
        ExtractionFailure.missing => l.readerFileMissing,
        ExtractionFailure.ocrUnavailable => l.readerOcrFailed,
        ExtractionFailure.failed => l.readerExtractFailed,
        ExtractionFailure.unreadable || null => l.readerUnreadable,
      };
    }
    if (s.quality == TextQuality.empty) {
      return s.fromCamera
          ? '${l.readerNoText} ${l.readerPhotoTips}'
          : l.readerNoText;
    }
    return [
      // A new document's kind and key facts come first.
      if (widget.source is FileSource && s.quality == TextQuality.good)
        ...insightLines(s.insights, l),
      if (s.quality == TextQuality.low) l.readerLowQuality,
      if (s.quality == TextQuality.low && s.fromCamera) l.readerPhotoTips,
      l.readerReadyParagraphs(s.paragraphCount),
      // Never read Filipino with an English voice without saying so.
      if (_controller.filipinoWithoutVoice) l.readerFilipinoNoVoice,
      if (s.resumedFrom != null)
        l.readerResumeAt(s.resumedFrom! + 1, s.sentences.length),
      if (!_offersRetake(s) && !_autoReads(s)) l.readerStartHint,
    ].join(' ');
  }

  void _retake() => ref.read(routerProvider).pushReplacement(AppRoutes.camera);

  /// What is said about a new document before reading: its kind, who it is
  /// from and its key facts (nothing when the kind is unclear).
  static List<String> insightLines(DocumentInsights d, AppLocalizations l) {
    if (d.type == DocType.other) return const [];
    return [
      typeLine(d.type, l),
      if (d.from case final from?)
        d.type == DocType.letter ? l.docLetterTo(from) : l.docFrom(from),
      if (d.total case final total?) l.docTotal(total),
      if (d.dueDate case final due?) l.docDue(due),
      if (d.expiry case final expiry?) l.docExpiry(expiry),
      if (d.dosage case final dosage?) l.docDosage(dosage),
      l.docAskHint,
    ];
  }

  /// "Mukhang resibo ito." etc.
  static String typeLine(DocType type, AppLocalizations l) => switch (type) {
    DocType.receipt => l.docTypeReceipt,
    DocType.bill => l.docTypeBill,
    DocType.medicine => l.docTypeMedicine,
    DocType.letter => l.docTypeLetter,
    DocType.form => l.docTypeForm,
    DocType.other => l.docTypeOther,
  };

  /// "Nasa pangungusap 12 ng 40 ka, mga 30 porsiyento. Kabanata 2 ng 5."
  String _progress(AppLocalizations l) {
    final s = ref.read(_provider);
    if (!s.canRead) return '';
    final total = s.sentences.length;
    final current = s.index >= total ? total : s.index + 1;
    final percent = (current * 100 / total).round();
    return [
      l.readerProgress('$current', '$total', '$percent'),
      if (s.hasChapters)
        l.readerProgressChapter(
          '${s.chapter + 1}',
          '${s.chapterStarts.length}',
        ),
    ].join(' ');
  }

  /// Answers a question about the open document ("magkano?", "ibuod mo").
  Future<void> _answerDocument(Question q, CommandBus bus) async {
    final s = ref.read(_provider);
    if (s.phase == ReaderPhase.loading) return bus.say(_l.readerLoading);
    if (!s.canRead) return bus.notAvailable();
    final l = _l;
    if (q == Question.progress) return bus.say(_progress(l));
    final d = await _controller.insights();
    if (!mounted) return;
    final answer = switch (q) {
      Question.docType => [
        typeLine(d.type, l),
        if (d.from case final from?)
          d.type == DocType.letter ? l.docLetterTo(from) : l.docFrom(from),
      ].join(' '),
      Question.total => d.total == null ? l.docNoTotal : l.docTotal(d.total!),
      Question.due => d.dueDate == null ? l.docNoDue : l.docDue(d.dueDate!),
      Question.expiry =>
        d.expiry == null ? l.docNoExpiry : l.docExpiry(d.expiry!),
      Question.dosage =>
        d.dosage == null ? l.docNoDosage : l.docDosage(d.dosage!),
      Question.summary =>
        d.summary.isEmpty ? l.docNoSummary : l.docSummary(d.summary.join(' ')),
      _ => _progress(l),
    };
    // Reading pauses for the answer ("ituloy" carries on).
    await _controller.pause(quiet: true);
    await bus.say(answer);
  }

  /// "Mga paborito ko": lists the favorites of this item; choosing one jumps
  /// there and carries on reading.
  Future<void> _showFavorites(CommandBus bus) async {
    final id = ref.read(_provider).itemId;
    if (id == null) return bus.notAvailable();
    await _controller.pause(quiet: true);
    // Not awaited: the choice arrives when the list closes.
    unawaited(
      ref
          .read(routerProvider)
          .push<Object?>(
            AppRoutes.favorites,
            extra: FavoritesArgs(id, forReader: true),
          )
          .then((picked) async {
            if (picked is Favorite && mounted) {
              await _controller.goTo(picked.chapterIndex, picked.sentenceIndex);
            }
          }),
    );
  }

  /// Runs [action] when the document can be read; otherwise explains.
  BusHandler _reading(Future<void> Function(ReaderController c) action) =>
      (bus) {
        final s = ref.read(_provider);
        if (s.phase == ReaderPhase.loading) return bus.say(_l.readerLoading);
        if (!s.canRead) return bus.notAvailable();
        return action(_controller);
      };

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: ReaderScreen.screenId,
    title: (l) => l.screenReader,
    // Evaluated when announced, so it reflects progress so far.
    prompt: (l) {
      final s = ref.read(_provider);
      if (s.phase == ReaderPhase.loading) return l.readerLoading;
      final outcome = _outcome(s, l);
      return _offersRetake(s) ? '$outcome ${l.readerRetakeOffer}' : outcome;
    },
    // How to accept the retake, only if no answer comes.
    followUp: (l) =>
        _offersRetake(ref.read(_provider)) ? l.offerConfirmHint : '',
    includeModeHint: false,
    help: (l) => l.helpReader,
    // Stop reading and save the position before leaving.
    beforeBack: () => _controller.pause(quiet: true),
    // Reads only whole phrases, so partial results can run commands.
    freeTextPrefixes: const [],
    // "mga paborito ko" lists the favorites; without this the "Paborito"
    // button's own label would match it and save a new one.
    onUtterance: (text, bus) async {
      final said = CommandMatcher.normalize(text);
      if (said.contains('mga paborito') || said.contains('my favorites')) {
        await _showFavorites(bus);
        return true;
      }
      final question = Understanding.documentQuestion(text);
      if (question != null) {
        await _answerDocument(question, bus);
        return true;
      }
      return false;
    },
    // "Nasaan ako?" adds how far the reading is.
    whereAmI: _progress,
    actions: [
      A11yAction(
        id: Ids.readerFavorite,
        label: (l) => l.readerFavorite,
        voiceSynonyms: const ['favorite', 'paborito', 'i-favorite ito'],
        confirmation: (_) => '',
        onActivate: _reading((c) => c.addFavorite()),
      ),
    ],
    intentHandlers: {
      NavIntent.favorite: _reading((c) => c.addFavorite()),
      NavIntent.favorites: _showFavorites,
      NavIntent.nextChapter: _reading((c) => c.skipChapter(1)),
      NavIntent.previousChapter: _reading((c) => c.skipChapter(-1)),
      NavIntent.activate: _reading((c) => c.togglePlay()),
      NavIntent.read: _reading((c) => c.play()),
      NavIntent.resume: _reading((c) => c.play()),
      NavIntent.pause: _reading((c) => c.pause()),
      NavIntent.stopSpeech: _reading((c) => c.pause()),
      NavIntent.next: _reading((c) => c.skipSentence(1)),
      NavIntent.previous: _reading((c) => c.skipSentence(-1)),
      NavIntent.nextParagraph: _reading((c) => c.skipParagraph(1)),
      NavIntent.previousParagraph: _reading((c) => c.skipParagraph(-1)),
      NavIntent.repeat: _reading((c) => c.repeatSentence()),
      NavIntent.textBigger: _reading((c) => c.changeTextSize(1)),
      NavIntent.textSmaller: _reading((c) => c.changeTextSize(-1)),
      NavIntent.faster: _reading((c) => c.changeRate(ReadingRate.step)),
      NavIntent.slower: _reading((c) => c.changeRate(-ReadingRate.step)),
      NavIntent.readFromStart: _reading((c) => c.readFromStart()),
      NavIntent.save: _reading((c) => c.save()),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(_provider);
    final hasText = s.phase == ReaderPhase.ready && s.text.isNotEmpty;

    return AccessibleScreen(
      registration: _registration,
      child: GesturePadLayout(
        padHint: l10n.gestureAreaHintReader,
        content: DocumentBox(
          text: hasText ? s.text : null,
          isLoading: s.phase == ReaderPhase.loading,
          loadingMessage: s.pageCount > 1
              ? l10n.readerExtractingPage(s.page, s.pageCount)
              : null,
          emptyMessage: s.phase == ReaderPhase.loading || hasText
              ? null
              : _outcome(s, l10n),
          highlight: s.current?.range,
          caption: s.caption,
          favoriteLabel: hasText ? l10n.readerFavorite : null,
          onFavorite: hasText ? () => _bus.dispatch(NavIntent.favorite) : null,
          // Buttons, pinch and voice all go through the same intents.
          onTextSize: hasText
              ? (direction) => _bus.dispatch(
                  direction > 0 ? NavIntent.textBigger : NavIntent.textSmaller,
                )
              : null,
        ),
      ),
    );
  }
}
