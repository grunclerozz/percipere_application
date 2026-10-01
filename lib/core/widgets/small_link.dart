import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../gestures/gesture_surface.dart';
import 'fit_text.dart';

/// A compact outlined link to a secondary destination (History, Settings,
/// "Nakalimutan ang password"). Full width, at least 56 dp tall; labels
/// never wrap mid-word.
class SmallLink extends StatelessWidget {
  /// Creates a link.
  const SmallLink({
    super.key,
    required this.label,
    required this.icon,
    required this.focused,
    required this.onPressed,
    this.lines = 1,
  });

  /// Lines the label may use before it shrinks to fit.
  final int lines;

  /// Visible and spoken label.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// Whether the focus model points at this link.
  final bool focused;

  /// Called on tap.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Listener(
      onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: p.primary),
          label: FitText(
            label,
            lines: lines,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimens.minTouchTarget),
            shape: const StadiumBorder(),
            side: BorderSide(
              color: focused ? p.focusRing : p.border,
              width: focused ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
