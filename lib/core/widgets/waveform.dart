import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';

/// Horizontal audio waveform of thin vertical bars.
///
/// Animates while [active] (TTS speaking or STT listening) and is static when
/// idle. Also static when the system "remove animations" setting is on.
/// Purely decorative: excluded from semantics (the subtitle carries meaning).
class Waveform extends StatefulWidget {
  /// Creates a waveform.
  const Waveform({
    super.key,
    this.active = false,
    this.width = AppDimens.waveformWidth,
    this.height = AppDimens.waveformHeight,
  });

  /// Whether the bars should move.
  final bool active;

  /// Painted width.
  final double width;

  /// Painted height (the tallest bar).
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.waveformCycle,
  );

  bool get _shouldAnimate =>
      widget.active && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating || _controller.value != 0) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(widget.width, widget.height),
          painter: WaveformPainter(
            progress: _controller,
            animating: _shouldAnimate,
            color: context.palette.waveform,
          ),
        ),
      ),
    );
  }
}

/// Paints the waveform bars. [progress] (0..1) drives the animation.
class WaveformPainter extends CustomPainter {
  /// Creates the painter; repaints whenever [progress] ticks.
  WaveformPainter({
    required this.progress,
    required this.animating,
    required this.color,
  }) : super(repaint: progress);

  /// Animation cycle position, 0..1.
  final Animation<double> progress;

  /// When false, bars are drawn at their resting heights.
  final bool animating;

  /// Bar color.
  final Color color;

  /// Resting bar heights (fraction of full height), shaped after the design:
  /// short at the edges, clusters of tall bars toward the middle.
  static const List<double> restingHeights = [
    0.12, 0.20, 0.30, 0.18, 0.42, 0.58, 0.34, 0.72, 0.44, 0.24, 0.36, //
    0.52, 0.30, 0.64, 0.86, 0.50, 0.38, 0.68, 1.00, 0.62, 0.40, 0.56, //
    0.80, 0.46, 0.30, 0.60, 0.74, 0.36, 0.22, 0.48, 0.62, 0.30, 0.40, //
    0.66, 0.50, 0.28, 0.38, 0.24, 0.32, 0.18, 0.12,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final n = restingHeights.length;
    final step = size.width / n;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, step * 0.42);
    final centerY = size.height / 2;
    final t = progress.value;

    for (var i = 0; i < n; i++) {
      var h = restingHeights[i];
      if (animating) {
        // Integer speeds so the loop is seamless at t = 0/1.
        final speed = 1 + (i * 7) % 3;
        final wave = 0.5 + 0.5 * math.sin(2 * math.pi * t * speed + i * 0.9);
        h *= 0.3 + 0.7 * wave;
      }
      final half = math.max(h, 0.06) * size.height / 2;
      final x = step * (i + 0.5);
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.animating != animating || oldDelegate.color != color;
}
