/// Voice-input timing and thresholds, in one place so they can be tuned on
/// the tablet without touching the listening logic.
///
/// The `[VOICE TIMING]` log line (`adb logcat -s flutter`) shows what each
/// command actually took; change these values, rebuild and compare.
abstract final class VoiceConfig {
  // ── Hold to listen ───────────────────────────────────────────────────────

  /// How long one finger must stay still on the gesture area before the app
  /// stops speaking and listens (long-press). Long enough that resting a
  /// hand on the screen does not trigger it (0.6–0.8 s is sensible).
  static const Duration holdToListen = Duration(milliseconds: 650);

  // ── Pauses: how long a silence ends a listening session ──────────────────

  /// How long a session waits for the user to **start** speaking. The short
  /// pauses below only apply once words have been heard. Timed by the app
  /// (`SttSpeechInput`), never handed to Android: Android would use it as the
  /// silence that ends speech and hold every result back this long.
  static const Duration waitForSpeech = Duration(seconds: 4);

  /// Silence after the user's words that ends a **command** ("i-pause",
  /// "susunod"): the single end-of-speech timeout (1.2–1.5 s is sensible).
  /// Short, so the command runs soon after the user stops talking; partial
  /// results usually act before it anyway. Raise it if commands get cut
  /// off; lower it for a snappier response.
  static const Duration commandPause = Duration(milliseconds: 1300);

  /// Silence that ends **dictation** (names, email, password, collection
  /// names, titles). Longer, so users can stop to think mid-way.
  static const Duration dictationPause = Duration(seconds: 4);

  /// Silence that ends what the user says to **Percy** (a whole sentence,
  /// maybe with a pause to think): longer than a command, shorter than
  /// dictation.
  static const Duration percyPause = Duration(milliseconds: 2200);

  /// Longest single listening session (dictation).
  static const Duration listenFor = Duration(seconds: 30);

  /// Longest **command** session. Short, so a noisy room (where the words
  /// never stop changing) can't keep one session open: it ends, the result
  /// is judged, and a fresh session starts.
  static const Duration commandListenFor = Duration(seconds: 10);

  /// Longest Percy session.
  static const Duration percyListenFor = Duration(seconds: 20);

  /// Once words have been heard in a command session, it ends after this
  /// long even if the words keep changing (background talk, TV): commands
  /// are short, and what was heard is judged at once.
  static const Duration commandSpeechMax = Duration(seconds: 4);

  /// After online recognition failed for lack of network, the phone saying
  /// "connected" is trusted again only after this long (or when the
  /// connection comes back).
  static const Duration networkRetryAfter = Duration(seconds: 60);

  /// The Voice check test listen ("Sabihin: buksan ang Aklatan").
  static const Duration probeListenFor = Duration(seconds: 5);

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

  // ── Questions ────────────────────────────────────────────────────────────

  /// After asking a question the app stops talking and waits this long for
  /// an answer (voice, gesture or tap) before giving the instructions that
  /// follow it (how to answer, the mode hint). Speaking restarts the wait.
  /// Longer than [waitForSpeech] plus [afterSpeechGap], so a full listening
  /// session fits in it.
  static const Duration answerWait = Duration(seconds: 6);

  // ── Getting smarter with use ─────────────────────────────────────────────

  /// With "Awtomatiko" announcements, a screen opened this many times is
  /// familiar: its navigation hint and how-to-answer lines are left out.
  static const int familiarAfter = 3;

  /// Misunderstood commands in a row before the app offers the tutorial
  /// (and announcements go back to full detail).
  static const int missesBeforeHelp = 3;

  // ── Speech that gets cut off ─────────────────────────────────────────────

  /// A session cut off while the user was speaking (recognizer busy, audio
  /// focus lost, the app starting to talk) is restarted at once, keeping
  /// the words heard so far. After this many restarts in a row the app
  /// says "Pasensya na po, pakiulit."
  static const int cutOffRetries = 3;

  /// How long the restarted session waits for more words before acting on
  /// what was already heard.
  static const Duration carryWait = Duration(seconds: 2);

  /// Words kept from a cut-off session older than this are dropped.
  static const Duration carryFor = Duration(seconds: 8);

  /// How long "Alin sa dalawa: …?" waits for the user to name one.
  static const Duration choiceWait = Duration(seconds: 20);

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

  /// Reading pauses while the user speaks over it (so they can be heard)
  /// and resumes after this long at most if no command came.
  static const Duration duckMax = Duration(seconds: 5);

  /// After a pause for speech that turned out not to be a command, reading
  /// isn't paused for speech again for this long (a misheard echo must not
  /// make it restart the same sentence over and over).
  static const Duration duckCooldown = Duration(seconds: 8);

  // ── Timing logs ──────────────────────────────────────────────────────────

  /// Microphone level (Android rms dB, about −2 silent to 10 loud) taken as
  /// "speech started" in the `[VOICE TIMING]` log. Logging only.
  static const double speechStartLevel = 3;

  // ── Offline engines (bundled, downloaded once) ───────────────────────────

  /// Silence that ends a command for the app's own offline recognizer
  /// (Whisper + Silero VAD). Shorter than [commandPause]: the Android
  /// recognizer acts on partial results long before its pause ends, ours
  /// only once the speech has ended. Raise it if commands get cut off.
  static const Duration offlineEndOfSpeech = Duration(milliseconds: 700);

  // ── Reliability (2026-10-17, branch fix/voice-reliability) ───────────────

  /// After a listening session is cancelled or stopped, the Android
  /// recognizer is left alone this long before the next session starts.
  /// Starting at once gave `error_busy`, and late errors of the cancelled
  /// session were taken as the new session failing ("say it twice", "hold
  /// twice").
  static const Duration recognizerSettle = Duration(milliseconds: 300);

  /// The "listening" tone plays when the microphone actually delivers sound
  /// (first sound level), not when listening is requested: Android opens
  /// the microphone 0.2–0.6 s later, and words said in between were lost.
  /// If no sound has come after this long, the tone plays anyway.
  static const Duration cueFallback = Duration(milliseconds: 1500);

  /// Android reports the end of a failed session (`done`) a moment before
  /// the error that explains it: the app waits this long for the error
  /// before deciding what happened.
  static const Duration errorAfterDone = Duration(milliseconds: 200);

  /// A session event (end, error) this soon after the session started, when
  /// the session before it was closed by the app just before, belongs to
  /// that closed session: the new session is restarted quietly instead of
  /// counting as a failure.
  static const Duration staleEventWindow = Duration(milliseconds: 1000);

  /// Sessions in a row that never got any sound from the microphone before
  /// the app stops listening and says so (a dead recognizer). Sessions that
  /// heard sound prove the recognizer works and never count.
  static const int deadRecognizerAfter = 5;

  /// After giving up, the "voice isn't working" message waits this long: a
  /// late result that arrives meanwhile is acted on and the message is
  /// dropped.
  static const Duration giveUpGrace = Duration(milliseconds: 1500);

  // ── Noise (2026-10-17) ───────────────────────────────────────────────────

  /// Ask the phone's noise suppressor to clean the app's own microphone
  /// (offline commands), when the phone has one. The Android recognizer
  /// uses its own settings.
  static const bool micNoiseSuppressor = true;

  /// Ask the phone's automatic gain control for the app's own microphone.
  /// Off: it also raises background noise between words, which keeps the
  /// voice detector from hearing the end of a command.
  static const bool micAutoGain = false;

  /// Microphone level (about −2 silent to 10 loud) that counts as a noisy
  /// room when heard before the user's words.
  static const double noisyLevel = 4;

  /// Share of the level readings before the user's words at or above
  /// [noisyLevel] for the room to count as noisy (at least
  /// [noisyMinReadings] readings).
  static const double noisyShare = 0.5;

  /// Fewest level readings to judge the room by.
  static const int noisyMinReadings = 5;

  /// The recognizer's confidence (0..1, when it gives one) below which a
  /// result counts as uncertain, as in noise.
  static const double lowConfidence = 0.5;

  /// In a noisy room (or an uncertain result), a command at least this
  /// similar is asked back ("Ito po ba ang ibig ninyong sabihin…?") instead
  /// of "not understood". The quiet-room floor is 0.6 (`CommandMatcher`).
  static const double noisyAskScore = 0.45;
}
