# Percipere: system masterlist

Every source file of the app and what each class and function does. Generated on 9 October 2026 from
the **updated copy** (`percipere_app-main`, version 0.1.1+2), which contains everything in this
repository plus the 7 October additions (Percy, tutorial, natural phrasing, document insights).
Files only in the updated copy are marked 🆕. Descriptions come from the code's own `///` doc
comments (first sentence), so they describe what the code does.

**Size:** 139 Dart files, about 28,400 lines (generated translation files excluded), 51 test files
(667 tests), plus Android (Kotlin) and Python helper files.

## How the system fits together

```
 Gestures (Gesture Pad)   Voice (speech_to_text)   Taps (buttons)
          │                        │                     │
          └──────────────► CommandBus ◄──────────────────┘     core/accessibility
                               │  (matches phrases, runs screen actions,
                               │   asks yes/no, answers questions)
                               ▼
              ScreenRegistration of the active screen               features/*
                               │
         ┌─────────────────────┼────────────────────────┐
         ▼                     ▼                        ▼
   Announcer (TTS +      Reader / Library /      Percy (ElevenLabs,
   live subtitle)        Maglarawan logic        online, optional)
         │                     │
     core/tts       core/extraction, core/ocr, core/library,
                    core/describe, core/understanding, core/db (SQLite)
```

- **Input:** every gesture, voice command and tap becomes a `NavIntent` or an action id
  handled by the `CommandBus`. Gesture bindings live only in `gesture_map.dart`.
- **Output:** the `Announcer` speaks prompts sentence by sentence and shows them as subtitles in
  the Speaking Zone. The Reader drives TTS itself for sentence-level control.
- **Data:** one SQLite database (`app_database.dart`, versioned `migrations.dart`) with accounts,
  preferences and the Library. Login session in Android's encrypted storage.
- **Offline first:** OCR, image labeling, document insights, voice commands and TTS all run on
  the phone. Only Percy, the detailed Maglarawan description and admin books need internet
  (the last two are mocked until the web app exists).

## Folder overview

| Folder | Files | Lines | Responsibility |
|---|---:|---:|---|
| `lib/` (`main.dart`) | 1 | 11 | Entry point |
| `lib/app/` | 5 | 695 | App shell: root widget, startup, routes, ids, locale |
| `lib/app/theme/` | 3 | 499 | Colors, fonts, text sizes |
| `lib/config/` | 5 | 599 | Constants, voice timings, build settings, Filipino label map |
| `lib/core/accessibility/` | 12 | 2,216 | Command bus, announcer, focus, haptics, screen registration |
| `lib/core/assistant/` 🆕 | 5 | 1,153 | Percy, the voice assistant |
| `lib/core/auth/` | 10 | 1,090 | Accounts, passwords, session, fingerprint, lockout |
| `lib/core/db/` + `daos/` | 4 | 1,305 | SQLite, migrations, Library and preferences access |
| `lib/core/describe/` | 3 | 193 | Maglarawan image labeling and image prep |
| `lib/core/extraction/` | 4 | 461 | Image / PDF / DOCX → text |
| `lib/core/gestures/` | 3 | 407 | Gesture recognition and the gesture → intent map |
| `lib/core/library/` | 11 | 2,523 | Aklatan: models, admin books, EPUB/PDF, shelves, sync |
| `lib/core/network/` | 2 | 132 | Connectivity, online image description |
| `lib/core/ocr/` | 2 | 271 | ML Kit text recognition, text clean-up |
| `lib/core/platform/` | 4 | 155 | Permissions, system settings, storage, app close |
| `lib/core/settings/` | 2 | 388 | Settings model and controller |
| `lib/core/tts/` | 5 | 618 | Text-to-speech, sentences, language detection |
| `lib/core/understanding/` 🆕 | 1 | 467 | Document insights |
| `lib/core/voice/` | 6 | 2,190 | Speech recognition, command matching, natural phrasing |
| `lib/core/widgets/` | 13 | 1,629 | Shared UI widgets |
| `lib/features/auth/` | 13 | 2,511 | Login, register, password recovery, old PIN accounts |
| `lib/features/camera/` | 3 | 624 | Camera with spoken guidance |
| `lib/features/capture/` | 2 | 296 | Capture screen |
| `lib/features/describe/` | 3 | 789 | Maglarawan screens |
| `lib/features/home/` | 1 | 121 | Home screen |
| `lib/features/library/` | 6 | 2,762 | Library screens |
| `lib/features/reader/` | 2 | 1,359 | Reader |
| `lib/features/settings/` | 2 | 707 | Settings |
| `lib/features/setup/` | 3 | 1,426 | Guided setup (profiling) |
| `lib/features/tutorial/` 🆕 | 1 | 361 | Controls tutorial |
| `lib/features/upload/` | 1 | 178 | File picker |
| `lib/features/welcome/` | 1 | 231 | Welcome screen |
| `lib/l10n/` | 5 | — | Filipino (`app_fil.arb`, template) and English strings; Dart files generated |

## Screens at a glance

| Screen | File | What the user does there |
|---|---|---|
| Tutorial 🆕 | `features/tutorial/tutorial_screen.dart` | First launch: practise each gesture and a voice command; skippable |
| Welcome | `features/welcome/welcome_screen.dart` | Login, Register, or Subukan muna (guest) |
| Login / Register | `features/auth/login_screen.dart`, `register_screen.dart` | Spoken or typed forms; fingerprint login |
| Forgot password | `features/auth/forgot_password_screen.dart` | Email → security question → new password |
| Setup (profiling) | `features/setup/profiling_screen.dart` | Navigation mode, text size, colors, language, speed, pitch, theme, vibration, auto-read |
| Home | `features/home/home_screen.dart` | Magbasa ng bago (Capture) or Aklatan (Library) |
| Capture | `features/capture/capture_screen.dart` | Mag-upload, Gamit ang Camera, Maglarawan |
| Camera | `features/camera/camera_screen.dart` | Spoken framing guidance, auto-capture |
| Reader | `features/reader/reader_screen.dart` | Read aloud, skip, speed, text size, favorites, chapters, questions about the document |
| Maglarawan | `features/describe/describe_source_screen.dart`, `describe_screen.dart` | Describe a picture offline; detailed description online |
| Library | `features/library/library_screen.dart` | Shelves, search, filters, collections |
| Item details | `features/library/item_details_screen.dart` | Continue, chapters, favorites, collections, download, rename, delete |
| Favorites / Chapters | `features/library/favorites_screen.dart`, `chapters_screen.dart` | Jump to a saved spot or a chapter |
| Settings | `features/settings/settings_screen.dart` | All settings, tutorial replay, redo setup, logout |

---

# Dart source files (`lib/`)

How to read the tables: **bold** rows are top-level classes, functions, providers and constants;
↳ rows are the public methods and getters of the class above them.

## `lib/app/`

App shell: root widget, startup, routes, screen/action ids, locale.

### `app.dart`
_63 lines._ Root widget: wires theme, locale, text scaling and routing.

| Name | Kind | What it does |
|---|---|---|
| **`PercipereApp`** | class | Root widget: wires theme, locale, text scaling and routing. |
| **`UiTextScale`** | class | Keeps the screen layout fixed: buttons, fields and boxes keep their design size, so nothing overlaps or needs scrolling. |

### `bootstrap.dart`
_129 lines._ Startup work that must finish before the first frame: open the database, restore the session, load that account's settings (or the device's), start TTS and check which voices exist.

| Name | Kind | What it does |
|---|---|---|
| **`bootstrap`** | function | Startup work that must finish before the first frame: open the database, restore the session, load that account's settings (or the device's), start TTS and check which voices exist. |
| **`RestoredSession`** | typedef | The session found at startup. |
| **`restoreSession`** | function | Finds who is logged in: the secure-storage session (or, once, the pre-6B PIN login kept in preferences). |

### `ids.dart`
_226 lines._ Every screen id and action id used by the command bus (one constant each).

| Name | Kind | What it does |
|---|---|---|
| **`Ids`** | class | Every screen id and action id used by the command bus (one constant each). |

### `locale_provider.dart`
_16 lines._ The two supported locales (Filipino, English).

| Name | Kind | What it does |
|---|---|---|
| **`AppLocales`** | class | The two supported locales (Filipino, English). |
| **`appLocaleProvider`** | provider | The UI locale chosen in Settings. |

### `router.dart`
_261 lines._ Route paths.

| Name | Kind | What it does |
|---|---|---|
| **`AppRoutes`** | class | Route paths. |
| &nbsp;&nbsp;↳ `landing` | method | Where a logged-in account goes: set an email/password (old PIN account), finish the setup, or Home. |
| **`buildRouter`** | function | Builds the app router. |
| **`initialTutorialDoneProvider`** | provider | Whether the controls tutorial was already done on this device. |
| **`routerProvider`** | provider | The app-wide router. |

## `lib/app/theme/`

Colors, fonts and text sizes (themes chosen in setup and Settings).

### `app_palette.dart`
_261 lines._ Every color the UI uses, as a ThemeExtension so widgets can read it with `context.palette`.

| Name | Kind | What it does |
|---|---|---|
| **`AppPalette`** | class | Every color the UI uses, as a ThemeExtension so widgets can read it with `context.palette`. |
| &nbsp;&nbsp;↳ `of` | method | Looks up the preset for id. |
| &nbsp;&nbsp;↳ `withTextColor` | method | The preset for theme with the user's text color textColorId (an id from `TextColors`; unknown ids fall back to the theme default). |
| &nbsp;&nbsp;↳ `lerp` | method | Palettes switch instantly; interpolating between e.g. |
| **`AppPaletteContext`** | extension | Shorthand for reading the active AppPalette. |
| &nbsp;&nbsp;↳ `palette` | getter | The active palette. |

### `app_theme.dart`
_153 lines._ The user's reading-text size, as a ThemeExtension.

| Name | Kind | What it does |
|---|---|---|
| **`AppTextMetrics`** | class | The user's reading-text size, as a ThemeExtension. |
| **`AppTheme`** | class | Builds the app ThemeData from the user's ThemeSettings. |
| &nbsp;&nbsp;↳ `documentText` | method | Style for reading text (Document Box, setup preview): bold, in the user's text color, at exactly the user's text size. |

### `theme_settings.dart`
_85 lines._ Bundled font families the user can pick (all under `assets/fonts/`).

| Name | Kind | What it does |
|---|---|---|
| **`AppFont`** | enum | Bundled font families the user can pick (all under `assets/fonts/`). |
| **`TextSize`** | class | The user's reading-text size, in sp (profiling Step 2 and Settings). |
| &nbsp;&nbsp;↳ `normalize` | method | Clamps to the range and rounds to whole steps. |
| &nbsp;&nbsp;↳ `fromLegacyScale` | method | Converts the pre-6B percentage multiplier (0.8–2.0) to a size. |
| **`ThemeSettings`** | class | The user-adjustable visual settings that drive the theme. |
| **`themeSettingsProvider`** | provider | The app-wide theme settings; a view of settingsProvider. |

## `lib/config/`

Constants and tunable values (timings, voice thresholds, build-time settings, Filipino label map).

### `constants.dart`
_58 lines._ Layout and sizing constants shared across the app.

| Name | Kind | What it does |
|---|---|---|
| **`AppDimens`** | class | Layout and sizing constants shared across the app. |
| **`AppDurations`** | class | Timing constants. |

### `env.dart`
_53 lines._ Build-time environment configuration.

| Name | Kind | What it does |
|---|---|---|
| **`Env`** | class | Build-time environment configuration. |

### `image_labels_fil.dart`
_245 lines._ Filipino names for the most common labels of ML Kit's on-device image labeling model (which answers in English).

| Name | Kind | What it does |
|---|---|---|
| **`imageLabelsFil`** | constant | Filipino names for the most common labels of ML Kit's on-device image labeling model (which answers in English). |
| **`imageLabelReminders`** | constant | Labels (lowercase English) that suggest medicine, pills or money. |

### `palette.dart`
_148 lines._ The three color themes (profiling Step 7 and Settings).

| Name | Kind | What it does |
|---|---|---|
| **`ThemeId`** | enum | The three color themes (profiling Step 7 and Settings). |
| &nbsp;&nbsp;↳ `tryParse` | method | Parses a stored name. |
| **`TextColorOption`** | class | A text color the user can choose. |
| **`TextColors`** | class | Text colors per theme, in the order offered; the first is the theme's default. |
| &nbsp;&nbsp;↳ `forTheme` | method | The colors offered with theme; the first is its default. |
| &nbsp;&nbsp;↳ `defaultFor` | method | The default text color of theme. |
| &nbsp;&nbsp;↳ `resolve` | method | The option id if theme offers it, else the theme default. |
| &nbsp;&nbsp;↳ `offers` | method | Whether theme offers color id. |

### `voice_config.dart`
_95 lines._ Voice-input timing and thresholds, in one place so they can be tuned on the tablet without touching the listening logic.

| Name | Kind | What it does |
|---|---|---|
| **`VoiceConfig`** | class | Voice-input timing and thresholds, in one place so they can be tuned on the tablet without touching the listening logic. |

## `lib/core/accessibility/`

The accessibility core: every gesture, voice command and tap goes through the CommandBus; screens register their actions; the Announcer speaks.

### `accessibility_host.dart`
_121 lines._ App-level glue for the accessibility core.

| Name | Kind | What it does |
|---|---|---|
| **`AccessibilityHost`** | class | App-level glue for the accessibility core. |

### `accessible_screen.dart`
_88 lines._ Registers a screen's ScreenRegistration with the ActionRegistry while the screen is mounted.

| Name | Kind | What it does |
|---|---|---|
| **`AccessibleScreen`** | class | Registers a screen's ScreenRegistration with the ActionRegistry while the screen is mounted. |

### `action_registry.dart`
_50 lines._ Stack of registered screens; the last one is active.

| Name | Kind | What it does |
|---|---|---|
| **`ActionRegistry`** | class | Stack of registered screens; the last one is active. |
| &nbsp;&nbsp;↳ `top` | getter | The active screen, if any. |
| &nbsp;&nbsp;↳ `register` | method | Registers registration as the active screen. |
| &nbsp;&nbsp;↳ `replace` | method | Swaps old for next in place (same stack position), e.g. |
| &nbsp;&nbsp;↳ `unregister` | method | Removes registration wherever it is in the stack. |
| **`actionRegistryProvider`** | provider | Registered screens. |
| **`activeScreenProvider`** | provider | The active screen registration. |

### `announcer.dart`
_399 lines._ What the Speaking Zone shows: the sentence being spoken and whether speech (or, from Phase 3, listening) is in progress.

| Name | Kind | What it does |
|---|---|---|
| **`SpeechState`** | class | What the Speaking Zone shows: the sentence being spoken and whether speech (or, from Phase 3, listening) is in progress. |
| &nbsp;&nbsp;↳ `withSpeaking` | method | Returns a copy with speaking replaced. |
| &nbsp;&nbsp;↳ `withReading` | method | Returns a copy with reading replaced. |
| **`Announcer`** | class | Speaks prompts one sentence at a time and publishes each sentence as the live subtitle. |
| &nbsp;&nbsp;↳ `awaitingAnswer` | getter | Whether a question is waiting for the user's answer. |
| &nbsp;&nbsp;↳ `ask` | method | Asks question and waits for the answer before saying anything else. |
| &nbsp;&nbsp;↳ `answered` | method | The user answered or did something (command, gesture, tap): what was held back after the question is dropped. |
| &nbsp;&nbsp;↳ `userResponding` | method | The user has started speaking: give them the full wait again before any held-back instructions are spoken over them. |
| &nbsp;&nbsp;↳ `say` | method | Speaks text. |
| &nbsp;&nbsp;↳ `showSubtitle` | method | Shows text as the live subtitle without speaking it (what Percy, the voice assistant, and the user say). |
| &nbsp;&nbsp;↳ `setReading` | method | Marks document reading on/off (set by the Reader around its own TTS calls, which bypass this queue for sentence-level control). |
| &nbsp;&nbsp;↳ `noteReadAloud` | method | Records a document sentence the Reader is about to read aloud, so voice input can recognize the app's own voice (barge-in). |
| &nbsp;&nbsp;↳ `readAloudSince` | method | Sentences read aloud since since, plus the one before it (it may still have been playing then). |
| &nbsp;&nbsp;↳ `idle` | method | Completes once no prompt is being spoken or queued. |
| &nbsp;&nbsp;↳ `stop` | method | Stops all speech, including protected sentences. |
| &nbsp;&nbsp;↳ `splitAtQuestion` | method | Splits text after its last sentence that is a question: (the text up to and including that question, the rest or null). |
| &nbsp;&nbsp;↳ `splitSentences` | method | Splits text into sentences (on `.`, `!`, `?`, `…` followed by space), keeping the punctuation. |
| **`announcerProvider`** | provider | Speech output + live subtitle state. |

### `command_bus.dart`
_1042 lines._ A partial speech result that already reads as a whole command.

| Name | Kind | What it does |
|---|---|---|
| **`PartialMatch`** | class | A partial speech result that already reads as a whole command. |
| **`CommandBus`** | class | The single entry point for user input. |
| &nbsp;&nbsp;↳ `struggling` | getter | The user seems stuck: announcements give full help again. |
| &nbsp;&nbsp;↳ `strings` | getter | Prompt strings in the current speech language. |
| &nbsp;&nbsp;↳ `activeScreen` | getter | The active screen, if any. |
| &nbsp;&nbsp;↳ `onGesture` | method | Handles a recognized gesture. |
| &nbsp;&nbsp;↳ `dispatch` | method | Handles intent on the active screen: a pending question first (for NavIntent.activate), then the screen's override, then the default. |
| &nbsp;&nbsp;↳ `handleUtterance` | method | Handles a final speech recognition result. |
| &nbsp;&nbsp;↳ `answer` | method | Answers question from what the app knows right now. |
| &nbsp;&nbsp;↳ `judgePartial` | method | Whether the partial result partial is already a whole command, so it can run before the recognizer's final result. |
| &nbsp;&nbsp;↳ `expectedPhrases` | method | Phrases the recognizer should expect on the active screen. |
| &nbsp;&nbsp;↳ `offer` | method | Asks prompt and lets the user accept with a double-tap or "oo" within AppDurations.pendingAnswer. |
| &nbsp;&nbsp;↳ `moveFocus` | method | Moves focus and speaks the newly focused option ("Mag-upload, 1 sa 2"). |
| &nbsp;&nbsp;↳ `activateFocused` | method | Activates the focused option, or explains how to pick one. |
| &nbsp;&nbsp;↳ `activate` | method | Runs actionId on the active screen with a confirmation pulse and a short, protected spoken confirmation. |
| &nbsp;&nbsp;↳ `announceScreen` | method | Speaks the entry announcement of screen. |
| &nbsp;&nbsp;↳ `entryAnnouncement` | method | Builds "Title. |
| &nbsp;&nbsp;↳ `asksQuestion` | method | Whether text contains a question (a sentence ending in "?"). |
| &nbsp;&nbsp;↳ `isFamiliar` | method | Whether the user has opened screenId often enough to know it. |
| &nbsp;&nbsp;↳ `noteVisit` | method | Counts a visit to screenId (for "Awtomatiko" announcements). |
| &nbsp;&nbsp;↳ `modeHint` | method | The how-to-navigate hint for the current mode. |
| &nbsp;&nbsp;↳ `back` | method | Goes back one screen (gesture, voice and Android back all land here). |
| &nbsp;&nbsp;↳ `stopSpeech` | method | Silences all speech. |
| &nbsp;&nbsp;↳ `help` | method | Speaks the help for screen; in voice mode also lists voice commands. |
| &nbsp;&nbsp;↳ `notAvailable` | method | Error feedback for a command the screen doesn't support. |
| &nbsp;&nbsp;↳ `say` | method | Speaks text in the prompt language. |
| &nbsp;&nbsp;↳ `ask` | method | Asks the question in text and waits for the answer before saying then (and, with split, what follows the question in text); see Announcer.ask. |
| **`commandBusProvider`** | provider | The app's command bus. |

### `earcon.dart`
_32 lines._ Short non-speech sounds.

| Name | Kind | What it does |
|---|---|---|
| **`Earcon`** | class | Short non-speech sounds. |
| &nbsp;&nbsp;↳ `heard` | method | A short beep the moment a voice command is recognized, before the action finishes, so the user knows they were heard. |
| **`DeviceEarcon`** | class | Earcon played by Android's `ToneGenerator` (no sound file to load). |
| **`earconProvider`** | provider | The app's earcons; overridden in tests. |

### `familiarity.dart` 🆕
_62 lines._ How many times the current user has opened each screen (by screen id), so announcements can get shorter as the app becomes familiar (`Verbosity.auto`).

| Name | Kind | What it does |
|---|---|---|
| **`Familiarity`** | class | How many times the current user has opened each screen (by screen id), so announcements can get shorter as the app becomes familiar (`Verbosity.auto`). |
| &nbsp;&nbsp;↳ `visits` | method | Times screenId was opened before. |
| &nbsp;&nbsp;↳ `noteVisit` | method | Counts one more visit to screenId. |
| **`familiarityProvider`** | provider | Screen visit counts of the current user. |

### `focus_controller.dart`
_42 lines._ Id of the focused action on the active screen, or null.

| Name | Kind | What it does |
|---|---|---|
| **`FocusController`** | class | Id of the focused action on the active screen, or null. |
| &nbsp;&nbsp;↳ `move` | method | Moves focus by delta through the active screen's focusable actions, wrapping at the ends. |
| &nbsp;&nbsp;↳ `focus` | method | Focuses actionId directly (e.g. |
| **`focusControllerProvider`** | provider | Focused action id. |

### `haptics.dart`
_77 lines._ Haptic cues.

| Name | Kind | What it does |
|---|---|---|
| **`Haptics`** | class | Haptic cues. |
| &nbsp;&nbsp;↳ `tick` | method | Very light tick: finger landed on a gesture surface, focus moved. |
| &nbsp;&nbsp;↳ `heard` | method | Very short pulse: a voice command was heard (before it runs). |
| &nbsp;&nbsp;↳ `confirm` | method | Short pulse: an action was confirmed. |
| &nbsp;&nbsp;↳ `error` | method | Distinct triple buzz: something failed or isn't available. |
| **`DeviceHaptics`** | class | Haptics on the device vibrator. |
| **`hapticsProvider`** | provider | App haptics; follows the Settings toggle. |

### `nav_intent.dart`
_105 lines._ What the user wants to do, independent of how they asked (gesture or voice).

| Name | Kind | What it does |
|---|---|---|
| **`NavIntent`** | enum | What the user wants to do, independent of how they asked (gesture or voice). |

### `navigation_mode.dart`
_54 lines._ How the user prefers to drive the app.

| Name | Kind | What it does |
|---|---|---|
| **`NavMode`** | enum | How the user prefers to drive the app. |
| &nbsp;&nbsp;↳ `tryParse` | method | Parses a stored value, or null. |
| **`NavModeNotifier`** | class | The chosen navigation mode (null until chosen on Welcome); a view of settingsProvider, saved with the other settings. |
| &nbsp;&nbsp;↳ `set` | method | Chooses and saves mode. |
| **`navigationModeProvider`** | provider | Current navigation mode. |
| **`TalkBackNotifier`** | class | Whether TalkBack (or another screen reader) is active. |
| &nbsp;&nbsp;↳ `set` | method | Updates the flag. |
| **`talkBackProvider`** | provider | TalkBack active flag. |

### `screen_registration.dart`
_144 lines._ Builds a localized string.

| Name | Kind | What it does |
|---|---|---|
| **`L10nText`** | typedef | Builds a localized string. |
| **`BusHandler`** | typedef | Handler for an action or an intent override. |
| **`A11yAction`** | class | One thing the user can do on a screen, reachable by focus + double-tap, by a visual tap, and (Phase 3) by voice. |
| **`ScreenRegistration`** | class | Everything the accessibility core needs to know about one screen. |
| &nbsp;&nbsp;↳ `focusables` | getter | Focusable actions, in order. |
| &nbsp;&nbsp;↳ `action` | method | Finds an action by id. |

## `lib/core/assistant/`

Percy, the ElevenLabs voice assistant (online, optional).

### `assistant_config.dart` 🆕
_82 lines._ How to reach the ElevenLabs voice agent ("Percy").

| Name | Kind | What it does |
|---|---|---|
| **`AssistantConfig`** | class | How to reach the ElevenLabs voice agent ("Percy"). |
| &nbsp;&nbsp;↳ `isSetUp` | getter | Whether the assistant can be used at all. |
| &nbsp;&nbsp;↳ `isPrivate` | getter | Whether conversations need a token from tokenUrl. |
| **`assistantConfigProvider`** | provider | The assistant's configuration; overridden in tests. |
| **`TokenFetcher`** | typedef | Gets a conversation token for a private agent (token_server.py). |
| **`assistantTokenFetcherProvider`** | provider | The app's token fetcher; overridden in tests. |

### `assistant_controller.dart` 🆕
_400 lines._ Where the voice assistant ("Percy") is.

| Name | Kind | What it does |
|---|---|---|
| **`AssistantStatus`** | enum | Where the voice assistant ("Percy") is. |
| **`AssistantState`** | class | The voice assistant's state. |
| &nbsp;&nbsp;↳ `active` | getter | Whether a conversation is starting or running. |
| **`AssistantController`** | class | Runs conversations with the ElevenLabs voice agent ("Percy"). |
| &nbsp;&nbsp;↳ `runningTool` | getter | Whether one of Percy's tools is running right now (its commands must not end the conversation the way a user's gesture does). |
| &nbsp;&nbsp;↳ `toggle` | method | Starts a conversation, or ends the running one. |
| &nbsp;&nbsp;↳ `start` | method | Starts a conversation (checks set-up, internet and consent first). |
| &nbsp;&nbsp;↳ `stop` | method | Ends the conversation. |
| &nbsp;&nbsp;↳ `handOver` | method | Runs action once the conversation has ended (the app's own voice takes over), and ends it soon if Percy doesn't. |
| **`assistantControllerProvider`** | provider | The voice assistant. |
| **`assistantActiveProvider`** | provider | Whether a conversation with Percy is starting or running. |

### `assistant_platform.dart` 🆕
_235 lines._ Something that happened in the voice-assistant conversation.

| Name | Kind | What it does |
|---|---|---|
| **`AssistantEvent`** | class | Something that happened in the voice-assistant conversation. |
| **`AssistantConnected`** | class | The conversation is connected. |
| **`AssistantStatusChanged`** | class | The SDK's connection status changed (`connecting`, `connected`, …). |
| **`AssistantModeChanged`** | class | The agent started or stopped talking. |
| **`AssistantToolCall`** | class | The agent wants the app to do something (a client tool). |
| **`AssistantHeard`** | class | What the user said (final transcript of a turn). |
| **`AssistantSaid`** | class | What the agent said (one turn). |
| **`AssistantDisconnected`** | class | The conversation ended (`agent`, `user` or `error`). |
| **`AssistantFailed`** | class | The service reported an error. |
| **`AssistantStartOptions`** | class | What a conversation starts with. |
| **`AssistantPlatform`** | class | The ElevenLabs conversation on the phone. |
| &nbsp;&nbsp;↳ `events` | getter | Events of the current conversation. |
| &nbsp;&nbsp;↳ `start` | method | Starts a conversation; throws if it can't. |
| &nbsp;&nbsp;↳ `end` | method | Ends the conversation. |
| &nbsp;&nbsp;↳ `sendToolResult` | method | Answers tool call id with result. |
| &nbsp;&nbsp;↳ `sendContext` | method | Tells the agent something without asking it to reply. |
| **`MethodChannelAssistantPlatform`** | class | AssistantPlatform over the Android bridge (`AssistantBridge.kt`). |
| **`assistantPlatformProvider`** | provider | The app's assistant platform. |

### `assistant_tools.dart` 🆕
_377 lines._ A tool call the app can't carry out; message goes back to Percy.

| Name | Kind | What it does |
|---|---|---|
| **`AssistantToolError`** | class | A tool call the app can't carry out; message goes back to Percy. |
| **`AssistantTools`** | class | Percy's client tools, answered by the app through the command bus, so whatever Percy does is exactly what the user could do by gesture, voice or tap. |
| &nbsp;&nbsp;↳ `run` | method | Runs tool name with params; returns the text for Percy. |

### `reader_snapshot.dart` 🆕
_59 lines._ What the Reader shows right now, for the voice assistant (where the user is in the document, and its text for questions or a summary).

| Name | Kind | What it does |
|---|---|---|
| **`ReaderSnapshot`** | class | What the Reader shows right now, for the voice assistant (where the user is in the document, and its text for questions or a summary). |
| **`ReaderSnapshotNotifier`** | class | The open Reader's snapshot (null when no Reader is open). |
| &nbsp;&nbsp;↳ `set` | method | Sets or clears (null) the snapshot. |
| &nbsp;&nbsp;↳ `clearIf` | method | Clears the snapshot if it is still snapshot (a Reader closing must not clear a newer Reader's snapshot). |
| **`readerSnapshotProvider`** | provider | The open Reader, if any. |

## `lib/core/auth/`

Accounts, passwords, login session, fingerprint, guest profile, lockout.

### `account.dart`
_124 lines._ A local account (or the device's guest profile).

| Name | Kind | What it does |
|---|---|---|
| **`Account`** | class | A local account (or the device's guest profile). |
| &nbsp;&nbsp;↳ `name` | getter | "Juan dela Cruz". |
| **`SecurityQuestion`** | enum | The security questions offered at registration (spoken list). |
| &nbsp;&nbsp;↳ `text` | method | The question text. |
| &nbsp;&nbsp;↳ `tryParse` | method | Parses a stored id, or null. |

### `account_repository.dart`
_337 lines._ Registration failed because the email is already used on this device.

| Name | Kind | What it does |
|---|---|---|
| **`EmailTakenException`** | class | Registration failed because the email is already used on this device. |
| **`AccountRepository`** | class | Accounts in the `users` table: registration, password checks, security questions, the guest profile and legacy PIN accounts. |
| &nbsp;&nbsp;↳ `get` | method | One account, or null. |
| &nbsp;&nbsp;↳ `findByEmail` | method | The account using email, or null. |
| &nbsp;&nbsp;↳ `emailTaken` | method | Whether email is used by an account other than exceptId. |
| &nbsp;&nbsp;↳ `register` | method | Creates an account; the password is stored only as a salted hash. |
| &nbsp;&nbsp;↳ `verifyPassword` | method | The account for email if password is right; otherwise null. |
| &nbsp;&nbsp;↳ `setPassword` | method | Sets a new password for id. |
| &nbsp;&nbsp;↳ `setSecurityAnswer` | method | Sets the security question and its (normalized, hashed) answer. |
| &nbsp;&nbsp;↳ `verifySecurityAnswer` | method | Whether answer matches the security answer of id. |
| &nbsp;&nbsp;↳ `markLogin` | method | Records a login. |
| &nbsp;&nbsp;↳ `setProfilingCompleted` | method | Marks the guided setup completed (or not, for "Ulitin ang setup"). |
| &nbsp;&nbsp;↳ `setFingerprint` | method | Turns fingerprint login on or off. |
| &nbsp;&nbsp;↳ `markSynced` | method | Records that the web app has this version of id (Phase 7). |
| &nbsp;&nbsp;↳ `unsynced` | method | Real accounts the web app doesn't have yet. |
| &nbsp;&nbsp;↳ `guest` | method | The device's guest profile, created on first use and reused after. |
| &nbsp;&nbsp;↳ `migrateGuest` | method | Moves the guest's preferences and Library (documents, downloads, progress, favorites, collections) to accountId, then deletes the guest profile. |
| &nbsp;&nbsp;↳ `legacyAccounts` | method | Old name + PIN accounts that haven't set an email and password yet. |
| &nbsp;&nbsp;↳ `verifyLegacyPin` | method | Whether pin is the old PIN of legacy account id. |
| &nbsp;&nbsp;↳ `upgradeLegacy` | method | Turns legacy account id into an email + password account, keeping its settings and history. |
| **`LegacyPinHash`** | class | How Phase 6 hashed 4-digit PINs (salted SHA-256, 10 000 rounds). |
| &nbsp;&nbsp;↳ `hash` | method | Hash of pin with salt. |
| **`accountRepositoryProvider`** | provider | Accounts. |

### `account_sync_repository.dart`
_38 lines._ Sends accounts to the web admin app (Phase 7).

| Name | Kind | What it does |
|---|---|---|
| **`AccountSyncRepository`** | class | Sends accounts to the web admin app (Phase 7). |
| &nbsp;&nbsp;↳ `enqueue` | method | Queues account for upload (after registration or a profile change). |
| &nbsp;&nbsp;↳ `syncPending` | method | Uploads everything queued; returns how many accounts were sent. |
| **`MockAccountSyncRepository`** | class | Placeholder until the web app exists: remembers what would be sent and sends nothing, so `synced` stays 0 and Phase 7 picks everything up. |
| **`accountSyncRepositoryProvider`** | provider | Account sync. |

### `biometrics.dart`
_71 lines._ Outcome of a fingerprint check.

| Name | Kind | What it does |
|---|---|---|
| **`BiometricResult`** | enum | Outcome of a fingerprint check. |
| **`Biometrics`** | class | Fingerprint login. |
| &nbsp;&nbsp;↳ `available` | method | Whether this phone has a fingerprint (or other biometric) enrolled. |
| &nbsp;&nbsp;↳ `authenticate` | method | Shows Android's fingerprint prompt with reason. |
| **`DeviceBiometrics`** | class | Biometrics on `local_auth` (biometrics only — no device PIN fallback, since our own password is the fallback). |
| **`biometricsProvider`** | provider | Fingerprint service. |

### `guest_reminders.dart`
_39 lines._ "Naka-save ito sa phone na ito lamang.

| Name | Kind | What it does |
|---|---|---|
| **`GuestReminders`** | class | "Naka-save ito sa phone na ito lamang. |
| &nbsp;&nbsp;↳ `historySaved` | method | A document was saved to history: schedule the reminder, once. |
| &nbsp;&nbsp;↳ `takeHistoryReminder` | method | Whether the history reminder should be said now; marks it said. |

### `login_throttle.dart`
_113 lines._ What kind of secret is being guessed; each has its own counter.

| Name | Kind | What it does |
|---|---|---|
| **`ThrottleKind`** | enum | What kind of secret is being guessed; each has its own counter. |
| **`LoginThrottle`** | class | Lockout after repeated failures, per email, stored in SQLite so it survives an app restart. |
| &nbsp;&nbsp;↳ `delayAfter` | method | Lockout length after failures failures (zero below the limit). |
| &nbsp;&nbsp;↳ `remaining` | method | Time left before email may try again; zero if it may try now. |
| &nbsp;&nbsp;↳ `recordFailure` | method | Records a failure; returns the lockout it starts (zero if none). |
| &nbsp;&nbsp;↳ `failures` | method | Failures so far for email. |
| &nbsp;&nbsp;↳ `reset` | method | Clears the counter after a success. |
| **`loginThrottleProvider`** | provider | Login lockout. |

### `password_hasher.dart`
_119 lines._ A stored secret: how it was made, the salt and the hash (both base64).

| Name | Kind | What it does |
|---|---|---|
| **`StoredSecret`** | class | A stored secret: how it was made, the salt and the hash (both base64). |
| **`PasswordHasher`** | class | Salted, slow password hashing: PBKDF2-HMAC-SHA256 with a 16-byte random salt. |
| &nbsp;&nbsp;↳ `hash` | method | Hashes secret with a new random salt. |
| &nbsp;&nbsp;↳ `verify` | method | Whether secret matches a hash made by hash. |
| &nbsp;&nbsp;↳ `iterationsOf` | method | Iterations encoded in kind, or null if it isn't a PBKDF2 hash. |
| &nbsp;&nbsp;↳ `pbkdf2` | method | PBKDF2-HMAC-SHA256 (RFC 8018) of secret with base64 salt; returns the base64 derived key (keyBytes long — a single block). |
| **`passwordHasherProvider`** | provider | The app's password hasher (tests override it with a fast one). |

### `session.dart`
_82 lines._ The account logged in at startup.

| Name | Kind | What it does |
|---|---|---|
| **`initialAccountProvider`** | provider | The account logged in at startup. |
| **`CurrentAccount`** | class | The logged-in account (or the guest profile), or null on the Welcome / Login / Register screens. |
| &nbsp;&nbsp;↳ `login` | method | Logs account in, remembers the session and switches to its settings. |
| &nbsp;&nbsp;↳ `startGuest` | method | Starts (or resumes) the device's guest profile. |
| &nbsp;&nbsp;↳ `completeRegistration` | method | Logs a newly registered account in. |
| &nbsp;&nbsp;↳ `logout` | method | Logs out: forgets the session and returns to the device's settings, which keep the look and voice the user had. |
| &nbsp;&nbsp;↳ `refresh` | method | Re-reads the logged-in account (after a change to it). |
| **`currentAccountProvider`** | provider | Logged-in account. |
| **`userPrefsProvider`** | provider | Preferences of the logged-in account (setup progress, reminders). |
| **`initialSessionExpiredProvider`** | provider | True when a saved session was dropped at startup because the account has "stay logged in" off. |

### `session_store.dart`
_94 lines._ Where the login session lives between launches (Android Keystore-backed encrypted storage).

| Name | Kind | What it does |
|---|---|---|
| **`SessionStore`** | class | Where the login session lives between launches (Android Keystore-backed encrypted storage). |
| &nbsp;&nbsp;↳ `readUserId` | method | The logged-in account id, or null. |
| &nbsp;&nbsp;↳ `writeUserId` | method | Remembers userId as logged in. |
| &nbsp;&nbsp;↳ `clearUserId` | method | Forgets the session (logout). |
| &nbsp;&nbsp;↳ `readFingerprintUserId` | method | The account whose fingerprint login is on, or null. |
| &nbsp;&nbsp;↳ `writeFingerprintUserId` | method | Sets (or clears, with null) the fingerprint account. |
| **`SecureSessionStore`** | class | SessionStore on `flutter_secure_storage`. |
| **`MemorySessionStore`** | class | In-memory SessionStore (tests). |
| **`sessionStoreProvider`** | provider | The session store. |

### `validators.dart`
_73 lines._ Input rules and spoken-input clean-up for account forms.

| Name | Kind | What it does |
|---|---|---|
| **`AuthRules`** | class | Input rules and spoken-input clean-up for account forms. |
| &nbsp;&nbsp;↳ `normalizeEmail` | method | Emails are stored and compared trimmed and lowercased. |
| &nbsp;&nbsp;↳ `isValidEmail` | method | Whether email looks like an email address. |
| &nbsp;&nbsp;↳ `isValidPassword` | method | Whether password is long enough. |
| &nbsp;&nbsp;↳ `spokenEmail` | method | A dictated email made usable: "juan dela cruz at gmail dot com" → "juandelacruz@gmail.com". |
| &nbsp;&nbsp;↳ `spokenPassword` | method | A dictated password: spaces removed and lowercased, because speech recognizers capitalize and space words unpredictably. |
| &nbsp;&nbsp;↳ `spokenName` | method | A dictated name: trimmed, single spaces, each word capitalized. |
| &nbsp;&nbsp;↳ `normalizeAnswer` | method | A security answer as it is hashed and compared: lowercase, no diacritics or punctuation, single spaces, trimmed — so "Sto. |

## `lib/core/db/`

SQLite database, versioned migrations.

### `app_database.dart`
_54 lines._ The app's single SQLite database.

| Name | Kind | What it does |
|---|---|---|
| **`AppDatabase`** | class | The app's single SQLite database. |
| &nbsp;&nbsp;↳ `open` | method | Opens (creating/migrating as needed) the database. |
| &nbsp;&nbsp;↳ `close` | method | Closes the database. |
| **`appDatabaseProvider`** | provider | The opened database, shared app-wide. |

## `lib/core/db/daos/`

Database access objects (Library, preferences).

### `library_dao.dart`
_736 lines._ Reads and writes the Library: items, favorites, collections.

| Name | Kind | What it does |
|---|---|---|
| **`LibraryDao`** | class | Reads and writes the Library: items, favorites, collections. |
| &nbsp;&nbsp;↳ `insertDocument` | method | Saves a newly read document of the user's own; returns it. |
| &nbsp;&nbsp;↳ `get` | method | Loads one item (without its text), or null. |
| &nbsp;&nbsp;↳ `getBook` | method | The item of userId for catalog book bookId, or null. |
| &nbsp;&nbsp;↳ `list` | method | All of userId's items, most recently opened (or added) first. |
| &nbsp;&nbsp;↳ `loadText` | method | Loads the item's text as chapters. |
| &nbsp;&nbsp;↳ `itemsNeedingTotals` | method | Items whose sentence total is not known yet (migrated history). |
| &nbsp;&nbsp;↳ `setTotals` | method | Stores the counts of an item and recomputes its percentage. |
| &nbsp;&nbsp;↳ `updateProgress` | method | Saves the resume position and progress. |
| &nbsp;&nbsp;↳ `setFinished` | method | Marks an item finished (or not), keeping its position. |
| &nbsp;&nbsp;↳ `resetProgress` | method | Back to the start: position 0, not finished. |
| &nbsp;&nbsp;↳ `updateText` | method | Replaces the text of a saved description (a detailed one arrived). |
| &nbsp;&nbsp;↳ `setCover` | method | Sets the cover file of an item. |
| &nbsp;&nbsp;↳ `markOpened` | method | Records that the item was opened. |
| &nbsp;&nbsp;↳ `clearNew` | method | Clears the "Bago" label (the details were viewed). |
| &nbsp;&nbsp;↳ `rename` | method | Renames an own document. |
| &nbsp;&nbsp;↳ `delete` | method | Deletes an own document with its favorites and collection links (cascade). |
| &nbsp;&nbsp;↳ `syncCatalog` | method | Merges a fresh catalog into userId's book rows and says what changed. |
| &nbsp;&nbsp;↳ `setDownloaded` | method | Marks a book downloaded at version with its filePath and text cache. |
| &nbsp;&nbsp;↳ `clearDownload` | method | Forgets a downloaded book's files but keeps its progress. |
| &nbsp;&nbsp;↳ `setTextCache` | method | Saves the text cache of a book that is only being read online. |
| &nbsp;&nbsp;↳ `syncBatch` | method | What userId would send to the web app (Phase 7): admin books they have started or downloaded, progress, favorites inside books and collections with their book links. |
| &nbsp;&nbsp;↳ `addFavorite` | method | Saves a spot; the same spot twice is stored once. |
| &nbsp;&nbsp;↳ `favorites` | method | The item's favorites in reading order. |
| &nbsp;&nbsp;↳ `deleteFavorite` | method | Deletes a favorite. |
| &nbsp;&nbsp;↳ `itemsWithFavorites` | method | Ids of userId's items that have at least one favorite. |
| &nbsp;&nbsp;↳ `createCollection` | method | Creates a collection. |
| &nbsp;&nbsp;↳ `collections` | method | userId's collections, oldest first, with item counts. |
| &nbsp;&nbsp;↳ `renameCollection` | method | Renames a collection. |
| &nbsp;&nbsp;↳ `deleteCollection` | method | Deletes a collection. |
| &nbsp;&nbsp;↳ `addToCollection` | method | Adds an item to a collection (twice is fine). |
| &nbsp;&nbsp;↳ `removeFromCollection` | method | Removes an item from a collection. |
| &nbsp;&nbsp;↳ `collectionItemIds` | method | Ids of the items in a collection. |
| &nbsp;&nbsp;↳ `collectionsOf` | method | Ids of the collections an item is in. |
| **`libraryDaoProvider`** | provider | Library access. |

### `preferences_dao.dart`
_159 lines._ Preference keys.

| Name | Kind | What it does |
|---|---|---|
| **`PrefKeys`** | class | Preference keys. |
| **`PreferencesDao`** | class | Reads and writes the `preferences` table. |
| &nbsp;&nbsp;↳ `get` | method | Returns the decoded value for key, or null. |
| &nbsp;&nbsp;↳ `set` | method | Stores value (JSON-encodable) for key. |
| &nbsp;&nbsp;↳ `getAll` | method | All decoded values for userId. |
| &nbsp;&nbsp;↳ `remove` | method | Deletes key. |

## `lib/core/db/`

SQLite database, versioned migrations.

### `migrations.dart`
_356 lines._ One schema step.

| Name | Kind | What it does |
|---|---|---|
| **`Migration`** | class | One schema step. |
| **`Migrations`** | class | Versioned schema migrations. |
| &nbsp;&nbsp;↳ `latestVersion` | getter | Schema version of a fully migrated database. |
| &nbsp;&nbsp;↳ `migrate` | method | Applies every migration with `from < version <= to`. |

## `lib/core/describe/`

Maglarawan: on-device image labeling and image preparation.

### `image_labeler.dart`
_51 lines._ One thing ML Kit thinks is in the picture.

| Name | Kind | What it does |
|---|---|---|
| **`LabelResult`** | class | One thing ML Kit thinks is in the picture. |
| **`ImageLabelerService`** | class | On-device image labeling. |
| &nbsp;&nbsp;↳ `label` | method | Labels the (color) image at path, most confident first. |
| &nbsp;&nbsp;↳ `close` | method | Frees native resources. |
| **`MlKitImageLabelerService`** | class | ImageLabelerService on ML Kit's bundled base model (works offline). |
| **`imageLabelerProvider`** | provider | The app's image labeler. |

### `image_prep.dart`
_91 lines._ Longest side of an image sent to the server.

| Name | Kind | What it does |
|---|---|---|
| **`uploadMaxSide`** | constant | Longest side of an image sent to the server. |
| **`thumbnailMaxSide`** | constant | Longest side of a history thumbnail. |
| **`resizeToJpeg`** | function | Decodes bytes, turns it upright, shrinks it so its longest side is at most maxSide (never enlarges) and encodes it as JPEG. |
| **`ImagePrep`** | class | Image work for Maglarawan. |
| &nbsp;&nbsp;↳ `forUpload` | method | The image at path, shrunk and compressed for upload; null if unreadable. |
| &nbsp;&nbsp;↳ `saveThumbnail` | method | Saves a small thumbnail of the image at path for Reading History and returns its file path; null if unreadable. |
| **`IsolateImagePrep`** | class | ImagePrep that works in a background isolate. |
| **`imagePrepProvider`** | provider | The app's image preparation. |
| **`deleteThumbnail`** | function | Removes a history thumbnail; a missing file or path is fine. |

### `label_description.dart`
_51 lines._ Smallest confidence a label needs to be mentioned.

| Name | Kind | What it does |
|---|---|---|
| **`minLabelConfidence`** | constant | Smallest confidence a label needs to be mentioned. |
| **`maxSpokenLabels`** | constant | Most labels mentioned. |
| **`pickLabels`** | function | The labels worth mentioning: confidence of at least minLabelConfidence, most confident first, at most maxSpokenLabels. |
| **`translateLabel`** | function | english in Filipino when filipino and the map knows it; otherwise the English label, lowercase. |
| **`needsReminder`** | function | Whether any of labels suggests medicine, pills or money. |
| **`joinLabels`** | function | "a", "a at b", "a, b, at c". |
| **`offlineDescription`** | function | What is said for the labels of one image, always starting "Mukhang…" / "It looks like…" (it is an estimate). |

## `lib/core/extraction/`

Turning images, PDFs and DOCX files into text.

### `document_extractor.dart`
_182 lines._ Kinds of documents the app can read.

| Name | Kind | What it does |
|---|---|---|
| **`DocumentKind`** | enum | Kinds of documents the app can read. |
| &nbsp;&nbsp;↳ `forPath` | method | Kind for a file name, or null if unsupported. |
| **`DocumentFile`** | class | A document file waiting to be read. |
| &nbsp;&nbsp;↳ `sourceType` | getter | History `source_type`: `camera`, `image`, `pdf` or `docx`. |
| **`ExtractionResult`** | class | Clean text plus how it was obtained. |
| **`DocumentExtractor`** | class | Reads any supported document into clean text. |
| &nbsp;&nbsp;↳ `extract` | method | Extracts file. |
| **`DefaultDocumentExtractor`** | class | The real extractor: ML Kit for images, pdfrx (+ OCR) for PDFs, and archive/xml for DOCX; then cleanText and assessQuality. |
| **`documentExtractorProvider`** | provider | The app's document extractor. |

### `docx_extractor.dart`
_64 lines._ Extracts plain text from a .docx file: unzips it and walks `word/document.xml`, one line per paragraph (`w:p`), honoring tabs and line breaks.

| Name | Kind | What it does |
|---|---|---|
| **`extractDocxText`** | function | Extracts plain text from a .docx file: unzips it and walks `word/document.xml`, one line per paragraph (`w:p`), honoring tabs and line breaks. |
| **`extractDocxTextAsync`** | function | extractDocxText in a background isolate for larger files. |

### `extraction_exception.dart`
_54 lines._ Why a document couldn't be read.

| Name | Kind | What it does |
|---|---|---|
| **`ExtractionFailure`** | enum | Why a document couldn't be read. |
| **`ExtractionException`** | class | Thrown by extractors; carries a failure the Reader can explain aloud. |
| **`recognizeOrThrow`** | function | Runs OCR on path; an engine failure (the file itself is fine) becomes ExtractionFailure.ocrUnavailable instead of "the file is damaged". |

### `pdf_extractor.dart`
_161 lines._ Raw text of a PDF plus how it was obtained.

| Name | Kind | What it does |
|---|---|---|
| **`PdfExtraction`** | class | Raw text of a PDF plus how it was obtained. |
| **`PdfReader`** | class | Reads PDFs. |
| &nbsp;&nbsp;↳ `read` | method | Extracts text from the PDF at path, OCR'ing pages with no text layer. |
| **`PdfrxReader`** | class | PdfReader via pdfrx (PDFium). |

## `lib/core/gestures/`

Recognizing gestures and mapping them to intents.

### `gesture_classifier.dart`
_200 lines._ Turns raw pointer events into GestureTypes, including multi-finger gestures that Flutter's recognizers don't cover.

| Name | Kind | What it does |
|---|---|---|
| **`GestureClassifier`** | class | Turns raw pointer events into GestureTypes, including multi-finger gestures that Flutter's recognizers don't cover. |
| &nbsp;&nbsp;↳ `pointerDown` | method | A finger landed. |
| &nbsp;&nbsp;↳ `pointerMove` | method | A finger moved. |
| &nbsp;&nbsp;↳ `pointerUp` | method | A finger lifted. |
| &nbsp;&nbsp;↳ `pointerCancel` | method | The system cancelled a pointer (e.g. |

### `gesture_map.dart`
_100 lines._ Gestures the gesture layer recognizes.

| Name | Kind | What it does |
|---|---|---|
| **`GestureType`** | enum | Gestures the gesture layer recognizes. |
| **`gestureMap`** | constant | THE gesture → intent table. |
| **`GestureTuning`** | class | Timing and distance thresholds, in logical pixels and milliseconds. |

### `gesture_surface.dart`
_107 lines._ Detects navigation gestures on child and sends them to the CommandBus.

| Name | Kind | What it does |
|---|---|---|
| **`GestureSurface`** | class | Detects navigation gestures on child and sends them to the CommandBus. |
| &nbsp;&nbsp;↳ `claimPointer` | method | Marks pointer as handled by a button under the finger. |

## `lib/core/library/`

Aklatan (Library): models, books from the web app, EPUB/PDF reading, shelves, sync.

### `admin_book_repository.dart`
_285 lines._ Why a web app request failed.

| Name | Kind | What it does |
|---|---|---|
| **`BookServiceProblem`** | enum | Why a web app request failed. |
| **`BookServiceException`** | class | Thrown by AdminBookRepository. |
| **`AdminBookRepository`** | class | The books the admins manage in the web app (`docs/api-contract.md`). |
| &nbsp;&nbsp;↳ `catalog` | method | The whole active catalog (every page of `GET /api/books`). |
| &nbsp;&nbsp;↳ `downloadFile` | method | Downloads the book file (`GET /api/books/{id}/file`) to destination, reporting bytes received and the total. |
| &nbsp;&nbsp;↳ `cover` | method | The cover image (`GET /api/books/{id}/cover`), or null if it has none. |
| **`MockAdminBookRepository`** | class | A mocked web app with public-domain sample books, so the Library can be built and tested before the web app exists. |
| &nbsp;&nbsp;↳ `simulateNewBook` | method | Adds a book the way an admin would; the next refresh sees it as new. |
| &nbsp;&nbsp;↳ `simulateUpdate` | method | Publishes a new version of bookId (downloads can then be updated). |
| &nbsp;&nbsp;↳ `simulateRemoval` | method | Takes bookId off the shelves. |
| **`adminBookRepositoryProvider`** | provider | The web app's books. |

### `book_content.dart`
_179 lines._ Why a book could not be turned into text.

| Name | Kind | What it does |
|---|---|---|
| **`BookReadProblem`** | enum | Why a book could not be turned into text. |
| **`BookReadException`** | class | Thrown by BookContentLoader. |
| **`LoadedBook`** | class | A book's text and what was learned about it while reading the file. |
| **`BookContentLoader`** | class | Turns a downloaded PDF or EPUB into chapters of text. |
| &nbsp;&nbsp;↳ `load` | method | Reads path. |
| **`DefaultBookContentLoader`** | class | The real loader: the EPUB parser (in a background isolate) and the existing PDF pipeline — text layer first, OCR for scanned pages. |
| **`chaptersFromPdf`** | function | Splits a PDF into chapters using its outline (one chapter from each top-level bookmark to the next). |
| **`bookContentLoaderProvider`** | provider | The app's book loader. |

### `catalog_book.dart`
_86 lines._ A book in the web app's catalog (see `docs/api-contract.md`).

| Name | Kind | What it does |
|---|---|---|
| **`CatalogBook`** | class | A book in the web app's catalog (see `docs/api-contract.md`). |
| **`CatalogDiff`** | class | What a catalog refresh changed for one user. |
| &nbsp;&nbsp;↳ `isEmpty` | getter | Nothing changed. |

### `chaptered_text.dart`
_125 lines._ The whole text of an item laid out for the Reader: one string, its sentences, and where each chapter starts.

| Name | Kind | What it does |
|---|---|---|
| **`ChapteredText`** | class | The whole text of an item laid out for the Reader: one string, its sentences, and where each chapter starts. |
| &nbsp;&nbsp;↳ `hasChapters` | getter | Whether there is more than one chapter to move between. |
| &nbsp;&nbsp;↳ `info` | getter | Sentences per chapter, for progress. |
| &nbsp;&nbsp;↳ `wordCount` | getter | Words in text. |
| &nbsp;&nbsp;↳ `chapterOf` | method | Chapter that sentence index belongs to. |
| &nbsp;&nbsp;↳ `inChapter` | method | Sentence index counted inside its chapter. |
| &nbsp;&nbsp;↳ `globalOf` | method | Global sentence index of sentence in chapter, clamped to the text. |
| &nbsp;&nbsp;↳ `buildAsync` | method | build for long books, in a background isolate. |
| **`countWords`** | function | Number of whitespace-separated words in text. |
| **`favoriteLabel`** | function | The first few words of a sentence, for a favorite's label. |

### `epub_parser.dart`
_532 lines._ Why an EPUB could not be read.

| Name | Kind | What it does |
|---|---|---|
| **`EpubProblem`** | enum | Why an EPUB could not be read. |
| **`EpubException`** | class | Thrown when an EPUB cannot be read. |
| **`BookImageRef`** | class | Where an image sits in the book text (kept for Phase 6E Part B). |
| &nbsp;&nbsp;↳ `toJson` | method | JSON form. |
| &nbsp;&nbsp;↳ `fromJson` | method | Reads the JSON form. |
| **`BookText`** | class | The readable content of a book: chapters of text plus image positions. |
| &nbsp;&nbsp;↳ `toJsonString` | method | The cache file format. |
| &nbsp;&nbsp;↳ `fromJsonString` | method | Reads the cache file format (also the older plain chapter list). |
| **`EpubBook`** | class | A parsed EPUB. |
| **`EpubParser`** | class | Reads EPUB files: the OPF spine gives the chapter order, the table of contents (EPUB 3 nav or EPUB 2 NCX) the chapter titles, and each XHTML chapter is turned into plain paragraphs without markup, scrâ¦ |
| &nbsp;&nbsp;↳ `parse` | method | Parses bytes. |

### `library_models.dart`
_313 lines._ Where a library item came from.

| Name | Kind | What it does |
|---|---|---|
| **`LibrarySource`** | enum | Where a library item came from. |
| &nbsp;&nbsp;↳ `parse` | method | Parses the stored name. |
| **`LibraryFormat`** | enum | File format of a library item. |
| &nbsp;&nbsp;↳ `parse` | method | Parses the stored name. |
| **`ChapterInfo`** | class | One chapter of an item: its title and how many sentences it has. |
| &nbsp;&nbsp;↳ `toJson` | method | JSON form. |
| &nbsp;&nbsp;↳ `fromJson` | method | Reads the JSON form. |
| &nbsp;&nbsp;↳ `encode` | method | Encodes a chapter list for the database. |
| &nbsp;&nbsp;↳ `decode` | method | Decodes a stored chapter list (empty for null or bad data). |
| **`LibraryItem`** | class | A shelf item: an own document or an admin book. |
| &nbsp;&nbsp;↳ `isBook` | getter | Whether this is an admin book. |
| &nbsp;&nbsp;↳ `inProgress` | getter | Started but not finished. |
| &nbsp;&nbsp;↳ `updateAvailable` | getter | A downloaded book whose catalog version is newer. |
| &nbsp;&nbsp;↳ `globalSentence` | getter | Position counted over the whole item (sentences in earlier chapters plus the sentence in this one). |
| **`Favorite`** | class | A saved spot inside an item. |
| **`LibraryCollection`** | class | A user-made group of items. |
| **`ChapterText`** | class | One chapter's text. |

### `library_paths.dart`
_51 lines._ Where the Library keeps its files (all in the app's private storage).

| Name | Kind | What it does |
|---|---|---|
| **`LibraryPaths`** | class | Where the Library keeps its files (all in the app's private storage). |
| &nbsp;&nbsp;↳ `books` | method | Downloaded books (kept until the user removes them). |
| &nbsp;&nbsp;↳ `texts` | method | Extracted text of downloaded books. |
| &nbsp;&nbsp;↳ `covers` | method | Book covers. |
| &nbsp;&nbsp;↳ `cache` | method | Temporary files: books read online and their text. |
| **`DeviceLibraryPaths`** | class | LibraryPaths under the app's support and cache directories. |
| **`libraryPathsProvider`** | provider | The Library's folders; overridden in tests with a temporary directory. |

### `library_service.dart`
_293 lines._ How a request to read or download a book ended.

| Name | Kind | What it does |
|---|---|---|
| **`BookResult`** | enum | How a request to read or download a book ended. |
| **`LibraryService`** | class | Brings admin books to the phone: refreshes the catalog, reads books online, downloads them for offline reading, and removes downloads. |
| &nbsp;&nbsp;↳ `refreshCatalog` | method | Fetches the catalog and merges it into the user's shelves. |
| &nbsp;&nbsp;↳ `prepareToRead` | method | Makes item's text ready to open in the Reader. |
| &nbsp;&nbsp;↳ `download` | method | Saves the book for offline reading. |
| &nbsp;&nbsp;↳ `isLowOnSpace` | method | Whether bytes would leave less than storageMargin free. |
| &nbsp;&nbsp;↳ `removeDownload` | method | Deletes the downloaded file and text, keeping progress and favorites. |
| &nbsp;&nbsp;↳ `deleteItem` | method | Deletes an own document with everything that belongs to it. |
| **`libraryServiceProvider`** | provider | The Library's book service. |

### `library_sync_repository.dart`
_70 lines._ What a signed-in account would send to the web app so its Library follows it to another device (Phase 7).

| Name | Kind | What it does |
|---|---|---|
| **`LibrarySyncBatch`** | class | What a signed-in account would send to the web app so its Library follows it to another device (Phase 7). |
| &nbsp;&nbsp;↳ `isEmpty` | getter | Nothing to send. |
| **`LibrarySyncRepository`** | class | Library sync with the web app (`docs/api-contract.md`). |
| &nbsp;&nbsp;↳ `push` | method | Sends local changes of userId. |
| &nbsp;&nbsp;↳ `pull` | method | Fetches what userId saved on other devices, changed after since. |
| **`MockLibrarySyncRepository`** | class | Accepts everything and returns nothing; remembers what it was sent so tests can check what would be uploaded. |
| **`librarySyncRepositoryProvider`** | provider | Library sync. |

### `library_view.dart`
_288 lines._ Which items the Library shows.

| Name | Kind | What it does |
|---|---|---|
| **`LibraryFilterKind`** | enum | Which items the Library shows. |
| **`LibraryFilter`** | class | The active filter. |
| **`ShelfKind`** | enum | The kinds of rows on the Library screen. |
| **`Shelf`** | class | One horizontal row of the Library. |
| &nbsp;&nbsp;↳ `length` | getter | Number of tiles. |
| **`LibraryView`** | class | Pure functions that turn the user's items into what the Library shows. |
| &nbsp;&nbsp;↳ `applyFilter` | method | Items passing filter. |
| &nbsp;&nbsp;↳ `search` | method | Items whose title or author contains every word of query (case, accents and punctuation ignored). |
| &nbsp;&nbsp;↳ `shelves` | method | The shelves for the current view. |
| &nbsp;&nbsp;↳ `minutesLeft` | method | Minutes left to read at readingRate (1.0 = normal speech, about 150 words a minute), or null when the word count is not known yet. |
| &nbsp;&nbsp;↳ `findByTitle` | method | Items to "ituloy" (continue) matching title: the best title match. |
| &nbsp;&nbsp;↳ `titleScore` | method | How well title (as said) fits name: 2 exact, 1–2 contained, 0.9 all words present, else edit similarity (0 below floor). |

### `sample_books.dart`
_301 lines._ A chapter of a sample book.

| Name | Kind | What it does |
|---|---|---|
| **`SampleChapter`** | class | A chapter of a sample book. |
| **`SampleBooks`** | class | Public-domain sample content for the mocked web app. |
| &nbsp;&nbsp;↳ `illustration` | method | A tiny valid PNG illustration (a solid colored square). |
| &nbsp;&nbsp;↳ `epub` | method | Builds an EPUB 3 file. |
| &nbsp;&nbsp;↳ `pdf` | method | Builds a small PDF with a text layer and, if outline, a bookmark per chapter. |

## `lib/core/network/`

Connectivity and the online image-description service.

### `connectivity.dart`
_10 lines._ Whether the phone is online right now.

| Name | Kind | What it does |
|---|---|---|
| **`isOnlineProvider`** | provider | Whether the phone is online right now. |

### `image_description_repository.dart`
_122 lines._ The server's detailed description of an image.

| Name | Kind | What it does |
|---|---|---|
| **`DescriptionResult`** | class | The server's detailed description of an image. |
| **`DescriptionException`** | class | Why a detailed description could not be had. |
| **`ImageDescriptionRepository`** | class | Detailed image descriptions, from the web app. |
| &nbsp;&nbsp;↳ `describe` | method | Describes jpeg (already resized) in language (`fil` or `en`). |
| **`HttpImageDescriptionRepository`** | class | The real thing: `POST {API_BASE_URL}/api/describe-image` (multipart). |
| **`imageDescriptionRepositoryProvider`** | provider | The app's description service: the mock while `USE_MOCK_API` is true. |

## `lib/core/ocr/`

On-device text recognition (ML Kit) and text clean-up.

### `ocr_service.dart`
_123 lines._ Text recognized on one image.

| Name | Kind | What it does |
|---|---|---|
| **`OcrPage`** | class | Text recognized on one image. |
| **`FrameStats`** | class | What the camera guidance needs to know about a preview frame. |
| **`OcrService`** | class | On-device text recognition. |
| &nbsp;&nbsp;↳ `recognizeFile` | method | Recognizes text in the image file at path. |
| &nbsp;&nbsp;↳ `close` | method | Frees native resources. |
| **`MlKitOcrService`** | class | OcrService via Google ML Kit (Latin script: English and Filipino). |
| **`toOcrPage`** | function | Converts an ML Kit result into an OcrPage. |
| **`toFrameStats`** | function | Summarizes an ML Kit result on a preview frame of imageSize (already rotated to upright) with brightness meanLuma. |
| **`ocrServiceProvider`** | provider | The app's OCR service. |

### `text_cleanup.dart`
_148 lines._ Turns raw extracted text (OCR, PDF, DOCX) into clean, readable paragraphs separated by a blank line.

| Name | Kind | What it does |
|---|---|---|
| **`cleanText`** | function | Turns raw extracted text (OCR, PDF, DOCX) into clean, readable paragraphs separated by a blank line. |
| **`cleanTextAsync`** | function | Runs cleanText in a background isolate for large texts (so the UI and speech never stutter); small texts are cleaned inline. |
| **`isGarbageLine`** | function | Whether line is OCR noise rather than text: mostly symbols, a run of one repeated character, or a lone non-alphanumeric character. |
| **`TextQuality`** | enum | How usable extracted text is. |
| **`assessQuality`** | function | Rates text. |

## `lib/core/platform/`

Android permissions, settings pages, storage space, closing the app.

### `app_closer.dart`
_9 lines._ Closes the app (back on the first screen, after confirmation).

| Name | Kind | What it does |
|---|---|---|
| **`appCloserProvider`** | provider | Closes the app (back on the first screen, after confirmation). |

### `permissions.dart`
_70 lines._ Runtime permissions the app asks for.

| Name | Kind | What it does |
|---|---|---|
| **`AppPermission`** | enum | Runtime permissions the app asks for. |
| **`PermissionAccess`** | enum | State of a runtime permission. |
| **`PermissionService`** | class | Runtime permissions. |
| &nbsp;&nbsp;↳ `status` | method | Current state of permission, without asking. |
| &nbsp;&nbsp;↳ `request` | method | Shows the Android permission dialog for permission if needed. |
| &nbsp;&nbsp;↳ `openAppSettings` | method | Opens this app's page in Android Settings. |
| **`DevicePermissionService`** | class | PermissionService via `permission_handler`. |
| **`permissionServiceProvider`** | provider | Runtime permission access. |

### `storage_info.dart`
_32 lines._ Free space on the phone, to warn before a big download.

| Name | Kind | What it does |
|---|---|---|
| **`StorageInfo`** | class | Free space on the phone, to warn before a big download. |
| &nbsp;&nbsp;↳ `freeBytes` | method | Free bytes in the app's storage, or null when unknown. |
| **`DeviceStorageInfo`** | class | StorageInfo via a small Android channel (`StatFs`). |
| **`storageInfoProvider`** | provider | Free-space source; overridden in tests. |

### `system_settings.dart`
_44 lines._ Opens Android system settings pages.

| Name | Kind | What it does |
|---|---|---|
| **`SystemSettings`** | class | Opens Android system settings pages. |
| &nbsp;&nbsp;↳ `openTtsSettings` | method | Opens Settings → Text-to-speech output (to install voices / pick engine). |
| &nbsp;&nbsp;↳ `openVoiceInputSettings` | method | Opens Settings → Voice input (to download offline speech recognition). |
| **`AndroidSystemSettings`** | class | SystemSettings via Android intents. |
| **`systemSettingsProvider`** | provider | System settings launcher. |

## `lib/core/settings/`

User settings model and controller.

### `app_settings.dart`
_295 lines._ How much the app says when a screen opens.

| Name | Kind | What it does |
|---|---|---|
| **`Verbosity`** | enum | How much the app says when a screen opens. |
| **`DocumentVoice`** | enum | Which voice reads documents. |
| **`DescribeConsent`** | enum | Whether the user allows sending images to the server for a detailed description (Maglarawan). |
| **`AppSettings`** | class | Every user-adjustable setting, saved per profile (or for the device when no one is logged in). |
| &nbsp;&nbsp;↳ `theme` | getter | The theme-related part. |
| &nbsp;&nbsp;↳ `resolvedTextColor` | getter | The text color actually shown (the theme default if none is chosen). |
| &nbsp;&nbsp;↳ `toPrefs` | method | Preference key → JSON value. |
| &nbsp;&nbsp;↳ `fromPrefs` | method | Reads settings from stored preferences; anything missing or invalid keeps its default. |

### `settings_controller.dart`
_93 lines._ Settings loaded at startup.

| Name | Kind | What it does |
|---|---|---|
| **`initialSettingsProvider`** | provider | Settings loaded at startup. |
| **`initialSettingsScopeProvider`** | provider | The preference scope at startup: a user id, or PreferencesDao.deviceScope. |
| **`SettingsController`** | class | The single source of truth for user settings. |
| &nbsp;&nbsp;↳ `scope` | getter | Current preference scope. |
| &nbsp;&nbsp;↳ `update` | method | Applies change and saves what changed. |
| &nbsp;&nbsp;↳ `switchScope` | method | Switches to another profile's settings (or the device's). |
| &nbsp;&nbsp;↳ `reload` | method | Re-reads the current scope from the database (after another component rewrote it, e.g. |
| **`settingsProvider`** | provider | User settings. |

## `lib/core/tts/`

Text-to-speech, sentence splitting, language detection, reading speed.

### `chunker.dart`
_182 lines._ One sentence of a document: a character range plus its paragraph.

| Name | Kind | What it does |
|---|---|---|
| **`Sentence`** | class | One sentence of a document: a character range plus its paragraph. |
| &nbsp;&nbsp;↳ `range` | getter | Character range, for highlighting. |
| &nbsp;&nbsp;↳ `textIn` | method | The sentence as it should be spoken (line breaks flattened). |
| **`chunkText`** | function | Splits text into sentences for chunked TTS, keeping exact character offsets so the Reader can highlight what is being spoken. |
| **`paragraphStarts`** | function | Index of the first sentence of each paragraph. |
| **`titleFor`** | function | A title for history: the first line, shortened to about max characters at a word boundary. |

### `language_detector.dart`
_190 lines._ Document language, as far as the TTS voice is concerned.

| Name | Kind | What it does |
|---|---|---|
| **`DocLanguage`** | enum | Document language, as far as the TTS voice is concerned. |
| **`LanguageGuess`** | class | Result of detectLanguage. |
| &nbsp;&nbsp;↳ `mixed` | getter | Substantial amounts of both (Taglish). |
| **`filipinoStopWords`** | constant | Common Filipino function words (very frequent, rarely English). |
| **`englishStopWords`** | constant | Common English function words. |
| **`detectLanguage`** | function | Picks the TTS language for a document from Filipino vs English function words. |

### `reading_rate.dart`
_30 lines._ Reading speed (and pitch) as a multiplier of normal speech (1.0 = normal).

| Name | Kind | What it does |
|---|---|---|
| **`ReadingRate`** | class | Reading speed (and pitch) as a multiplier of normal speech (1.0 = normal). |
| &nbsp;&nbsp;↳ `normalize` | method | Clamps and rounds to whole steps (avoids 1.2500000002). |
| &nbsp;&nbsp;↳ `label` | method | "1.25", "1.5", "1.0" — for "Bilis: 1.25x". |
| **`readingRateProvider`** | provider | The user's reading speed; a view of settingsProvider. |

### `speech_language.dart`
_39 lines._ The language used for spoken prompts (and their subtitles).

| Name | Kind | What it does |
|---|---|---|
| **`SpeechLanguage`** | class | The language used for spoken prompts (and their subtitles). |
| &nbsp;&nbsp;↳ `strings` | getter | Prompt strings in locale. |
| &nbsp;&nbsp;↳ `fellBackFrom` | method | Whether prompts fell back from Filipino to English. |
| **`speechLanguageProvider`** | provider | Prompt language derived from the UI locale and voice availability. |

### `tts_service.dart`
_177 lines._ Which TTS voices this phone can use offline.

| Name | Kind | What it does |
|---|---|---|
| **`VoiceStatus`** | class | Which TTS voices this phone can use offline. |
| **`TtsService`** | class | Text-to-speech output. |
| &nbsp;&nbsp;↳ `speak` | method | Speaks text in languageTag at rate × normal speed. |
| &nbsp;&nbsp;↳ `stop` | method | Stops speaking immediately. |
| &nbsp;&nbsp;↳ `checkVoices` | method | Checks which voices are usable. |
| &nbsp;&nbsp;↳ `setPitch` | method | Sets pitch (1.0 is normal). |
| **`FlutterTtsService`** | class | TtsService backed by the Android TTS engine via `flutter_tts`. |
| &nbsp;&nbsp;↳ `create` | method | Creates and configures the service. |
| **`ttsServiceProvider`** | provider | The app's TTS service. |
| **`VoiceStatusNotifier`** | class | Current voice availability; refreshed when the app resumes (the user may have just installed the Filipino voice). |
| &nbsp;&nbsp;↳ `refresh` | method | Re-checks the engine. |
| **`voiceStatusProvider`** | provider | Voice availability. |

## `lib/core/understanding/`

Offline document insights (type, total, due date, expiry, dosage, summary).

### `document_insights.dart` 🆕
_467 lines._ What kind of document a text looks like.

| Name | Kind | What it does |
|---|---|---|
| **`DocType`** | enum | What kind of document a text looks like. |
| **`DocumentInsights`** | class | The useful facts found in a document, all optional. |
| &nbsp;&nbsp;↳ `hasKeyFacts` | getter | Whether any key fact was found (worth saying before reading). |
| **`DocumentAnalyzer`** | class | Reads a document's text and finds what kind it is and its key facts. |
| &nbsp;&nbsp;↳ `analyzeAsync` | method | analyze off the UI isolate for long texts. |
| &nbsp;&nbsp;↳ `analyze` | method | Finds the type and key facts of text. |
| &nbsp;&nbsp;↳ `summarize` | method | Up to count of the most informative sentences of text, in their original order (word-frequency scoring, offline). |

## `lib/core/voice/`

Speech recognition, command matching, natural phrasing, listening while reading.

### `barge_in.dart`
_66 lines._ Listening while the app reads a document aloud ("barge-in"): telling the user's commands apart from the app's own voice, which the microphone hears too.

| Name | Kind | What it does |
|---|---|---|
| **`BargeIn`** | class | Listening while the app reads a document aloud ("barge-in"): telling the user's commands apart from the app's own voice, which the microphone hears too. |
| &nbsp;&nbsp;↳ `residual` | method | The words of heard that are not the app's own voice: words found in readAloud (the sentences just read) are removed, also when the recognizer got them slightly wrong. |
| &nbsp;&nbsp;↳ `isEcho` | method | Whether heard is only the app's own voice. |
| &nbsp;&nbsp;↳ `command` | method | The reading command the user said in heard, or null. |
| &nbsp;&nbsp;↳ `phrases` | getter | Phrases the recognizer should expect while reading. |

### `command_matcher.dart`
_349 lines._ Something a phrase can trigger.

| Name | Kind | What it does |
|---|---|---|
| **`CommandTarget`** | class | Something a phrase can trigger. |
| **`ActionTarget`** | class | Triggers an action registered by the active screen. |
| **`ValueTarget`** | class | Triggers a value from outside (a NavIntent, a yes/no answer, a number…). |
| **`CommandPhrase`** | class | A phrase that triggers target. |
| **`MatchResult`** | class | Outcome of matching an utterance. |
| **`Matched`** | class | Confident match. |
| **`Ambiguous`** | class | Close but unsure: ask "Ang ibig mo bang sabihin ay …?". |
| **`NoMatch`** | class | Nothing close enough. |
| **`CommandMatcher`** | class | Fuzzy matcher for short bilingual voice commands. |
| &nbsp;&nbsp;↳ `match` | method | Matches utterance against phrases. |
| &nbsp;&nbsp;↳ `wholeScore` | method | Similarity of the **whole** utterance to phrase (0..1), ignoring word breaks: "i pause" and "ipause" both score 1 against "i-pause". |
| &nbsp;&nbsp;↳ `extendedBy` | method | Whether phrase continues the words said so far (input), so the user may still be saying it: "susunod" → "susunod na talata", "susunod na tala" → "susunod na talata". |
| &nbsp;&nbsp;↳ `score` | method | Similarity of phrase to the utterance input tokens: 0..1, or just above 1 when the phrase occurs verbatim (1 + 0.01 per word). |
| &nbsp;&nbsp;↳ `tokens` | method | Normalized words of text: lowercase, diacritics removed, hyphens dropped, other punctuation treated as spaces. |
| &nbsp;&nbsp;↳ `normalize` | method | Normalizes text for comparison. |
| &nbsp;&nbsp;↳ `similarity` | method | 1 − (edit distance / longer length). |
| &nbsp;&nbsp;↳ `levenshtein` | method | Character edit distance. |

### `speech_input.dart`
_149 lines._ Parameters for one listening session.

| Name | Kind | What it does |
|---|---|---|
| **`ListenRequest`** | class | Parameters for one listening session. |
| **`SpeechInput`** | class | Speech recognition. |
| &nbsp;&nbsp;↳ `initialize` | method | Prepares the recognizer. |
| &nbsp;&nbsp;↳ `localeIds` | method | Recognizer locale ids available on this phone. |
| &nbsp;&nbsp;↳ `listen` | method | Starts a session. |
| &nbsp;&nbsp;↳ `changePauseFor` | method | Changes the silence that ends the open session, counted from now. |
| &nbsp;&nbsp;↳ `stop` | method | Ends the session, keeping what was heard so far. |
| &nbsp;&nbsp;↳ `cancel` | method | Ends the session and discards it. |
| **`SttSpeechInput`** | class | SpeechInput backed by the Android recognizer via `speech_to_text`. |
| **`speechInputProvider`** | provider | The app's speech input. |

### `understanding.dart` 🆕
_508 lines._ Questions the app answers from what it knows right now (not commands bound to a button).

| Name | Kind | What it does |
|---|---|---|
| **`Question`** | enum | Questions the app answers from what it knows right now (not commands bound to a button). |
| **`documentQuestions`** | constant | The Reader-only questions (about the open document). |
| **`TitleCommand`** | typedef | "Basahin / buksan / ituloy ang <title>" said on any screen. |
| **`TitleVerb`** | enum | What to do with the named document. |
| **`Understanding`** | class | Turns how people actually talk into what the command matcher expects. |
| &nbsp;&nbsp;↳ `clean` | method | text as the matcher should see it: normalized, verb forms mapped, particles and polite openings removed. |
| &nbsp;&nbsp;↳ `question` | method | The app-wide question asked in text, if any. |
| &nbsp;&nbsp;↳ `documentQuestion` | method | The question about the open document asked in text, if any. |
| &nbsp;&nbsp;↳ `isLast` | method | Phrases that mean "the most recent document" (_lastWords). |
| &nbsp;&nbsp;↳ `titleCommand` | method | "Basahin ang Liham kay Nanay", "pakibukas yung resibo", "continue the last one": the verb and the title as said (original words), or null. |

### `voice_commands.dart`
_107 lines._ Spoken phrases (Filipino and English) for the app-wide voice commands.

| Name | Kind | What it does |
|---|---|---|
| **`globalVoiceCommands`** | constant | Spoken phrases (Filipino and English) for the app-wide voice commands. |
| **`wakeWords`** | constant | Saying just the app name re-arms listening; as a prefix it is ignored ("Percipere, camera"). |
| **`yesWords`** | constant | Answers to "Ang ibig mo bang sabihin ay …?" and to offers. |
| **`noWords`** | constant | Negative answers. |
| **`readingControlIntents`** | constant | The only commands accepted while a document is being read aloud (barge-in): the microphone also hears the app's own voice, so the list is kept to what controls the reading. |

### `voice_controller.dart`
_1011 lines._ Recognizer state as the UI sees it.

| Name | Kind | What it does |
|---|---|---|
| **`ListenStatus`** | enum | Recognizer state as the UI sees it. |
| **`VoiceState`** | class | What the Speaking Zone shows about voice input. |
| &nbsp;&nbsp;↳ `listening` | getter | Whether a session is open. |
| **`initialMicGrantedProvider`** | provider | Whether the microphone was already allowed at launch. |
| **`VoiceController`** | class | Voice input and listen/speak turn-taking. |
| &nbsp;&nbsp;↳ `micGranted` | getter | Whether the microphone is allowed (as last checked). |
| &nbsp;&nbsp;↳ `noteActivity` | method | Records user activity; resets the auto-listen idle budget. |
| &nbsp;&nbsp;↳ `commandExecuted` | method | Called by the command bus each time a command runs (voice, gesture or tap): logs the voice command's timing, and — for a gesture or tap while a session is open — starts that session afresh, since whatâ¦ |
| &nbsp;&nbsp;↳ `markMatched` | method | Called by the command bus once it knows what a recognized phrase is. |
| &nbsp;&nbsp;↳ `setAppActive` | method | Called on app pause/resume. |
| &nbsp;&nbsp;↳ `dictate` | method | Listens once for free speech (a name, a document title) and returns the words — not treated as a command. |
| &nbsp;&nbsp;↳ `listenNow` | method | Long-press / "listen": stops any speech (including document reading) at once and listens now. |
| &nbsp;&nbsp;↳ `ensureReady` | method | Makes sure the mic is allowed and the recognizer is initialized. |
| &nbsp;&nbsp;↳ `stopListening` | method | Closes any open session. |
| **`voiceControllerProvider`** | provider | Voice input controller. |

## `lib/core/widgets/`

Shared UI pieces (Speaking Zone, Gesture Pad, Document Box, buttons).

### `bordered_panel.dart`
_39 lines._ Rounded rectangle with a thin border on the page background — the base of the Gesture Pad and the Document Box.

| Name | Kind | What it does |
|---|---|---|
| **`BorderedPanel`** | class | Rounded rectangle with a thin border on the page background — the base of the Gesture Pad and the Document Box. |

### `boxed_list.dart`
_140 lines._ One row of a BoxedList.

| Name | Kind | What it does |
|---|---|---|
| **`BoxedListItem`** | class | One row of a BoxedList. |
| **`BoxedList`** | class | A list of choices inside a fixed bordered box (security questions, setup summary, old accounts). |

### `document_box.dart`
_493 lines._ The Document Box on the Reader screen: shows extracted text (bold, justified) with an always-visible scrollbar, a loading state while scanning, the sentence being read highlighted, and a transient capâ¦

| Name | Kind | What it does |
|---|---|---|
| **`DocumentBox`** | class | The Document Box on the Reader screen: shows extracted text (bold, justified) with an always-visible scrollbar, a loading state while scanning, the sentence being read highlighted, and a transient capâ¦ |

### `eye_logo.dart`
_67 lines._ The Percipere eye mark shown at the top of most screens (mockups).

| Name | Kind | What it does |
|---|---|---|
| **`EyeLogo`** | class | The Percipere eye mark shown at the top of most screens (mockups). |

### `fit_text.dart`
_184 lines._ Text that always stays inside its box: the box has a fixed height of lines lines of style, and text that would need more room is shrunk to fit instead of pushing the rest of the screen down (review feâ¦

| Name | Kind | What it does |
|---|---|---|
| **`FitText`** | class | Text that always stays inside its box: the box has a fixed height of lines lines of style, and text that would need more room is shrunk to fit instead of pushing the rest of the screen down (review feâ¦ |

### `gesture_pad.dart`
_60 lines._ The Gesture Pad: the bordered box at the bottom of in-app screens and the only surface where navigation gestures are detected (so they never clash with scrolling or buttons elsewhere).

| Name | Kind | What it does |
|---|---|---|
| **`GesturePad`** | class | The Gesture Pad: the bordered box at the bottom of in-app screens and the only surface where navigation gestures are detected (so they never clash with scrolling or buttons elsewhere). |

### `gesture_pad_layout.dart`
_59 lines._ Standard in-app screen layout: content on top, the GesturePad taking roughly the bottom third.

| Name | Kind | What it does |
|---|---|---|
| **`GesturePadLayout`** | class | Standard in-app screen layout: content on top, the GesturePad taking roughly the bottom third. |

### `guest_reminder_on_entry.dart`
_98 lines._ When a guest is reminded to register.

| Name | Kind | What it does |
|---|---|---|
| **`GuestReminderMoment`** | enum | When a guest is reminded to register. |
| **`GuestReminderOnEntry`** | class | Says the guest registration reminder once, after screenId's own announcement, at moment. |

### `live_speaking_zone.dart`
_58 lines._ A SpeakingZone bound to the Announcer and the voice controller.

| Name | Kind | What it does |
|---|---|---|
| **`LiveSpeakingZone`** | class | A SpeakingZone bound to the Announcer and the voice controller. |

### `pill_button.dart`
_141 lines._ Visual style of a PillButton.

| Name | Kind | What it does |
|---|---|---|
| **`PillVariant`** | enum | Visual style of a PillButton. |
| **`PillButton`** | class | Full-width, pill-shaped button from the design (min 56dp tall, bold label, soft drop shadow). |

### `small_link.dart`
_68 lines._ A compact outlined link to a secondary destination (History, Settings, "Nakalimutan ang password").

| Name | Kind | What it does |
|---|---|---|
| **`SmallLink`** | class | A compact outlined link to a secondary destination (History, Settings, "Nakalimutan ang password"). |

### `speaking_zone.dart`
_73 lines._ The Speaking Zone: waveform plus a live subtitle of what TTS is saying.

| Name | Kind | What it does |
|---|---|---|
| **`SpeakingZone`** | class | The Speaking Zone: waveform plus a live subtitle of what TTS is saying. |

### `waveform.dart`
_149 lines._ Horizontal audio waveform of thin vertical bars.

| Name | Kind | What it does |
|---|---|---|
| **`Waveform`** | class | Horizontal audio waveform of thin vertical bars. |
| **`WaveformPainter`** | class | Paints the waveform bars. |

## `lib/features/auth/`

Screens: login, register, forgot password, security question, fingerprint, old PIN accounts.

### `auth_choice_screen.dart`
_66 lines._ "Nais mo bang mag login sa iyong account?" with Login and Register (mockups `login_confirmation` / `register_confirmation`).

| Name | Kind | What it does |
|---|---|---|
| **`AuthChoiceScreen`** | class | "Nais mo bang mag login sa iyong account?" with Login and Register (mockups `login_confirmation` / `register_confirmation`). |

### `choice_layout.dart`
_76 lines._ One button of a ChoiceLayout.

| Name | Kind | What it does |
|---|---|---|
| **`ChoiceButton`** | class | One button of a ChoiceLayout. |
| **`ChoiceLayout`** | class | The "Nais mo bang mag login?" mockup layout: eye logo, title, Speaking Zone with the question, pill buttons, and the Gesture Pad. |

### `fingerprint_offer_screen.dart`
_104 lines._ After registering (when the phone has a fingerprint enrolled): "Gusto mo bang gamitin ang iyong fingerprint sa pag-login?" Oo checks the finger once and turns fingerprint login on; Hindi skips.

| Name | Kind | What it does |
|---|---|---|
| **`FingerprintOfferScreen`** | class | After registering (when the phone has a fingerprint enrolled): "Gusto mo bang gamitin ang iyong fingerprint sa pag-login?" Oo checks the finger once and turns fingerprint login on; Hindi skips. |

### `forgot_password_screen.dart`
_296 lines._ Forgot password: email → the security question set at registration → a new password.

| Name | Kind | What it does |
|---|---|---|
| **`ForgotPasswordScreen`** | class | Forgot password: email → the security question set at registration → a new password. |

### `form_scaffold.dart`
_86 lines._ The layout of the Register / Login mockups: eye logo, title, Speaking Zone, the form, and the Gesture Pad below.

| Name | Kind | What it does |
|---|---|---|
| **`FormScaffold`** | class | The layout of the Register / Login mockups: eye logo, title, Speaking Zone, the form, and the Gesture Pad below. |

### `legacy_account_screen.dart`
_154 lines._ Claiming an old name + PIN account (made before Phase 6B): choose it, enter its old PIN once, then set an email and password (`UpgradeAccountScreen`).

| Name | Kind | What it does |
|---|---|---|
| **`LegacyAccountScreen`** | class | Claiming an old name + PIN account (made before Phase 6B): choose it, enter its old PIN once, then set an email and password (`UpgradeAccountScreen`). |

### `legacy_pin.dart`
_286 lines._ Digits in a spoken PIN: "isa dalawa tatlo apat", "1 2 3 4", "1234".

| Name | Kind | What it does |
|---|---|---|
| **`parseDigits`** | function | Digits in a spoken PIN: "isa dalawa tatlo apat", "1 2 3 4", "1234". |
| **`PinEntry`** | class | Legacy (pre-6B) PIN entry, used only to claim an old name + PIN account once before it sets an email and password. |
| &nbsp;&nbsp;↳ `count` | getter | Digits entered so far. |
| &nbsp;&nbsp;↳ `dial` | getter | Digit currently on the dial. |
| &nbsp;&nbsp;↳ `clear` | method | Clears everything. |
| &nbsp;&nbsp;↳ `intents` | method | Screen intent handlers for PIN entry, speaking via l. |
| &nbsp;&nbsp;↳ `add` | method | Enters digit. |
| &nbsp;&nbsp;↳ `deleteLast` | method | Removes the last digit. |
| &nbsp;&nbsp;↳ `takeSpoken` | method | Takes a whole spoken PIN. |
| **`PinPad`** | class | The PIN display (filled dots, the dial digit) and a keypad for sighted helpers. |
| **`tickFor`** | function | Haptic tick helper for keypad presses. |

### `lockout_countdown.dart`
_55 lines._ The spoken countdown while a login is locked: the time left every 10 seconds and the last 3 seconds, then "Maaari ka nang sumubok muli."

| Name | Kind | What it does |
|---|---|---|
| **`LockoutCountdown`** | class | The spoken countdown while a login is locked: the time left every 10 seconds and the last 3 seconds, then "Maaari ka nang sumubok muli." |
| &nbsp;&nbsp;↳ `seconds` | getter | Whole seconds left; 0 when not locked. |
| &nbsp;&nbsp;↳ `start` | method | Starts (or restarts) counting down wait. |

### `login_screen.dart`
_382 lines._ Login: Email Address and Password, then Submit (double-tap the Gesture Pad, or "submit" / "tapos na").

| Name | Kind | What it does |
|---|---|---|
| **`LoginScreen`** | class | Login: Email Address and Password, then Submit (double-tap the Gesture Pad, or "submit" / "tapos na"). |

### `register_screen.dart`
_179 lines._ Register: First Name, Last Name, Email Address, Password, then Submit.

| Name | Kind | What it does |
|---|---|---|
| **`RegisterScreen`** | class | Register: First Name, Last Name, Email Address, Password, then Submit. |

### `security_question_screen.dart`
_200 lines._ Right after registering: choose a security question from a short spoken list (swipe + double-tap, or say it), then answer it by voice or typing.

| Name | Kind | What it does |
|---|---|---|
| **`SecurityQuestionScreen`** | class | Right after registering: choose a security question from a short spoken list (swipe + double-tap, or say it), then answer it by voice or typing. |

### `upgrade_account_screen.dart`
_178 lines._ An old name + PIN account (logged in, or just claimed) sets an email and password, keeping its settings and history.

| Name | Kind | What it does |
|---|---|---|
| **`UpgradeAccountScreen`** | class | An old name + PIN account (logged in, or just claimed) sets an email and password, keeping its settings and history. |

### `voice_form.dart`
_449 lines._ What a form field holds; decides how dictation is cleaned up and how the value is read back.

| Name | Kind | What it does |
|---|---|---|
| **`FieldKind`** | enum | What a form field holds; decides how dictation is cleaned up and how the value is read back. |
| **`VoiceField`** | class | One field of a VoiceForm. |
| &nbsp;&nbsp;↳ `value` | getter | Current value, trimmed (passwords are kept exactly). |
| &nbsp;&nbsp;↳ `isEmpty` | getter | Whether nothing was entered. |
| &nbsp;&nbsp;↳ `describe` | method | "Email Address: juan@gmail.com" / "Password: 9 titik" / "First Name, walang laman". |
| &nbsp;&nbsp;↳ `spokenValue` | method | The value as it may be spoken: passwords only by length. |
| &nbsp;&nbsp;↳ `fromSpeech` | method | Cleans up dictated heard for this field. |
| **`VoiceForm`** | class | A spoken form: each field can be dictated or typed. |
| &nbsp;&nbsp;↳ `focused` | getter | The focused field, if any. |
| &nbsp;&nbsp;↳ `hasInput` | getter | Whether anything was entered (back then asks first). |
| &nbsp;&nbsp;↳ `firstEmpty` | getter | The first field without a value. |
| &nbsp;&nbsp;↳ `focusStart` | method | Focuses field (or the first empty one) without speaking; returns the question to ask, or the "complete" hint when everything is filled. |
| &nbsp;&nbsp;↳ `ask` | method | Focuses f and asks its question. |
| &nbsp;&nbsp;↳ `fill` | method | Fills the focused field with text (spoken or typed), reads it back and asks the next empty field. |
| &nbsp;&nbsp;↳ `typed` | method | A text field finished typing: read it back and move on. |
| &nbsp;&nbsp;↳ `onUtterance` | method | Takes free speech for the focused field. |
| &nbsp;&nbsp;↳ `dictate` | method | Long-press: dictate the focused field (or the first empty one). |
| &nbsp;&nbsp;↳ `clear` | method | Clears the focused field. |
| &nbsp;&nbsp;↳ `actions` | method | Field actions (focus order) plus Submit and Clear. |
| &nbsp;&nbsp;↳ `intents` | method | Gesture behavior on a form screen. |
| **`reportInvalid`** | function | Speaks validation problems and focuses the first bad field. |
| **`VoiceTextField`** | class | The pill-shaped text field from the mockups. |
| **`FieldRow`** | typedef | Fields of form that should share a row (First/Last Name). |
| **`VoiceFormView`** | class | The fields laid out as in the mockups, then a Submit button. |
| **`focusFirstFieldWhenActive`** | function | Watches the active screen and focuses the first empty field once screenId is active. |

## `lib/features/camera/`

Screen: in-app camera with spoken framing guidance.

### `camera_guidance.dart`
_124 lines._ Spoken hint for the current camera frame.

| Name | Kind | What it does |
|---|---|---|
| **`Guidance`** | enum | Spoken hint for the current camera frame. |
| &nbsp;&nbsp;↳ `text` | method | The spoken sentence. |
| &nbsp;&nbsp;↳ `of` | method | Classifies one preview frame. |
| **`GuidanceStep`** | class | What to do after a frame. |
| **`GuidanceTracker`** | class | Turns a stream of per-frame Guidance into calm speech: - a hint must hold for stableFrames frames before it's spoken (no flicker between "Ilapit pa" and "Handa na"); - at least minGap between hints; -â¦ |
| &nbsp;&nbsp;↳ `update` | method | Feeds one frame's guidance. |
| &nbsp;&nbsp;↳ `markSpoken` | method | Records that g was actually spoken at now. |
| &nbsp;&nbsp;↳ `reset` | method | Forgets everything (after a failed capture, say). |

### `camera_screen.dart`
_307 lines._ Camera capture with audio guidance.

| Name | Kind | What it does |
|---|---|---|
| **`CameraScreen`** | class | Camera capture with audio guidance. |

### `camera_session.dart`
_193 lines._ A live camera with text analysis on preview frames.

| Name | Kind | What it does |
|---|---|---|
| **`CameraSession`** | class | A live camera with text analysis on preview frames. |
| &nbsp;&nbsp;↳ `start` | method | Opens the back camera and starts analysing frames; onFrame gets a summary of each analysed frame (a few per second). |
| &nbsp;&nbsp;↳ `preview` | method | The live preview. |
| &nbsp;&nbsp;↳ `takePicture` | method | Stops analysis and takes a full-resolution photo; returns its path. |
| **`DeviceCameraSession`** | class | CameraSession on the device camera, with ML Kit on NV21 frames. |
| **`toNv21`** | function | Packs a camera frame as NV21 (Y plane, then interleaved V/U), whether the plugin delivered one NV21 plane or three YUV_420_888 planes. |
| **`meanLuma`** | function | Average of a sample of the first ySize bytes (the luma plane). |
| **`cameraSessionFactoryProvider`** | provider | Creates camera sessions (a new one each time the camera screen opens or resumes). |

## `lib/features/capture/`

Screen: Capture (Mag-upload / Gamit ang Camera / Maglarawan).

### `capture_screen.dart`
_205 lines._ Screen B — Capture method: upload a file or use the camera.

| Name | Kind | What it does |
|---|---|---|
| **`CaptureScreen`** | class | Screen B — Capture method: upload a file or use the camera. |

### `describe_intro_on_entry.dart`
_91 lines._ On each user's first visit to screenId (Capture) after Maglarawan was added, reads the full explanation once, queued after the screen's own announcement.

| Name | Kind | What it does |
|---|---|---|
| **`DescribeIntroOnEntry`** | class | On each user's first visit to screenId (Capture) after Maglarawan was added, reads the full explanation once, queued after the screen's own announcement. |

## `lib/features/describe/`

Screens: Maglarawan source choice and the Description screen.

### `describe_controller.dart`
_521 lines._ What the Description screen shows.

| Name | Kind | What it does |
|---|---|---|
| **`DescribeSubject`** | class | What the Description screen shows. |
| **`NewImage`** | class | A picture to describe (from the camera or the file picker). |
| **`SavedDescription`** | class | A description saved in the Library. |
| **`DescribePhase`** | enum | Where the analysis is. |
| **`DescribeState`** | class | State of the Description screen. |
| &nbsp;&nbsp;↳ `fullText` | getter | Everything there is to read. |
| &nbsp;&nbsp;↳ `picturePath` | getter | The picture to show: the live image, or the saved thumbnail. |
| **`DescribeController`** | class | Describes one picture: offline labels first (always), the existing OCR for text, and — only if the user agrees — the web app's detailed description. |
| &nbsp;&nbsp;↳ `repeat` | method | "Ulitin": say the description again. |
| &nbsp;&nbsp;↳ `requestDetail` | method | "Mas detalyado": the web app's description, after consent. |
| &nbsp;&nbsp;↳ `readText` | method | "Basahin ang teksto": open the text found in the picture in the Reader. |
| &nbsp;&nbsp;↳ `save` | method | "I-save": put the description in Reading History (once; later detail updates the saved text). |
| &nbsp;&nbsp;↳ `newPicture` | method | "Bagong larawan": back to choosing a source. |
| &nbsp;&nbsp;↳ `changeTextSize` | method | Pinch, A−/A+ or voice: text size one step bigger (direction 1) or smaller (−1), saved like in the Reader. |
| **`describeControllerProvider`** | provider | Description state per subject; disposed when the screen closes. |

### `describe_screen.dart`
_148 lines._ The Description screen: the picture's thumbnail and the description in the Document Box, the options on the Gesture Pad.

| Name | Kind | What it does |
|---|---|---|
| **`DescribeScreen`** | class | The Description screen: the picture's thumbnail and the description in the Document Box, the options on the Gesture Pad. |

### `describe_source_screen.dart`
_120 lines._ Maglarawan, step 1: where the picture comes from — the camera (with its audio guidance) or an uploaded image.

| Name | Kind | What it does |
|---|---|---|
| **`DescribeSourceScreen`** | class | Maglarawan, step 1: where the picture comes from — the camera (with its audio guidance) or an uploaded image. |

## `lib/features/home/`

Screen: Home (Magbasa ng bago / Aklatan).

### `home_screen.dart`
_121 lines._ Home: "Ano ang gusto mong gawin?" — read something new (Capture) or open the Library (Aklatan).

| Name | Kind | What it does |
|---|---|---|
| **`HomeScreen`** | class | Home: "Ano ang gusto mong gawin?" — read something new (Capture) or open the Library (Aklatan). |

## `lib/features/library/`

Screens: Library shelves, item details, favorites, chapters.

### `chapters_screen.dart`
_151 lines._ The chapters of an EPUB (or a PDF with an outline).

| Name | Kind | What it does |
|---|---|---|
| **`ChaptersScreen`** | class | The chapters of an EPUB (or a PDF with an outline). |

### `favorites_screen.dart`
_248 lines._ Opens the favorites list of an item.

| Name | Kind | What it does |
|---|---|---|
| **`FavoritesArgs`** | class | Opens the favorites list of an item. |
| **`FavoritesScreen`** | class | The favorites of one item, in reading order. |

### `item_details_screen.dart`
_574 lines._ Details of one library item, like an Apple Books book page: cover, title, progress, time left, and the actions — Ituloy/Basahin first, so double-tapping twice from the Library resumes reading.

| Name | Kind | What it does |
|---|---|---|
| **`ItemDetailsScreen`** | class | Details of one library item, like an Apple Books book page: cover, title, progress, time left, and the actions — Ituloy/Basahin first, so double-tapping twice from the Library resumes reading. |

### `library_actions.dart`
_250 lines._ What can be done with a library item: read it (fetching books first), download it, mark it finished.

| Name | Kind | What it does |
|---|---|---|
| **`LibraryActions`** | class | What can be done with a library item: read it (fetching books first), download it, mark it finished. |
| &nbsp;&nbsp;↳ `open` | method | Opens item in the Reader (or the Description screen for a saved Maglarawan). |
| &nbsp;&nbsp;↳ `download` | method | Downloads a book for offline reading. |
| &nbsp;&nbsp;↳ `removeDownload` | method | Deletes the downloaded copy, keeping progress and favorites. |
| &nbsp;&nbsp;↳ `setFinished` | method | Marks item finished or not. |
| &nbsp;&nbsp;↳ `offerUpdate` | method | Offers to update a downloaded book whose version changed, keeping the reading position. |
| &nbsp;&nbsp;↳ `sizeLabel` | method | "3.2 MB" / "512 KB" for bytes. |
| &nbsp;&nbsp;↳ `whenLabel` | method | "kahapon", "ngayon", "3 araw na ang nakalipas" or a date. |
| **`libraryActionsProvider`** | provider | The Library's item actions. |

### `library_controller.dart`
_223 lines._ What the Library screen shows.

| Name | Kind | What it does |
|---|---|---|
| **`LibraryState`** | class | What the Library screen shows. |
| &nbsp;&nbsp;↳ `shelves` | getter | Shelves for the current view. |
| &nbsp;&nbsp;↳ `visibleItems` | getter | Items passing the current filter and search. |
| **`LibraryController`** | class | Loads and changes the user's Library. |
| &nbsp;&nbsp;↳ `load` | method | Fills in sentence totals of migrated history, then loads the lists. |
| &nbsp;&nbsp;↳ `reload` | method | Reads items, collections and favorites again. |
| &nbsp;&nbsp;↳ `refreshCatalog` | method | Asks the web app for the catalog and merges it. |
| &nbsp;&nbsp;↳ `setFilter` | method | Applies filter (and clears the search). |
| &nbsp;&nbsp;↳ `setQuery` | method | Applies a search; an empty query shows everything again. |
| &nbsp;&nbsp;↳ `cycle` | getter | Filters in the order the Filter control cycles through them. |
| &nbsp;&nbsp;↳ `createCollection` | method | Makes a collection; returns it. |
| &nbsp;&nbsp;↳ `renameCollection` | method | Renames a collection. |
| &nbsp;&nbsp;↳ `deleteCollection` | method | Deletes a collection (its items stay). |
| **`libraryControllerProvider`** | provider | The Library lists. |

### `library_screen.dart`
_1316 lines._ The Library (Aklatan): the user's documents and the admin books on shelves, like Apple Books.

| Name | Kind | What it does |
|---|---|---|
| **`LibraryScreen`** | class | The Library (Aklatan): the user's documents and the admin books on shelves, like Apple Books. |

## `lib/features/reader/`

Screen: the Reader (reads documents aloud sentence by sentence).

### `reader_controller.dart`
_962 lines._ What the Reader opens.

| Name | Kind | What it does |
|---|---|---|
| **`ReaderSource`** | class | What the Reader opens. |
| **`TextSource`** | class | Text that is already extracted. |
| **`FileSource`** | class | A file still to be read (camera photo or upload); saved to the Library. |
| **`ItemSource`** | class | A library item, resumed at its saved position (or at chapter and sentence when jumping to a favorite). |
| **`ReaderPhase`** | enum | Reader lifecycle. |
| **`ReaderState`** | class | State of the Reader for one source. |
| &nbsp;&nbsp;↳ `hasChapters` | getter | More than one chapter to move between. |
| &nbsp;&nbsp;↳ `chapter` | getter | Chapter of the current sentence. |
| &nbsp;&nbsp;↳ `paragraphCount` | getter | Paragraph count. |
| &nbsp;&nbsp;↳ `current` | getter | The sentence to highlight, if any. |
| &nbsp;&nbsp;↳ `canRead` | getter | Whether reading controls apply. |
| **`ReaderController`** | class | Loads a ReaderSource and reads it aloud sentence by sentence. |
| &nbsp;&nbsp;↳ `insights` | method | What kind of document this is and its key facts (computed once). |
| &nbsp;&nbsp;↳ `readingLanguage` | getter | The language the document is read in: detected, unless Settings forces a document voice. |
| &nbsp;&nbsp;↳ `filipinoWithoutVoice` | getter | Whether a Filipino document will be read by an English voice. |
| &nbsp;&nbsp;↳ `play` | method | Reads from the current sentence. |
| &nbsp;&nbsp;↳ `pause` | method | Pauses reading (spoken confirmation unless quiet). |
| &nbsp;&nbsp;↳ `togglePlay` | method | Tap: play or pause. |
| &nbsp;&nbsp;↳ `skipSentence` | method | Swipe right/left: next or previous sentence. |
| &nbsp;&nbsp;↳ `skipParagraph` | method | Two-finger swipe: next or previous paragraph. |
| &nbsp;&nbsp;↳ `repeatSentence` | method | Double-tap: read the current sentence again. |
| &nbsp;&nbsp;↳ `readFromStart` | method | "Mula sa simula": restart from the first sentence. |
| &nbsp;&nbsp;↳ `changeRate` | method | Swipe up/down: change the reading speed by delta (0.1 steps). |
| &nbsp;&nbsp;↳ `changeTextSize` | method | A+/A−, pinch or voice: text size one step bigger (direction 1) or smaller (−1), saved to the user's settings. |
| &nbsp;&nbsp;↳ `save` | method | "I-save": documents are auto-saved; this confirms (and saves if not yet). |
| &nbsp;&nbsp;↳ `addFavorite` | method | "Paborito": saves the current spot as a favorite. |
| &nbsp;&nbsp;↳ `goTo` | method | Jumps to a saved spot and carries on reading from there. |
| &nbsp;&nbsp;↳ `skipChapter` | method | "Susunod / nakaraang kabanata": jumps to the start of the next chapter, or the start of this one (previous, when already past its start). |
| **`readerControllerProvider`** | provider | Reader state per source; disposed when the Reader closes. |

### `reader_screen.dart`
_397 lines._ Screen C — Reader: the Document Box replaces the Speaking Zone, and the Gesture Pad carries all reading controls.

| Name | Kind | What it does |
|---|---|---|
| **`ReaderScreen`** | class | Screen C — Reader: the Document Box replaces the Speaking Zone, and the Gesture Pad carries all reading controls. |
| &nbsp;&nbsp;↳ `insightLines` | method | What is said about a new document before reading: its kind, who it is from and its key facts (nothing when the kind is unclear). |
| &nbsp;&nbsp;↳ `typeLine` | method | "Mukhang resibo ito." etc. |

## `lib/features/settings/`

Screen: Settings and its rows.

### `setting_items.dart`
_353 lines._ How a setting is changed.

| Name | Kind | What it does |
|---|---|---|
| **`SettingKind`** | enum | How a setting is changed. |
| **`SettingContext`** | class | What a setting's value text needs. |
| **`confirmLogout`** | function | Logs out after a spoken confirmation; then "log in or register?" (or Welcome, for a guest). |
| **`settingItemsFor`** | function | The settings offered to account, in order. |

### `settings_screen.dart`
_354 lines._ Accessibility Settings.

| Name | Kind | What it does |
|---|---|---|
| **`SettingsScreen`** | class | Accessibility Settings. |

## `lib/features/setup/`

Screens: guided setup (profiling) after login.

### `profiling_screen.dart`
_1094 lines._ The guided setup after login ("profiling"): one screen per step, each with the eye logo, a live preview where it helps, the Speaking Zone and the Gesture Pad.

| Name | Kind | What it does |
|---|---|---|
| **`ProfilingScreen`** | class | The guided setup after login ("profiling"): one screen per step, each with the eye logo, a live preview where it helps, the Speaking Zone and the Gesture Pad. |

### `setup_flow.dart`
_216 lines._ The steps of the guided setup, in order.

| Name | Kind | What it does |
|---|---|---|
| **`SetupStep`** | enum | The steps of the guided setup, in order. |
| &nbsp;&nbsp;↳ `tryParse` | method | Parses a stored name, or null. |
| &nbsp;&nbsp;↳ `needsSight` | getter | Steps that only matter to someone who can see some text. |
| **`SetupMode`** | enum | Why the setup is running. |
| **`SetupFlow`** | class | Which steps to ask and where the user is: the pure logic behind the profiling screens (skip, back, resume, jump from the summary). |
| &nbsp;&nbsp;↳ `step` | getter | The current step. |
| &nbsp;&nbsp;↳ `hidden` | method | Whether s is skipped for this user. |
| &nbsp;&nbsp;↳ `number` | getter | 1-based step number. |
| &nbsp;&nbsp;↳ `total` | getter | How many numbered steps there are. |
| &nbsp;&nbsp;↳ `isFirst` | getter | Whether this is the first step. |
| &nbsp;&nbsp;↳ `summaryItems` | getter | Steps shown in the summary (the ones in this plan, not hidden). |
| &nbsp;&nbsp;↳ `next` | method | After confirming or skipping the current step. |
| &nbsp;&nbsp;↳ `back` | method | Back one step (values already chosen are kept). |
| &nbsp;&nbsp;↳ `answerSeesText` | method | Answers "can you see some text?" and moves on: to the text steps on yes, past them on no. |
| &nbsp;&nbsp;↳ `jumpTo` | method | From the summary: open s (returns to the summary afterwards). |

### `setup_labels.dart`
_116 lines._ A text color's name in the language of l ("Kayumanggi" / "Dark brown").

| Name | Kind | What it does |
|---|---|---|
| **`colorName`** | function | A text color's name in the language of l ("Kayumanggi" / "Dark brown"). |
| **`themeName`** | function | A theme's name. |
| **`stepQuestion`** | function | The question of step (shown before it is spoken). |
| **`stepValue`** | function | The current value of step as shown under the question. |
| **`summaryLine`** | function | One summary line: "Bilis: 1.25x" (no final period; lines are joined into sentences). |
| **`stepKeywords`** | constant | Words that name each step ("bumalik sa bilis"). |
| **`matchStepJump`** | function | The step named in "bumalik sa bilis" / "palitan ang kulay", if it is one of items; null otherwise (then the words are handled as a command). |

## `lib/features/tutorial/`

Screen: controls tutorial.

### `tutorial_screen.dart` 🆕
_361 lines._ One step of the tutorial.

| Name | Kind | What it does |
|---|---|---|
| **`TutorialStep`** | enum | One step of the tutorial. |
| **`TutorialScreen`** | class | Controls tutorial ("Pag-aaral ng mga kontrol"): explains and lets the user practise each gesture and a voice command before using the app. |

## `lib/features/upload/`

System file picker and camera-app fallback.

### `document_picker.dart`
_178 lines._ Outcome of asking the user for a file.

| Name | Kind | What it does |
|---|---|---|
| **`PickResult`** | class | Outcome of asking the user for a file. |
| **`Picked`** | class | A supported file was chosen. |
| **`PickCancelled`** | class | The picker was closed without a choice. |
| **`PickUnsupported`** | class | A file of an unsupported type was chosen. |
| **`PickFailed`** | class | A file was chosen but could not be read or copied (or the picker itself failed). |
| **`logCapture`** | function | Logs a capture/upload problem with its stack trace (`adb logcat -s flutter \| findstr CAPTURE`). |
| **`DocumentPicker`** | class | System pickers. |
| &nbsp;&nbsp;↳ `pickDocument` | method | Opens the Storage Access Framework picker for JPG/PNG/PDF/DOCX. |
| &nbsp;&nbsp;↳ `pickImage` | method | Opens the picker for JPG/PNG images only (Maglarawan). |
| &nbsp;&nbsp;↳ `takePhotoWithSystemCamera` | method | Fallback when the in-app camera fails: the phone's own camera app. |
| **`SystemDocumentPicker`** | class | DocumentPicker via `file_picker` (no broad storage permission needed) and `image_picker`. |
| &nbsp;&nbsp;↳ `localCopyOf` | method | A readable local path for file: its own path when that file is really there and not empty, otherwise a private copy of its bytes (Android may hand back only a content:// address). |
| **`documentPickerProvider`** | provider | The app's document picker. |

## `lib/features/welcome/`

Screen: Welcome (Login / Register / Subukan muna).

### `welcome_screen.dart`
_231 lines._ Screen A — Welcome: Login, Register, or "Subukan muna (Try first)".

| Name | Kind | What it does |
|---|---|---|
| **`WelcomeScreen`** | class | Screen A — Welcome: Login, Register, or "Subukan muna (Try first)". |

## `lib/`

Entry point.

### `main.dart`
_11 lines._ Starts the app: runs `bootstrap()` and shows `PercipereApp`.

| Name | Kind | What it does |
|---|---|---|
| **`main`** | function | Starts the app: runs `bootstrap()` and shows `PercipereApp`. |

---

# Android native code (`android/`)

| File | What it does |
|---|---|
| `app/src/main/kotlin/ph/bataan/percipere/MainActivity.kt` | The app's Android activity (`FlutterFragmentActivity`, needed by fingerprint login). Hosts two channels: `ph.bataan.percipere/storage` → `freeBytes` (free space via `StatFs`, for the Library's low-storage warning) and `ph.bataan.percipere/sound` → `heard` (the short beep when a voice command is heard, via `ToneGenerator`). ⚠️ **Missing from the updated copy**; present in this repository. |
| `AssistantBridge.kt` 🆕 | Bridge between Dart and the ElevenLabs Android SDK: channels `ph.bataan.percipere/assistant` (start, end, toolResult, context) and `…/assistant_events`. ⚠️ **Missing from the updated copy and from this repository**; must be obtained from the sender. |
| `app/src/main/AndroidManifest.xml` | Permissions: camera, microphone (`RECORD_AUDIO`), internet and network state, vibration, Bluetooth and audio settings (for Percy's audio), and the activity. |
| `app/build.gradle.kts` | Application id `ph.bataan.percipere.app`, minSdk 24, release shrinking, ElevenLabs SDK dependency. |
| `app/proguard-rules.pro` | Keep rules so release builds don't strip ML Kit, the input plugins and the ElevenLabs/WebRTC SDK. |
| `build.gradle.kts` | Repositories (JitPack, limited to LiveKit's `audioswitch`). |

# Voice assistant helpers (`assistant/`, Python, PC/server only) 🆕

| File | What it does |
|---|---|
| `setup_agent.py` | Configures the ElevenLabs agent from the PC: client tools, instructions, Tagalog + English, voice, end-call tool, call length and daily limits, overrides. Options: `--voice-id`, `--max-minutes`, `--daily-limit`, `--private`, `--dry-run`. The API key comes from `ELEVENLABS_API_KEY`, never the app. |
| `server/token_server.py` | Optional token service for a private agent: gives the app a short-lived conversation token so only the app can use the ElevenLabs credits. |
| `agent_config/prompt.md` | Percy's instructions: personality, language, how to speak, which tool to use when, hand-over to the app, document and privacy rules. |
| `agent_config/tools.json` | The 12 client tools (`get_screen`, `go_to`, `choose_option`, `list_library`, `open_document`, `read_document`, `scan_document`, `upload_document`, `get_document_text`, `reading_settings`, `save_favorite`, `describe_controls`); a Dart test checks they match `AssistantTools.names`. |
| `tests/test_setup_agent.py`, `tests/test_token_server.py` | Unit tests for the two scripts. |
| `requirements.txt` | Python packages for the scripts. |

# Other folders

| Folder | Contents |
|---|---|
| `assets/fonts/` | Bundled fonts: Montserrat (default), Atkinson Hyperlegible, Lexend. |
| `lib/l10n/` | `app_fil.arb` (Filipino, the template) and `app_en.arb`; `app_localizations*.dart` are generated from them. |
| `tool/test_each.sh` | Runs each test file separately and retries `flutter_tester` crashes (use on this PC). |
| `docs/specs/` | Requirements and decisions: `architecture.md`, `decisions.md`, `library.md`, `image-recognition.md`, `assistant.md` 🆕, `auth.md`, `profiling.md`, `guest-mode.md`, `navigation.md`, `algorithms.md`. |
| `docs/testing/` | Manual checklists per phase (6C, 6E, voice response, input fix 🆕, assistant 🆕, system test). |
| `docs/api-contract.md` | Endpoints the web admin app must provide. |
| `docs/ui/` | Mockups (they win over prompt wording). |

# Tests (`test/`)

51 test files; 667 tests pass with `bash tool/test_each.sh` (one Windows-only path failure in
`test/features/upload/document_picker_test.dart`).

| Folder | Test files |
|---|---|
| `test/` | `android_release_rules_test.dart` |
| `test/app/` | `theme_test.dart` |
| `test/core/accessibility/` | `announcer_test.dart`, `command_bus_test.dart`, `question_wait_test.dart`, `smart_voice_test.dart` |
| `test/core/assistant/` 🆕 | `assistant_controller_test.dart` |
| `test/core/auth/` | `auth_test.dart` |
| `test/core/db/` | `library_dao_test.dart`, `migrations_test.dart`, `preferences_dao_test.dart` |
| `test/core/describe/` | `image_prep_test.dart`, `label_description_test.dart` |
| `test/core/extraction/` | `extraction_test.dart` |
| `test/core/gestures/` | `gesture_classifier_test.dart` |
| `test/core/library/` | `epub_parser_test.dart`, `library_service_test.dart`, `library_view_test.dart` |
| `test/core/ocr/` | `text_cleanup_test.dart` |
| `test/core/settings/` | `settings_controller_test.dart` |
| `test/core/tts/` | `chunker_test.dart`, `language_detector_test.dart` |
| `test/core/understanding/` 🆕 | `document_insights_test.dart` |
| `test/core/voice/` | `command_matcher_test.dart`, `understanding_test.dart`, `voice_controller_test.dart`, `voice_response_test.dart` |
| `test/core/widgets/` | `widgets_test.dart` |
| `test/features/` | `assistant_flow_test.dart`, `auth_flow_test.dart`, `capture_flow_test.dart`, `capture_regression_test.dart`, `phase6_flows_test.dart`, `screens_fit_test.dart`, `screens_test.dart`, `smart_voice_flow_test.dart`, `text_size_layout_test.dart`, `voice_flow_test.dart`, `welcome_flow_test.dart` |
| `test/features/camera/` | `camera_guidance_test.dart` |
| `test/features/describe/` | `describe_controller_test.dart`, `describe_flow_test.dart` |
| `test/features/library/` | `library_details_flow_test.dart`, `library_extras_test.dart`, `library_flow_test.dart` |
| `test/features/reader/` | `reader_controller_test.dart`, `reader_flow_test.dart`, `reader_library_test.dart` |
| `test/features/setup/` | `profiling_flow_test.dart`, `setup_flow_test.dart` |
| `test/features/upload/` 🆕 | `document_picker_test.dart` |
