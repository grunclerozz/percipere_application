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

  /// Bigger document text ("palakihin"). Also the A+ button and pinch out.
  textBigger,

  /// Smaller document text ("paliitin"). Also the A- button and pinch in.
  textSmaller,

  /// Start reading the document ("basahin").
  read,

  /// Pause reading ("i-pause").
  pause,

  /// Resume reading ("ituloy").
  resume,

  /// Read from the beginning ("mula sa simula").
  readFromStart,

  /// Save the document to the Library ("i-save").
  save,

  /// Go to the Home screen ("home", "simula").
  home,

  /// Open the camera ("camera").
  camera,

  /// Take the photo; elsewhere same as [camera] ("kunan").
  capture,

  /// Upload a file ("mag-upload").
  upload,

  /// Open the Library ("aklatan", "kasaysayan").
  library,

  /// Reader: next chapter.
  nextChapter,

  /// Reader: previous chapter.
  previousChapter,

  /// Reader: save this spot as a favorite.
  favorite,

  /// Reader: list the favorites of this item.
  favorites,

  /// Open Accessibility Settings ("settings", "ayos"). Phase 6.
  settings,

  /// Open "Mag-report ng problema" ("mag-report", "may problema"). Phase 10.
  report,

  /// Open Maglarawan's existing image-source route.
  describe,

  /// Replay the existing controls tutorial.
  tutorial,

  /// Switch to voice navigation ("pa-boses").
  voiceMode,

  /// Switch to gesture navigation ("pa-galaw").
  gestureMode,

  /// Starts or ends a conversation with Percy, the voice assistant.
  assistant,
}
