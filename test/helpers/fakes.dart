import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:percipere_app/core/accessibility/haptics.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/auth/account.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/biometrics.dart';
import 'package:percipere_app/core/auth/login_throttle.dart';
import 'package:percipere_app/core/auth/password_hasher.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/auth/session_store.dart';
import 'package:percipere_app/core/db/app_database.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/extraction/extraction_exception.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';
import 'package:percipere_app/core/platform/app_closer.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/platform/system_settings.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/features/camera/camera_session.dart';
import 'package:percipere_app/features/upload/document_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Records what would have been spoken.
///
/// With [autoComplete] (default) every utterance finishes immediately.
/// Otherwise each one waits for [finishCurrent] or [stop], so tests can
/// interrupt speech mid-sentence.
class FakeTts implements TtsService {
  /// Creates a fake TTS.
  FakeTts({
    this.autoComplete = true,
    this.voices = const VoiceStatus(filipinoReady: true),
  });

  /// Whether utterances complete immediately.
  bool autoComplete;

  /// What [checkVoices] reports.
  VoiceStatus voices;

  /// Every utterance, in order.
  final List<String> spoken = [];

  /// The language tag of each utterance.
  final List<String> tags = [];

  /// The speed of each utterance.
  final List<double> rates = [];

  /// Number of [stop] calls.
  int stopCalls = 0;

  Completer<bool>? _current;

  /// Everything spoken so far, joined.
  String get transcript => spoken.join(' ');

  /// Whether an utterance is waiting to finish.
  bool get isSpeaking => _current != null;

  /// Ends the utterance in progress as finished.
  void finishCurrent() => _end(true);

  void _end(bool finished) {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete(finished);
  }

  @override
  Future<bool> speak(
    String text, {
    required String languageTag,
    double rate = 1.0,
  }) {
    spoken.add(text);
    tags.add(languageTag);
    rates.add(rate);
    if (autoComplete) return Future.value(true);
    // A new utterance while one is pending: the old one counts as stopped.
    _end(false);
    return (_current = Completer<bool>()).future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _end(false);
  }

  @override
  Future<VoiceStatus> checkVoices() async => voices;

  /// Pitches set, in order.
  final List<double> pitches = [];

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);
}

/// Records haptic cues.
class FakeHaptics implements Haptics {
  /// Cues in order: `tick`, `confirm`, `error`.
  final List<String> events = [];

  @override
  Future<void> tick() async => events.add('tick');

  @override
  Future<void> confirm() async => events.add('confirm');

  @override
  Future<void> error() async => events.add('error');
}

/// Counts settings pages opened.
class FakeSystemSettings implements SystemSettings {
  /// Times the TTS settings page was opened.
  int ttsOpened = 0;

  @override
  Future<bool> openTtsSettings() async {
    ttsOpened++;
    return true;
  }

  /// Times the voice input settings page was opened.
  int voiceInputOpened = 0;

  @override
  Future<bool> openVoiceInputSettings() async {
    voiceInputOpened++;
    return true;
  }
}

/// Scripted speech recognizer: tests decide what is "heard".
class FakeSpeechInput implements SpeechInput {
  /// Creates a fake recognizer.
  FakeSpeechInput({
    this.available = true,
    this.locales = const ['en_US', 'fil_PH'],
  });

  /// Whether the phone "has" a recognizer.
  bool available;

  /// Recognizer locales.
  List<String> locales;

  /// Every session started, in order.
  final List<ListenRequest> sessions = [];

  /// Whether a session is open.
  bool listening = false;

  /// Number of cancel() calls.
  int cancels = 0;

  void Function(String code)? _onError;
  void Function(String status)? _onStatus;
  void Function(String words, bool isFinal)? _onResult;

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    return available;
  }

  @override
  Future<List<String>> localeIds() async => locales;

  @override
  Future<void> listen(
    ListenRequest request, {
    required void Function(String words, bool isFinal) onResult,
  }) async {
    sessions.add(request);
    _onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async {
    listening = false;
    cancels++;
  }

  /// Delivers a partial result.
  void partial(String words) => _onResult!(words, false);

  /// Delivers a final result and ends the session.
  void hear(String words) {
    listening = false;
    _onResult!(words, true);
    _onStatus?.call('done');
  }

  /// Ends the session with nothing heard.
  void silence() => fail('error_speech_timeout');

  /// Ends the session with an Android error [code].
  void fail(String code) {
    listening = false;
    _onError?.call(code);
    _onStatus?.call('done');
  }
}

/// Scripted runtime permissions: current state and what a request yields.
class FakePermissions implements PermissionService {
  /// Creates fake permissions. Defaults to a fresh install: nothing allowed
  /// yet, and the user allows whatever is asked.
  FakePermissions({
    PermissionAccess mic = PermissionAccess.denied,
    PermissionAccess micOnRequest = PermissionAccess.granted,
    PermissionAccess camera = PermissionAccess.denied,
    PermissionAccess cameraOnRequest = PermissionAccess.granted,
  }) : access = {AppPermission.microphone: mic, AppPermission.camera: camera},
       onRequest = {
         AppPermission.microphone: micOnRequest,
         AppPermission.camera: cameraOnRequest,
       };

  /// Current state per permission.
  final Map<AppPermission, PermissionAccess> access;

  /// Result of the next request per permission.
  final Map<AppPermission, PermissionAccess> onRequest;

  /// Permission dialogs "shown", per permission.
  final Map<AppPermission, int> requests = {};

  /// Times the app settings page was opened.
  int settingsOpened = 0;

  /// Microphone dialogs shown.
  int get micRequests => requests[AppPermission.microphone] ?? 0;

  /// Camera dialogs shown.
  int get cameraRequests => requests[AppPermission.camera] ?? 0;

  @override
  Future<PermissionAccess> status(AppPermission p) async => access[p]!;

  @override
  Future<PermissionAccess> request(AppPermission p) async {
    requests[p] = (requests[p] ?? 0) + 1;
    return access[p] = onRequest[p]!;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

// Kept reachable for the whole run, so no connection is ever finalized
// mid-run.
final List<AppDatabase> _databases = [];

/// An empty in-memory database. Uses the no-isolate FFI factory so it works
/// inside `testWidgets`' fake-async zone. A new one per test (isolated from
/// work a previous test's widgets left running), never closed; in-memory
/// databases are freed when the test process exits.
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: 'file:percipere_test_${_databases.length}?mode=memory',
    singleInstance: false,
  );
  _databases.add(db);
  return db;
}

/// Test doubles for everything `bootstrap()` normally provides.
///
/// Defaults to a fresh install: nobody logged in, Filipino voice installed,
/// microphone not yet allowed. With [TestEnv.create]'s `loggedIn` (the
/// default whenever a navigation mode is given) a registered account that
/// finished the setup is logged in, so the app starts on Capture.
class TestEnv {
  /// Creates a test environment.
  TestEnv({
    required this.database,
    FakeTts? tts,
    FakeSpeechInput? speech,
    FakePermissions? permissions,
    this.mode,
    this.appSettings,
    this.account,
  }) : tts = tts ?? FakeTts(),
       speech = speech ?? FakeSpeechInput(),
       permissions = permissions ?? FakePermissions();

  /// Opens a database and builds the environment.
  static Future<TestEnv> create({
    FakeTts? tts,
    FakeSpeechInput? speech,
    FakePermissions? permissions,
    NavMode? mode,
    AppSettings? appSettings,
    bool? loggedIn,
    bool setupDone = true,
  }) async {
    final database = await openTestDatabase();
    Account? account;
    if (loggedIn ?? mode != null) {
      final repo = AccountRepository(database.db, testHasher);
      final a = await repo.register(
        firstName: 'Ana',
        lastName: 'Cruz',
        email: testEmail,
        password: testPassword,
      );
      await repo.setProfilingCompleted(a.id, setupDone);
      account = await repo.get(a.id);
    }
    return TestEnv(
      database: database,
      tts: tts,
      speech: speech,
      permissions: permissions,
      mode: mode,
      appSettings: appSettings,
      account: account,
    );
  }

  /// Email of the test account (test value only).
  static const String testEmail = 'ana@example.com';

  /// Password of the test account (test value only).
  static const String testPassword = 'test-pass-123';

  /// Fast hashing for tests (same algorithm, few iterations, no isolate).
  static const PasswordHasher testHasher = PasswordHasher(
    iterations: 1000,
    useIsolate: false,
  );

  /// The logged-in account at "launch", if any.
  final Account? account;

  /// Saved session (secure storage stand-in).
  late final MemorySessionStore sessions = MemorySessionStore(
    userId: account?.id,
  );

  /// Scripted fingerprint sensor.
  final FakeBiometrics biometrics = FakeBiometrics();

  /// The clock the login lockout reads (advance it to let a lockout end).
  DateTime now = DateTime(2026, 10, 1, 9);

  /// Times "close the app" ran.
  int appClosed = 0;

  /// In-memory database.
  final AppDatabase database;

  /// Fake speech output.
  final FakeTts tts;

  /// Fake speech input.
  final FakeSpeechInput speech;

  /// Fake runtime permissions.
  final FakePermissions permissions;

  /// Saved navigation mode at "launch".
  final NavMode? mode;

  /// Settings at "launch" (navigation mode comes from [mode]).
  final AppSettings? appSettings;

  /// Fake haptics.
  final FakeHaptics haptics = FakeHaptics();

  /// Fake settings launcher.
  final FakeSystemSettings settings = FakeSystemSettings();

  /// Fake file picker.
  final FakeDocumentPicker picker = FakeDocumentPicker();

  /// Fake extractor (swap its fields to script results).
  final FakeDocumentExtractor extractor = FakeDocumentExtractor();

  /// The camera the next camera screen gets.
  FakeCameraSession camera = FakeCameraSession();

  /// Provider overrides.
  List<Override> get overrides => [
    appDatabaseProvider.overrideWithValue(database),
    ttsServiceProvider.overrideWithValue(tts),
    voiceStatusProvider.overrideWith(() => VoiceStatusNotifier(tts.voices)),
    initialSettingsProvider.overrideWithValue(
      (appSettings ?? const AppSettings()).copyWith(navMode: mode),
    ),
    if (account != null) ...[
      initialAccountProvider.overrideWithValue(account),
      initialSettingsScopeProvider.overrideWithValue(account!.id),
    ],
    passwordHasherProvider.overrideWithValue(testHasher),
    sessionStoreProvider.overrideWithValue(sessions),
    biometricsProvider.overrideWithValue(biometrics),
    appCloserProvider.overrideWithValue(() => appClosed++),
    loginThrottleProvider.overrideWith(
      (ref) => LoginThrottle(database.db, clock: () => now),
    ),
    initialMicGrantedProvider.overrideWithValue(
      permissions.access[AppPermission.microphone] == PermissionAccess.granted,
    ),
    hapticsProvider.overrideWithValue(haptics),
    systemSettingsProvider.overrideWithValue(settings),
    speechInputProvider.overrideWithValue(speech),
    documentPickerProvider.overrideWithValue(picker),
    documentExtractorProvider.overrideWithValue(extractor),
    cameraSessionFactoryProvider.overrideWithValue(() => camera),
    permissionServiceProvider.overrideWithValue(permissions),
  ];
}

/// A Filipino paragraph long enough to overflow the Document Box.
const String sampleText =
    'Ang Bataan ay isang lalawigan sa rehiyon ng Gitnang Luzon. Kilala ito '
    'sa makasaysayang Martsa ng Kamatayan noong Ikalawang Digmaang '
    'Pandaigdig, at sa Dambana ng Kagitingan sa Bundok Samat.\n\n'
    'Ang pagbabasa ay karapatan ng lahat. Sa tulong ng Percipere, maaaring '
    'pakinggan ang mga liham, resibo, reseta, at aklat nang hindi na '
    'kailangang umasa sa ibang tao.\n\n'
    'Maaari mong i-pause, ituloy, bilisan, o bagalan ang pagbasa gamit ang '
    'galaw ng iyong daliri o ang iyong boses.';

/// Scripted file choices.
class FakeDocumentPicker implements DocumentPicker {
  /// Next result of [pickDocument].
  PickResult nextPick = const Picked(
    DocumentFile(path: 'upload.pdf', kind: DocumentKind.pdf),
  );

  /// Next result of [takePhotoWithSystemCamera].
  PickResult nextPhoto = const Picked(
    DocumentFile(path: 'photo.jpg', kind: DocumentKind.image, fromCamera: true),
  );

  /// Times the file picker was opened.
  int picks = 0;

  /// Times the system camera was opened.
  int photos = 0;

  @override
  Future<PickResult> pickDocument() async {
    picks++;
    return nextPick;
  }

  @override
  Future<PickResult> takePhotoWithSystemCamera() async {
    photos++;
    return nextPhoto;
  }
}

/// Scripted extraction: returns [result], or throws [failure]; reports
/// [pages] pages of progress first. With [hold], waits for [release].
class FakeDocumentExtractor implements DocumentExtractor {
  /// Creates a fake extractor.
  FakeDocumentExtractor({
    this.result = const ExtractionResult(
      text: sampleText,
      quality: TextQuality.good,
      pageCount: 1,
      usedOcr: true,
    ),
    this.failure,
    this.pages = 1,
    this.hold = false,
  });

  /// What extraction yields.
  ExtractionResult result;

  /// Thrown instead, if set.
  ExtractionFailure? failure;

  /// Pages of progress to report.
  int pages;

  /// Whether to wait for [release] before finishing.
  bool hold;

  /// Files extracted, in order.
  final List<DocumentFile> extracted = [];

  // Created inside extract(), i.e. in the test's zone: a completer made
  // while building the env (on the real clock) would never complete there.
  Completer<void>? _gate;
  bool _released = false;

  /// Lets a held extraction finish.
  void release() {
    _released = true;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<ExtractionResult> extract(
    DocumentFile file, {
    void Function(int page, int pageCount)? onPage,
  }) async {
    extracted.add(file);
    for (var i = 1; i <= pages; i++) {
      onPage?.call(i, pages);
    }
    if (hold && !_released) await (_gate ??= Completer<void>()).future;
    if (failure != null) throw ExtractionException(failure!);
    return result;
  }
}

/// A camera that emits scripted frames.
class FakeCameraSession implements CameraSession {
  /// Creates a fake camera; [failOnStart] simulates a broken camera.
  FakeCameraSession({this.failOnStart = false});

  /// Throw from [start].
  bool failOnStart;

  /// Whether [start] succeeded.
  bool started = false;

  /// Whether [dispose] was called.
  bool disposed = false;

  /// Photos taken.
  int pictures = 0;

  void Function(FrameStats stats)? _onFrame;

  @override
  Future<void> start(void Function(FrameStats stats) onFrame) async {
    if (failOnStart) throw StateError('no camera');
    _onFrame = onFrame;
    started = true;
  }

  /// Emits one analysed frame.
  void frame(FrameStats stats) => _onFrame?.call(stats);

  @override
  Widget preview() => const ColoredBox(color: Color(0xFF333333));

  @override
  Future<String> takePicture() async {
    pictures++;
    return 'camera_$pictures.jpg';
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// Frame stats presets.
abstract final class Frames {
  /// Nothing readable.
  static const FrameStats empty = FrameStats(
    lineCount: 0,
    textAreaFraction: 0,
    touchesEdge: false,
    meanLuma: 120,
  );

  /// Text too small.
  static const FrameStats far = FrameStats(
    lineCount: 3,
    textAreaFraction: 0.05,
    touchesEdge: false,
    meanLuma: 120,
  );

  /// Clear text.
  static const FrameStats good = FrameStats(
    lineCount: 12,
    textAreaFraction: 0.4,
    touchesEdge: false,
    meanLuma: 130,
  );

  /// Too dark.
  static const FrameStats dark = FrameStats(
    lineCount: 0,
    textAreaFraction: 0,
    touchesEdge: false,
    meanLuma: 20,
  );
}

/// Scripted fingerprint sensor.
class FakeBiometrics implements Biometrics {
  /// Whether a fingerprint is enrolled.
  bool enrolled = false;

  /// What the next check returns.
  BiometricResult next = BiometricResult.success;

  /// Checks shown.
  int prompts = 0;

  @override
  Future<bool> available() async => enrolled;

  @override
  Future<BiometricResult> authenticate(String reason) async {
    prompts++;
    return next;
  }
}
