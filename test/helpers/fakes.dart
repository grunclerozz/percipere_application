import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:percipere_app/config/percy_config.dart';
import 'package:percipere_app/core/accessibility/earcon.dart';
import 'package:percipere_app/core/accessibility/haptics.dart';
import 'package:percipere_app/core/accessibility/navigation_mode.dart';
import 'package:percipere_app/core/assistant/assistant_config.dart';
import 'package:percipere_app/core/assistant/assistant_platform.dart';
import 'package:percipere_app/core/auth/account.dart';
import 'package:percipere_app/core/auth/account_api.dart';
import 'package:percipere_app/core/auth/account_repository.dart';
import 'package:percipere_app/core/auth/account_service.dart';
import 'package:percipere_app/core/auth/biometrics.dart';
import 'package:percipere_app/core/auth/login_throttle.dart';
import 'package:percipere_app/core/auth/password_hasher.dart';
import 'package:percipere_app/core/auth/session.dart';
import 'package:percipere_app/core/auth/session_store.dart';
import 'package:percipere_app/core/db/app_database.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/describe/image_labeler.dart';
import 'package:percipere_app/core/describe/image_prep.dart';
import 'package:percipere_app/core/extraction/document_extractor.dart';
import 'package:percipere_app/core/extraction/extraction_exception.dart';
import 'package:percipere_app/core/library/admin_book_repository.dart';
import 'package:percipere_app/core/library/book_content.dart';
import 'package:percipere_app/core/library/epub_parser.dart';
import 'package:percipere_app/core/library/library_models.dart';
import 'package:percipere_app/core/library/library_paths.dart';
import 'package:percipere_app/core/network/connectivity.dart';
import 'package:percipere_app/core/network/image_description_repository.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/core/ocr/text_cleanup.dart';
import 'package:percipere_app/core/percy/intent_classifier.dart';
import 'package:percipere_app/core/percy/knowledge_base.dart';
import 'package:percipere_app/core/percy/percy_controller.dart';
import 'package:percipere_app/core/percy/percy_log_export.dart';
import 'package:percipere_app/core/percy/percy_responses.dart';
import 'package:percipere_app/core/platform/app_closer.dart';
import 'package:percipere_app/core/platform/permissions.dart';
import 'package:percipere_app/core/platform/storage_info.dart';
import 'package:percipere_app/core/platform/system_settings.dart';
import 'package:percipere_app/core/report/issue_report.dart';
import 'package:percipere_app/core/report/issue_report_api.dart';
import 'package:percipere_app/core/settings/app_settings.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/tts/tts_service.dart';
import 'package:percipere_app/core/voice/speech_input.dart';
import 'package:percipere_app/core/voice/voice_controller.dart';
import 'package:percipere_app/features/camera/camera_session.dart';
import 'package:percipere_app/features/upload/document_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_book_repository.dart';
import 'sample_books.dart';

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

  /// What [listVoices] reports.
  List<TtsVoice> installedVoices = const [];

  /// Reading-voice preferences set, in order.
  final List<String> voicePreferences = [];

  @override
  Future<List<TtsVoice>> listVoices() async => installedVoices;

  @override
  Future<void> setVoicePreference(String preference) async =>
      voicePreferences.add(preference);

  /// Set to make the next utterances report an engine failure.
  @override
  bool lastFailed = false;

  /// What [report] says.
  TtsReport ttsReport = const TtsReport(
    engine: 'com.google.android.tts',
    voiceName: 'fil-ph-x-fie-local',
    local: true,
  );

  @override
  Future<TtsReport> report(String languageTag) async => ttsReport;
}

/// Records haptic cues.
/// Counts "heard" earcons.
class FakeEarcon implements Earcon {
  /// Times the "heard" sound played.
  int played = 0;

  @override
  Future<void> heard() async => played++;

  /// Times the "listening" cue played.
  int listeningCues = 0;

  @override
  Future<void> listening() async => listeningCues++;

  /// Times the "stopped" tone played.
  int stoppedCues = 0;

  @override
  Future<void> stopped() async => stoppedCues++;

  /// Times a playing tone was silenced.
  int stops = 0;

  @override
  Future<void> stop() async => stops++;
}

class FakeHaptics implements Haptics {
  /// Cues in order: `tick`, `heard`, `confirm`, `error`.
  final List<String> events = [];

  @override
  Future<void> tick() async => events.add('tick');

  @override
  Future<void> heard() async => events.add('heard');

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
  SpeechResultCallback? _onResult;
  void Function(double level)? _onSoundLevel;

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

  /// What [recognizerInfo] reports (default: nothing known, as on older
  /// Android).
  RecognizerInfo info = RecognizerInfo.unknown;

  /// Languages asked to download for offline use.
  final List<String> downloads = [];

  @override
  Future<RecognizerInfo> recognizerInfo() async => info;

  @override
  Future<bool> downloadOffline(String languageTag) async {
    downloads.add(languageTag);
    return true;
  }

  @override
  Future<void> listen(
    ListenRequest request, {
    required SpeechResultCallback onResult,
    void Function(double level)? onSoundLevel,
    void Function()? onSpeechStart,
  }) async {
    sessions.add(request);
    _onResult = onResult;
    _onSoundLevel = onSoundLevel;
    _onSpeechStart = onSpeechStart;
    listening = true;
  }

  void Function()? _onSpeechStart;

  /// The voice detector hears speech begin (the app's own recognizer).
  void speechStarts() => _onSpeechStart?.call();

  /// The microphone delivers sound at [level] (Android's rms dB scale):
  /// proves the session is really listening.
  void soundLevel([double level = 0]) => _onSoundLevel?.call(level);

  /// Ends the session the way Android really does: `done` first, the error
  /// that explains it a moment later.
  Future<void> endLikeAndroid(
    String code, {
    Duration gap = const Duration(milliseconds: 20),
  }) async {
    listening = false;
    _onStatus?.call('notListening');
    _onStatus?.call('done');
    await Future<void>.delayed(gap);
    _onError?.call(code);
  }

  /// Pause changes made during sessions.
  final List<Duration> pauseChanges = [];

  @override
  void changePauseFor(Duration pauseFor) => pauseChanges.add(pauseFor);

  /// Number of stop() calls (keep what was heard).
  int stops = 0;

  @override
  Future<void> stop() async {
    stops++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    listening = false;
    cancels++;
  }

  /// Mutes asked for (one per "listening" tone, then the guard after it).
  final List<Duration> mutes = [];

  @override
  void muteAudio(Duration duration) => mutes.add(duration);

  /// Times the app's microphone was released (before the app speaks).
  int micReleases = 0;

  @override
  Future<void> releaseMic() async => micReleases++;

  /// What [measureRoom] "hears" (empty: it can't measure).
  List<double> room = const [];

  /// Room measurements taken.
  int measurements = 0;

  @override
  Future<List<double>> measureRoom(Duration duration) async {
    measurements++;
    return room;
  }

  /// Delivers a partial result.
  void partial(String words) => _onResult!(words, false);

  /// Delivers a final result with the recognizer's other guesses.
  void hearWith(
    String words,
    List<String> alternates, {
    double confidence = 0.9,
  }) {
    listening = false;
    _onResult!(words, true, alternates: alternates, confidence: confidence);
    _onStatus?.call('done');
  }

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
    bool describeIntroSeen = true,
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
    if (describeIntroSeen) {
      // Older tests don't expect the one-time Maglarawan explanation.
      final prefs = PreferencesDao(database.db);
      for (final scope in [PreferencesDao.deviceScope, ?account?.id]) {
        await prefs.set(PrefKeys.describeIntroSeen, true, userId: scope);
      }
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

  /// Earcons played.
  final FakeEarcon earcon = FakeEarcon();

  /// Fake settings launcher.
  final FakeSystemSettings settings = FakeSystemSettings();

  /// Fake file picker.
  final FakeDocumentPicker picker = FakeDocumentPicker();

  /// Fake extractor (swap its fields to script results).
  final FakeDocumentExtractor extractor = FakeDocumentExtractor();

  /// Fake image labeler (what the picture contains).
  final FakeImageLabeler labeler = FakeImageLabeler();

  /// Fake OCR (text found in a picture).
  final FakeOcrService ocr = FakeOcrService();

  /// Fake image preparation.
  final FakeImagePrep imagePrep = FakeImagePrep();

  /// A stand-in web app with the sample books.
  final FakeAdminBookRepository books = FakeAdminBookRepository();

  /// Free space on the phone.
  final FakeStorageInfo storage = FakeStorageInfo();

  /// Where the Library keeps its files.
  final TempLibraryPaths libraryPaths = TempLibraryPaths();

  /// Reads books into text.
  final FakeBookContentLoader bookLoader = FakeBookContentLoader();

  /// Fake web app.
  final FakeDescriptionRepository describeRepo = FakeDescriptionRepository();

  /// Whether the phone is online.
  bool online = true;

  /// The web app's accounts; null (the default) keeps accounts on the phone
  /// only, as before the web app existed.
  FakeAccountApi? accountApi;

  /// The web app's report endpoint; null = no web app (reports wait).
  FakeIssueReportApi? reportApi;

  /// Fire to say the connection came back.
  final StreamController<void> connectionRestored =
      StreamController<void>.broadcast();

  /// App and phone details attached to reports (test values).
  static const IssueDetails testIssueDetails = IssueDetails(
    appVersion: '0.1.1+2',
    osVersion: 'Android 14 (SDK 34)',
    deviceModel: 'Test Tablet',
  );

  /// Developer setting: the ElevenLabs Percy instead of the self-built
  /// one (off by default, as in the app).
  bool percyElevenLabs = false;

  /// A developer build (`PERCIPERE_DEV=true`): the ElevenLabs switch and
  /// the Percy analysis panel only work in one.
  bool devBuild = false;

  /// Files handed to the share sheet (Percy log export).
  final List<String> sharedFiles = [];

  /// The voice assistant's conversation (scripted).
  final FakeAssistantPlatform assistant = FakeAssistantPlatform();

  /// The assistant's set-up; not set up unless a test gives an agent id.
  AssistantConfig assistantConfig = const AssistantConfig(
    agentId: '',
    voiceId: 'test-voice',
  );

  /// The camera the next camera screen gets.
  FakeCameraSession camera = FakeCameraSession();

  /// Provider overrides.
  List<Override> get overrides => [
    appDatabaseProvider.overrideWithValue(database),
    ttsServiceProvider.overrideWithValue(tts),
    voiceStatusProvider.overrideWith(() => VoiceStatusNotifier(tts.voices)),
    initialSettingsProvider.overrideWithValue(
      (appSettings ?? const AppSettings()).copyWith(
        navMode: mode,
        percyElevenLabs: percyElevenLabs,
      ),
    ),
    if (account != null) ...[
      initialAccountProvider.overrideWithValue(account),
      initialSettingsScopeProvider.overrideWithValue(account!.id),
    ],
    devBuildProvider.overrideWithValue(devBuild),
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
    earconProvider.overrideWithValue(earcon),
    systemSettingsProvider.overrideWithValue(settings),
    speechInputProvider.overrideWithValue(speech),
    imageLabelerProvider.overrideWithValue(labeler),
    ocrServiceProvider.overrideWithValue(ocr),
    imagePrepProvider.overrideWithValue(imagePrep),
    imageDescriptionRepositoryProvider.overrideWithValue(describeRepo),
    isOnlineProvider.overrideWithValue(() async => online),
    documentPickerProvider.overrideWithValue(picker),
    documentExtractorProvider.overrideWithValue(extractor),
    cameraSessionFactoryProvider.overrideWithValue(() => camera),
    permissionServiceProvider.overrideWithValue(permissions),
    adminBookRepositoryProvider.overrideWithValue(books),
    storageInfoProvider.overrideWithValue(storage),
    libraryPathsProvider.overrideWithValue(libraryPaths),
    bookContentLoaderProvider.overrideWithValue(bookLoader),
    assistantPlatformProvider.overrideWithValue(assistant),
    percyBrainProvider.overrideWith((ref) async => testPercyBrain()),
    percyCsvSharerProvider.overrideWithValue(
      (path) async => sharedFiles.add(path),
    ),
    assistantConfigProvider.overrideWithValue(assistantConfig),
    accountApiProvider.overrideWithValue(accountApi),
    issueReportApiProvider.overrideWithValue(reportApi),
    issueDetailsProvider.overrideWithValue(() async => testIssueDetails),
    connectionRestoredProvider.overrideWithValue(connectionRestored.stream),
    deviceLabelProvider.overrideWithValue(() async => 'Test tablet'),
  ];
}

/// The ElevenLabs conversation, scripted: records what the app sends and
/// lets a test play Percy's side ([emit]).
class FakeAssistantPlatform implements AssistantPlatform {
  final StreamController<AssistantEvent> _events =
      StreamController<AssistantEvent>.broadcast(sync: true);

  /// Options of each started conversation.
  final List<AssistantStartOptions> starts = [];

  /// Tool results sent back: (id, result, isError).
  final List<(String, String, bool)> results = [];

  /// Times the conversation was ended by the app.
  int ends = 0;

  /// Thrown by the next [start], if set.
  Object? startError;

  /// When true, [end] reports the disconnection like the real SDK.
  bool reportEnd = true;

  @override
  Stream<AssistantEvent> get events => _events.stream;

  /// Plays an event from Percy's side.
  void emit(AssistantEvent event) => _events.add(event);

  /// Percy calls tool [name]; completes with the app's answer.
  Future<(String, bool)> callTool(
    String name, [
    Map<String, Object?> parameters = const {},
  ]) async {
    final id = 'call-${results.length}-$name';
    final before = results.length;
    emit(AssistantToolCall(id: id, name: name, parameters: parameters));
    for (var i = 0; i < 400 && results.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final r = results.lastWhere((r) => r.$1 == id);
    return (r.$2, r.$3);
  }

  @override
  Future<void> start(AssistantStartOptions options) async {
    final e = startError;
    if (e != null) throw e;
    starts.add(options);
  }

  @override
  Future<void> end() async {
    ends++;
    if (reportEnd) emit(const AssistantDisconnected('user'));
  }

  @override
  Future<bool> sendToolResult(
    String id,
    String result, {
    bool isError = false,
  }) async {
    results.add((id, result, isError));
    return true;
  }

  /// Context updates sent.
  final List<String> contexts = [];

  @override
  Future<void> sendContext(String text) async => contexts.add(text);
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

  /// When set, the file picker runs this real picker instead of [nextPick]
  /// (the full path from the system picker's result to the Reader).
  DocumentPicker? real;

  @override
  Future<PickResult> pickDocument() async {
    picks++;
    return real?.pickDocument() ?? nextPick;
  }

  /// Next result of [pickImage].
  PickResult nextImage = const Picked(
    DocumentFile(path: 'picture.jpg', kind: DocumentKind.image),
  );

  /// Times the image picker was opened.
  int imagePicks = 0;

  @override
  Future<PickResult> pickImage() async {
    imagePicks++;
    return nextImage;
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

  /// When set, extraction is done by this (real) extractor instead.
  DocumentExtractor? real;

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
    final delegate = real;
    if (delegate != null) return delegate.extract(file, onPage: onPage);
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

  /// A real file to hand back from [takePicture] (default: a fake name).
  String? photoPath;

  @override
  Future<String> takePicture() async {
    pictures++;
    return photoPath ?? 'camera_$pictures.jpg';
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

/// Scripted image labels: [results] is what the picture "contains".
class FakeImageLabeler implements ImageLabelerService {
  /// What labeling returns.
  List<LabelResult> results = const [
    LabelResult('Food', 0.93),
    LabelResult('Plate', 0.88),
    LabelResult('Table', 0.81),
    LabelResult('Spoon', 0.55),
  ];

  /// Throws instead, if set.
  bool fail = false;

  /// Images labeled so far.
  final List<String> labeled = [];

  @override
  Future<List<LabelResult>> label(String path) async {
    labeled.add(path);
    if (fail) throw StateError('cannot open image');
    return results;
  }

  @override
  Future<void> close() async {}
}

/// Scripted OCR: [page] is the text "found" in any image.
class FakeOcrService implements OcrService {
  /// What recognition returns.
  OcrPage page = const OcrPage(text: '');

  @override
  Future<OcrPage> recognizeFile(String path) async => page;

  @override
  Future<void> close() async {}
}

/// Image preparation without files or isolates.
class FakeImagePrep implements ImagePrep {
  /// Images prepared for upload.
  int uploads = 0;

  /// Makes [saveThumbnail] fail.
  bool failThumbnail = false;

  /// Thumbnails saved.
  int thumbnails = 0;

  @override
  Future<Uint8List?> forUpload(String path) async {
    uploads++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<String?> saveThumbnail(String path) async {
    if (failThumbnail) throw StateError('disk full');
    thumbnails++;
    return 'thumbs/thumb_$thumbnails.jpg';
  }
}

/// Scripted web app: records each request.
class FakeDescriptionRepository implements ImageDescriptionRepository {
  /// What the server answers.
  DescriptionResult result = const DescriptionResult(
    description: 'Mukhang isang mesa na may pagkain.',
    hasText: false,
  );

  /// Fails instead, if set.
  bool fail = false;

  /// Languages of the requests.
  final List<String> languages = [];

  /// User ids of the requests (null = anonymous guest).
  final List<String?> userIds = [];

  @override
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    String? userId,
  }) async {
    languages.add(language);
    userIds.add(userId);
    if (fail) throw const DescriptionException('offline');
    return result;
  }
}

/// Free space on the phone, set by the test.
class FakeStorageInfo implements StorageInfo {
  /// Free bytes reported (null = unknown).
  int? free = 10 * 1024 * 1024 * 1024;

  @override
  Future<int?> freeBytes() async => free;
}

/// The Library's folders in a temporary directory (created at once, so no
/// directory work happens inside a widget test's fake-async zone).
class TempLibraryPaths implements LibraryPaths {
  /// Creates the folders.
  TempLibraryPaths() : root = Directory.systemTemp.createTempSync('percipere_');

  /// Base directory.
  final Directory root;

  Directory _dir(String name) =>
      Directory('${root.path}/$name')..createSync(recursive: true);

  @override
  Future<Directory> books() async => _dir('books');

  @override
  Future<Directory> texts() async => _dir('texts');

  @override
  Future<Directory> covers() async => _dir('covers');

  @override
  Future<Directory> cache() async => _dir('cache');
}

/// Reads sample EPUBs for real (without an isolate) and gives scripted text
/// for PDFs, which need the native PDF engine.
class FakeBookContentLoader implements BookContentLoader {
  /// When set, every load throws this.
  BookReadProblem? problem;

  /// Files loaded.
  final List<String> loaded = [];

  @override
  Future<LoadedBook> load(
    String path,
    LibraryFormat format, {
    required String Function(int number) chapterTitle,
    void Function(int page, int pageCount)? onPage,
  }) async {
    loaded.add(path);
    if (problem != null) throw BookReadException(problem!);
    if (format == LibraryFormat.epub) {
      final book = EpubParser.parse(
        File(path).readAsBytesSync(),
        fallbackTitle: chapterTitle,
      );
      return LoadedBook(book.text, title: book.title, author: book.author);
    }
    final chapters = path.contains('bk-crow')
        ? [SampleBooks.kindness[1]]
        : SampleBooks.hare;
    return LoadedBook(
      BookText([
        for (final c in chapters)
          ChapterText(c.title, c.paragraphs.join('\n\n')),
      ]),
    );
  }
}

PercyBrain? _percyBrain;

/// Percy's real bundled model and lines, read once from the project files
/// (no asset bundle or isolate needed in tests).
PercyBrain testPercyBrain() => _percyBrain ??= PercyBrain(
  IntentClassifier.parse(File(PercyConfig.modelAsset).readAsStringSync()),
  PercyResponses.parse(
    File(PercyConfig.personaAsset).readAsStringSync(),
    File(PercyConfig.responsesAsset).readAsStringSync(),
    random: math.Random(7),
  ),
  KnowledgeBase.parse(File(PercyConfig.knowledgeAsset).readAsStringSync()),
);

/// One account in [FakeAccountApi].
class FakeServerAccount {
  /// Creates an account.
  FakeServerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.status = 'active',
  });

  /// `app_users.user_id`.
  final int id;

  /// Full name.
  String fullName;

  /// Email.
  final String email;

  /// Password (test values only).
  String password;

  /// `pending_approval`, `active`, `suspended`.
  String status;
}

/// The web app's accounts (the dashboard's `api/v1/`), in memory, with the
/// same rules: statuses and tokens (no emailed codes, no password reset).
class FakeAccountApi implements AccountApi {
  /// Accounts by email.
  final Map<String, FakeServerAccount> accounts = {};

  /// Live tokens → account email.
  final Map<String, String> tokens = {};

  /// Every call, by name ("login", "register", …).
  final List<String> calls = [];

  /// Tokens ended by logout.
  final List<String> loggedOut = [];

  /// No connection: every call fails with [AccountApiError.offline].
  bool offline = false;

  /// New accounts wait for an administrator (`pending_approval`).
  bool approval = false;

  int _nextId = 1;
  int _nextToken = 1;

  /// Adds an account directly (as if registered before).
  FakeServerAccount add({
    required String email,
    required String password,
    String fullName = 'Ana Cruz',
    String status = 'active',
  }) => accounts[email] = FakeServerAccount(
    id: _nextId++,
    fullName: fullName,
    email: email,
    password: password,
    status: status,
  );

  void _call(String name) {
    calls.add(name);
    if (offline) throw const AccountApiException(AccountApiError.offline);
  }

  static Never _fail(AccountApiError error) => throw AccountApiException(error);

  ServerUser _user(FakeServerAccount a) => ServerUser(
    id: '${a.id}',
    fullName: a.fullName,
    email: a.email,
    status: a.status,
  );

  ServerSession _session(FakeServerAccount a) {
    final token = 'token-${_nextToken++}';
    tokens[token] = a.email;
    return ServerSession(token: token, user: _user(a));
  }

  @override
  Future<RegisterStatus> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _call('register');
    if (accounts.containsKey(email)) _fail(AccountApiError.emailTaken);
    final a = add(
      email: email,
      password: password,
      fullName: fullName,
      status: approval ? 'pending_approval' : 'active',
    );
    return a.status == 'active'
        ? RegisterStatus.active
        : RegisterStatus.pendingApproval;
  }

  @override
  Future<ServerSession> login({
    required String email,
    required String password,
    required String device,
  }) async {
    _call('login');
    final a = accounts[email];
    if (a == null || a.password != password) {
      _fail(AccountApiError.invalidCredentials);
    }
    switch (a.status) {
      case 'pending_approval':
        _fail(AccountApiError.pendingApproval);
      case 'suspended':
        _fail(AccountApiError.accountSuspended);
    }
    return _session(a);
  }

  @override
  Future<ServerUser> me(String token) async {
    _call('me');
    final a = accounts[tokens[token]];
    if (a == null) _fail(AccountApiError.unauthorized);
    if (a.status == 'suspended') _fail(AccountApiError.accountSuspended);
    if (a.status != 'active') _fail(AccountApiError.unauthorized);
    return _user(a);
  }

  @override
  Future<void> logout(String token) async {
    _call('logout');
    if (tokens.remove(token) == null) _fail(AccountApiError.unauthorized);
    loggedOut.add(token);
  }
}

/// The web app's report endpoint, in memory: stores each ticket once.
class FakeIssueReportApi implements IssueReportApi {
  /// Received reports by ticket (JSON body as sent).
  final Map<String, Map<String, Object?>> received = {};

  /// Tokens sent with each ticket.
  final Map<String, String?> tokens = {};

  /// No connection: every send fails and may be retried.
  bool offline = false;

  /// The web app refuses every report (e.g. 422).
  bool refuse = false;

  /// Sends tried.
  int calls = 0;

  @override
  Future<IssueReceipt> send(IssueReport report, {String? token}) async {
    calls++;
    if (offline) {
      throw const IssueSendException('connectionError', refused: false);
    }
    if (refuse) {
      throw const IssueSendException('validation_failed', refused: true);
    }
    final body = report.toJson();
    received.putIfAbsent(report.ticketNo, () => body);
    tokens[report.ticketNo] = token;
    final id = received.keys.toList().indexOf(report.ticketNo) + 100;
    return IssueReceipt(serverId: '$id', status: 'open');
  }

  /// What the dashboard says per ticket (default `open` once received).
  final Map<String, ServerReportStatus> statuses = {};

  /// Status questions asked.
  int statusCalls = 0;

  @override
  Future<ServerReportStatus?> status(String ticketNo) async {
    statusCalls++;
    if (offline || !received.containsKey(ticketNo)) return null;
    return statuses[ticketNo] ?? ServerReportStatus.open;
  }
}
