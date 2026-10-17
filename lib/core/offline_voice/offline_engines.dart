import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'command_recognizer.dart';
import 'model_catalog.dart';
import 'model_store.dart';
import 'offline_listener.dart';
import 'offline_speaker.dart';

/// The app's own offline engines once their models are installed: the
/// command listener (sherpa-onnx Whisper + Silero VAD) and the Tagalog and
/// English voices (sherpa-onnx VITS). Loaded at startup when the models are
/// already on the tablet, or right after the first download.
class OfflineEngines {
  /// Creates the holder. [mic] and [player] are for tests.
  OfflineEngines({MicStream? mic, PcmPlayer? player})
    : _mic = mic, // ignore: prefer_initializing_formals
      _player = player ?? const ChannelPcmPlayer();

  final MicStream? _mic;
  final PcmPlayer _player;

  CommandRecognizer? _recognizer;
  OfflineCommandListener? _listener;
  OfflineVoice? _speaker;
  Future<void>? _loading;
  Future<void>? _voicesLoading;
  Set<String> _voiceFiles = const {};

  /// Called when an engine finished loading (or was unloaded).
  final ValueNotifier<int> changes = ValueNotifier(0);

  /// The offline command listener, when loaded.
  OfflineCommandListener? get listener => _listener;

  /// The offline voices, when loaded.
  OfflineVoice? get speaker => _speaker;

  /// Puts test doubles in place of the loaded engines.
  @visibleForTesting
  void debugUse({
    OfflineCommandListener? listener,
    OfflineVoice? speaker,
    Set<String>? voices,
  }) {
    _listener = listener ?? _listener;
    _speaker = speaker ?? _speaker;
    _voiceFiles = voices ?? _voiceFiles;
    changes.value++;
  }

  /// Offline commands work now.
  bool get commandsReady => _listener != null;

  /// Languages (`fil`, `en`) whose offline voice is installed — known
  /// before the voices have finished loading.
  Set<String> get voiceLanguages => _voiceFiles;

  /// Waits for loading in progress, if any.
  Future<void> get loaded => _loading ?? Future.value();

  /// Loads in progress (voices or the command recognizer).
  int _pendingLoads = 0;

  /// Whether an engine is being loaded now (heavy work: voice input is
  /// busy, not broken, meanwhile).
  bool get loading => _pendingLoads > 0;

  /// Waits until the voices are loaded (not the command recognizer, which
  /// loads after them).
  Future<void> get voicesLoaded => _voicesLoading ?? loaded;

  /// Loads the engines whose models are installed in [store] (and not
  /// loaded yet). Safe to call again; callers share one load.
  Future<void> load(ModelStore store) {
    // Known at once (prompts can be Filipino before the voice has loaded).
    _voiceFiles = _installedVoices(store);
    final previous = _loading ?? Future<void>.value();
    _pendingLoads++;
    return _loading = previous
        .then((_) => _load(store))
        .whenComplete(() => _pendingLoads--);
  }

  static Set<String> _installedVoices(ModelStore store) {
    final installed = store.installedAll();
    return {
      if (OfflineVoiceFiles.usable(
        installed[OfflineModelCatalog.filipinoVoiceName]?.dir,
      ))
        'fil',
      if (OfflineVoiceFiles.usable(
        installed[OfflineModelCatalog.englishVoiceName]?.dir,
      ))
        'en',
    };
  }

  Future<void> _load(ModelStore store) async {
    store.repairTokens();
    final installed = store.installedAll();
    _voiceFiles = _installedVoices(store);
    // The voices first: the next prompt may be waiting for them.
    final voices = _voicesLoading = _guarded(
      store,
      'voices',
      [
        ?installed[OfflineModelCatalog.filipinoVoiceName],
        ?installed[OfflineModelCatalog.englishVoiceName],
      ],
      () => _loadVoices(installed),
    );
    await voices;
    _voiceFiles = _installedVoices(store);
    await _guarded(
      store,
      'commands',
      [?installed[OfflineModelCatalog.commandsName]],
      () => _loadCommands(installed),
    );
  }

  /// Runs [load] inside the store's crash guard (see
  /// [ModelStore.beginLoad]).
  Future<void> _guarded(
    ModelStore store,
    String engine,
    List<InstalledModel> models,
    Future<void> Function() load,
  ) async {
    if (models.isEmpty) return;
    if (!store.beginLoad(engine, models)) {
      changes.value++;
      return;
    }
    try {
      await load();
    } finally {
      store.endLoad(engine);
    }
  }

  Future<void> _loadVoices(Map<String, InstalledModel> installed) async {
    final tagalog = installed[OfflineModelCatalog.filipinoVoiceName]?.dir;
    final english = installed[OfflineModelCatalog.englishVoiceName]?.dir;
    final speaker = _speaker;
    final wanted = _voiceFiles;
    final old = speaker is OfflineSpeaker ? speaker : null;
    final missingVoice =
        speaker == null || wanted.any((lang) => !speaker.speaks(lang));
    if (wanted.isEmpty || !missingVoice) return;
    final watch = Stopwatch()..start();
    final fresh = await OfflineSpeaker.start(
      OfflineVoiceFiles(tagalogDir: tagalog, englishDir: english),
      player: _player,
    );
    if (fresh == null) return;
    await old?.dispose();
    _speaker = fresh;
    debugPrint('[OFFLINE VOICE] voices ready in ${watch.elapsedMilliseconds}ms');
    changes.value++;
  }

  Future<void> _loadCommands(Map<String, InstalledModel> installed) async {
    final commands = installed[OfflineModelCatalog.commandsName]?.dir;
    if (_recognizer != null || commands == null) return;
    final watch = Stopwatch()..start();
    final recognizer = await CommandRecognizer.start(RecognizerFiles(commands));
    if (recognizer == null) return;
    _recognizer = recognizer;
    _listener = OfflineCommandListener(
      SherpaRecognizerPort(recognizer),
      _mic ?? ChannelMicStream(),
    );
    debugPrint(
      '[OFFLINE VOICE] commands ready in ${watch.elapsedMilliseconds}ms',
    );
    changes.value++;
  }

  /// Frees the engines (before their files are deleted).
  Future<void> unload() async {
    await loaded.catchError((Object _) {});
    _loading = null;
    _voicesLoading = null;
    final listener = _listener;
    final recognizer = _recognizer;
    final speaker = _speaker;
    _listener = null;
    _recognizer = null;
    _speaker = null;
    _voiceFiles = const {};
    await listener?.dispose();
    await recognizer?.dispose();
    if (speaker is OfflineSpeaker) await speaker.dispose();
    changes.value++;
  }
}

/// The app's offline engines (one per app run).
final offlineEnginesProvider = Provider<OfflineEngines>(
  (ref) => OfflineEngines(),
);

/// Where the models are kept; null when unknown (tests). Set by
/// `bootstrap()`.
final modelStoreProvider = Provider<ModelStore?>((ref) => null);
