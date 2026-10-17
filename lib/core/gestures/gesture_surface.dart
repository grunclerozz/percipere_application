import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/haptics.dart';
import '../accessibility/nav_intent.dart';
import '../accessibility/navigation_mode.dart';
import 'gesture_classifier.dart';
import 'gesture_map.dart';

/// Detects navigation gestures on [child] and sends them to the
/// [CommandBus].
///
/// Used by the Gesture Pad, and as the whole-screen surface on Welcome.
/// While TalkBack is on, TalkBack owns touch gestures: only its
/// double-tap-and-hold reaches the app as a held touch, so only the hold
/// (push-to-talk) and its release are detected, and the same "listen now"
/// is offered as TalkBack's long-press and custom action (no release
/// comes from those: a silence ends that session).
///
/// Buttons inside a surface call [GestureSurface.claimPointer] on pointer
/// down so their taps don't also count as surface taps.
class GestureSurface extends ConsumerStatefulWidget {
  /// Creates a gesture surface.
  const GestureSurface({super.key, required this.child, this.onGesture});

  /// Content receiving the gestures.
  final Widget child;

  /// Overrides where gestures go (tests); defaults to the command bus.
  final void Function(GestureType gesture)? onGesture;

  /// Marks [pointer] as handled by a button under the finger.
  static void claimPointer(BuildContext context, int pointer) {
    context
        .getInheritedWidgetOfExactType<_GestureSurfaceScope>()
        ?.state
        ._claimed
        .add(pointer);
  }

  @override
  ConsumerState<GestureSurface> createState() => _GestureSurfaceState();
}

class _GestureSurfaceState extends ConsumerState<GestureSurface> {
  final Set<int> _claimed = {};
  late final GestureClassifier _classifier = GestureClassifier(
    onGesture: _dispatch,
    onFirstTouch: () => ref.read(hapticsProvider).tick(),
  );

  void _dispatch(GestureType gesture) {
    if (!mounted) return;
    final handler = widget.onGesture;
    if (handler != null) {
      handler(gesture);
    } else {
      ref.read(commandBusProvider).onGesture(gesture);
    }
  }

  /// TalkBack's long-press or custom action: listen now (without a hold to
  /// release). Ignored while a held touch already started listening.
  void _listenFromTalkBack() {
    if (!mounted || _classifier.holding) return;
    final handler = widget.onGesture;
    if (handler != null) {
      handler(GestureType.longPress);
    } else {
      unawaited(ref.read(commandBusProvider).dispatch(NavIntent.listen));
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final talkBack = ref.watch(talkBackProvider);
    _classifier.holdOnly = talkBack;
    final surface = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _classifier.pointerDown(
        e.pointer,
        e.localPosition,
        e.timeStamp,
        claimed: _claimed.remove(e.pointer),
      ),
      onPointerMove: (e) => _classifier.pointerMove(e.pointer, e.localPosition),
      onPointerUp: (e) =>
          _classifier.pointerUp(e.pointer, e.localPosition, e.timeStamp),
      onPointerCancel: (e) => _classifier.pointerCancel(e.pointer),
      // A swipe here is a command: content may still scroll (large
      // text) but must not stretch or glow at the edges as if the
      // swipe were meant for it.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: widget.child,
      ),
    );
    return _GestureSurfaceScope(
      state: this,
      child: talkBack
          ? Semantics(
              container: true,
              onLongPress: _listenFromTalkBack,
              customSemanticsActions: {
                CustomSemanticsAction(
                  label: AppLocalizations.of(context).gestureHoldListenAction,
                ): _listenFromTalkBack,
              },
              child: surface,
            )
          : surface,
    );
  }
}

class _GestureSurfaceScope extends InheritedWidget {
  const _GestureSurfaceScope({required this.state, required super.child});

  final _GestureSurfaceState state;

  @override
  bool updateShouldNotify(_GestureSurfaceScope oldWidget) => false;
}
