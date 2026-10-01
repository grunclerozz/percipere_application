import '../../core/ocr/ocr_service.dart';
import '../../l10n/app_localizations.dart';

/// Spoken hint for the current camera frame.
enum Guidance {
  /// Too dark to read.
  tooDark,

  /// No text in view.
  noText,

  /// Text too small: move closer.
  moveCloser,

  /// Text fills the frame and runs off the edge: move back.
  moveBack,

  /// Good: hold steady.
  ready;

  /// The spoken sentence.
  String text(AppLocalizations l) => switch (this) {
    tooDark => l.guideTooDark,
    noText => l.guideNoText,
    moveCloser => l.guideMoveCloser,
    moveBack => l.guideMoveBack,
    ready => l.guideReady,
  };

  /// Classifies one preview frame.
  static Guidance of(FrameStats s) {
    if (s.meanLuma < 45) return tooDark;
    if (s.lineCount == 0) return noText;
    if (s.touchesEdge && s.textAreaFraction > 0.55) return moveBack;
    if (s.lineCount < 2 || s.textAreaFraction < 0.12) return moveCloser;
    return ready;
  }
}

/// What to do after a frame.
class GuidanceStep {
  /// Creates a step.
  const GuidanceStep({this.speak, this.autoCapture = false});

  /// Hint to speak now, if any.
  final Guidance? speak;

  /// The text has been clear long enough to take the photo automatically.
  final bool autoCapture;
}

/// Turns a stream of per-frame [Guidance] into calm speech:
/// - a hint must hold for [stableFrames] frames before it's spoken (no
///   flicker between "Ilapit pa" and "Handa na");
/// - at least [minGap] between hints;
/// - a problem hint repeats every [repeatAfter] if nothing changes;
/// - [autoCaptureFrames] consecutive "ready" frames trigger auto-capture.
class GuidanceTracker {
  /// Creates a tracker.
  GuidanceTracker({
    this.stableFrames = 2,
    this.minGap = const Duration(milliseconds: 2500),
    this.repeatAfter = const Duration(seconds: 6),
    this.autoCaptureFrames = 4,
  });

  /// Frames a hint must hold before it's spoken.
  final int stableFrames;

  /// Minimum time between spoken hints.
  final Duration minGap;

  /// Repeat interval for an unchanged problem hint.
  final Duration repeatAfter;

  /// Consecutive "ready" frames that trigger auto-capture.
  final int autoCaptureFrames;

  Guidance? _candidate;
  int _count = 0;
  int _readyStreak = 0;
  Guidance? _spoken;
  DateTime? _spokenAt;

  /// Feeds one frame's guidance.
  GuidanceStep update(Guidance g, DateTime now) {
    _count = g == _candidate ? _count + 1 : 1;
    _candidate = g;
    _readyStreak = g == Guidance.ready ? _readyStreak + 1 : 0;

    Guidance? speak;
    if (_count >= stableFrames) {
      final since = _spokenAt == null ? null : now.difference(_spokenAt!);
      final changed = g != _spoken;
      if (changed && (since == null || since >= minGap)) {
        speak = g;
      } else if (!changed &&
          g != Guidance.ready &&
          since != null &&
          since >= repeatAfter) {
        speak = g;
      }
    }
    return GuidanceStep(
      speak: speak,
      autoCapture: _readyStreak >= autoCaptureFrames,
    );
  }

  /// Records that [g] was actually spoken at [now].
  void markSpoken(Guidance g, DateTime now) {
    _spoken = g;
    _spokenAt = now;
  }

  /// Forgets everything (after a failed capture, say).
  void reset() {
    _candidate = null;
    _count = 0;
    _readyStreak = 0;
    _spoken = null;
    _spokenAt = null;
  }
}
