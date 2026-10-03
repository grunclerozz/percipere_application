import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_settings.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/auth/guest_reminders.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/documents_dao.dart';
import '../../core/extraction/document_extractor.dart';
import '../../core/extraction/extraction_exception.dart';
import '../../core/ocr/text_cleanup.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/chunker.dart';
import '../../core/tts/language_detector.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/tts/tts_service.dart';
import '../../l10n/app_localizations.dart';

/// What the Reader opens.
@immutable
sealed class ReaderSource {
  const ReaderSource();
}

/// Text that is already extracted. Saved to history only if [save].
final class TextSource extends ReaderSource {
  /// Creates a text source.
  const TextSource(this.text, {this.save = false});

  /// The text.
  final String text;

  /// Add it to Reading History.
  final bool save;

  @override
  bool operator ==(Object other) =>
      other is TextSource && other.text == text && other.save == save;

  @override
  int get hashCode => Object.hash(text, save);
}

/// A file still to be read (camera photo or upload); saved to history.
final class FileSource extends ReaderSource {
  /// Creates a file source.
  const FileSource(this.file);

  /// The file.
  final DocumentFile file;

  @override
  bool operator ==(Object other) => other is FileSource && other.file == file;

  @override
  int get hashCode => file.hashCode;
}

/// A Reading History entry, resumed at its saved position.
final class HistorySource extends ReaderSource {
  /// Creates a history source.
  const HistorySource(this.documentId);

  /// `documents.id`.
  final int documentId;

  @override
  bool operator ==(Object other) =>
      other is HistorySource && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}

/// Reader lifecycle.
enum ReaderPhase {
  /// Extracting text.
  loading,

  /// Text available (possibly empty or low quality — see [ReaderState.quality]).
  ready,

  /// The file couldn't be read.
  failed,
}

/// State of the Reader for one source.
@immutable
class ReaderState {
  /// Creates a state.
  const ReaderState({
    required this.phase,
    this.text = '',
    this.quality = TextQuality.good,
    this.page = 0,
    this.pageCount = 0,
    this.failure,
    this.fromCamera = false,
    this.sentences = const [],
    this.index = 0,
    this.playing = false,
    this.language = DocLanguage.filipino,
    this.documentId,
    this.resumedFrom,
    this.caption,
  });

  /// Lifecycle phase.
  final ReaderPhase phase;

  /// Clean document text (paragraphs separated by a blank line).
  final String text;

  /// How usable [text] looks.
  final TextQuality quality;

  /// Page being extracted (multi-page PDFs), 1-based; 0 if unknown.
  final int page;

  /// Pages in the document; 0 if unknown.
  final int pageCount;

  /// Why it failed, when [phase] is [ReaderPhase.failed].
  final ExtractionFailure? failure;

  /// The document is a camera photo (so "take it again" makes sense).
  final bool fromCamera;

  /// Sentences of [text], in reading order.
  final List<Sentence> sentences;

  /// Current sentence; `sentences.length` once the end was reached.
  final int index;

  /// Reading aloud right now.
  final bool playing;

  /// Detected document language (chooses the voice).
  final DocLanguage language;

  /// Reading History id, once saved.
  final int? documentId;

  /// Sentence index the document was resumed at (history), if not 0.
  final int? resumedFrom;

  /// Short system message pinned in the Document Box ("Bilis: 1.2x").
  final String? caption;

  /// Paragraph count.
  int get paragraphCount =>
      sentences.isEmpty ? 0 : sentences.last.paragraph + 1;

  /// The sentence to highlight, if any.
  Sentence? get current =>
      index >= 0 && index < sentences.length ? sentences[index] : null;

  /// Whether reading controls apply.
  bool get canRead => phase == ReaderPhase.ready && sentences.isNotEmpty;

  static const Object _keep = Object();

  /// Returns a copy with the given fields replaced ([caption] can be set to
  /// null explicitly).
  ReaderState copyWith({
    ReaderPhase? phase,
    String? text,
    TextQuality? quality,
    int? page,
    int? pageCount,
    ExtractionFailure? failure,
    List<Sentence>? sentences,
    int? index,
    bool? playing,
    DocLanguage? language,
    int? documentId,
    int? resumedFrom,
    Object? caption = _keep,
  }) => ReaderState(
    phase: phase ?? this.phase,
    text: text ?? this.text,
    quality: quality ?? this.quality,
    page: page ?? this.page,
    pageCount: pageCount ?? this.pageCount,
    failure: failure ?? this.failure,
    fromCamera: fromCamera,
    sentences: sentences ?? this.sentences,
    index: index ?? this.index,
    playing: playing ?? this.playing,
    language: language ?? this.language,
    documentId: documentId ?? this.documentId,
    resumedFrom: resumedFrom ?? this.resumedFrom,
    caption: identical(caption, _keep) ? this.caption : caption as String?,
  );
}

/// Loads a [ReaderSource] and reads it aloud sentence by sentence.
///
/// - Extraction runs in the background (native engines and isolates).
/// - Reading uses TTS directly, one sentence per call, so pause/skip/
///   highlight are exact. Each loop run has a token: pausing or skipping bumps
///   it, so a stopped sentence is told apart from one interrupted by someone
///   else (a prompt, "stop all speech", long-press to talk) — which pauses.
/// - Documents are auto-saved to Reading History; the position is saved on
///   pause, every few sentences, and when the Reader closes.
class ReaderController extends Notifier<ReaderState> {
  /// Creates the controller for [source].
  ReaderController(this.source);

  /// What this Reader shows.
  final ReaderSource source;

  /// Save the position at least every this many sentences.
  static const int saveEvery = 5;

  late TtsService _tts;
  late DocumentsDao _dao;
  late Announcer _announcer;
  int _token = 0;
  bool _playing = false;
  int? _documentId;
  int _index = 0;
  int _savedIndex = -1;
  Timer? _captionTimer;

  /// Spoken note (text size) waiting for the next sentence break, so changing
  /// the size never cuts a sentence off.
  String? _pendingNote;

  @override
  ReaderState build() {
    _tts = ref.read(ttsServiceProvider);
    _dao = ref.read(documentsDaoProvider);
    _announcer = ref.read(announcerProvider.notifier);
    ref.onDispose(() {
      _token++;
      _captionTimer?.cancel();
      if (_playing) {
        _playing = false;
        unawaited(_tts.stop());
        final announcer = _announcer;
        // Providers can't be modified inside onDispose.
        scheduleMicrotask(() => announcer.setReading(false));
      }
      final id = _documentId;
      if (id != null && _index != _savedIndex) {
        unawaited(_dao.updatePosition(id, _index));
      }
    });

    switch (source) {
      case TextSource(:final text, :final save):
        final ready = _ready(text, assessQuality(text));
        if (save) scheduleMicrotask(() => _saveNew(ready, 'image'));
        return ready;
      case FileSource(:final file):
        scheduleMicrotask(() => _load(file));
        return ReaderState(
          phase: ReaderPhase.loading,
          fromCamera: file.fromCamera,
        );
      case HistorySource(:final documentId):
        scheduleMicrotask(() => _loadHistory(documentId));
        return const ReaderState(phase: ReaderPhase.loading);
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  ReaderState _ready(
    String text,
    TextQuality quality, {
    ReaderState? base,
    DocLanguage? language,
    int index = 0,
  }) {
    final sentences = chunkText(text);
    _index = index;
    return (base ?? const ReaderState(phase: ReaderPhase.ready)).copyWith(
      phase: ReaderPhase.ready,
      text: text,
      quality: quality,
      sentences: sentences,
      index: index,
      language: language ?? detectLanguage(text).language,
      resumedFrom: index > 0 ? index : null,
    );
  }

  Future<void> _load(DocumentFile file) async {
    try {
      final result = await ref
          .read(documentExtractorProvider)
          .extract(
            file,
            onPage: (page, count) {
              if (ref.mounted) {
                state = state.copyWith(page: page, pageCount: count);
              }
            },
          );
      if (!ref.mounted) return;
      final ready = _ready(
        result.text,
        result.quality,
        base: state.copyWith(pageCount: result.pageCount),
      );
      state = ready;
      if (result.quality != TextQuality.empty) {
        await _saveNew(ready, file.sourceType);
      }
    } on ExtractionException catch (e) {
      debugPrint('Extraction failed: $e');
      if (ref.mounted) {
        state = state.copyWith(phase: ReaderPhase.failed, failure: e.failure);
      }
    } finally {
      // Camera photos are only needed to extract the text.
      if (file.fromCamera) {
        try {
          await File(file.path).delete();
        } on Object {
          // Already gone.
        }
      }
    }
  }

  Future<void> _loadHistory(int id) async {
    final record = await _dao.get(id);
    if (!ref.mounted) return;
    if (record == null) {
      state = state.copyWith(
        phase: ReaderPhase.failed,
        failure: ExtractionFailure.unreadable,
      );
      return;
    }
    _documentId = id;
    unawaited(_dao.markOpened(id));
    final sentences = chunkText(record.fullText);
    final start = record.lastPosition < sentences.length
        ? record.lastPosition
        : 0;
    _savedIndex = start;
    state = _ready(
      record.fullText,
      assessQuality(record.fullText),
      language: record.language == 'en'
          ? DocLanguage.english
          : DocLanguage.filipino,
      index: start,
    ).copyWith(documentId: id);
  }

  Future<void> _saveNew(ReaderState s, String sourceType) async {
    if (_documentId != null || s.text.trim().isEmpty) return;
    final account = ref.read(currentAccountProvider);
    final id = await _dao.insert(
      title: titleFor(s.text),
      fullText: s.text,
      sourceType: sourceType,
      language: s.language == DocLanguage.english ? 'en' : 'fil',
      userId: account?.id,
    );
    _documentId = id;
    if (account != null && account.isGuest) {
      // Remind the guest once, later, at a natural moment (never while
      // reading): the next time Capture is announced.
      await GuestReminders(ref.read(userPrefsProvider)).historySaved(account);
    }
    if (ref.mounted) state = state.copyWith(documentId: id);
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// The voice for this document: Filipino documents use the Filipino voice
  /// when installed (the Reader warns before falling back to English).
  String get _voiceTag {
    final voices = ref.read(voiceStatusProvider);
    return readingLanguage == DocLanguage.filipino && voices.filipinoReady
        ? voices.filipinoTag
        : voices.englishTag;
  }

  /// The language the document is read in: detected, unless Settings forces
  /// a document voice.
  DocLanguage get readingLanguage =>
      switch (ref.read(settingsProvider).documentVoice) {
        DocumentVoice.auto => state.language,
        DocumentVoice.filipino => DocLanguage.filipino,
        DocumentVoice.english => DocLanguage.english,
      };

  /// Whether a Filipino document will be read by an English voice.
  bool get filipinoWithoutVoice =>
      readingLanguage == DocLanguage.filipino &&
      !ref.read(voiceStatusProvider).filipinoReady;

  /// Reads from the current sentence. With [single], reads just that one
  /// sentence and stays on it.
  Future<void> play({bool single = false}) async {
    if (!state.canRead) return;
    final token = ++_token;
    final n = state.sentences.length;
    if (state.index >= n) _setIndex(0);
    _playing = true;
    state = state.copyWith(playing: true);
    // Cut any prompt so reading starts at once.
    await _announcer.stop();
    if (token != _token || !ref.mounted) return;
    _announcer.setReading(true);

    while (token == _token) {
      final i = state.index;
      if (i >= n) return _finish();
      final spoken = await _tts.speak(
        state.sentences[i].textIn(state.text),
        languageTag: _voiceTag,
        rate: ref.read(readingRateProvider),
      );
      if (token != _token || !ref.mounted) return; // we paused or skipped
      if (!spoken) return _stopped(); // someone else stopped speech
      if (single) return _stopped();
      _setIndex(i + 1);
      if ((_index - _savedIndex).abs() >= saveEvery) unawaited(_savePosition());
      final note = _pendingNote;
      if (note != null) {
        // Sentence break: say what changed, then carry on.
        _pendingNote = null;
        _announcer.setReading(false);
        await _announcer.say(note);
        if (token != _token || !ref.mounted) return;
        _announcer.setReading(true);
      }
    }
  }

  /// Pauses reading (spoken confirmation unless [quiet]).
  Future<void> pause({bool quiet = false}) async {
    if (!_playing) return;
    await _halt();
    _stopped();
    if (!quiet) await _sayCaption(_l.readerPaused, resume: false);
  }

  /// Tap: play or pause.
  Future<void> togglePlay() => _playing ? pause() : play();

  /// Swipe right/left: next or previous sentence.
  Future<void> skipSentence(int delta) {
    final n = state.sentences.length;
    final from = state.index >= n ? n : state.index;
    return _jumpTo(from + delta);
  }

  /// Two-finger swipe: next or previous paragraph.
  Future<void> skipParagraph(int delta) {
    final sentences = state.sentences;
    if (sentences.isEmpty) return Future.value();
    final starts = paragraphStarts(sentences);
    final i = state.index.clamp(0, sentences.length - 1);
    final p = sentences[i].paragraph;
    int target;
    if (delta > 0) {
      target = starts.firstWhere((s) => s > state.index, orElse: () => -2);
      if (target == -2) target = sentences.length;
    } else {
      final ownStart = starts[p];
      target = state.index > ownStart && state.index < sentences.length
          ? ownStart
          : (p > 0 ? starts[p - 1] : -1);
      if (state.index >= sentences.length) target = starts.last;
    }
    return _jumpTo(target);
  }

  /// Double-tap: read the current sentence again.
  Future<void> repeatSentence() {
    final n = state.sentences.length;
    return _jumpTo(state.index >= n ? n - 1 : state.index);
  }

  /// "Mula sa simula": restart from the first sentence.
  Future<void> readFromStart() async {
    if (!state.canRead) return;
    await _halt();
    _setIndex(0);
    _stopped();
    await _sayCaption(_l.readerFromStart, resume: false);
    await play();
  }

  /// Swipe up/down: change the reading speed by [delta] (0.1 steps).
  Future<void> changeRate(double delta) async {
    final before = ref.read(readingRateProvider);
    final after =
        (await ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(readingRate: before + delta)))
            .readingRate;
    if (!ref.mounted) return;
    if (after == before) unawaited(ref.read(hapticsProvider).error());
    await _sayCaption(_l.readerSpeed(ReadingRate.label(after)));
  }

  /// A+/A−, pinch or voice: text size one step bigger ([direction] 1) or
  /// smaller (−1), saved to the user's settings. While reading, the new
  /// value shows in the caption at once and is spoken at the next sentence
  /// break; otherwise it is spoken right away.
  Future<void> changeTextSize(int direction) async {
    if (state.phase != ReaderPhase.ready) return;
    final before = ref.read(settingsProvider).textSize;
    final after =
        (await ref
                .read(settingsProvider.notifier)
                .update(
                  (s) =>
                      s.copyWith(textSize: before + direction * TextSize.step),
                ))
            .textSize;
    if (!ref.mounted) return;
    final atLimit = after == before;
    final note = atLimit
        ? (direction > 0 ? _l.readerSizeMax : _l.readerSizeMin)
        : _l.readerSize(after.round());
    if (atLimit) {
      unawaited(ref.read(hapticsProvider).error());
      // A held pinch repeats at the limit: say it once.
      if (state.caption == note || _pendingNote == note) return;
    }
    if (_playing) {
      _showCaption(note);
      _pendingNote = note;
    } else {
      await _sayCaption(note, resume: false);
    }
  }

  /// "I-save": documents are auto-saved; this confirms (and saves if not yet).
  Future<void> save() async {
    await _saveNew(state, 'image');
    await _savePosition();
    await _sayCaption(_l.readerSaved);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;

  void _setIndex(int i) {
    _index = i;
    state = state.copyWith(index: i);
  }

  /// Stops the current sentence without changing the playing flag.
  Future<void> _halt() async {
    _token++;
    await _tts.stop();
  }

  void _stopped() {
    _playing = false;
    _pendingNote = null;
    if (!ref.mounted) return;
    state = state.copyWith(playing: false);
    _announcer.setReading(false);
    unawaited(_savePosition());
  }

  void _finish() {
    _playing = false;
    state = state.copyWith(playing: false, index: state.sentences.length);
    _announcer.setReading(false);
    _index = 0; // resume from the start next time
    unawaited(_savePosition());
    unawaited(_announcer.say(_l.readerFinished));
  }

  Future<void> _jumpTo(int target) async {
    if (!state.canRead) return;
    final n = state.sentences.length;
    if (target < 0 || target >= n) {
      unawaited(ref.read(hapticsProvider).error());
      final wasPlaying = _playing;
      await _sayCaption(
        target < 0 ? _l.readerAtStart : _l.readerAtEnd,
        resume: wasPlaying,
      );
      return;
    }
    final wasPlaying = _playing;
    if (wasPlaying) await _halt();
    _setIndex(target);
    unawaited(ref.read(hapticsProvider).tick());
    await play(single: !wasPlaying);
  }

  /// Shows [text] as a caption for ~2 s and speaks it, pausing reading
  /// around it and resuming afterwards if it was playing (and [resume]).
  Future<void> _sayCaption(String text, {bool resume = true}) async {
    _showCaption(text);
    final wasPlaying = _playing;
    if (wasPlaying) {
      await _halt();
      _stopped();
    }
    await _announcer.say(text);
    if (wasPlaying && resume && ref.mounted) await play();
  }

  /// Shows [text] in the caption strip for ~2 s (no speech).
  void _showCaption(String text) {
    _captionTimer?.cancel();
    state = state.copyWith(caption: text);
    _captionTimer = Timer(const Duration(seconds: 2), () {
      if (ref.mounted && state.caption == text) {
        state = state.copyWith(caption: null);
      }
    });
  }

  Future<void> _savePosition() async {
    final id = _documentId;
    if (id == null || _index == _savedIndex) return;
    _savedIndex = _index;
    await _dao.updatePosition(id, _index);
  }
}

/// Reader state per source; disposed when the Reader closes.
final readerControllerProvider = NotifierProvider.autoDispose
    .family<ReaderController, ReaderState, ReaderSource>(ReaderController.new);
