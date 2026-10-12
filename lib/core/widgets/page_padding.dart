import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/constants.dart';

/// The one padding every screen uses: [AppDimens.pagePadding] at the sides,
/// [AppDimens.pageVerticalPadding] above and below, and on wide screens
/// (tablet) extra side space so the content stays at most
/// [AppDimens.maxContentWidth] wide and centered.
///
/// Uses the screen width (every screen is full width). Only the sides grow, so the child still gets the full height it had
/// (a `Spacer` or `Expanded` inside keeps working).
class PagePadding extends StatelessWidget {
  /// Creates the padding around [child].
  const PagePadding({
    super.key,
    required this.child,
    this.top = AppDimens.pageVerticalPadding,
    this.bottom = AppDimens.pageVerticalPadding,
  });

  /// The screen content.
  final Widget child;

  /// Space above the content.
  final double top;

  /// Space below the content.
  final double bottom;

  /// The space at each side for a screen [width].
  static double sideFor(double width) => width.isFinite
      ? math.max(AppDimens.pagePadding, (width - AppDimens.maxContentWidth) / 2)
      : AppDimens.pagePadding;

  @override
  Widget build(BuildContext context) {
    // The screen width, not a LayoutBuilder: some screens sit in a
    // SliverFillRemaining, which needs intrinsic sizes.
    final side = sideFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, top, side, bottom),
      child: child,
    );
  }
}
