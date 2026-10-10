/// Layout and sizing constants shared across the app.
///
/// Colors, fonts and text sizes are NOT here — they live in the theme
/// (`lib/app/theme/`) because users can change them in Accessibility Settings.
abstract final class AppDimens {
  /// Minimum height/width of anything the user can activate.
  static const double minTouchTarget = 56;

  /// Horizontal padding of every screen.
  static const double pagePadding = 32;

  /// Corner radius of pill buttons (large enough to be fully rounded).
  static const double pillRadius = 40;

  /// Corner radius of bordered panels (Gesture Pad, Document Box).
  static const double panelRadius = 8;

  /// Stroke width of bordered panels.
  static const double panelBorderWidth = 1;

  /// Vertical gap between stacked pill buttons.
  static const double buttonGap = 14;

  /// Share of the screen height taken by the Gesture Pad.
  static const double gesturePadHeightFraction = 0.3;

  /// Smallest Gesture Pad height, for short screens or landscape.
  static const double gesturePadMinHeight = 160;

  /// Size of the Speaking Zone waveform.
  static const double waveformWidth = 200;

  /// Height of the Speaking Zone waveform.
  static const double waveformHeight = 48;

  /// Width of the speed strip at the right edge of the Gesture Pad.
  static const double speedStripWidth = 88;

  /// Finger travel on the speed strip for one 0.25x step.
  static const double speedStepDistance = 36;
}

/// Timing constants.
abstract final class AppDurations {
  /// How long a Document Box caption ("Bilis: 1.2x") stays before fading.
  static const Duration captionVisible = Duration(seconds: 2);

  /// Fade in/out of transient UI such as captions and the "heard" line.
  static const Duration fade = Duration(milliseconds: 250);

  /// One full cycle of the waveform animation.
  static const Duration waveformCycle = Duration(milliseconds: 1400);

  /// In voice mode, stop auto-listening after this long with no command or
  /// gesture (saves battery and avoids endless recognizer beeps). A
  /// long-press re-arms it.
  static const Duration voiceIdleLimit = Duration(seconds: 60);

  /// How long "Narinig: …" stays under the waveform.
  static const Duration heardVisible = Duration(seconds: 3);

  /// A pending "oo/hindi" question or offer expires after this.
  static const Duration pendingAnswer = Duration(seconds: 20);

  /// The speed strip speaks the new speed once the finger has been still
  /// this long (fast drags never queue speech).
  static const Duration speedSpeakDelay = Duration(milliseconds: 450);
}
