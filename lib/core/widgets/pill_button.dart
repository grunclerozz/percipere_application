import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../gestures/gesture_surface.dart';
import 'fit_text.dart';

/// Visual style of a [PillButton].
enum PillVariant {
  /// Navy fill, white text.
  primary,

  /// Beige fill, navy text.
  secondary,

  /// Smaller white button ("Subukan muna (Try first)" on Welcome); on the
  /// dark themes, the dark secondary fill with an outline.
  tertiary,
}

/// Full-width, pill-shaped button from the design (min 56dp tall, bold label,
/// soft drop shadow).
///
/// [focused] draws a thick ring around the button when it holds the
/// accessibility focus of the focus model (gesture/voice navigation), so the
/// focused item is visible without relying on color alone.
class PillButton extends StatelessWidget {
  /// Creates a pill button.
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.primary,
    this.focused = false,
    this.semanticHint,
  });

  /// Visible and spoken label.
  final String label;

  /// Called on tap (or TalkBack activation). Null disables the button.
  final VoidCallback? onPressed;

  /// Primary or secondary style.
  final PillVariant variant;

  /// Whether the focus model currently points at this button.
  final bool focused;

  /// Optional extra screen-reader hint.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isPrimary = variant == PillVariant.primary;
    final isTertiary = variant == PillVariant.tertiary;
    final fill = isPrimary
        ? p.primary
        : isTertiary
        ? p.tertiary
        : p.secondary;
    final ink = isPrimary ? p.onPrimary : p.onSecondary;
    final outline = isPrimary ? Colors.transparent : p.secondaryOutline;
    final labelStyle = isTertiary
        ? Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15)
        : Theme.of(context).textTheme.labelLarge;
    const radius = BorderRadius.all(Radius.circular(AppDimens.pillRadius));

    // Claim pointers so a surrounding gesture surface doesn't also treat
    // this tap as a "repeat" / "activate" gesture.
    return Listener(
      onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        focused: focused,
        label: label,
        hint: semanticHint,
        onTap: onPressed,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: AppDurations.fade,
          // The ring is always laid out (transparent when unfocused) so focusing
          // never shifts the layout.
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(
                color: focused ? p.focusRing : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 10,
                  offset: const Offset(3, 5),
                ),
              ],
            ),
            child: Material(
              color: fill,
              shape: StadiumBorder(
                side: BorderSide(color: outline, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimens.minTouchTarget,
                    minWidth: double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Center(
                      widthFactor: 1,
                      // One line, shrunk to fit: the button never grows.
                      child: FitText(
                        label,
                        style: labelStyle?.copyWith(color: ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
