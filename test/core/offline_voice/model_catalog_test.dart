import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/offline_voice/model_catalog.dart';

void main() {
  final sha = 'a' * 64;

  Map<String, Object> entry(String name, {String version = '1'}) => {
    'name': name,
    'version': version,
    'size': 1234,
    'sha256': sha,
    'url': '/models/$name.tar.gz',
  };

  test('reads {"models": [...]} and resolves relative URLs', () {
    final models = OfflineModelCatalog.parse({
      'models': [entry(OfflineModelCatalog.commandsName)],
    }, base: 'http://192.168.1.5/percipere_dashboard/');
    expect(models.single.url,
        'http://192.168.1.5/percipere_dashboard/models/percipere-asr-fil-en.tar.gz');
    expect(models.single.kind, OfflineModelKind.commands);
  });

  test('reads {"data": [...]} and a bare list; "sha256:" prefix allowed', () {
    final withPrefix = {
      ...entry(OfflineModelCatalog.filipinoVoiceName),
      'sha256': 'sha256:$sha',
    };
    expect(OfflineModelCatalog.parse({'data': [withPrefix]}), hasLength(1));
    expect(OfflineModelCatalog.parse([withPrefix]), hasLength(1));
  });

  test('skips unknown names, bad checksums and missing sizes', () {
    final models = OfflineModelCatalog.parse([
      entry('something-else'),
      {...entry(OfflineModelCatalog.commandsName), 'sha256': 'abc'},
      {...entry(OfflineModelCatalog.englishVoiceName), 'size': 0},
    ]);
    expect(models, isEmpty);
  });

  test('the newest version of each model wins, in download order', () {
    final models = OfflineModelCatalog.parse([
      entry(OfflineModelCatalog.englishVoiceName),
      entry(OfflineModelCatalog.commandsName, version: '1.2'),
      entry(OfflineModelCatalog.commandsName, version: '1.10'),
    ]);
    expect(models.map((m) => m.name), [
      OfflineModelCatalog.commandsName,
      OfflineModelCatalog.englishVoiceName,
    ]);
    expect(models.first.version, '1.10');
  });

  test('the built-in list has every model with a GitHub copy', () {
    expect(
      OfflineModelCatalog.builtIn.map((m) => m.name),
      OfflineModelCatalog.names,
    );
    for (final m in OfflineModelCatalog.builtIn) {
      expect(m.url, startsWith(OfflineModelCatalog.githubRelease));
      expect(m.size, greaterThan(0));
      expect(m.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
  });

  test('the server list gets the GitHub copy of the same file', () {
    final builtIn = OfflineModelCatalog.builtIn.first;
    final models = OfflineModelCatalog.parse([
      {
        'name': builtIn.name,
        'version': builtIn.version,
        'size': builtIn.size,
        'sha256': builtIn.sha256,
        'url': 'http://pc/models/x.tar.gz',
      },
    ]);
    expect(models.single.fallbackUrl, builtIn.fallbackUrl);
  });

  test('compareVersions', () {
    expect(OfflineModelCatalog.compareVersions('2', '1'), 1);
    expect(OfflineModelCatalog.compareVersions('1.9', '1.10'), -1);
    expect(OfflineModelCatalog.compareVersions('2025-12-20', '2025-12-20'), 0);
  });
}
