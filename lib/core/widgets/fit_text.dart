import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Text that always stays inside its box: the box has a fixed height of
/// [lines] lines of [style], and text that would need more room is shrunk to
/// fit instead of pushing the rest of the screen down (review feedback:
/// boxes keep their size, nothing needs scrolling).
///
/// With one line the text never wraps and shrinks to the box width; with
/// several it wraps at the box width and shrinks to the box height.
class FitText extends StatelessWidget {
  /// Creates fitted text.
  const FitText(
    this.text, {
    super.key,
    required this.style,
    this.lines = 1,
    this.textAlign = TextAlign.center,
    this.textScaler,
  });

  /// The text.
  final String text;

  /// Its style (font size and line height decide the box height).
  final TextStyle? style;

  /// How many lines the box holds at full size.
  final int lines;

  /// Alignment within the box.
  final TextAlign textAlign;

  /// Overrides the ambient text scaler.
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final scaler = textScaler ?? MediaQuery.textScalerOf(context);
    final fontSize = style?.fontSize ?? 14;
    final lineHeight = scaler.scale(fontSize) * (style?.height ?? 1.25);
    // A little slack so descenders aren't clipped.
    final boxHeight = lineHeight * lines + 2;
    return _ScaleDownBox(
      height: boxHeight,
      wrap: lines > 1,
      child: Text(
        text,
        textAlign: textAlign,
        style: style,
        textScaler: scaler,
        softWrap: lines > 1,
        maxLines: lines > 1 ? null : 1,
      ),
    );
  }
}

/// A box of fixed [height] (and the available width) whose child is laid out
/// at that width ([wrap]) or at its natural width (no wrap), then scaled
/// down uniformly, never up, to fit, and centered.
class _ScaleDownBox extends SingleChildRenderObjectWidget {
  const _ScaleDownBox({
    required this.height,
    required this.wrap,
    required super.child,
  });

  final double height;
  final bool wrap;

  @override
  _RenderScaleDownBox createRenderObject(BuildContext context) =>
      _RenderScaleDownBox(height, wrap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScaleDownBox renderObject,
  ) {
    renderObject
      ..boxHeight = height
      ..wrap = wrap;
  }
}

class _RenderScaleDownBox extends RenderProxyBox {
  _RenderScaleDownBox(this._boxHeight, this._wrap);

  double _boxHeight;
  set boxHeight(double v) {
    if (v == _boxHeight) return;
    _boxHeight = v;
    markNeedsLayout();
  }

  bool _wrap;
  set wrap(bool v) {
    if (v == _wrap) return;
    _wrap = v;
    markNeedsLayout();
  }

  double _scale = 1;
  Offset _offset = Offset.zero;

  // Fixed height whatever the text: layouts measuring intrinsics (e.g.
  // SliverFillRemaining) see a stable box.
  @override
  double computeMinIntrinsicHeight(double width) => _boxHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _boxHeight;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.maxWidth, _boxHeight));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _boxHeight));
      return;
    }
    final bounded = constraints.hasBoundedWidth;
    child.layout(
      _wrap && bounded
          ? BoxConstraints(maxWidth: constraints.maxWidth)
          : const BoxConstraints(),
      parentUsesSize: true,
    );
    final c = child.size;
    // In an unbounded row the box is as wide as the text.
    size = constraints.constrain(
      Size(bounded ? constraints.maxWidth : c.width, _boxHeight),
    );
    _scale = math.min(
      1,
      math.min(
        c.width <= 0 ? 1 : size.width / c.width,
        c.height <= 0 ? 1 : size.height / c.height,
      ),
    );
    _offset = Offset(
      (size.width - c.width * _scale) / 2,
      (size.height - c.height * _scale) / 2,
    );
  }

  Matrix4 get _transform => Matrix4.identity()
    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
    ..scaleByDouble(_scale, _scale, 1, 1);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            child?.hitTest(result, position: position) ?? false,
      );
}
