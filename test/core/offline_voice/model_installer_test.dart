import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/offline_voice/model_catalog.dart';
import 'package:percipere_app/core/offline_voice/model_installer.dart';
import 'package:percipere_app/core/offline_voice/model_store.dart';

import '../../helpers/fake_model_source.dart';

void main() {
  late Directory dir;
  late ModelStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('models');
    store = ModelStore(dir.path);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ModelInstaller installer(FakeModelSource source, {int? free}) =>
      ModelInstaller(
        source: source,
        store: store,
        freeBytes: () async => free,
        backoff: (_) => Duration.zero,
      );

  final commands = archiveOf({
    'encoder.onnx': 'enc',
    'decoder.onnx': 'dec',
    'tokens.txt': 'a 0',
    'silero_vad.onnx': 'vad',
  });
  final voice = archiveOf({'model.onnx': 'tgl', 'tokens.txt': 'a 0'});

  test('downloads, verifies and unpacks every model', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final b = modelFor(OfflineModelCatalog.filipinoVoiceName, voice);
    final source = FakeModelSource({a.url: commands, b.url: voice});
    final progress = <int>[];
    final result = await installer(source).installAll(
      [a, b],
      onProgress: (received, total) => progress.add(received),
    );
    expect(result.ok, isTrue);
    expect(result.installed.keys, containsAll([a.name, b.name]));
    final dirA = store.installed(a.name)!.dir;
    expect(File('$dirA/encoder.onnx').readAsStringSync(), 'enc');
    expect(store.installed(a.name)!.matches(a), isTrue);
    // The archive is removed once unpacked.
    expect(store.partOf(a).existsSync(), isFalse);
    expect(progress.last, a.size + b.size);
  });

  test('an installed model of the same file is not downloaded again',
      () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands});
    await installer(source).installAll([a]);
    source.fetches.clear();
    final again = await installer(source).installAll([a]);
    expect(again.ok, isTrue);
    expect(source.fetches, isEmpty);
  });

  test('an interrupted download resumes where it stopped', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands})..cutAfter = 40;
    final result = await installer(source).installAll([a]);
    expect(result.ok, isTrue);
    expect(source.fetches, hasLength(2));
    expect(source.fetches[1].$2, 40, reason: 'continued from byte 40');
  });

  test('a server that ignores Range still gives a whole file', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands})
      ..cutAfter = 40
      ..ignoreRange = true;
    final result = await installer(source).installAll([a]);
    expect(result.ok, isTrue);
  });

  test('a damaged file is downloaded again from the GitHub copy', () async {
    const github = 'https://github.com/x/releases/download/v1/c.tar.gz';
    final a = modelFor(
      OfflineModelCatalog.commandsName,
      commands,
      fallback: github,
    );
    final source = FakeModelSource({a.url: commands, github: commands})
      ..damaged.add(a.url);
    final result = await installer(source).installAll([a]);
    expect(result.ok, isTrue);
    expect(source.fetches.map((f) => f.$1), [a.url, github]);
  });

  test('a file that is always damaged fails and leaves no part behind',
      () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands})..damaged.add(a.url);
    final result = await installer(source).installAll([a]);
    expect(result.problem, InstallProblem.failed);
    expect(store.partOf(a).existsSync(), isFalse);
    expect(store.installed(a.name), isNull);
  });

  test('no network: offline, and the part is kept for later', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands})..cutAfter = 30;
    final first = installer(source);
    // The cut, then three connection errors.
    source.connectionErrors = 0;
    final cutResult = await ModelInstaller(
      source: source,
      store: store,
      freeBytes: () async => null,
      attempts: 1,
      backoff: (_) => Duration.zero,
    ).installAll([a]);
    expect(cutResult.problem, InstallProblem.offline);
    expect(store.partialBytes(a), 30);

    source.connectionErrors = 99;
    final offline = await first.installAll([a]);
    expect(offline.problem, InstallProblem.offline);
    expect(store.partialBytes(a), 30, reason: 'kept to resume');

    source.connectionErrors = 0;
    final back = await first.installAll([a]);
    expect(back.ok, isTrue);
    expect(source.fetches.last.$2, 30);
  });

  test('not enough free space: nothing is downloaded', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands});
    final result = await installer(source, free: 1000).installAll([a]);
    expect(result.problem, InstallProblem.lowStorage);
    expect(result.needed, greaterThan(1000));
    expect(source.fetches, isEmpty);
  });

  test('archive entries outside the model folder are ignored', () async {
    final evil = archiveOf({'../evil.txt': 'x', 'model.onnx': 'ok'});
    final a = modelFor(OfflineModelCatalog.englishVoiceName, evil);
    final source = FakeModelSource({a.url: evil});
    final result = await installer(source).installAll([a]);
    expect(result.ok, isTrue);
    expect(File('${dir.path}/evil.txt').existsSync(), isFalse);
    expect(File('${store.dirOf(a.name)}/model.onnx').existsSync(), isTrue);
  });

  test('a new version replaces the installed one', () async {
    final a = modelFor(OfflineModelCatalog.filipinoVoiceName, voice);
    final source = FakeModelSource({a.url: voice});
    await installer(source).installAll([a]);
    final newer = archiveOf({'model.onnx': 'tgl2', 'tokens.txt': 'a 0'});
    final b = OfflineModel(
      name: a.name,
      version: '2',
      size: newer.length,
      sha256: sha256.convert(newer).toString(),
      url: 'https://server/models/v2.tar.gz',
    );
    source.files[b.url] = newer;
    final result = await installer(source).installAll([b]);
    expect(result.ok, isTrue);
    expect(store.installed(a.name)!.version, '2');
    expect(
      File('${store.dirOf(a.name)}/model.onnx').readAsStringSync(),
      'tgl2',
    );
  });

  test('deleteAll removes models and partial downloads', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    await installer(FakeModelSource({a.url: commands})).installAll([a]);
    await store.deleteAll();
    expect(store.installedAll(), isEmpty);
    expect(store.usedBytes(), 0);
  });

  test('tokens.txt with Windows line endings is unpacked with line feeds',
      () async {
    final cr = String.fromCharCode(13);
    final lf = String.fromCharCode(10);
    final crlf = archiveOf({
      'model.onnx': 'x',
      'tokens.txt': 'a 0$cr$lf  1$cr$lf',
    });
    final a = modelFor(OfflineModelCatalog.filipinoVoiceName, crlf);
    await installer(FakeModelSource({a.url: crlf})).installAll([a]);
    expect(
      File('${store.dirOf(a.name)}/tokens.txt').readAsStringSync(),
      'a 0$lf  1$lf',
    );
  });

  test('an engine that keeps ending the app is marked broken and not '
      'downloaded again', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    final source = FakeModelSource({a.url: commands});
    await installer(source).installAll([a]);
    final model = store.installed(a.name)!;

    // Two starts whose load never returned (the app ended).
    expect(store.beginLoad('commands', [model]), isTrue);
    expect(store.beginLoad('commands', [model]), isTrue);
    // The third start refuses, removes the model and remembers it.
    expect(store.beginLoad('commands', [model]), isFalse);
    expect(store.installed(a.name), isNull);
    expect(store.broken(), contains(a.sha256));

    source.fetches.clear();
    final again = await installer(source).installAll([a]);
    expect(again.problem, InstallProblem.failed);
    expect(source.fetches, isEmpty);

    // Downloading again on purpose clears it.
    await store.deleteAll();
    expect(store.broken(), isEmpty);
  });

  test('a load that returns clears the guard', () async {
    final a = modelFor(OfflineModelCatalog.commandsName, commands);
    await installer(FakeModelSource({a.url: commands})).installAll([a]);
    final model = store.installed(a.name)!;
    for (var i = 0; i < 5; i++) {
      expect(store.beginLoad('commands', [model]), isTrue);
      store.endLoad('commands');
    }
    expect(store.broken(), isEmpty);
  });

  test('an older list never replaces a newer install', () async {
    final newer = archiveOf({'model.onnx': 'v2', 'tokens.txt': 'a 0'});
    final v2 = OfflineModel(
      name: OfflineModelCatalog.filipinoVoiceName,
      version: '2',
      size: newer.length,
      sha256: sha256.convert(newer).toString(),
      url: 'https://server/models/v2.tar.gz',
    );
    final source = FakeModelSource({v2.url: newer});
    await installer(source).installAll([v2]);
    final v1 = modelFor(OfflineModelCatalog.filipinoVoiceName, voice);
    expect(installer(source).missing([v1]), isEmpty);
    // The same version from another file is replaced.
    final repacked = archiveOf({'model.onnx': 'v2b', 'tokens.txt': 'a 0'});
    final v2b = OfflineModel(
      name: v2.name,
      version: '2',
      size: repacked.length,
      sha256: sha256.convert(repacked).toString(),
      url: 'https://server/models/v2b.tar.gz',
    );
    expect(installer(source).missing([v2b]), [v2b]);
  });
}
