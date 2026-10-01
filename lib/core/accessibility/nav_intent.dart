/// What the user wants to do, independent of how they asked (gesture or
/// voice). Gestures map to intents in `core/gestures/gesture_map.dart`;
/// voice commands map to intents or action ids (Phase 3).
enum NavIntent {
  /// Move focus to the next option (Reader: next sentence).
  next,

  /// Move focus to the previous option (Reader: previous sentence).
  previous,

  /// Activate the focused option.
  activate,

  /// Repeat the current prompt (Reader: play/pause).
  repeat,

  /// Reader: read faster. Lists: open item options.
  faster,

  /// Reader: read slower.
  slower,

  /// Go back one screen.
  back,

  /// Start listening for a voice command.
  listen,

  /// Stop all speech.
  stopSpeech,

  /// Explain the gestures and commands for this screen.
  help,

  /// Reader: next paragraph.
  nextParagraph,

  /// Reader: previous paragraph.
  previousParagraph,

  // ── Voice-only intents (no default gesture) ──────────────────────────────

  /// Start reading the document ("basahin").
  read,

  /// Pause reading ("i-pause").
  pause,

  /// Resume reading ("ituloy").
  resume,

  /// Read from the beginning ("mula sa simula").
  readFromStart,

  /// Save the document to history ("i-save").
  save,

  /// Go to the main (Capture) screen ("home", "simula").
  home,

  /// Open the camera ("camera").
  camera,

  /// Take the photo; elsewhere same as [camera] ("kunan").
  capture,

  /// Upload a file ("mag-upload").
  upload,

  /// Open Reading History ("kasaysayan"). Phase 6.
  history,

  /// Open Accessibility Settings ("settings", "ayos"). Phase 6.
  settings,

  /// Open Report / Feedback ("ulat"). Phase 7.
  report,

  /// Switch to voice navigation ("pa-boses").
  voiceMode,

  /// Switch to gesture navigation ("pa-galaw").
  gestureMode,
}
