/// Thresholds for the capture quality check (Laplacian variance and
/// brightness) and for the Otsu OCR fallback, in one place so they can be
/// tuned after trying real phones.
///
/// The `[IMAGE QUALITY]` and `[OCR FALLBACK]` log lines (`adb logcat -s
/// flutter`) show the measured values for every capture.
abstract final class ImageQualityConfig {
  /// The photo is shrunk so its longest side is this many pixels before it
  /// is measured (speed, and the same scale for every phone). The
  /// thresholds below belong to this size.
  static const int analysisMaxSide = 320;

  /// Variance of the 3x3 Laplacian below this means a blurry photo (few
  /// sharp edges). Unverified starting value: tune from the log.
  static const double blurVarianceBelow = 50;

  /// Mean luminance (0-255) below this means too dark.
  static const double tooDarkBelow = 45;

  /// Mean luminance (0-255) above this means too bright.
  static const double tooBrightAbove = 235;
}

/// When the first OCR result is "weak" and the Otsu retry runs.
abstract final class OcrFallbackConfig {
  /// Fewer letters and digits than this: weak.
  static const int weakBelowChars = 20;

  /// Mean ML Kit line confidence below this: weak.
  static const double weakBelowConfidence = 0.6;

  /// The binarized image is shrunk to this longest side first (speed);
  /// never enlarged.
  static const int maxSide = 2400;
}
