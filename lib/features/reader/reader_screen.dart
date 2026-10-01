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
import '../../core/extraction/extraction_exception.dart';
import '../../core/ocr/text_cleanup.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/widgets/document_box.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
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
/// "mula sa simula" and "i-save". The sentence being read is highlighted and
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

  @override
  void initState() {
    super.initState();
    ref.listenManual(_provider, _onChange);
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
  bool _autoReads(ReaderState s) =>
      widget.source is FileSource &&
      s.canRead &&
      !_offersRetake(s) &&
      ref.read(settingsProvider).autoRead;

  Future<void> _announceThenRead(String text) async {
    await _bus.say(text);
    if (!mounted) return;
    final s = ref.read(_provider);
    // Not if the user already started, paused or left meanwhile.
    if (s.playing ||
        ref.read(activeScreenProvider)?.id != ReaderScreen.screenId) {
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
        _ => l.readerUnreadable,
      };
    }
    if (s.quality == TextQuality.empty) {
      return s.fromCamera
          ? '${l.readerNoText} ${l.readerPhotoTips}'
          : l.readerNoText;
    }
    return [
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
      return _offersRetake(s)
          ? '$outcome ${l.readerRetakeOffer} ${l.offerConfirmHint}'
          : outcome;
    },
    includeModeHint: false,
    help: (l) => l.helpReader,
    // Stop reading and save the position before leaving.
    beforeBack: () => _controller.pause(quiet: true),
    intentHandlers: {
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
        ),
      ),
    );
  }
}
