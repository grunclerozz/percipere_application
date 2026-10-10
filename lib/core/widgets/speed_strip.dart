import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/haptics.dart';
import '../tts/reading_rate.dart';
import '../tts/speed_control.dart';

/// The reading-speed strip at the right edge of the Gesture Pad: slide up
/// for faster, down for slower (0.25x steps, 0.5x–2.0x), a tick per step,
/// and the new speed spoken once the finger stops.
///
/// It sits beside the pad's gesture surface, not on it, so its drags never
/// count as next/back swipes and the pad's swipes never change the speed.
/// TalkBack users get an adjustable control (swipe up/down on it) with
/// "Bilisan" / "Bagalan" actions.
class SpeedStrip extends ConsumerStatefulWidget {
  /// Creates the strip.
  const SpeedStrip({super.key});

  @override
  ConsumerState<SpeedStrip> createState() => _SpeedStripState();
}

class _SpeedStripState extends ConsumerState<SpeedStrip> {
  double _travel = 0;

  SpeedControl get _control => ref.read(speedControlProvider);

  void _onDrag(DragUpdateDetails d) {
    // Up (negative dy) is faster.
    _travel -= d.delta.dy;
    while (_travel.abs() >= AppDimens.speedStepDistance) {
      final direction = _travel > 0 ? 1 : -1;
      _travel -= direction * AppDimens.speedStepDistance;
      _control.step(direction);
    }
  }

  void _onRelease() {
    _travel = 0;
    _control.release();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final rate = ref.watch(readingRateProvider);
    final value = ReadingRate.label(rate);
    final strong = textTheme.labelLarge?.copyWith(
      color: p.heading,
      fontWeight: FontWeight.w700,
    );

    Widget fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

    return Semantics(
      container: true,
      label: l10n.speedStripValue(value),
      onIncrease: () => _control.step(1),
      onDecrease: () => _control.step(-1),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.speedIncrease): () =>
            _control.step(1),
        CustomSemanticsAction(label: l10n.speedDecrease): () =>
            _control.step(-1),
      },
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => ref.read(hapticsProvider).tick(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _travel = 0,
          onVerticalDragUpdate: _onDrag,
          onVerticalDragEnd: (_) => _onRelease(),
          onVerticalDragCancel: _onRelease,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: p.border,
                  width: AppDimens.panelBorderWidth,
                ),
              ),
            ),
            child: SizedBox(
              width: AppDimens.speedStripWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: fit(
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: p.heading,
                              size: 28,
                            ),
                            Text(
                              '${ReadingRate.label(ReadingRate.max)}x',
                              style: strong,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: fit(
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.speedStripLabel,
                              style: textTheme.labelMedium?.copyWith(
                                color: p.body,
                              ),
                            ),
                            Text(
                              '${value}x',
                              style: textTheme.titleMedium?.copyWith(
                                color: p.heading,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: fit(
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${ReadingRate.label(ReadingRate.min)}x',
                              style: strong,
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: p.heading,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
