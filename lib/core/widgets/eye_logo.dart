import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// The Percipere eye mark shown at the top of most screens (mockups).
/// Decorative: hidden from screen readers, drawn in the theme's heading
/// color so it follows the chosen theme.
class EyeLogo extends StatelessWidget {
  /// Creates the logo at [size] logical pixels wide.
  const EyeLogo({super.key, this.size = 30});

  /// Width; the height follows the eye's proportions.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: CustomPaint(
          size: Size(size, size * 0.62),
          painter: _EyePainter(context.palette.heading),
        ),
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.055)
      ..strokeCap = StrokeCap.round;

    // Almond outline.
    final outline = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(w * 0.5, -h * 0.35, w, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 1.35, 0, h * 0.5);
    canvas.drawPath(outline, stroke);

    // Iris ring and pupil.
    final center = Offset(w * 0.5, h * 0.5);
    canvas
      ..drawCircle(center, h * 0.3, stroke)
      ..drawCircle(center, h * 0.13, Paint()..color = color);

    // The upper lash line that sweeps past the corner in the mark.
    final lash = Path()
      ..moveTo(w * 0.62, h * 0.04)
      ..quadraticBezierTo(w * 0.9, h * 0.12, w * 1.0, h * 0.28);
    canvas.drawPath(lash, stroke..strokeWidth = stroke.strokeWidth * 0.7);
  }

  @override
  bool shouldRepaint(_EyePainter oldDelegate) => oldDelegate.color != color;
}
