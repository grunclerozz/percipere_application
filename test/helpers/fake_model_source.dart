import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:percipere_app/core/offline_voice/model_catalog.dart';
import 'package:percipere_app/core/offline_voice/model_installer.dart';

/// A model archive (`.tar.gz`) holding [files].
List<int> archiveOf(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    archive.addFile(ArchiveFile.bytes(key, utf8.encode(value)));
  }
  return const GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

/// Serves archives by URL; scripts failures, damaged bytes and servers that
/// ignore HTTP Range.
class FakeModelSource implements ModelSource {
  FakeModelSource(this.files, {this.models = const []});

  final Map<String, List<int>> files;
  final List<OfflineModel> models;

  /// Every fetch: url and the bytes the part already had.
  final List<(String, int)> fetches = [];

  /// Fail this many fetches with a connection error first.
  int connectionErrors = 0;

  /// Stop after this many bytes on the next fetch (an interrupted download).
  int? cutAfter;

  /// After the cut, the network stays gone (every fetch fails).
  bool offlineAfterCut = false;

  /// Send damaged bytes for these URLs.
  final Set<String> damaged = {};

  /// Ignore Range (always send the whole file).
  bool ignoreRange = false;

  @override
  Future<List<OfflineModel>> manifest() async => models;

  @override
  Future<void> fetch(
    String url,
    File part, {
    void Function(int length)? onBytes,
    CancelToken? cancel,
  }) async {
    final have = part.existsSync() ? part.lengthSync() : 0;
    fetches.add((url, have));
    if (connectionErrors > 0) {
      connectionErrors--;
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.connectionError,
      );
    }
    var body = files[url];
    if (body == null) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(path: url), statusCode: 404),
      );
    }
    if (damaged.contains(url)) {
      body = [...body]..[body.length ~/ 2] ^= 0xff;
    }
    final resume = have > 0 && !ignoreRange;
    final send = resume ? body.sublist(have) : body;
    final cut = cutAfter;
    cutAfter = null;
    await part.parent.create(recursive: true);
    final sink = part.openWrite(mode: resume ? FileMode.append : FileMode.write);
    if (cut != null && cut < send.length) {
      sink.add(send.sublist(0, cut));
      await sink.close();
      if (offlineAfterCut) connectionErrors = 1 << 20;
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.connectionError,
      );
    }
    sink.add(send);
    await sink.close();
    onBytes?.call(part.lengthSync());
  }
}

OfflineModel modelFor(String name, List<int> bytes, {String? fallback}) =>
    OfflineModel(
      name: name,
      version: '1',
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      url: 'https://server/models/$name.tar.gz',
      fallbackUrl: fallback,
    );

