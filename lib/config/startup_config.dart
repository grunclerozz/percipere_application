/// The startup loading screen ("Pakihintay po, inihahanda ang Percipere.").
abstract final class StartupConfig {
  /// Longest wait on the loading screen. After it the app goes on with what
  /// is ready, says once that some parts are still loading, and finishes
  /// loading in the background.
  static const Duration timeout = Duration(seconds: 15);

  /// Pause after "Handa na po" and its tone before the first screen opens.
  static const Duration afterReady = Duration(milliseconds: 250);
}
