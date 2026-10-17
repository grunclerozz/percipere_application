import '../../config/voice_config.dart';
import '../accessibility/nav_intent.dart';

/// Gestures the gesture layer recognizes.
enum GestureType {
  /// One finger, left to right.
  swipeRight,

  /// One finger, right to left.
  swipeLeft,

  /// One finger, upward.
  swipeUp,

  /// One finger, downward.
  swipeDown,

  /// One finger, single tap (fires after the double-tap window closes).
  singleTap,

  /// One finger, two taps in quick succession.
  doubleTap,

  /// One finger held still.
  longPress,

  /// Two fingers moving down together.
  twoFingerSwipeDown,

  /// Two fingers moving up together.
  twoFingerSwipeUp,

  /// Two fingers moving right together.
  twoFingerSwipeRight,

  /// Two fingers moving left together.
  twoFingerSwipeLeft,

  /// Two fingers, two taps in quick succession.
  twoFingerDoubleTap,

  /// Three fingers, one tap.
  threeFingerTap,
}

/// THE gesture → intent table. Change bindings here only.
///
/// Screens decide what an intent means for them (e.g. on the Reader,
/// [NavIntent.next] is "next sentence" and [NavIntent.activate] is
/// read/pause) via `ScreenRegistration.intentHandlers`. Two-finger swipe
/// left calls Percy, the voice assistant (2026-10-07).
const Map<GestureType, NavIntent> gestureMap = {
  GestureType.swipeRight: NavIntent.next,
  GestureType.swipeLeft: NavIntent.previous,
  GestureType.doubleTap: NavIntent.activate,
  GestureType.singleTap: NavIntent.repeat,
  GestureType.swipeUp: NavIntent.faster,
  GestureType.swipeDown: NavIntent.slower,
  // Reserved for back on every screen (Phase 6B).
  GestureType.twoFingerSwipeRight: NavIntent.back,
  GestureType.twoFingerSwipeDown: NavIntent.nextParagraph,
  GestureType.twoFingerSwipeUp: NavIntent.previousParagraph,
  GestureType.longPress: NavIntent.listen,
  GestureType.twoFingerDoubleTap: NavIntent.stopSpeech,
  GestureType.threeFingerTap: NavIntent.help,
  GestureType.twoFingerSwipeLeft: NavIntent.assistant,
};

/// Timing and distance thresholds, in logical pixels and milliseconds.
///
/// Tuned generously: many users are older adults and cannot see where their
/// finger is.
class GestureTuning {
  /// Creates tuning values.
  const GestureTuning({
    this.swipeMinDistance = 48,
    this.swipeMaxDuration = const Duration(milliseconds: 1200),
    this.tapSlop = 20,
    this.tapMaxDuration = const Duration(milliseconds: 400),
    this.doubleTapTimeout = const Duration(milliseconds: 350),
    this.longPressDuration = VoiceConfig.holdToListen,
  });

  /// Minimum travel for a swipe.
  final double swipeMinDistance;

  /// Longest time a swipe may take.
  final Duration swipeMaxDuration;

  /// Maximum movement still counted as a tap/long press.
  final double tapSlop;

  /// Longest press still counted as a tap.
  final Duration tapMaxDuration;

  /// Window for the second tap of a double tap.
  final Duration doubleTapTimeout;

  /// Hold time for a long press.
  final Duration longPressDuration;
}
