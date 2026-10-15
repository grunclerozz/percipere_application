import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_dio.dart';
import 'model_catalog.dart';
import 'model_store.dart';

/// Why the models could not be installed.
enum InstallProblem {
  /// No network (or the servers can't be reached).
  offline,

  /// Not enough free space.
  lowStorage,

  /// Downloads kept failing or the files were damaged.
  failed,

  /// Stopped on purpose (delete, re-download).
  cancelled,
}

/// The result of [ModelInstaller.installAll].
@immutable
class InstallResult {
  /// Creates a result.
  const InstallResult({this.problem, this.installed = const {}, this.needed});

  /// Null when every model is installed.
  final InstallProblem? problem;

  /// What is installed now.
  final Map<String, InstalledModel> installed;

  /// Bytes of free space needed (low storage).
  final int? needed;

  /// Everything is in place.
  bool get ok => problem == null;
}

/// The network side of model downloads. Abstract so tests can script it.
abstract interface class ModelSource {
  /// The model list: the dashboard's `GET /api/v1/models`, else its
  /// `models/manifest.json`, else the list built into the app.
  Future<List<OfflineModel>> manifest();

  /// Downloads [url] into [part], continuing after the [part]'s current
  /// bytes when the server allows it (HTTP Range); otherwise starts over.
  /// [onBytes] gets the file's total length so far. Throws on failure.
  Future<void> fetch(
    String url,
    File part, {
    void Function(int length)? onBytes,
    CancelToken? cancel,
  });
}

/// [ModelSource] over HTTP (dio, with the app's cleartext guard).
class HttpModelSource implements ModelSource {
  /// Creates the source for the dashboard at [baseUrl] (may be empty: the
  /// built-in list is used then).
  HttpModelSource(this.baseUrl, {Dio? dio})
    : _dio =
          dio ??
          apiDio(
            connect: const Duration(seconds: 15),
            receive: const Duration(seconds: 60),
          );

  /// The dashboard's address, without `/api/v1`.
  final String baseUrl;
  final Dio _dio;

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<List<OfflineModel>> manifest() async {
    if (_root.isNotEmpty) {
      for (final path in ['/api/v1/models', '/models/manifest.json']) {
        try {
          final response = await _dio.get<dynamic>(
            '$_root$path',
            options: Options(
              responseType: ResponseType.json,
              validateStatus: (_) => true,
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
          if (response.statusCode == 200) {
            final models = OfflineModelCatalog.parse(
              response.data,
              base: _root,
            );
            if (models.isNotEmpty) {
              debugPrint('[OFFLINE VOICE] model list from $path');
              return _complete(models);
            }
          }
        } on DioException catch (e) {
          debugPrint('[OFFLINE VOICE] $path unreachable: ${e.type}');
        } on Object catch (e) {
          debugPrint('[OFFLINE VOICE] $path failed: $e');
        }
      }
    }
    debugPrint('[OFFLINE VOICE] using the built-in model list (GitHub)');
    return OfflineModelCatalog.builtIn;
  }

  /// The server's list, with any model it lacks taken from the built-in
  /// list.
  static List<OfflineModel> _complete(List<OfflineModel> fromServer) => [
    for (final name in OfflineModelCatalog.names)
      fromServer.where((m) => m.name == name).firstOrNull ??
          OfflineModelCatalog.builtIn.firstWhere((m) => m.name == name),
  ];

  @override
  Future<void> fetch(
    String url,
    File part, {
    void Function(int length)? onBytes,
    CancelToken? cancel,
  }) async {
    await part.parent.create(recursive: true);
    final have = part.existsSync() ? part.lengthSync() : 0;
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 60),
        headers: {if (have > 0) HttpHeaders.rangeHeader: 'bytes=$have-'},
        validateStatus: (s) => s == 200 || s == 206 || s == 416,
      ),
    );
    final status = response.statusCode;
    if (status == 416) {
      // Nothing left to send: the part is already whole (or too long, which
      // the checksum will catch).
      onBytes?.call(have);
      return;
    }
    final resume = status == 206 && have > 0;
    final sink = part.openWrite(mode: resume ? FileMode.append : FileMode.write);
    var length = resume ? have : 0;
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        length += chunk.length;
        onBytes?.call(length);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }
}

/// Downloads, verifies and unpacks the offline models: resumable (a
/// stopped download continues where it was), SHA-256 checked, with free
/// space checked first and a few retries (the dashboard, then the GitHub
/// copy).
class ModelInstaller {
  /// Creates the installer.
  ModelInstaller({
    required this.source,
    required this.store,
    required this.freeBytes,
    this.attempts = 4,
    Duration Function(int attempt)? backoff,
  }) : _backoff = backoff ?? _defaultBackoff;

  /// Where the files come from.
  final ModelSource source;

  /// Where they go.
  final ModelStore store;

  /// Free space on the tablet (null: unknown).
  final Future<int?> Function() freeBytes;

  /// Tries per model before giving up.
  final int attempts;

  final Duration Function(int attempt) _backoff;

  /// Spare room left free after the install.
  static const int spareBytes = 20 * 1024 * 1024;

  static Duration _defaultBackoff(int attempt) =>
      Duration(seconds: const [2, 5, 10, 20][(attempt - 1).clamp(0, 3)]);

  /// The models from [list] to download: not installed, or installed in
  /// an older version (or the same version from another file). A list
  /// with an older version (the built-in one, when the server is out of
  /// reach) never replaces a newer install.
  List<OfflineModel> missing(List<OfflineModel> list) => [
    for (final m in list)
      if (_needs(m)) m,
  ];

  bool _needs(OfflineModel model) {
    final have = store.installed(model.name);
    if (have == null) return true;
    final order = OfflineModelCatalog.compareVersions(
      model.version,
      have.version,
    );
    return order > 0 || (order == 0 && !have.matches(model));
  }

  /// Bytes still to download for [models].
  int remainingBytes(List<OfflineModel> models) => models.fold(
    0,
    (sum, m) => sum + (m.size - store.partialBytes(m)).clamp(0, m.size),
  );

  /// Installs every model of [models] that is missing. [onProgress] gets
  /// the bytes downloaded and the total for this run.
  Future<InstallResult> installAll(
    List<OfflineModel> models, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    final todo = missing(models);
    if (todo.isEmpty) return InstallResult(installed: store.installedAll());

    final needed = todo.fold<int>(
      spareBytes,
      (sum, m) => sum + m.spaceNeeded - store.partialBytes(m),
    );
    final free = await freeBytes();
    if (free != null && free < needed) {
      return InstallResult(
        problem: InstallProblem.lowStorage,
        installed: store.installedAll(),
        needed: needed,
      );
    }

    final total = todo.fold<int>(0, (sum, m) => sum + m.size);
    var doneBefore = 0;
    for (final model in todo) {
      final problem = await _installOne(
        model,
        cancel: cancel,
        onBytes: (length) => onProgress?.call(doneBefore + length, total),
      );
      if (problem != null) {
        return InstallResult(problem: problem, installed: store.installedAll());
      }
      doneBefore += model.size;
      onProgress?.call(doneBefore, total);
    }
    return InstallResult(installed: store.installedAll());
  }

  Future<InstallProblem?> _installOne(
    OfflineModel model, {
    required void Function(int length) onBytes,
    CancelToken? cancel,
  }) async {
    if (store.broken().contains(model.sha256)) {
      // This very file ended the app while loading: not again.
      debugPrint('[OFFLINE VOICE] ${model.name}: marked broken, skipped');
      return InstallProblem.failed;
    }
    final part = store.partOf(model);
    var networkFailures = 0;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (cancel?.isCancelled ?? false) return InstallProblem.cancelled;
      // The dashboard first, then the GitHub copy, then again.
      final fallback = model.fallbackUrl;
      final url = attempt.isEven && fallback != null ? fallback : model.url;
      try {
        if (!part.existsSync() || part.lengthSync() < model.size) {
          debugPrint(
            '[OFFLINE VOICE] ${model.name}: download from $url '
            '(have ${part.existsSync() ? part.lengthSync() : 0} of '
            '${model.size}, attempt $attempt)',
          );
          await source.fetch(url, part, onBytes: onBytes, cancel: cancel);
        }
        final length = part.lengthSync();
        if (length == model.size &&
            await ModelStore.hashOf(part) == model.sha256) {
          await store.install(model, part);
          debugPrint('[OFFLINE VOICE] ${model.name} ${model.version} installed');
          return null;
        }
        debugPrint(
          '[OFFLINE VOICE] ${model.name}: damaged download '
          '($length bytes): starting over',
        );
        await _remove(part);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return InstallProblem.cancelled;
        debugPrint('[OFFLINE VOICE] ${model.name}: ${e.type} ${e.message}');
        final network =
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout;
        if (network) networkFailures++;
        if (e.response?.statusCode == 404 && attempt.isEven) {
          // Neither copy has this file.
          await _remove(part);
        }
      } on FileSystemException catch (e) {
        debugPrint('[OFFLINE VOICE] ${model.name}: file error $e');
        await _remove(part);
        return InstallProblem.failed;
      } on Object catch (e) {
        debugPrint('[OFFLINE VOICE] ${model.name}: $e');
      }
      if (attempt < attempts) {
        await Future<void>.delayed(_backoff(attempt));
      }
    }
    return networkFailures == attempts
        ? InstallProblem.offline
        : InstallProblem.failed;
  }

  static Future<void> _remove(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] could not delete ${f.path}: $e');
    }
  }
}
