import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';

/// Rounded rectangle with a thin border on the page background — the base of
/// the Gesture Pad and the Document Box.
class BorderedPanel extends StatelessWidget {
  /// Creates a bordered panel.
  const BorderedPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  /// Panel content (clipped to the rounded corners).
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.panelRadius));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: context.palette.border,
          width: AppDimens.panelBorderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
