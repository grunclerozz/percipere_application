import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity.dart';
import '../network/server_address.dart';
import '../platform/storage_info.dart';
import '../tts/tts_service.dart';
import 'model_catalog.dart';
import 'model_installer.dart';
import 'model_store.dart';
import 'offline_engines.dart';

/// Where the offline model download stands.
enum OfflineVoiceStatus {
  /// Not checked yet (or the models were deleted).
  idle,

  /// Reading the model list.
  checking,

  /// Downloading (and unpacking) models.
  downloading,

  /// Every model is installed.
  ready,

  /// No internet: continues when it comes back.
  waitingForInternet,

  /// Not enough free space.
  lowStorage,

  /// Downloads kept failing; tried again when the connection changes or the
  /// user asks.
  failed,

  /// No model folder (tests, or storage unavailable).
  unavailable,
}

/// The download's state, for the first-launch screen and Voice check.
@immutable
class OfflineVoiceState {
  /// Creates a state.
  const OfflineVoiceState({
    this.status = OfflineVoiceStatus.idle,
    this.received = 0,
    this.total = 0,
    this.installed = const {},
    this.neededBytes,
  });

  /// Where it stands.
  final OfflineVoiceStatus status;

  /// Bytes downloaded in this run.
  final int received;

  /// Bytes to download in this run (0 until known).
  final int total;

  /// What is installed.
  final Map<String, InstalledModel> installed;

  /// Free space needed (low storage).
  final int? neededBytes;

  /// Whole percent downloaded (0..100).
  int get percent =>
      total <= 0 ? 0 : (received * 100 / total).floor().clamp(0, 100);

  /// Every model is installed.
  bool get complete => OfflineModelCatalog.names.every(installed.containsKey);

  /// Megabytes to download, rounded up (for "Mga 68 MB").
  int get totalMegabytes => (total / 1000000).ceil();

  /// Copy with changes.
  OfflineVoiceState copyWith({
    OfflineVoiceStatus? status,
    int? received,
    int? total,
    Map<String, InstalledModel>? installed,
    int? neededBytes,
  }) => OfflineVoiceState(
    status: status ?? this.status,
    received: received ?? this.received,
    total: total ?? this.total,
    installed: installed ?? this.installed,
    neededBytes: neededBytes ?? this.neededBytes,
  );
}

/// Downloads the offline models once (first launch), resumes when the
/// internet comes back, and loads the engines when they are in place.
/// Settings → Voice check can download them again or delete them.
class OfflineVoiceController extends Notifier<OfflineVoiceState> {
  Future<InstallResult?>? _running;
  CancelToken? _cancel;
  StreamSubscription<void>? _connection;

  /// Builds the installer (tests override [installerFor]).
  @visibleForTesting
  static ModelInstaller Function(Ref ref, ModelStore store) installerFor =
      (ref, store) => ModelInstaller(
        source: HttpModelSource(ref.read(serverAddressProvider)),
        store: store,
        freeBytes: () => ref.read(storageInfoProvider).freeBytes(),
      );

  @override
  OfflineVoiceState build() {
    final store = ref.read(modelStoreProvider);
    try {
      _connection = ref
          .read(connectionRestoredProvider)
          .listen((_) => _connectionBack(), onError: (Object _) {});
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] connection changes unavailable: $e');
    }
    ref.onDispose(() {
      _cancel?.cancel();
      unawaited(_connection?.cancel());
    });
    if (store == null) {
      return const OfflineVoiceState(status: OfflineVoiceStatus.unavailable);
    }
    final installed = store.installedAll();
    final state = OfflineVoiceState(installed: installed);
    return state.complete
        ? state.copyWith(status: OfflineVoiceStatus.ready)
        : state;
  }

  void _connectionBack() {
    if (!ref.mounted) return;
    if (state.status == OfflineVoiceStatus.waitingForInternet ||
        state.status == OfflineVoiceStatus.failed) {
      debugPrint('[OFFLINE VOICE] internet back: resuming the download');
      unawaited(ensure());
    }
  }

  /// Downloads whatever is missing (one run at a time; callers share it).
  /// Returns the result, or null when nothing could be done.
  Future<InstallResult?> ensure() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<InstallResult?> _run() async {
    final store = ref.read(modelStoreProvider);
    if (store == null) return null;
    state = state.copyWith(status: OfflineVoiceStatus.checking);
    var online = true;
    try {
      online = await ref.read(isOnlineProvider)();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] network check failed: $e');
    }
    if (!ref.mounted) return null;
    final installer = installerFor(ref, store);
    if (!online) {
      // Everything is here: only a check for updates was skipped.
      if (state.complete) {
        state = state.copyWith(status: OfflineVoiceStatus.ready);
        return InstallResult(installed: state.installed);
      }
      state = state.copyWith(status: OfflineVoiceStatus.waitingForInternet);
      return const InstallResult(problem: InstallProblem.offline);
    }
    final models = await installer.source.manifest();
    if (!ref.mounted) return null;
    final todo = installer.missing(models);
    final cancel = _cancel = CancelToken();
    state = state.copyWith(
      status: todo.isEmpty
          ? OfflineVoiceStatus.ready
          : OfflineVoiceStatus.downloading,
      received: 0,
      total: installer.remainingBytes(todo),
    );
    var lastPercent = -1;
    final result = await installer.installAll(
      models,
      cancel: cancel,
      onProgress: (received, total) {
        if (!ref.mounted) return;
        final percent = total <= 0 ? 0 : received * 100 ~/ total;
        if (percent == lastPercent) return;
        lastPercent = percent;
        state = state.copyWith(received: received, total: total);
      },
    );
    if (!ref.mounted) return result;
    if (identical(_cancel, cancel)) _cancel = null;
    state = state.copyWith(
      installed: result.installed,
      neededBytes: result.needed,
      status: switch (result.problem) {
        null => OfflineVoiceStatus.ready,
        InstallProblem.offline => OfflineVoiceStatus.waitingForInternet,
        InstallProblem.lowStorage => OfflineVoiceStatus.lowStorage,
        InstallProblem.failed => OfflineVoiceStatus.failed,
        InstallProblem.cancelled => OfflineVoiceStatus.idle,
      },
    );
    if (result.installed.isNotEmpty) await _loadEngines(store);
    return result;
  }

  Future<void> _loadEngines(ModelStore store) async {
    try {
      await ref.read(offlineEnginesProvider).load(store);
      if (!ref.mounted) return;
      // Prompts can now be Filipino even without a Filipino voice from
      // Google.
      await ref.read(voiceStatusProvider.notifier).refresh();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] loading the engines failed: $e');
    }
  }

  /// Deletes every model (the engines are stopped first).
  Future<void> deleteAll() async {
    final store = ref.read(modelStoreProvider);
    if (store == null) return;
    _cancel?.cancel();
    await _running?.catchError((Object _) => null);
    await ref.read(offlineEnginesProvider).unload();
    try {
      await store.deleteAll();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] delete failed: $e');
    }
    if (!ref.mounted) return;
    state = OfflineVoiceState(installed: store.installedAll());
    await ref.read(voiceStatusProvider.notifier).refresh();
  }

  /// Deletes the models and downloads them again (also files that were
  /// marked broken).
  Future<InstallResult?> redownload() async {
    await deleteAll();
    if (!ref.mounted) return null;
    return ensure();
  }
}

/// True when the first-launch download screen should open at startup (the
/// models are missing and it wasn't shown on this tablet yet). Set by
/// `bootstrap()`.
final offlineVoiceSetupPendingProvider = Provider<bool>((ref) => false);

/// The offline model download.
final offlineVoiceProvider =
    NotifierProvider<OfflineVoiceController, OfflineVoiceState>(
      OfflineVoiceController.new,
    );
