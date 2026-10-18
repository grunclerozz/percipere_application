import 'package:flutter/material.dart';

import '../../config/constants.dart';
import 'eye_logo.dart';

/// The Percipere eye mark breathing slowly (a gentle grow-and-shrink with a
/// soft fade), for the loading screen.
///
/// Calm on purpose: one slow pulse, no spinning or flashing. Pulses only
/// while [active] and stays still when the system "remove animations"
/// setting is on. Decorative, hidden from screen readers (the status is in
/// the progress text).
class PulsingLogo extends StatefulWidget {
  /// Creates the logo at [size] logical pixels wide.
  const PulsingLogo({super.key, this.active = true, this.size = 72});

  /// Whether the logo pulses.
  final bool active;

  /// Width of the eye.
  final double size;

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.logoPulse,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  bool get _shouldAnimate =>
      widget.active && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulsingLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
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
        child: AnimatedBuilder(
          animation: _curve,
          child: EyeLogo(size: widget.size),
          builder: (context, child) => Opacity(
            opacity: 0.65 + 0.35 * _curve.value,
            child: Transform.scale(
              scale: 0.88 + 0.16 * _curve.value,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
