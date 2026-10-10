import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme/theme_settings.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/auth/guest_reminders.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/library_dao.dart';
import '../../core/describe/image_labeler.dart';
import '../../core/describe/image_prep.dart';
import '../../core/describe/label_description.dart';
import '../../core/library/chaptered_text.dart';
import '../../core/library/library_models.dart';
import '../../core/network/connectivity.dart';
import '../../core/network/image_description_repository.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/ocr/text_cleanup.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/chunker.dart';
import '../../core/tts/speech_language.dart';
import '../../l10n/app_localizations.dart';
import '../reader/reader_controller.dart';

/// What the Description screen shows.
@immutable
sealed class DescribeSubject {
  const DescribeSubject();
}

/// A picture to describe (from the camera or the file picker).
final class NewImage extends DescribeSubject {
  /// Describes the image at [path].
  const NewImage(this.path, {this.fromCamera = false});

  /// Local image file.
  final String path;

  /// Taken with the in-app camera: deleted when the screen closes.
  final bool fromCamera;

  @override
  bool operator ==(Object other) => other is NewImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// A description saved in the Library.
final class SavedDescription extends DescribeSubject {
  /// Reopens library item [id].
  const SavedDescription(this.id);

  /// Library item id.
  final String id;

  @override
  bool operator ==(Object other) => other is SavedDescription && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where the analysis is.
enum DescribePhase {
  /// Looking at the picture.
  working,

  /// Described.
  ready,

  /// The picture could not be opened.
  failed,
}

/// State of the Description screen.
@immutable
class DescribeState {
  /// Creates a state.
  const DescribeState({
    this.phase = DescribePhase.working,
    this.imagePath,
    this.thumbnailPath,
    this.description = '',
    this.detailed,
    this.foundText,
    this.documentId,
    this.caption,
  });

  /// Progress.
  final DescribePhase phase;

  /// The picture being described (not for saved descriptions).
  final String? imagePath;

  /// Saved thumbnail (saved descriptions).
  final String? thumbnailPath;

  /// The offline description (or the saved text).
  final String description;

  /// The server's detailed description, once asked for.
  final String? detailed;

  /// Readable text found in the picture, if any.
  final String? foundText;

  /// Library item, once saved.
  final String? documentId;

  /// Short message above the text ("Laki: 22"), cleared after a moment.
  final String? caption;

  /// Everything there is to read.
  String get fullText =>
      detailed == null ? description : '$description $detailed';

  /// The picture to show: the live image, or the saved thumbnail.
  String? get picturePath => imagePath ?? thumbnailPath;

  static const Object _keep = Object();

  /// Copy with changes ([detailed], [foundText], [caption] can be nulled).
  DescribeState copyWith({
    DescribePhase? phase,
    String? description,
    Object? detailed = _keep,
    Object? foundText = _keep,
    String? documentId,
    Object? caption = _keep,
  }) => DescribeState(
    phase: phase ?? this.phase,
    imagePath: imagePath,
    thumbnailPath: thumbnailPath,
    description: description ?? this.description,
    detailed: identical(detailed, _keep) ? this.detailed : detailed as String?,
    foundText: identical(foundText, _keep)
        ? this.foundText
        : foundText as String?,
    documentId: documentId ?? this.documentId,
    caption: identical(caption, _keep) ? this.caption : caption as String?,
  );
}

/// Describes one picture: offline labels first (always), the existing OCR for
/// text, and — only if the user agrees — the web app's detailed description.
class DescribeController extends Notifier<DescribeState> {
  /// Creates the controller for [subject].
  DescribeController(this.subject);

  /// What is being described.
  final DescribeSubject subject;

  /// Says "Tinitingnan ang larawan…" when the analysis takes longer.
  static const Duration progressAfter = Duration(seconds: 1);

  Timer? _progress;
  Timer? _captionTimer;
  bool _offlineNoticeGiven = false;
  bool _saving = false;

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);
  Announcer get _announcer => ref.read(announcerProvider.notifier);

  @override
  DescribeState build() {
    ref.onDispose(() {
      final subject = this.subject;
      if (subject is NewImage && subject.fromCamera) {
        // Camera photos are only needed for the description.
        unawaited(File(subject.path).delete().then((_) {}).catchError((_) {}));
      }
      _progress?.cancel();
      _captionTimer?.cancel();
    });
    switch (subject) {
      case NewImage(:final path):
        scheduleMicrotask(
          () => _analyse().catchError(
            (Object e) => debugPrint('Describe crashed: $e'),
          ),
        );
        return DescribeState(imagePath: path);
      case SavedDescription(:final id):
        scheduleMicrotask(
          () =>
              _loadSaved(id)
                  .catchError((Object e) => debugPrint('Load crashed: $e')),
        );
        return const DescribeState();
    }
  }

  // ── Analysis ──────────────────────────────────────────────────────────────

  Future<void> _analyse() async {
    final path = (subject as NewImage).path;
    _progress = Timer(progressAfter, () {
      if (ref.mounted && state.phase == DescribePhase.working) {
        unawaited(_announcer.say(_l.describeWorking, interrupt: false));
      }
    });
    try {
      final results = await Future.wait<Object?>([
        ref.read(imageLabelerProvider).label(path),
        _findText(path),
      ]);
      if (!ref.mounted) return;
      _progress?.cancel();
      final labels = results[0]! as List<LabelResult>;
      state = state.copyWith(
        phase: DescribePhase.ready,
        description: offlineDescription(labels, _l),
        foundText: results[1] as String?,
      );
    } on Object catch (e) {
      debugPrint('Describe failed: $e');
      _progress?.cancel();
      if (!ref.mounted) return;
      state = state.copyWith(phase: DescribePhase.failed);
      unawaited(ref.read(hapticsProvider).error());
      await _announcer.say(_l.describeUnreadable, interrupt: false);
      return;
    }
    await _announcer.say(state.description, interrupt: false);
    if (!ref.mounted) return;
    final text = state.foundText;
    if (text != null) {
      await _bus.offer(_l.describeTextFound, readText, onDecline: _offerDetail);
    } else {
      await _offerDetail();
    }
  }

  /// OCR on the same image; the text only if it reads like text.
  Future<String?> _findText(String path) async {
    try {
      final page = await ref.read(ocrServiceProvider).recognizeFile(path);
      final text = cleanText(page.text);
      final quality = assessQuality(text, ocrConfidence: page.confidence);
      return quality == TextQuality.good ? text : null;
    } on Object catch (e) {
      debugPrint('Text check failed: $e');
      return null;
    }
  }

  Future<void> _loadSaved(String id) async {
    final LibraryItem? record;
    String text = '';
    try {
      final dao = ref.read(libraryDaoProvider);
      record = await dao.get(id);
      if (record != null) {
        final chapters = await dao.loadText(record);
        text = chapters.isEmpty ? '' : chapters.first.text;
      }
    } on Object catch (e) {
      debugPrint('Loading description failed: $e');
      if (ref.mounted) {
        state = state.copyWith(phase: DescribePhase.failed);
        await _announcer.say(_l.describeUnreadable, interrupt: false);
      }
      return;
    }
    if (!ref.mounted) return;
    if (record == null) {
      state = state.copyWith(phase: DescribePhase.failed);
      await _announcer.say(_l.describeUnreadable, interrupt: false);
      return;
    }
    unawaited(
      ref.read(libraryDaoProvider).markOpened(id).catchError((Object e) {
        debugPrint('markOpened failed: $e');
      }),
    );
    state = DescribeState(
      phase: DescribePhase.ready,
      thumbnailPath: record.coverPath,
      description: text,
      documentId: id,
    );
    await _announcer.say(text, interrupt: false);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// "Ulitin": say the description again.
  Future<void> repeat() async {
    if (state.phase != DescribePhase.ready) return _bus.notAvailable();
    await _announcer.say(state.fullText);
  }

  /// Whether the phone is online; a failing check counts as offline.
  Future<bool> _online() async {
    try {
      return await ref.read(isOnlineProvider)();
    } on Object catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }

  /// Offered after the offline description when online.
  Future<void> _offerDetail() async {
    if (!ref.mounted || state.phase != DescribePhase.ready) return;
    if (subject is! NewImage) return;
    final online = await _online();
    if (!ref.mounted) return;
    if (!online) {
      if (!_offlineNoticeGiven) {
        _offlineNoticeGiven = true;
        await _announcer.say(_l.describeNeedsInternet, interrupt: false);
      }
      return;
    }
    if (ref.read(settingsProvider).describeConsent ==
        DescribeConsent.declined) {
      return; // Said no before: don't ask again, Settings can change it.
    }
    await _bus.offer(_l.describeDetailOffer, requestDetail);
  }

  /// "Mas detalyado": the web app's description, after consent.
  Future<void> requestDetail() async {
    final subject = this.subject;
    if (state.phase != DescribePhase.ready || subject is! NewImage) {
      return _bus.notAvailable();
    }
    final online = await _online();
    if (!ref.mounted) return;
    if (!online) {
      await _announcer.say(_l.describeNeedsInternet);
      return;
    }
    switch (ref.read(settingsProvider).describeConsent) {
      case DescribeConsent.allowed:
        return _fetchDetail(subject.path);
      case DescribeConsent.declined:
        await _announcer.say(_l.describeConsentDeclined);
      case DescribeConsent.ask:
        await _bus.offer(
          _l.describeConsentAsk,
          () async {
            await _setConsent(DescribeConsent.allowed);
            await _fetchDetail(subject.path);
          },
          onDecline: () async {
            await _setConsent(DescribeConsent.declined);
            await _announcer.say(_l.describeConsentDeclined);
          },
        );
    }
  }

  Future<void> _setConsent(DescribeConsent value) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(describeConsent: value));

  Future<void> _fetchDetail(String path) async {
    final timer = Timer(progressAfter, () {
      if (ref.mounted) {
        unawaited(_announcer.say(_l.describeWorking, interrupt: false));
      }
    });
    try {
      final jpeg = await ref.read(imagePrepProvider).forUpload(path);
      if (jpeg == null) throw const DescriptionException('unreadable image');
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final account = ref.read(currentAccountProvider);
      final result = await ref
          .read(imageDescriptionRepositoryProvider)
          .describe(
            jpeg: jpeg,
            language: _l.localeName == 'fil' ? 'fil' : 'en',
            // Guests are anonymous.
            userId: account == null || account.isGuest ? null : account.id,
          );
      timer.cancel();
      if (!ref.mounted) return;
      state = state.copyWith(detailed: result.description);
      final id = state.documentId;
      if (id != null) {
        await ref.read(libraryDaoProvider).updateText(id, state.fullText);
      }
      await _announcer.say(result.description);
    } on Object catch (e) {
      timer.cancel();
      debugPrint('Detailed description failed: $e');
      if (!ref.mounted) return;
      unawaited(ref.read(hapticsProvider).error());
      await _announcer.say(_l.describeDetailFailed);
    }
  }

  /// "Basahin ang teksto": open the text found in the picture in the Reader.
  Future<void> readText() async {
    final text = state.foundText;
    if (text == null) {
      unawaited(ref.read(hapticsProvider).error());
      return _announcer.say(_l.describeNoText);
    }
    unawaited(
      ref
          .read(routerProvider)
          .push(AppRoutes.reader, extra: TextSource(text, save: true)),
    );
  }

  /// "I-save": put the description in Reading History (once; later detail
  /// updates the saved text).
  Future<void> save() async {
    if (state.phase != DescribePhase.ready) return _bus.notAvailable();
    if (_saving) return; // a second activation while the first is running
    _saving = true;
    try {
      final dao = ref.read(libraryDaoProvider);
      final existing = state.documentId;
      if (existing != null) {
        await dao.updateText(existing, state.fullText);
      } else {
        final path = state.imagePath;
        String? thumbnail;
        if (path != null) {
          try {
            thumbnail = await ref.read(imagePrepProvider).saveThumbnail(path);
          } on Object catch (e) {
            // Saving the description matters more than its picture.
            debugPrint('Thumbnail failed: $e');
          }
        }
        if (!ref.mounted) return;
        final account = ref.read(currentAccountProvider);
        final item = await dao.insertDocument(
          title: titleFor(state.description),
          fullText: state.fullText,
          source: LibrarySource.description,
          format: LibraryFormat.image,
          language: _l.localeName == 'fil' ? 'fil' : 'en',
          userId: account?.id,
          coverPath: thumbnail,
          wordCount: countWords(state.fullText),
        );
        if (!ref.mounted) return;
        state = state.copyWith(documentId: item.id);
        if (account != null && account.isGuest) {
          await GuestReminders(ref.read(userPrefsProvider))
              .historySaved(account);
        }
      }
    } on Object catch (e) {
      debugPrint('Saving description failed: $e');
      if (ref.mounted) {
        unawaited(ref.read(hapticsProvider).error());
        await _bus.notAvailable();
      }
      return;
    } finally {
      _saving = false;
    }
    if (ref.mounted) await _announcer.say(_l.readerSaved);
  }

  /// "Bagong larawan": back to choosing a source.
  void newPicture() => unawaited(
    ref.read(routerProvider).pushReplacement(AppRoutes.describeSource),
  );

  /// Pinch, A−/A+ or voice: text size one step bigger ([direction] 1) or
  /// smaller (−1), saved like in the Reader.
  Future<void> changeTextSize(int direction) async {
    // A pinch reaches here without the command bus: it still counts as the
    // user acting, so an open question's instructions are dropped and this
    // confirmation isn't held back behind them.
    _announcer.answered();
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
      if (state.caption == note) return;
    }
    _captionTimer?.cancel();
    state = state.copyWith(caption: note);
    _captionTimer = Timer(const Duration(seconds: 2), () {
      if (ref.mounted && state.caption == note) {
        state = state.copyWith(caption: null);
      }
    });
    await _announcer.say(note, interrupt: false);
  }
}

/// Description state per subject; disposed when the screen closes.
final describeControllerProvider = NotifierProvider.autoDispose
    .family<DescribeController, DescribeState, DescribeSubject>(
      DescribeController.new,
    );
