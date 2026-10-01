import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../l10n/app_localizations.dart';
import '../gestures/gesture_surface.dart';
import 'bordered_panel.dart';

/// The Gesture Pad: the bordered box at the bottom of in-app screens and the
/// only surface where navigation gestures are detected (so they never clash
/// with scrolling or buttons elsewhere).
///
/// A light haptic tick confirms when a finger lands on it. Long-press starts
/// voice listening in any mode.
class GesturePad extends StatelessWidget {
  /// Creates a Gesture Pad.
  const GesturePad({super.key, required this.hint, this.showHintLabel = true});

  /// Screen-reader hint listing the main gestures for the current screen.
  final String hint;

  /// Show the very faint "Gesture area" label inside the pad.
  final bool showHintLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;

    return Semantics(
      container: true,
      label: l10n.gestureAreaLabel,
      hint: hint,
      child: BorderedPanel(
        child: GestureSurface(
          child: SizedBox.expand(
            child: showHintLabel
                ? Center(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          l10n.gestureAreaLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: p.muted.withValues(
                                  alpha: p.muted.a * 0.6,
                                ),
                              ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
