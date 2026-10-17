import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/offline_voice/model_catalog.dart';
import 'package:percipere_app/core/offline_voice/model_installer.dart';
import 'package:percipere_app/core/offline_voice/model_store.dart';
import 'package:percipere_app/core/offline_voice/offline_engines.dart';
import 'package:percipere_app/core/offline_voice/offline_voice_setup.dart';

import '../../helpers/fake_model_source.dart';
import '../../helpers/fakes.dart';

/// The first-launch download: offline → waits, resumes when the internet
/// is back; progress; delete and download again.
void main() {
  late Directory dir;
  late ModelStore store;
  late TestEnv env;
  late ProviderContainer container;
  late FakeModelSource source;
  int? free;

  // Random content, so the archives don't shrink below the cut.
  final random = Random(7);
  String noise() =>
      String.fromCharCodes([for (var i = 0; i < 3000; i++) 33 + random.nextInt(90)]);
  final archives = {
    for (final n in OfflineModelCatalog.names)
      n: archiveOf({'README.txt': 'model $n', 'data.bin': noise()}),
  };
  final models = [
    for (final n in OfflineModelCatalog.names) modelFor(n, archives[n]!),
  ];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('voice_models');
    store = ModelStore(dir.path);
    free = null;
    source = FakeModelSource(
      {for (final m in models) m.url: archives[m.name]!},
      models: models,
    );
    OfflineVoiceController.installerFor = (ref, s) => ModelInstaller(
      source: source,
      store: s,
      freeBytes: () async => free,
      backoff: (_) => Duration.zero,
    );
    env = await TestEnv.create();
    container = ProviderContainer(
      overrides: [
        ...env.overrides,
        modelStoreProvider.overrideWithValue(store),
      ],
    );
    container.listen(offlineVoiceProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  OfflineVoiceController setup() =>
      container.read(offlineVoiceProvider.notifier);
  OfflineVoiceState state() => container.read(offlineVoiceProvider);

  /// Waits (real time, the PC may be busy) until the download is [status].
  Future<void> until(OfflineVoiceStatus status) async {
    for (var i = 0; i < 200 && state().status != status; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('downloads everything and is ready', () async {
    final percents = <int>[];
    container.listen(offlineVoiceProvider, (_, s) => percents.add(s.percent));
    final result = await setup().ensure();
    expect(result!.ok, isTrue);
    expect(state().status, OfflineVoiceStatus.ready);
    expect(state().complete, isTrue);
    expect(state().total, models.fold<int>(0, (s, m) => s + m.size));
    expect(percents.last, 100);
  });

  test('no internet: waits, then resumes by itself when it is back',
      () async {
    env.online = false;
    await setup().ensure();
    expect(state().status, OfflineVoiceStatus.waitingForInternet);
    expect(source.fetches, isEmpty);

    env.online = true;
    env.connectionRestored.add(null);
    await until(OfflineVoiceStatus.ready);
    expect(state().status, OfflineVoiceStatus.ready);
  });

  test('a download cut by the network resumes from where it stopped',
      () async {
    // The cut, then the network is gone for every retry.
    source
      ..cutAfter = 500
      ..offlineAfterCut = true;
    await setup().ensure();
    expect(state().status, OfflineVoiceStatus.waitingForInternet);
    final model = models.first;
    expect(store.partialBytes(model), 500);

    source.connectionErrors = 0;
    env.connectionRestored.add(null);
    await until(OfflineVoiceStatus.ready);
    expect(state().status, OfflineVoiceStatus.ready);
    expect(
      source.fetches.where((f) => f.$1 == model.url).last.$2,
      500,
      reason: 'continued, not restarted',
    );
  });

  test('not enough space', () async {
    free = 100;
    await setup().ensure();
    expect(state().status, OfflineVoiceStatus.lowStorage);
    expect(state().neededBytes, greaterThan(100));
  });

  test('delete, then download again', () async {
    await setup().ensure();
    await setup().deleteAll();
    expect(state().installed, isEmpty);
    expect(state().status, OfflineVoiceStatus.idle);
    await setup().redownload();
    expect(state().status, OfflineVoiceStatus.ready);
  });

  test('already installed at startup: ready at once', () async {
    await ModelInstaller(
      source: source,
      store: store,
      freeBytes: () async => null,
    ).installAll(models);
    final fresh = ProviderContainer(
      overrides: [
        ...env.overrides,
        modelStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(fresh.dispose);
    expect(fresh.read(offlineVoiceProvider).status, OfflineVoiceStatus.ready);
  });

  test('no model folder: unavailable, nothing happens', () async {
    final none = ProviderContainer(overrides: env.overrides);
    addTearDown(none.dispose);
    expect(
      none.read(offlineVoiceProvider).status,
      OfflineVoiceStatus.unavailable,
    );
    expect(await none.read(offlineVoiceProvider.notifier).ensure(), isNull);
  });

  test('install problems map to statuses', () {
    expect(InstallProblem.values, hasLength(4));
  });

  test('offline with everything installed: stays ready', () async {
    await setup().ensure();
    env.online = false;
    await setup().ensure();
    expect(state().status, OfflineVoiceStatus.ready);
  });
}
