import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_settings.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/auth/guest_reminders.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/describe/image_prep.dart';
import '../../core/extraction/document_extractor.dart';
import '../../core/extraction/extraction_exception.dart';
import '../../core/library/chaptered_text.dart';
import '../../core/library/library_models.dart';
import '../../core/ocr/text_cleanup.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/chunker.dart';
import '../../core/tts/language_detector.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/tts/speed_control.dart';
import '../../core/tts/tts_service.dart';
import '../../core/understanding/document_insights.dart';
import '../../core/voice/reading_duck.dart';
import '../../l10n/app_localizations.dart';

/// What the Reader opens.
@immutable
sealed class ReaderSource {
  const ReaderSource();
}

/// Text that is already extracted. Saved to the Library only if [save].
final class TextSource extends ReaderSource {
  /// Creates a text source.
  const TextSource(this.text, {this.save = false});

  /// The text.
  final String text;

  /// Add it to the Library.
  final bool save;

  @override
  bool operator ==(Object other) =>
      other is TextSource && other.text == text && other.save == save;

  @override
  int get hashCode => Object.hash(text, save);
}

/// A file still to be read (camera photo or upload); saved to the Library.
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

/// A library item, resumed at its saved position (or at [chapter] and
/// [sentence] when jumping to a favorite).
final class ItemSource extends ReaderSource {
  /// Opens item [itemId].
  const ItemSource(
    this.itemId, {
    this.fromStart = false,
    this.chapter,
    this.sentence,
    this.play = false,
  });

  /// Start reading as soon as it is open ("basahin ang …").
  final bool play;

  /// `library_items.id`.
  final String itemId;

  /// Ignore the saved position and begin at the start.
  final bool fromStart;

  /// Chapter to start in, when jumping.
  final int? chapter;

  /// Sentence (inside [chapter]) to start at.
  final int? sentence;

  @override
  bool operator ==(Object other) =>
      other is ItemSource &&
      other.itemId == itemId &&
      other.fromStart == fromStart &&
      other.chapter == chapter &&
      other.sentence == sentence &&
      other.play == play;

  @override
  int get hashCode => Object.hash(itemId, fromStart, chapter, sentence, play);
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
    this.itemId,
    this.title,
    this.resumedFrom,
    this.caption,
    this.chapterStarts = const [],
    this.chapterTitles = const [],
    this.insights = DocumentInsights.none,
  });

  /// What kind of document a new one looks like, and its key facts (said
  /// before reading). Only filled in for new documents (camera / upload).
  final DocumentInsights insights;

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

  /// Library item id, once saved.
  final String? itemId;

  /// Title of the item (for the finished announcement).
  final String? title;

  /// Index of the first sentence of each chapter (one entry if none).
  final List<int> chapterStarts;

  /// Chapter titles, parallel to [chapterStarts].
  final List<String> chapterTitles;

  /// More than one chapter to move between.
  bool get hasChapters => chapterStarts.length > 1;

  /// Chapter of the current sentence.
  int get chapter {
    var c = 0;
    for (var i = 0; i < chapterStarts.length; i++) {
      if (chapterStarts[i] <= index) c = i;
    }
    return c;
  }

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
    String? itemId,
    String? title,
    List<int>? chapterStarts,
    List<String>? chapterTitles,
    int? resumedFrom,
    DocumentInsights? insights,
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
    itemId: itemId ?? this.itemId,
    title: title ?? this.title,
    chapterStarts: chapterStarts ?? this.chapterStarts,
    chapterTitles: chapterTitles ?? this.chapterTitles,
    resumedFrom: resumedFrom ?? this.resumedFrom,
    insights: insights ?? this.insights,
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
/// - Documents are auto-saved to the Library as soon as their text is
///   extracted; the position (chapter and sentence) is saved on pause, every
///   few sentences, and when the Reader closes.
/// - Items with chapters announce each chapter's title as it starts.
class ReaderController extends Notifier<ReaderState> {
  /// Creates the controller for [source].
  ReaderController(this.source);

  /// What this Reader shows.
  final ReaderSource source;

  /// Save the position at least every this many sentences.
  static const int saveEvery = 5;

  late TtsService _tts;
  late LibraryDao _dao;
  late Announcer _announcer;
  int _token = 0;
  bool _playing = false;

  /// Reading is paused because the user is speaking over it.
  bool _ducked = false;
  String? _itemId;
  Future<void>? _saving;
  bool _finished = false;
  ChapteredText? _layout;
  int _index = 0;
  int _savedIndex = -1;
  Timer? _captionTimer;

  /// Spoken note (text size) waiting for the next sentence break, so changing
  /// the size never cuts a sentence off.
  String? _pendingNote;

  @override
  ReaderState build() {
    _tts = ref.read(ttsServiceProvider);
    _dao = ref.read(libraryDaoProvider);
    _announcer = ref.read(announcerProvider.notifier);
    // The speed strip speaks its value through the Reader, which pauses
    // around it and goes on at the new speed.
    final speed = ref.read(speedControlProvider);
    Future<void> speedNote(String note) => _sayCaption(note);
    speed.reader = speedNote;
    // The user talks over the reading: pause it so they can be heard, then
    // carry on (unless their command changed what the Reader is doing).
    ref.listen(readingDuckProvider, (_, on) => on ? _duck() : _unduck());
    ref.onDispose(() {
      if (identical(speed.reader, speedNote)) speed.reader = null;
      _token++;
      _captionTimer?.cancel();
      if (_playing) {
        _playing = false;
        unawaited(_tts.stop());
        final announcer = _announcer;
        // Providers can't be modified inside onDispose.
        scheduleMicrotask(() => announcer.setReading(false));
      }
      final id = _itemId;
      if (id != null && _index != _savedIndex && !_finished) {
        unawaited(_writePosition(id, _index));
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
      case ItemSource():
        scheduleMicrotask(() => _loadItem(source as ItemSource));
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
    _layout = null;
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
      final insights = result.quality == TextQuality.empty
          ? DocumentInsights.none
          : await _analyze(result.text);
      if (!ref.mounted) return;
      final ready = _ready(
        result.text,
        result.quality,
        base: state.copyWith(pageCount: result.pageCount, insights: insights),
      );
      state = ready;
      if (result.quality != TextQuality.empty) {
        try {
          await _saveNew(ready, file.sourceType, photo: file);
        } on Object catch (e, stack) {
          // Storage failure: the text is still readable; say it wasn't kept.
          debugPrint('[CAPTURE] saving to the Library failed: $e');
          debugPrint('[CAPTURE] $stack');
          if (ref.mounted) {
            unawaited(_announcer.say(_l.readerSaveFailed, interrupt: false));
          }
        }
      }
    } on ExtractionException catch (e) {
      debugPrint(
        '[CAPTURE] reading ${file.kind.name} failed: $e '
        '(path ${file.path})',
      );
      if (ref.mounted) {
        state = state.copyWith(phase: ReaderPhase.failed, failure: e.failure);
      }
    } on Object catch (e, stack) {
      // Anything else (preparing the sentences, the Library…) must not
      // leave the Reader stuck on "loading", nor blame the file.
      debugPrint(
        '[CAPTURE] reading ${file.kind.name} failed after extraction '
        '${e.runtimeType}: $e',
      );
      debugPrint('[CAPTURE] $stack');
      if (ref.mounted) {
        state = state.copyWith(
          phase: ReaderPhase.failed,
          failure: ExtractionFailure.failed,
        );
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

  Future<void> _loadItem(ItemSource src) async {
    final LibraryItem? item;
    final List<ChapterText> chapters;
    try {
      item = await _dao.get(src.itemId);
      chapters = item == null ? const [] : await _dao.loadText(item);
    } on Object catch (e, stack) {
      // The Library database, not the document.
      debugPrint('[CAPTURE] loading Library item ${src.itemId} failed: $e');
      debugPrint('[CAPTURE] $stack');
      if (ref.mounted) {
        state = state.copyWith(
          phase: ReaderPhase.failed,
          failure: ExtractionFailure.failed,
        );
      }
      return;
    }
    if (!ref.mounted) return;
    if (item == null || chapters.every((c) => c.text.trim().isEmpty)) {
      state = state.copyWith(
        phase: ReaderPhase.failed,
        failure: ExtractionFailure.unreadable,
      );
      return;
    }
    final layout = await ChapteredText.buildAsync(chapters);
    if (!ref.mounted) return;
    _itemId = item.id;
    _finished = item.finished;
    unawaited(_dao.markOpened(item.id));
    if (item.totalSentences != layout.sentences.length ||
        item.chapters.length != layout.chapterStarts.length) {
      // First time the text is laid out (migrated history, new book).
      unawaited(
        _dao.setTotals(
          item.id,
          totalSentences: layout.sentences.length,
          wordCount: layout.wordCount,
          chapters: layout.info,
        ),
      );
    }
    final int start;
    if (src.chapter != null) {
      start = layout.globalOf(src.chapter!, src.sentence ?? 0);
    } else if (src.fromStart || item.finished) {
      start = 0;
    } else {
      final saved = layout.globalOf(item.chapterIndex, item.sentenceIndex);
      start = saved < layout.sentences.length ? saved : 0;
    }
    _savedIndex = start;
    _layout = layout;
    _index = start;
    state = ReaderState(
      phase: ReaderPhase.ready,
      text: layout.text,
      sentences: layout.sentences,
      index: start,
      language: item.language == 'en'
          ? DocLanguage.english
          : DocLanguage.filipino,
      quality: assessQuality(layout.text),
      itemId: item.id,
      title: item.title,
      chapterStarts: layout.chapterStarts,
      chapterTitles: layout.chapterTitles,
      resumedFrom: start > 0 ? start : null,
    );
  }

  DocumentInsights? _insights;

  /// What kind of document this is and its key facts (computed once).
  Future<DocumentInsights> insights() async {
    final known = _insights;
    if (known != null) return known;
    if (!state.canRead) return DocumentInsights.none;
    return _analyze(state.text);
  }

  Future<DocumentInsights> _analyze(String text) async {
    try {
      return _insights = await DocumentAnalyzer.analyzeAsync(text);
    } on Object catch (e, stack) {
      // A nicety: never let it stop the reading.
      debugPrint('[CAPTURE] document analysis failed: $e');
      debugPrint('[CAPTURE] $stack');
      return _insights = DocumentInsights.none;
    }
  }

  /// Stores a newly read document in the Library (once).
  Future<void> _saveNew(
    ReaderState s,
    String sourceType, {
    DocumentFile? photo,
  }) {
    return _saving ??= _saveNewNow(s, sourceType, photo: photo);
  }

  Future<void> _saveNewNow(
    ReaderState s,
    String sourceType, {
    DocumentFile? photo,
  }) async {
    if (_itemId != null || s.text.trim().isEmpty) return;
    final account = ref.read(currentAccountProvider);
    String? cover;
    if (photo != null && photo.kind == DocumentKind.image) {
      try {
        cover = await ref.read(imagePrepProvider).saveThumbnail(photo.path);
      } on Object catch (e) {
        // The document matters more than its picture.
        debugPrint('[CAPTURE] cover failed (document still saved): $e');
      }
    }
    final (source, format) = switch (sourceType) {
      'camera' => (LibrarySource.camera, LibraryFormat.image),
      'pdf' => (LibrarySource.upload, LibraryFormat.pdf),
      'docx' => (LibrarySource.upload, LibraryFormat.docx),
      _ => (LibrarySource.upload, LibraryFormat.image),
    };
    final item = await _dao.insertDocument(
      title: titleFor(s.text),
      fullText: s.text,
      source: source,
      format: format,
      language: s.language == DocLanguage.english ? 'en' : 'fil',
      userId: account?.id,
      coverPath: cover,
      totalSentences: s.sentences.length,
      wordCount: countWords(s.text),
    );
    _itemId = item.id;
    if (account != null && account.isGuest) {
      // Remind the guest once, later, at a natural moment (never while
      // reading): the next time the Library is announced.
      await GuestReminders(ref.read(userPrefsProvider)).historySaved(account);
    }
    if (ref.mounted) state = state.copyWith(itemId: item.id, title: item.title);
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
    _ducked = false;
    if (_finished) {
      // Reading a finished item again.
      _finished = false;
      final id = _itemId;
      if (id != null) unawaited(_dao.setFinished(id, finished: false));
    }
    state = state.copyWith(playing: true);
    // Cut any prompt so reading starts at once.
    await _announcer.stop();
    if (token != _token || !ref.mounted) return;
    _announcer.setReading(true);

    while (token == _token) {
      final i = state.index;
      if (i >= n) return _finish();
      final sentence = state.sentences[i].textIn(state.text);
      _announcer.noteReadAloud(sentence);
      var spoken = await _tts.speak(
        sentence,
        languageTag: _voiceTag,
        rate: ref.read(readingRateProvider),
      );
      if (token != _token || !ref.mounted) return; // we paused or skipped
      if (!spoken && _tts.lastFailed) {
        // The engine failed (e.g. a voice that needs the internet, while
        // offline); the TTS service has moved to another voice: try the
        // sentence once more before giving up.
        debugPrint('[READER] sentence $i failed to speak: trying again');
        spoken = await _tts.speak(
          sentence,
          languageTag: _voiceTag,
          rate: ref.read(readingRateProvider),
        );
        if (token != _token || !ref.mounted) return;
        if (!spoken && _tts.lastFailed) {
          unawaited(ref.read(hapticsProvider).error());
          return _stopped();
        }
      }
      if (!spoken) return _stopped(); // someone else stopped speech
      if (single) return _stopped();
      _setIndex(i + 1);
      if ((_index - _savedIndex).abs() >= saveEvery) unawaited(_savePosition());
      if (_index < n &&
          state.hasChapters &&
          state.chapterStarts.contains(_index)) {
        final title = state.chapterTitles[state.chapterStarts.indexOf(_index)];
        _pendingNote = [?_pendingNote, _l.readerChapter(title)].join(' ');
      }
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

  /// "Paborito": saves the current spot as a favorite.
  Future<void> addFavorite() async {
    if (!state.canRead) return;
    await _saving;
    final id = _itemId;
    if (id == null) {
      unawaited(ref.read(hapticsProvider).error());
      return _sayCaption(_l.commandNotAvailable, resume: false);
    }
    final i = state.index.clamp(0, state.sentences.length - 1);
    final (chapter, sentence) = _chapterPos(i);
    try {
      await _dao.addFavorite(
        itemId: id,
        chapterIndex: chapter,
        sentenceIndex: sentence,
        label: favoriteLabel(state.sentences[i].textIn(state.text)),
      );
    } on Object catch (e) {
      debugPrint('Saving the favorite failed: $e');
      unawaited(ref.read(hapticsProvider).error());
      return _sayCaption(_l.commandNotAvailable, resume: false);
    }
    unawaited(ref.read(hapticsProvider).confirm());
    if (ref.mounted) await _sayCaption(_l.readerFavoriteSaved);
  }

  /// Jumps to a saved spot and carries on reading from there.
  Future<void> goTo(int chapter, int sentence) async {
    if (!state.canRead) return;
    final target = _layout?.globalOf(chapter, sentence) ?? sentence;
    await _halt();
    _stopped();
    _setIndex(target.clamp(0, state.sentences.length - 1));
    await play();
  }

  /// "Susunod / nakaraang kabanata": jumps to the start of the next chapter,
  /// or the start of this one (previous, when already past its start).
  Future<void> skipChapter(int delta) async {
    if (!state.hasChapters) {
      unawaited(ref.read(hapticsProvider).error());
      return _sayCaption(_l.readerNoChapters, resume: _playing);
    }
    final starts = state.chapterStarts;
    final c = state.chapter;
    final int target;
    if (delta > 0) {
      target = c + 1 < starts.length ? starts[c + 1] : -1;
    } else {
      target = state.index > starts[c]
          ? starts[c]
          : (c > 0 ? starts[c - 1] : -1);
    }
    if (target < 0) {
      unawaited(ref.read(hapticsProvider).error());
      return _sayCaption(
        delta > 0 ? _l.readerAtEnd : _l.readerAtStart,
        resume: _playing,
      );
    }
    if (_playing) {
      await _halt();
      _stopped();
    }
    _setIndex(target);
    unawaited(ref.read(hapticsProvider).tick());
    final title = state.chapterTitles[state.chapter];
    _showCaption(title);
    await _announcer.say(_l.readerChapter(title));
    if (ref.mounted) await play();
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

  /// Stops the voice mid-sentence while the user speaks; stays "playing".
  void _duck() {
    if (!_playing || _ducked) return;
    _ducked = true;
    unawaited(_halt());
  }

  /// Reads the interrupted sentence again, if nothing else took over.
  void _unduck() {
    if (!_ducked) return;
    _ducked = false;
    // After the notification that called this, not during it.
    scheduleMicrotask(() {
      if (ref.mounted && _playing && !_ducked) unawaited(play());
    });
  }

  void _stopped() {
    _playing = false;
    _ducked = false;
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
    final id = _itemId;
    if (id != null) {
      _finished = true;
      _savedIndex = 0;
      unawaited(
        _dao
            .updateProgress(
              id,
              chapterIndex: 0,
              sentenceIndex: 0,
              globalSentence: 0,
            )
            .then((_) => _dao.setFinished(id, finished: true))
            .catchError((Object e) => debugPrint('Finish failed: $e')),
      );
    }
    final title = state.title;
    unawaited(
      _announcer.say(
        title == null ? _l.readerFinished : _l.readerFinishedTitle(title),
      ),
    );
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
    final id = _itemId;
    if (id == null || _index == _savedIndex || _finished) return;
    _savedIndex = _index;
    await _writePosition(id, _index);
  }

  (int, int) _chapterPos(int index) {
    final l = _layout;
    return l == null ? (0, index) : (l.chapterOf(index), l.inChapter(index));
  }

  Future<void> _writePosition(String id, int index) {
    final (chapter, sentence) = _chapterPos(index);
    return _dao
        .updateProgress(
          id,
          chapterIndex: chapter,
          sentenceIndex: sentence,
          globalSentence: index,
        )
        .catchError((Object e) => debugPrint('Saving position failed: $e'));
  }
}

/// Reader state per source; disposed when the Reader closes.
final readerControllerProvider = NotifierProvider.autoDispose
    .family<ReaderController, ReaderState, ReaderSource>(ReaderController.new);
