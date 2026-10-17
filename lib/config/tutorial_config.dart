/// The controls tutorial's skip rule on the first launch: the user hears
/// Percy's introduction (the first step) before skipping is possible.
abstract final class TutorialConfig {
  /// Shortest time the first step must have been spoken for, to count as
  /// heard. A voice that fails reports "done" at once; that is not hearing
  /// it, so skipping then waits for [firstStepTimeout]. Percy's introduction
  /// takes about 25 seconds at normal speed, 10 at the fastest.
  static const Duration firstStepMinSpoken = Duration(seconds: 5);

  /// Longest wait before skipping is allowed anyway (speech that failed, was
  /// cut off, or never reports its end), so nobody is trapped. Counted from
  /// when the tutorial opens.
  static const Duration firstStepTimeout = Duration(seconds: 60);
}
