import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/accessibility/nav_intent.dart';
import 'package:percipere_app/core/gestures/gesture_classifier.dart';
import 'package:percipere_app/core/gestures/gesture_map.dart';

/// Drives a [GestureClassifier] with synthetic pointer sessions.
class _Driver {
  _Driver(this.async) {
    classifier = GestureClassifier(
      onGesture: gestures.add,
      onFirstTouch: () => touches++,
    );
  }

  final FakeAsync async;
  late final GestureClassifier classifier;
  final List<GestureType> gestures = [];
  int touches = 0;
  int _pointer = 0;

  Duration get _now => async.elapsed;

  /// [fingers] touch at once, each moves by [delta] over [duration], lift.
  void session({
    int fingers = 1,
    Offset delta = Offset.zero,
    Duration duration = const Duration(milliseconds: 80),
    bool claimed = false,
  }) {
    final ids = [for (var i = 0; i < fingers; i++) ++_pointer];
    for (final (i, id) in ids.indexed) {
      classifier.pointerDown(
        id,
        Offset(100.0 + i * 40, 300),
        _now,
        claimed: claimed,
      );
    }
    async.elapse(duration);
    for (final (i, id) in ids.indexed) {
      final end = Offset(100.0 + i * 40, 300) + delta;
      classifier
        ..pointerMove(id, end)
        ..pointerUp(id, end, _now);
    }
  }

  void wait(int ms) => async.elapse(Duration(milliseconds: ms));
}

void main() {
  void run(void Function(_Driver d) body) =>
      fakeAsync((async) => body(_Driver(async)));

  test('single tap fires after the double-tap window', () {
    run((d) {
      d.session();
      expect(d.gestures, isEmpty);
      d.wait(400);
      expect(d.gestures, [GestureType.singleTap]);
      expect(d.touches, 1);
    });
  });

  test('two quick taps are a double tap, not two single taps', () {
    run((d) {
      d
        ..session()
        ..wait(150)
        ..session()
        ..wait(500);
      expect(d.gestures, [GestureType.doubleTap]);
    });
  });

  test('slow taps are two single taps', () {
    run((d) {
      d
        ..session()
        ..wait(600)
        ..session()
        ..wait(600);
      expect(d.gestures, [GestureType.singleTap, GestureType.singleTap]);
    });
  });

  test('one-finger swipes in four directions', () {
    run((d) {
      d
        ..session(delta: const Offset(120, 10))
        ..session(delta: const Offset(-120, -5))
        ..session(delta: const Offset(8, -120))
        ..session(delta: const Offset(-8, 120));
      expect(d.gestures, [
        GestureType.swipeRight,
        GestureType.swipeLeft,
        GestureType.swipeUp,
        GestureType.swipeDown,
      ]);
    });
  });

  test('short drags are neither swipes nor taps', () {
    run((d) {
      d
        ..session(delta: const Offset(35, 0))
        ..wait(600);
      expect(d.gestures, isEmpty);
    });
  });

  test('holding still is a long press, fired while held', () {
    run((d) {
      d.classifier.pointerDown(1, const Offset(10, 10), d._now);
      d.wait(700);
      expect(d.gestures, [GestureType.longPress]);
      d.classifier.pointerUp(1, const Offset(10, 10), d._now);
      d.wait(600);
      expect(d.gestures, [GestureType.longPress], reason: 'no extra tap');
    });
  });

  test('moving cancels the long press', () {
    run((d) {
      d.classifier.pointerDown(1, const Offset(10, 10), d._now);
      d.wait(100);
      d.classifier.pointerMove(1, const Offset(80, 10));
      d.wait(700);
      expect(d.gestures, isEmpty);
    });
  });

  test('two-finger swipes: down, up and right are recognized', () {
    run((d) {
      d.session(fingers: 2, delta: const Offset(0, 150));
      d.session(fingers: 2, delta: const Offset(0, -150));
      d.session(fingers: 2, delta: const Offset(150, 0));
      expect(d.gestures, [
        GestureType.twoFingerSwipeDown,
        GestureType.twoFingerSwipeUp,
        GestureType.twoFingerSwipeRight,
      ]);
    });
  });

  test('two-finger double tap stops speech; a lone two-finger tap does '
      'nothing', () {
    run((d) {
      d
        ..session(fingers: 2)
        ..wait(600);
      expect(d.gestures, isEmpty);
      d
        ..session(fingers: 2)
        ..wait(120)
        ..session(fingers: 2);
      expect(d.gestures, [GestureType.twoFingerDoubleTap]);
    });
  });

  test('three-finger tap is help', () {
    run((d) {
      d.session(fingers: 3);
      expect(d.gestures, [GestureType.threeFingerTap]);
    });
  });

  test('taps claimed by a button are ignored, and no long press starts', () {
    run((d) {
      d
        ..session(claimed: true)
        ..wait(600);
      expect(d.gestures, isEmpty);
      d.classifier.pointerDown(9, Offset.zero, d._now, claimed: true);
      d.wait(900);
      expect(d.gestures, isEmpty);
    });
  });

  test('a swipe right after a tap flushes the tap first', () {
    run((d) {
      d
        ..session()
        ..wait(100)
        ..session(delta: const Offset(150, 0));
      expect(d.gestures, [GestureType.singleTap, GestureType.swipeRight]);
    });
  });

  test('every gesture has an intent', () {
    expect(gestureMap.keys.toSet(), GestureType.values.toSet());
    // 2026-10-07: two-finger swipe left (unused until then) calls Percy.
    expect(gestureMap[GestureType.twoFingerSwipeLeft], NavIntent.assistant);
    // Phase 6B: two-finger swipe right is back everywhere.
    expect(gestureMap[GestureType.twoFingerSwipeRight], NavIntent.back);
    expect(gestureMap[GestureType.twoFingerSwipeDown], NavIntent.nextParagraph);
    expect(
      gestureMap[GestureType.twoFingerSwipeUp],
      NavIntent.previousParagraph,
    );
  });
}
