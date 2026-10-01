# Percipere: implementation summary

Written from the code as of commit `69796cd` (Phase 6B), 1 October 2026. Everything below
is what the code does, not what the specs ask for. Where the two differ, the code is
described and the gap is listed in section 9.

Percipere is an Android app (`ph.bataan.percipere`) that reads printed and digital text
aloud. It is driven by gestures or voice, in Filipino (default) or English.

---

## 1. Tech stack

### Toolchain
| | Version |
|---|---|
| Flutter | 3.47.5 (stable, framework `6a19cca564`) |
| Dart | 3.13.4 (`sdk: ^3.13.4`) |
| Android Gradle Plugin | 9.1.0 |
| Kotlin Gradle plugin | 2.4.0 |
| Gradle | 9.3.1 |
| Java / JVM target | 17 |
| minSdk / compileSdk / targetSdk | 24 / 37.0 / Flutter default |
| Android entry point | `MainActivity : FlutterFragmentActivity` (needed by `local_auth`) |

### Packages used by the app (resolved versions from `pubspec.lock`)
| Package | Version | Used for |
|---|---|---|
| flutter_riverpod | 3.4.3 | State management (hand-written providers, no codegen) |
| go_router | 18.0.2 | Navigation |
| sqflite | 2.4.4 | Local SQLite database |
| path | 1.9.1 | Database and temp file paths |
| path_provider | 2.1.6 | Temp directory for rendered PDF pages |
| google_mlkit_text_recognition | 0.17.1 | On-device OCR (Latin script) |
| speech_to_text | 7.5.0 | Speech recognition (Android recognizer) |
| flutter_tts | 4.2.5 | Text-to-speech (prefers the Google engine) |
| camera | 0.12.1 | In-app camera with live frame analysis |
| image_picker | 1.2.3 | Fallback: the phone's own camera app |
| file_picker | 13.1.0 | File upload through Android's picker (no storage permission) |
| archive | 4.3.0 | Unzipping DOCX files |
| xml | 7.1.0 | Reading DOCX `word/document.xml` |
| pdfrx | 2.6.5 | PDF text layer and page rendering (PDFium) |
| crypto | 3.0.7 | HMAC-SHA256 (passwords) and SHA-256 (legacy PINs) |
| uuid | 4.6.0 | Account ids |
| flutter_secure_storage | 11.2.0 | Login session |
| local_auth | 3.0.2 | Fingerprint login |
| permission_handler | 13.0.2 | Microphone and camera permissions |
| android_intent_plus | 6.1.0 | Opening Android TTS and voice-input settings |
| vibration | 3.2.1 | Haptic patterns |
| intl | 0.20.3 | Dates in History, generated localizations |
| flutter_localizations | SDK | Filipino and English UI |

### Declared in `pubspec.yaml` but never imported by `lib/`
dio 5.11.1, connectivity_plus 7.3.1, audio_session 0.2.4, package_info_plus 10.2.1,
device_info_plus 13.2.0, csv 8.0.0, share_plus 13.3.0. They are placeholders for later
phases and could be removed until then.

### Development
flutter_test, integration_test (declared, no integration tests yet), flutter_lints 6.0.0,
mocktail 1.0.5 (declared, unused: tests use hand-written fakes), sqflite_common_ffi 2.4.3
(SQLite in tests), fake_async 1.3.3.

### Fonts and languages
- **Fonts:** bundled in `assets/fonts/`: Montserrat (default), Atkinson Hyperlegible,
  Lexend.
- **Languages:** `lib/l10n/app_fil.arb` (template) and `app_en.arb`, 314 strings each.

---

## 2. Architecture in one paragraph

`main()` runs `bootstrap()` (opens the database, restores the session, loads that
account's settings, starts TTS, checks voices) and starts `PercipereApp`. Every screen
wraps itself in `AccessibleScreen` and registers a `ScreenRegistration`: its title,
spoken prompt, actions and intent overrides. Gestures (`GestureSurface` →
`GestureClassifier` → `gestureMap`), voice (`VoiceController` → `CommandBus
.handleUtterance` → `CommandMatcher`), visual taps and Android back all end up in
`CommandBus`, which runs the action on the active screen and speaks a confirmation
through `Announcer`. Settings are one `AppSettings` object per account, saved key by key
in SQLite.

---

## 3. Module by module

Line counts in brackets. Private helpers are listed only where they carry the screen's
behavior.

### `lib/main.dart`, `lib/app/`
- **main.dart [11]:** `main()`, which calls `bootstrap()` then `runApp`.
- **app.dart [84]:** `PercipereApp`, the root widget (theme, locale, router).
  `UserTextScale` multiplies Android's font scale by the app's text-size factor.
- **bootstrap.dart [106]:**
  - `bootstrap()` returns the provider overrides.
  - `restoreSession()` reads the secure-storage session, migrates the pre-6B
    `account.currentUser` preference, and expires the session when "stay logged in" is
    off.
- **router.dart [181]:**
  - `AppRoutes` holds the 15 route paths and `home(account)`.
  - `buildRouter()`.
  - `routerProvider` chooses the start screen: Welcome, the "log in again" screen, or the
    account's home.
- **ids.dart [157]:** `Ids`, the stable screen and action ids (also intended for usage
  logs).
- **locale_provider.dart [16]:** `AppLocales` (fil, en), `appLocaleProvider`.
- **theme/app_palette.dart [261]:**
  - `AppPalette`, a theme extension with three presets: `creamNavy`, `darkYellow`,
    `darkWhite`.
  - `of()`, `withTextColor()`, value equality, `context.palette`.
- **theme/app_theme.dart [157]:** `AppTheme.build()`, `AppTheme.documentText()`, and
  `AppTextMetrics` (reading-text size), `documentTextScaler`.
- **theme/theme_settings.dart [95]:** `AppFont`; `TextSize` (18–48 sp, step 2, reading
  text only; legacy % conversion); `ThemeSettings`; `themeSettingsProvider`.

### `lib/config/`
- **constants.dart [62]:** `AppDimens` (56 dp touch targets, padding, Gesture Pad = 30%
  of the height) and `AppDurations` (auto-listen delay 450 ms, 60 s voice idle limit,
  20 s yes/no window, …).
- **palette.dart [148]:** `ThemeId` (with names migrated from before 6B),
  `TextColorOption`, `TextColors.forTheme/defaultFor/resolve/offers`.
- **env.dart [17]:** `Env.apiBaseUrl` (default `https://percipere-admin.invalid`) and
  `Env.useMockApi` (default true). **Not referenced anywhere** (see section 7).

### `lib/core/accessibility/`
- **command_bus.dart [486]:** `CommandBus`, the single input entry point.
  - Dispatch: `onGesture`, `dispatch(intent)`, `handleUtterance`.
  - Yes/no questions: `offer()`, with an ask-back for unclear speech.
  - Focus and actions: `moveFocus`, `activateFocused`, `activate`.
  - Speech: `announceScreen`, `entryAnnouncement` (with "Bumalik sa …"), `modeHint`,
    `help`, `say`, `stopSpeech`, `notAvailable`.
  - `back()`: confirms unsaved input, runs `beforeBack`, pops or offers to close the app.
- **announcer.dart [223]:** `Announcer`, the speech queue spoken sentence by sentence,
  feeding the live subtitle (`say`, `stop`, `idle`, `setReading`,
  `splitSentences`). Protected confirmations aren't cut off. With TalkBack on it sends
  TalkBack announcements instead of using TTS. `SpeechState`.
- **accessible_screen.dart [88]:** `AccessibleScreen` registers a screen and routes
  Android back through `PopScope` → `NavIntent.back`.
- **accessibility_host.dart [118]:** `AccessibilityHost`.
  - Announces each screen when it becomes active.
  - Startup notices: missing Filipino voice, TalkBack.
  - Re-checks voices when the app resumes and pauses listening in the background.
- **action_registry.dart [50]:** `ActionRegistry` (`register`, `replace`, `unregister`),
  `activeScreenProvider`.
- **screen_registration.dart [124]:** `A11yAction`, `ScreenRegistration` (`prompt`,
  `actions`, `intentHandlers`, `onUtterance`, `autoListen`, `hasUnsavedInput`,
  `beforeBack`).
- **focus_controller.dart [42]:** `FocusController` (`move`, `focus`); resets when the
  screen changes.
- **haptics.dart [64]:** the `Haptics` interface and `DeviceHaptics`: `tick`, `confirm`
  (45 ms), `error` (triple buzz). Follows the vibration setting.
- **nav_intent.dart [84]:** the `NavIntent` enum (27 intents, section 5).
- **navigation_mode.dart [54]:** `NavMode` (voice/gestures), `navigationModeProvider`,
  `talkBackProvider`.

### `lib/core/auth/`
- **password_hasher.dart [119]:** `PasswordHasher`.
  - `hash`, `verify`, static `pbkdf2`: PBKDF2-HMAC-SHA256, 100 000 iterations, 16-byte
    random salt, 32-byte key, constant-time compare, run in `Isolate.run`.
  - `StoredSecret`.
- **account.dart [124]:** `Account` (`name`, `isGuest`, `isLegacy`, flags) and
  `SecurityQuestion` (5 questions).
- **account_repository.dart [331]:** `AccountRepository`.
  - Accounts: `get`, `findByEmail`, `emailTaken`, `register`, `verifyPassword`,
    `setPassword`, `markLogin`.
  - Security answer: `setSecurityAnswer`, `verifySecurityAnswer`.
  - Flags and sync: `setProfilingCompleted`, `setFingerprint`, `markSynced`,
    `unsynced`.
  - Guest: `guest`, `migrateGuest`.
  - Legacy PIN accounts: `legacyAccounts`, `verifyLegacyPin`, `upgradeLegacy`.
  - Also `EmailTakenException` and `LegacyPinHash` (the old salted SHA-256 × 10 000).
- **validators.dart [73]:** `AuthRules`: `normalizeEmail`, `isValidEmail`,
  `isValidPassword` (≥ 8), `spokenEmail` ("at"→@, "dot/tuldok/punto"→., "underscore",
  "dash/gitling"), `spokenPassword` (lowercase, no spaces), `spokenName`,
  `normalizeAnswer`.
- **login_throttle.dart [113]:** `LoginThrottle`: `delayAfter`, `remaining`,
  `recordFailure`, `failures`, `reset`. Five free tries, then 30 s doubling, up to 1 h.
  Separate `login` and `reset` counters per email.
- **session.dart [82]:** `CurrentAccount` (`login`, `startGuest`, `completeRegistration`,
  `logout`, `refresh`), `currentAccountProvider`, `userPrefsProvider`,
  `initialAccountProvider`, `initialSessionExpiredProvider`.
- **session_store.dart [94]:** `SessionStore`, with `SecureSessionStore`
  (flutter_secure_storage) and `MemorySessionStore`. It holds the user id and the
  fingerprint user id only.
- **biometrics.dart [71]:** `Biometrics` / `DeviceBiometrics` (`available`,
  `authenticate`, biometric only), `BiometricResult`.
- **account_sync_repository.dart [38]:** the `AccountSyncRepository` interface (`enqueue`,
  `syncPending`) and `MockAccountSyncRepository` (section 9).
- **guest_reminders.dart [39]:** `GuestReminders` (`historySaved`,
  `takeHistoryReminder`).

### `lib/core/db/`
- **app_database.dart [54]:** `AppDatabase.open()` (runs migrations, turns foreign keys
  on), `appDatabaseProvider`.
- **migrations.dart [204]:** `Migration`, `Migrations.migrate()`, v1 and v2 (section 6).
- **daos/preferences_dao.dart [140]:** `PrefKeys` (all keys, section 6) and
  `PreferencesDao` (`get`, `set`, `getAll`, `remove`, JSON values).
- **daos/documents_dao.dart [143]:** `DocumentRecord` and `DocumentsDao` (`insert`,
  `get`, `list(userId, query)`, `updatePosition`, `markOpened`, `rename`, `delete`).

### `lib/core/gestures/`
- **gesture_classifier.dart [200]:** `GestureClassifier` turns raw pointers into
  gestures, multi-finger included (`pointerDown/Move/Up/Cancel`).
- **gesture_map.dart [99]:** `GestureType` (13 types), `gestureMap` (the only
  gesture → intent table), `GestureTuning` (thresholds, section 5).
- **gesture_surface.dart [107]:** `GestureSurface`.
  - Sends gestures to the bus; `claimPointer` stops a button tap from also counting as
    a gesture.
  - Turned off while TalkBack is on.
  - Turns off overscroll effects underneath.

### `lib/core/voice/`
- **voice_controller.dart [455]:** `VoiceController` (state: `VoiceState`).
  - Listening: `ensureReady` (asks for the microphone after a spoken explanation),
    `listenNow`, `dictate`, `stopListening`, `noteActivity`, `setAppActive`.
  - `sensitive` hides recognized words while a password is being dictated.
  - Turn-taking with speech, auto-listen, and the on-device → online fallback.
- **command_matcher.dart [264]:** `CommandMatcher`.
  - `match`, `score` (containment, 1 + 0.01 per word), `normalize`, `similarity`,
    `levenshtein`.
  - Run at ≥ 0.8, ask back at 0.6–0.8; a tie within 0.005 asks rather than guessing.
- **speech_input.dart [121]:** `SpeechInput` / `SttSpeechInput` (`initialize`,
  `localeIds`, `listen`, `stop`, `cancel`) and `ListenRequest`.
  - Listens for up to 12 s.
  - Stops after a 3 s pause for commands, 4 s when dictating.
  - Passes the expected phrases to the recognizer as hints.
- **voice_commands.dart [65]:** `globalVoiceCommands`, `wakeWords`, `yesWords`,
  `noWords` (section 5).

### `lib/core/tts/`
- **tts_service.dart [177]:** `TtsService` / `FlutterTtsService` (`create`, `speak`,
  `stop`, `checkVoices`, `setPitch`), `VoiceStatus`, `VoiceStatusNotifier.refresh`.
  - Prefers `com.google.android.tts`.
  - Rate 1.0 maps to the engine's 0.5.
  - Each utterance is timed out at 5 s + 150 ms per character.
- **speech_language.dart [39]:** `speechLanguageProvider`: Filipino prompts only when a
  Filipino voice is installed, otherwise English.
- **chunker.dart [182]:** `Sentence`, `chunkText` (sentences of at most 220 characters,
  with exact offsets), `paragraphStarts`, `titleFor`.
- **language_detector.dart [190]:** `detectLanguage` (Filipino wins at ≥ 40% of
  function-word hits; Taglish counts as Filipino), `DocLanguage`, `LanguageGuess`.
- **reading_rate.dart [30]:** `ReadingRate` (0.5–2.0, step 0.25, `normalize`, `label`),
  `readingRateProvider`.

### `lib/core/ocr/` and `lib/core/extraction/`
- **ocr_service.dart [123]:** `OcrService` / `MlKitOcrService.recognizeFile`, `OcrPage`,
  `FrameStats`, `toOcrPage`, `toFrameStats`.
- **text_cleanup.dart [148]:** `cleanText` / `cleanTextAsync` (in an isolate),
  `isGarbageLine`, `TextQuality`, `assessQuality`.
- **document_extractor.dart [162]:** `DocumentKind` (image/pdf/docx), `DocumentFile`,
  `ExtractionResult`, `DefaultDocumentExtractor.extract`.
- **pdf_extractor.dart [140]:** `PdfrxReader.read`. Pages with fewer than 20 characters
  in their text layer are rendered at 2× to a temporary PNG and OCR'd; the PNG is
  deleted afterwards.
- **docx_extractor.dart [57]:** `extractDocxText`, `extractDocxTextAsync`.
- **extraction_exception.dart [26]:** `ExtractionFailure` (unsupported,
  passwordProtected, unreadable), `ExtractionException`.

### `lib/core/settings/`
- **app_settings.dart [254]:** `AppSettings`, 14 fields:
  - Navigation and voice: navMode, readingRate, pitch, locale, documentVoice.
  - Look: textSize, textColor, font, themeId.
  - Behavior: haptics, verbosity, autoCapture, autoRead, stayLoggedIn.

  Also `copyWith`, `withTheme` (resets a text color the new theme doesn't offer),
  `toPrefs` / `fromPrefs`, `Verbosity`, and `DocumentVoice`.
- **settings_controller.dart [93]:** `SettingsController` (`update`, which saves only
  the changed keys; `switchScope`; `reload`), `settingsProvider`.

### `lib/core/platform/`
- **permissions.dart [70]:** `PermissionService` / `DevicePermissionService` (`status`,
  `request`, `openAppSettings`) for the microphone and camera.
- **system_settings.dart [44]:** `AndroidSystemSettings` (`openTtsSettings`,
  `openVoiceInputSettings`, through Android intents).
- **app_closer.dart [9]:** `appCloserProvider` (`SystemNavigator.pop`).

### `lib/core/widgets/`
- **Layout:**
  - `GesturePadLayout`: content above, Gesture Pad below.
  - `GesturePad`: the bordered gesture area.
  - `BorderedPanel`.
  - `EyeLogo`: a painted eye mark.
- **Speech display:**
  - `SpeakingZone` / `LiveSpeakingZone`: waveform, live subtitle, the "Narinig" line.
  - `Waveform` (and its `WaveformPainter`).
- **Reading:** `DocumentBox`: document text, sentence highlight kept in view, loading
  state, caption strip.
- **Buttons:**
  - `PillButton`: primary / secondary / tertiary, with a focus ring.
  - `SmallLink`.
- **Guest:** `GuestReminderOnEntry`.

### `lib/features/`
- **welcome/welcome_screen.dart [230]:** Login, Register, Subukan muna.
  - The whole screen is the gesture surface.
  - `_askMicOnce` requests the microphone after the intro, on first launch only.
  - `_openTtsSettings` (swipe up) is available while the Filipino voice is missing.
- **auth/**
  - **Shared form and layouts:**
    - `voice_form.dart` [449]: `VoiceForm` (`fill`, `typed`, `onUtterance`, `dictate`,
      `clear`, `ask`, `focusStart`, `actions`, `intents`), `VoiceField`, `FieldKind`,
      `VoiceTextField`, `VoiceFormView`, `reportInvalid`.
    - `form_scaffold.dart` and `choice_layout.dart`: the mockup layouts.
    - `lockout_countdown.dart`: `LockoutCountdown`, which speaks every 10 s and the last
      3 s.
  - **Register and Login:**
    - `register_screen.dart` [179]: `_submit` validates input, registers, migrates a
      guest, then goes to the security question.
    - `login_screen.dart` [349]:
      - Methods: `_load`, `_tryFingerprint`, `_submit` (with lockout), `_loggedIn`.
      - Extra actions: forgot password, fingerprint, legacy account.
    - `auth_choice_screen.dart`: "Nais mo bang mag login…?" (after logout or an expired
      session).
  - **After registering:**
    - `security_question_screen.dart` [203]: choose a question, then answer it.
    - `fingerprint_offer_screen.dart`: `_enable`.
  - **Recovery:** `forgot_password_screen.dart` [296]: email → security answer → new
    password (`_checkEmail`, `_checkAnswer`, `_savePassword`).
  - **Legacy PIN accounts:**
    - `legacy_account_screen.dart`: choose an old PIN account, then enter its PIN.
    - `legacy_pin.dart` [286]: `PinEntry`, `PinPad`, `parseDigits`.
    - `upgrade_account_screen.dart`: set an email and password.
- **setup/**
  - **setup_flow.dart [214]:** `SetupStep` (11 values), `SetupMode` (firstRun/redo),
    and `SetupFlow`, which works out:
    - which steps to ask (`start`): the guest list, the steps not done yet, or all of
      them;
    - moving between steps: `next`, `back`, `answerSeesText`, `jumpTo`, `hidden`;
    - numbering: `number`, `total`, `summaryItems`.
  - **profiling_screen.dart [987]:** `ProfilingScreen`.
    - Flow: `_load` (resume), `_go`, `_confirm`, `_skip`, `_back`, `_answerSeesText`,
      `_finish`.
    - Live changes: `_change`, `_cycleColor`, `_cycleTheme`, `_sampleVoice`.
    - Step types: `_choice`, `_adjust`, `_summary`.
    - Views: `_NavModeView` and `_StepView`.
  - **setup_labels.dart [116]:** `colorName`, `themeName`, `stepQuestion`, `stepValue`,
    `summaryLine`, `stepKeywords`, `matchStepJump` ("bumalik sa bilis").
- **capture/capture_screen.dart [164]:** Mag-upload, Gamit ang Camera, Kasaysayan, Mga
  Setting. Delivers the guest's history reminder.
- **camera/**
  - **camera_screen.dart [282]:** `_start`, `_onFrame`, `_capture`, `_ensurePermission`,
    `_useSystemCamera`, `_openReader`.
  - **camera_session.dart [193]:** `DeviceCameraSession`:
    - back lens, `ResolutionPreset.veryHigh`, NV21 frames, flash off, no audio;
    - analyses a frame every 650 ms;
    - `toNv21`, `meanLuma`.
  - **camera_guidance.dart [124]:** `Guidance` (tooDark, noText, tooFar, tooClose,
    ready) and `GuidanceTracker`:
    - hints at least 2.5 s apart, repeated after 6 s;
    - takes the photo automatically after 4 "ready" frames in a row.
- **upload/document_picker.dart [81]:** `SystemDocumentPicker.pickDocument` (jpg, jpeg,
  png, pdf, docx) and `takePhotoWithSystemCamera`; `PickResult` (Picked, PickCancelled,
  PickUnsupported).
- **reader/**
  - **reader_controller.dart [586]:** `ReaderController` (autoDispose family per
    `ReaderSource`: `TextSource`, `FileSource`, `HistorySource`).
    - Playback: `play`, `pause`, `togglePlay`, `repeatSentence`, `readFromStart`.
    - Moving: `skipSentence`, `skipParagraph`.
    - Speed and saving: `changeRate`, `save`.
    - Auto-saves to history, and saves the position every 5 sentences, on pause and on
      close.
  - **reader_screen.dart [211]:** intent mapping, `_autoReads` / `_announceThenRead`,
    `beforeBack` (pause and save), retake offer for poor photos.
- **history/history_screen.dart [371]:** list, open/resume, item options (open, rename by
  dictation, delete after confirmation), "hanapin X", "ipakita lahat".
- **settings/**
  - **setting_items.dart [323]:** `settingItemsFor(account)` builds the rows (section 4
    lists them). Also `confirmLogout` and `_toggleFingerprint`.
  - **settings_screen.dart [354]:** `_change`, `_activate`, `_adjustFocused`, and
    TalkBack adjustable rows.

### Tests (`test/`, 27 files, 273 tests)
- **Unit:** gestures, command matcher, announcer, command bus, voice controller,
  chunker, language detector, text cleanup, extraction, migrations, DAOs, settings,
  themes (including the 7:1 contrast check), auth (PBKDF2 test vectors, repository,
  lockout, session, guest migration, `restoreSession`), setup flow.
- **Widget and flow:** screens, Welcome, back navigation, Register / Login / Forgot,
  setup, capture, camera, Reader, Settings, History.
- **Helpers:**
  - `test/helpers/` has fakes for TTS, speech, permissions, the camera, the picker,
    the extractor, biometrics and the session store, plus a fresh in-memory database
    per test.
  - `tool/test_each.sh` runs each file alone and retries `flutter_tester` crashes on
    the development PC.

---

## 4. Screens and routes

Each route below lists the screen's spoken title.

| Route | Screen | Title |
|---|---|---|
| `/` | Welcome | Welcome |
| `/register` | Register | Register |
| `/register/security` | Security question | Tanong pangseguridad |
| `/register/fingerprint` | Fingerprint offer | Fingerprint |
| `/login` | Login | Login |
| `/login/forgot` | Forgot password | Nakalimutan ang password |
| `/login/legacy` | Old PIN account | Lumang account |
| `/account/upgrade` | Set email + password | I-update ang account |
| `/auth` | Log in or register? | Login |
| `/setup` | Guided setup | Hakbang N ng M |
| `/capture` | Capture (home) | Pagkuha ng dokumento |
| `/camera` | Camera | Camera |
| `/reader` | Reader | Pagbasa |
| `/settings` | Settings | Mga Setting |
| `/history` | History | Kasaysayan ng Pagbasa |

**Startup routing:**
- No session → `/`.
- Session expired ("stay logged in" off) → `/auth`.
- Legacy PIN account → `/account/upgrade`.
- Setup not completed → `/setup`.
- Otherwise → `/capture`.

**Settings rows, in order:**
- Everyone: reading speed, pitch, language, document voice, text size, theme, text
  color, font, navigation mode, vibration, auto-read, verbosity, auto-capture, TTS
  voices.
- Accounts only: stay logged in, fingerprint login.
- Guests only: Register.
- Everyone: Ulitin ang setup, Logout.

---

## 5. Gestures and voice commands

### 5.1 Gestures
Gestures work on the Gesture Pad; on Welcome and setup Step 1 the whole screen takes
them. They are turned off while TalkBack is on.

The recognition thresholds, for users who can't see where their finger is:
- A swipe must travel at least 48 px within 1.2 s.
- A tap moves less than 20 px and lasts at most 400 ms.
- The second tap of a double-tap must come within 350 ms.
- A long-press is 650 ms.

| Gesture | Default intent | Reader | Setup steps | Forms (Register, Login, …) |
|---|---|---|---|---|
| Swipe right | next option | next sentence | next option / next value (color, theme) | next field |
| Swipe left | previous option | previous sentence | previous option / value | previous field |
| Double-tap | press focused option | read / pause | confirm or choose | submit |
| Tap | repeat the screen prompt | repeat sentence | repeat the question | repeat the field question |
| Swipe up | `faster` (Settings: change value up; History: item options; Welcome: open TTS settings if no Filipino voice) | faster | bigger / faster / higher | — |
| Swipe down | `slower` (Settings: change value down) | slower | smaller / slower / lower | — |
| Long-press | listen for a command | listen | listen | dictate the focused field |
| Two-finger swipe right | back | back (stops and saves first) | previous step | back (asks if something was typed) |
| Two-finger swipe down | next paragraph | next paragraph | — | — |
| Two-finger swipe up | previous paragraph | previous paragraph | — | — |
| Two-finger double-tap | stop speaking | pause | stop speaking | stop speaking |
| Three-finger tap | help for this screen | help | help | help |
| Two-finger swipe left | (recognized, unassigned) | | | |

Other screen-specific gestures:
- **Camera:** double-tap takes the photo.
- **Legacy PIN entry:** swipe up/down turns the digit dial, double-tap enters a digit,
  swipe left deletes, and long-press lets you say all four digits.

Android back (button or edge swipe) is the same as two-finger swipe right.

### 5.2 App-wide voice commands (`voice_commands.dart`)
| Intent | Phrases |
|---|---|
| activate | piliin, select, ok, okay, buksan, open |
| read | basahin, read, basa |
| pause | i-pause, pause, sandali |
| resume | ituloy, resume, continue, tuloy |
| stopSpeech | itigil, stop, tigil, tahimik |
| repeat | ulitin, repeat, ulit, again |
| next / previous | susunod, next, sunod / nakaraan, previous |
| next / previous paragraph | susunod na talata, next paragraph / nakaraang talata, previous paragraph |
| readFromStart | mula sa simula, basahin mula sa simula, from the beginning, start over, umpisahan ulit |
| back | bumalik, bumalik ng page, balik, bumalik sa nakaraang page, back, go back |
| faster / slower | bilisan, faster, mas mabilis / bagalan, slower, mas mabagal |
| camera / capture | camera, kamera / kunan, capture, take picture |
| upload | mag-upload, upload, i-upload |
| save | i-save, save, itago |
| history | kasaysayan, history |
| settings | settings, setting, ayos, mga setting |
| help | tulong, help |
| home | home, simula, umpisa |
| report | ulat, report, feedback, puna (answers "not ready yet") |
| voiceMode / gestureMode | pa-boses, voice mode / pa-galaw, gesture mode |

- **Yes / no** (only while a question is pending; it expires after 20 s):
  - yes: oo, opo, oho, yes, yeah, tama, sige;
  - no: hindi, huwag, no, mali, ayoko.
- **Wake words:** percipere / persipere / perchipere. On its own, a wake word re-arms
  listening; before a command, it is ignored.
- **Matching order:**
  1. a pending yes/no question;
  2. the screen's own `onUtterance` hook;
  3. the screen's action labels (Filipino and English, plus each part of
     "Pa-boses (Voice)") and `voiceSynonyms`;
  4. the app-wide phrases above.
- **Unclear speech:** if the best match scores 0.6–0.8, the app asks "Ang ibig mo bang
  sabihin ay …?".

### 5.3 Screen-specific voice phrases
- **Welcome:**
  - login, log in, mag-login, pumasok;
  - register, mag-register, magparehistro;
  - subukan, subukan muna, try first, try, guest.
- **Log in or register? (`/auth`):** login, log in, mag-login, oo / register,
  mag-register.
- **Forms (Register, Login, Forgot, Upgrade, Security answer):**
  - anything that isn't exactly a command fills the focused field;
  - submit: submit, tapos na, tapos, ipasa, isumite, done;
  - clear the field: burahin, linisin, clear.
- **Login:** nakalimutan, nakalimutan ang password, forgot password, forgot /
  fingerprint, daliri / lumang account, pin, old account.
- **Security question:** alaga, hayop, pet / bayan, sinilangan, town, birthplace / nanay,
  ina, dalaga, mother / paaralan, eskwelahan, school / pagkain, paborito, food.
- **Fingerprint offer:** oo, opo, yes, sige, gamitin / hindi, huwag, no, laktawan, skip.
- **Legacy PIN:** digits in Filipino, English or Spanish-derived words (isa, dalawa…,
  one, two…, uno, dos…), or numerals.
- **Setup, every step:**
  - laktawan, lumaktaw, skip;
  - okay, ok, sige, tama, tapos na, confirm.
- **Setup, specific steps:**
  - Step 1: boses, pa-boses, voice / galaw, pa-galaw, gestures, gesture.
  - Sight question: oo, opo, yes, nakakakita / hindi, no, wala, hindi nakakakita.
  - Text size: palakihin, lakihan, bigger, zoom in / paliitin, liitan, smaller, zoom out.
  - Voice language: tagalog, filipino, pilipino / ingles, english.
  - Tone: taasan, mas mataas, higher / babaan, mas mababa, lower.
  - Vibration and auto-read: oo, opo, yes, on / hindi, no, off, huwag.
- **Setup summary:**
  - finish: oo, opo, tama, sige, okay, ok, yes, tapos na, tapusin;
  - jump to a step: "bumalik sa / balik sa / go back to / back to / palitan ang /
    baguhin ang / change" + a step name (bilis, kulay, tema, tono, laki, wika,
    vibrate, …).
- **Capture:** mag-upload, upload, i-upload / camera, kamera / kasaysayan, history /
  settings, setting, ayos.
- **Camera:** kunan, capture, litrato, picture.
- **History:**
  - search: "hanapin / maghanap / search / find" + words;
  - show all again: ipakita lahat, lahat, show all;
  - item options: buksan, open, basahin / palitan, rename, pangalan / burahin, delete,
    tanggalin;
  - a document title opens that document.
- **Settings:** a row's name opens rows that do something (TTS voices, fingerprint,
  register, Ulitin ang setup, Logout).

---

## 6. Database

SQLite file `percipere.db` with foreign keys on. Schema version 2. Timestamps are
milliseconds since the epoch.

### v1 (Phase 1)
- **`users`:** `id` TEXT PK, `display_name` TEXT NOT NULL, `email` TEXT, `secret_hash`
  TEXT NOT NULL, `secret_salt` TEXT NOT NULL, `remote_id` TEXT, `created_at`,
  `updated_at` INTEGER NOT NULL, `last_login_at` INTEGER.
- **`preferences`:** (`user_id` TEXT, `key` TEXT) PK, `value` TEXT (JSON) NOT NULL,
  `updated_at`.
  - `user_id` is an account id, or `device` before login.
- **`documents`:** `id` INTEGER PK AUTOINCREMENT, `user_id` → users ON DELETE CASCADE,
  `title`, `full_text`, `source_type` CHECK in (camera, image, pdf, docx), `language`
  default `fil`, `created_at`, `updated_at`, `last_opened_at`, `last_position` INTEGER
  default 0.
  - Index on (`user_id`, `created_at` DESC).
- **`usage_logs`:** `id`, `session_id`, `event_type`, `screen`, `input_mode` CHECK in
  (gesture, voice, touch, talkback), `payload`, `created_at`, `uploaded_at`.
  - Index on `uploaded_at`.
- **`outbox`:** `id`, `type` CHECK in (report, feedback, sus, usage_logs, account_sync),
  `payload`, `status` CHECK in (pending, sending, sent, failed) default pending,
  `attempts`, `last_error`, `next_attempt_at`, `created_at`, `updated_at`.
  - Index on (`status`, `next_attempt_at`).
- **`sus_responses`:** `id`, `user_id` → users ON DELETE SET NULL, `answers` (JSON),
  `score` CHECK 0–100, `language`, `input_mode`, `created_at`.
- **`wer_results`:** `id`, `session_id`, `locale`, `on_device` (0/1), `reference`,
  `hypothesis`, substitutions, deletions, insertions, reference words, `wer`,
  `created_at`.
  - Index on `session_id`.

### v2 (Phase 6B)
- **`users` gains:**
  - names: `first_name`, `last_name`;
  - secrets: `secret_kind` (`pin` | `pbkdf2-sha256:<n>` | `none`, default `pin`),
    `security_question`, `security_answer_hash`, `security_answer_salt`;
  - flags: `is_guest`, `profiling_completed`, `fingerprint_enabled` (0/1);
  - sync: `synced` (0/1), `server_id`.
- **Data changes:**
  - `first_name` ← `display_name`, `server_id` ← `remote_id`;
  - emails of old PIN accounts are cleared (they set one when upgrading);
  - `documents.user_id` ← the logged-in profile, for documents read before 6B.
- **Unique index** `idx_users_email` on (`email` COLLATE NOCASE) where the email is not
  null.
- **`login_attempts`:** `key` TEXT PK (`login:<email>` or `reset:<email>`), `failures`,
  `locked_until`, `updated_at`.

### Preference keys (`PrefKeys`)
- **Settings, per account or `device`:**
  - navigation and voice: `nav.mode`, `tts.readingRate`, `tts.pitch`, `ui.locale`,
    `doc.voice`;
  - look: `ui.textSize`, `ui.textColor`, `ui.font`, `ui.palette` (the theme);
  - behavior: `haptics.enabled`, `speech.verbosity`, `camera.autoCapture`,
    `reader.autoRead`, `account.stayLoggedIn`.
- **Setup progress:** `setup.done`, `setup.step`, `setup.seesText`.
- **Guest reminders:** `guest.reminder.history`, `guest.reminder.settings`.
- **Device only:** `mic.askedOnWelcome`, `tts.filipinoFallback`.
- **Read only for migration:** `ui.textScale` (old text size) and `account.currentUser`
  (old session).

### Outside SQLite
`flutter_secure_storage` (Android Keystore) holds `session.userId` and
`session.fingerprintUserId`, and nothing else.

---

## 7. API endpoints

**None.**
- The code makes no network requests: no HTTP client is imported, and `dio` and
  `connectivity_plus` are declared but unused.
- `Env.apiBaseUrl` (default `https://percipere-admin.invalid`) and `Env.useMockApi`
  exist but are never read.
- The web admin app and its endpoints are planned for Phase 7.

---

## 8. Offline vs online

| Feature | Offline? | Notes |
|---|---|---|
| Accounts, login, lockout, forgot password, fingerprint | Fully offline | Local SQLite, Keystore and biometrics. Emails can't be verified. |
| OCR (camera, images, scanned PDF pages) | Fully offline | ML Kit's bundled on-device model. |
| PDF text and DOCX | Fully offline | |
| Reading aloud and prompts (TTS) | Offline once voices are installed | Uses the phone's TTS engine (prefers Google). Without a Filipino voice, prompts switch to English and the app offers to open TTS settings. Voices are downloaded through Android settings, which needs internet. |
| Voice commands (speech recognition) | Offline if the phone has the language pack | Tries on-device recognition first (`onDevice: true`). If the language pack is missing it retries online. Online and no network: it explains and offers Android's voice-input settings, while gestures keep working. Recognizer locale order: fil-PH, fil, tl-PH, en-PH, en-US for Filipino; en-PH, en-US, fil-PH for English. |
| History, settings, setup | Fully offline | |
| Account sync, reports, feedback, SUS, usage upload | Not built | Tables exist; nothing reads or writes them yet. |

The manifest declares INTERNET and ACCESS_NETWORK_STATE, which are only needed for the
online recognition fallback (and Phase 7).

---

## 9. Unfinished, mocked or unused

- **Account sync is mocked.** `MockAccountSyncRepository.enqueue` records the account
  id in memory and logs it; `syncPending()` returns 0.
  - Accounts stay `synced = 0`, so Phase 7 can send them all.
  - `AccountRepository.markSynced` and `unsynced` exist but nothing calls them.
- **No network layer:** see section 7.
- **Report / feedback** (`NavIntent.report`, "ulat") only says the feature isn't ready.
  "Guests can send feedback marked anonymous" from the guest-mode spec isn't built.
- **Unused tables:** `usage_logs`, `outbox`, `sus_responses` and `wer_results` are
  created but never written. `users.remote_id` was superseded by `server_id`.
- **Unused preference:** `tts.filipinoFallback` is written on every launch but never
  read.
- **Administrator reset** is only mentioned in a spoken message; it depends on the web
  app.
- **Unused packages:** listed in section 1. `mocktail` and `integration_test` are
  declared but not used.
- **Stale doc comment:** `NavIntent.repeat` still says "Reader: play/pause". Since 6B the
  Reader uses double-tap (`activate`) for play/pause and tap (`repeat`) to repeat the
  sentence.
- **Two-finger swipe left** is recognized but deliberately does nothing.
- **Not run on a real phone:** fingerprint login, and the PIN-account upgrade from an
  actual Phase 6 install, are covered only by tests and emulator checks.
- **Test-runner crashes:** `flutter_tester` still crashes at random on the Windows
  development PC (`0xC0000005`); `tool/test_each.sh` works around it. This affects
  only tests, not the app.
