/// Voice-input timing and thresholds, in one place so they can be tuned on
/// the tablet without touching the listening logic.
///
/// The `[VOICE TIMING]` log line (`adb logcat -s flutter`) shows what each
/// command actually took; change these values, rebuild and compare.
abstract final class VoiceConfig {
  // ── Pauses: how long a silence ends a listening session ──────────────────

  /// How long a session waits for the user to **start** speaking. The short
  /// pauses below only apply once words have been heard (the plugin's
  /// silence timer otherwise starts when listening starts, and a session
  /// that ends that fast counts as a recognizer failure).
  static const Duration waitForSpeech = Duration(seconds: 4);

  /// Silence after the user's words that ends a **command** ("i-pause",
  /// "susunod"). Short, so the command runs soon after the user stops talking. Raise it if commands
  /// get cut off; lower it for a snappier response.
  static const Duration commandPause = Duration(milliseconds: 1200);

  /// Silence that ends **dictation** (names, email, password, collection
  /// names, titles). Longer, so users can stop to think mid-way.
  static const Duration dictationPause = Duration(seconds: 4);

  /// Longest single listening session.
  static const Duration listenFor = Duration(seconds: 30);

  /// After the recognizer is told to stop, how long to wait for its final
  /// result before using the last partial result instead (plugin default:
  /// 2 s).
  static const Duration finalTimeout = Duration(milliseconds: 800);

  // ── Acting on partial results ────────────────────────────────────────────

  /// A partial result this similar to a whole command (0..1) runs at once,
  /// without waiting for the final result.
  static const double partialAcceptScore = 0.9;

  /// A partial result at least this similar runs once the same command has
  /// matched in two partial results in a row.
  static const double partialRepeatScore = 0.8;

  // ── Gaps between listening sessions ──────────────────────────────────────

  /// Wait after the app stops speaking before listening again, so the
  /// microphone doesn't hear the speaker's echo.
  static const Duration afterSpeechGap = Duration(milliseconds: 450);

  /// Wait before the next session when nothing was spoken (a session ended
  /// in silence, or a result was discarded). Short, but not zero: the
  /// recognizer needs a moment after `done` or it answers `error_busy`.
  static const Duration sessionGap = Duration(milliseconds: 200);

  // ── Listening while reading (barge-in) ───────────────────────────────────

  /// Wait after document reading starts before opening the microphone.
  static const Duration bargeInStartDelay = Duration(milliseconds: 300);

  /// A heard word this similar to a word of the sentence being read (and at
  /// least [echoMinFuzzyLength] letters long) counts as the app's own voice.
  static const double echoWordSimilarity = 0.8;

  /// Shorter words must match the read text exactly to count as echo.
  static const int echoMinFuzzyLength = 4;

  /// How many recently read sentences count as the app's own voice.
  static const int echoSentences = 8;

  // ── Timing logs ──────────────────────────────────────────────────────────

  /// Microphone level (Android rms dB, about −2 silent to 10 loud) taken as
  /// "speech started" in the `[VOICE TIMING]` log. Logging only.
  static const double speechStartLevel = 3;
}
