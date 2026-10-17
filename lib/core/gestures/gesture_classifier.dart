import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'gesture_map.dart';

/// Turns raw pointer events into [GestureType]s, including multi-finger
/// gestures that Flutter's recognizers don't cover.
///
/// A "session" runs from the first finger down to the last finger up. The
/// finger count of a session is the most fingers down at once.
///
/// A hold ([GestureType.longPress]) is followed by [GestureType.holdRelease]
/// when the last finger lifts (push-to-talk). With [holdOnly] (TalkBack on:
/// only its double-tap-and-hold reaches the app as touches) nothing but the
/// hold and its release is reported.
class GestureClassifier {
  /// Creates a classifier that reports gestures to [onGesture].
  GestureClassifier({
    required this.onGesture,
    this.onFirstTouch,
    this.tuning = const GestureTuning(),
    this.holdOnly = false,
  });

  /// Report only holds and their release.
  bool holdOnly;

  /// Called for every recognized gesture.
  final void Function(GestureType gesture) onGesture;

  /// Called when a finger first lands (for the haptic "you're on the pad").
  final void Function()? onFirstTouch;

  /// Thresholds.
  final GestureTuning tuning;

  final Map<int, Offset> _start = {};
  final Map<int, Offset> _last = {};
  final Set<int> _active = {};
  Duration _sessionStart = Duration.zero;
  int _maxFingers = 0;
  bool _consumed = false;
  bool _claimed = false;
  Timer? _longPressTimer;

  /// A hold was reported and its release is still to come.
  bool _holding = false;

  /// Whether a hold is in progress (its release is still to come).
  bool get holding => _holding;

  int _pendingTapFingers = 0;
  Timer? _tapTimer;

  /// A finger landed. [claimed] means a button under the finger will handle
  /// a tap itself, so this session must not also produce a tap gesture.
  void pointerDown(
    int pointer,
    Offset position,
    Duration timeStamp, {
    bool claimed = false,
  }) {
    if (_active.isEmpty) {
      _start.clear();
      _last.clear();
      _sessionStart = timeStamp;
      _maxFingers = 0;
      _consumed = false;
      _claimed = false;
      onFirstTouch?.call();
    }
    _active.add(pointer);
    _start[pointer] = position;
    _last[pointer] = position;
    _maxFingers = math.max(_maxFingers, _active.length);
    _claimed |= claimed;

    _longPressTimer?.cancel();
    if (_active.length == 1 && !claimed) {
      _longPressTimer = Timer(tuning.longPressDuration, _onLongPress);
    }
  }

  /// A finger moved.
  void pointerMove(int pointer, Offset position) {
    if (!_active.contains(pointer)) return;
    _last[pointer] = position;
    if (_travel(pointer) > tuning.tapSlop) _longPressTimer?.cancel();
  }

  /// A finger lifted.
  void pointerUp(int pointer, Offset position, Duration timeStamp) {
    if (!_active.remove(pointer)) return;
    _last[pointer] = position;
    if (_active.isEmpty) _endSession(timeStamp);
  }

  /// The system cancelled a pointer (e.g. a scroll took over).
  void pointerCancel(int pointer) {
    if (!_active.remove(pointer)) return;
    if (_active.isEmpty) {
      _longPressTimer?.cancel();
      _consumed = true;
      _releaseHold();
    }
  }

  /// Cancels timers; a hold still open is released.
  void dispose() {
    _longPressTimer?.cancel();
    _tapTimer?.cancel();
    _releaseHold();
  }

  void _releaseHold() {
    if (!_holding) return;
    _holding = false;
    onGesture(GestureType.holdRelease);
  }

  double _travel(int pointer) =>
      ((_last[pointer] ?? Offset.zero) - (_start[pointer] ?? Offset.zero))
          .distance;

  void _onLongPress() {
    if (_active.length != 1 || _consumed) return;
    _consumed = true;
    _holding = true;
    if (!holdOnly) _flushPendingTap();
    onGesture(GestureType.longPress);
  }

  void _endSession(Duration end) {
    _longPressTimer?.cancel();
    _releaseHold();
    if (_consumed || holdOnly) return;

    final duration = end - _sessionStart;
    final fingers = _maxFingers;

    var delta = Offset.zero;
    var maxTravel = 0.0;
    for (final p in _start.keys) {
      delta += _last[p]! - _start[p]!;
      maxTravel = math.max(maxTravel, _travel(p));
    }
    delta /= _start.length.toDouble();

    if (delta.distance >= tuning.swipeMinDistance &&
        duration <= tuning.swipeMaxDuration) {
      final horizontal = delta.dx.abs() > delta.dy.abs();
      final GestureType? swipe;
      if (fingers == 1) {
        swipe = horizontal
            ? (delta.dx > 0 ? GestureType.swipeRight : GestureType.swipeLeft)
            : (delta.dy > 0 ? GestureType.swipeDown : GestureType.swipeUp);
      } else if (fingers == 2 && horizontal) {
        swipe = delta.dx > 0
            ? GestureType.twoFingerSwipeRight
            : GestureType.twoFingerSwipeLeft;
      } else if (fingers == 2) {
        swipe = delta.dy > 0
            ? GestureType.twoFingerSwipeDown
            : GestureType.twoFingerSwipeUp;
      } else {
        swipe = null;
      }
      if (swipe != null) {
        _flushPendingTap();
        onGesture(swipe);
      }
      return;
    }

    final isTap =
        maxTravel <= tuning.tapSlop && duration <= tuning.tapMaxDuration;
    if (!isTap) return;
    if (_claimed && fingers == 1) {
      // A button handles this tap; don't also run "repeat"/"activate".
      _cancelPendingTap();
      return;
    }

    switch (fingers) {
      case 1:
        if (_pendingTapFingers == 1) {
          _cancelPendingTap();
          onGesture(GestureType.doubleTap);
        } else {
          _flushPendingTap();
          _startPendingTap(1);
        }
      case 2:
        if (_pendingTapFingers == 2) {
          _cancelPendingTap();
          onGesture(GestureType.twoFingerDoubleTap);
        } else {
          _flushPendingTap();
          _startPendingTap(2);
        }
      case 3:
        _flushPendingTap();
        onGesture(GestureType.threeFingerTap);
    }
  }

  void _startPendingTap(int fingers) {
    _pendingTapFingers = fingers;
    _tapTimer = Timer(tuning.doubleTapTimeout, _flushPendingTap);
  }

  /// Emits a waiting single tap now (a lone two-finger tap has no action).
  void _flushPendingTap() {
    final fingers = _pendingTapFingers;
    _cancelPendingTap();
    if (fingers == 1) onGesture(GestureType.singleTap);
  }

  void _cancelPendingTap() {
    _tapTimer?.cancel();
    _tapTimer = null;
    _pendingTapFingers = 0;
  }
}
