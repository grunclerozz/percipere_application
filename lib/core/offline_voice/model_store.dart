import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'model_catalog.dart';

/// A model that is unpacked and ready.
@immutable
class InstalledModel {
  /// Creates the record.
  const InstalledModel({
    required this.name,
    required this.version,
    required this.sha256,
    required this.dir,
  });

  /// Model name.
  final String name;

  /// Installed version.
  final String version;

  /// SHA-256 of the archive it came from.
  final String sha256;

  /// Folder holding its files.
  final String dir;

  /// Whether this is the same file as [model].
  bool matches(OfflineModel model) =>
      model.name == name && model.sha256 == sha256;
}

/// Where the offline models live on the tablet: one folder per model under
/// the app's private storage, with a `.installed.json` record written last
/// (a folder without it is a half-finished install and is ignored).
/// Downloads go to `.downloads/<name>-<sha>.tar.gz.part` first, so an
/// interrupted download resumes where it stopped.
class ModelStore {
  /// Creates a store in [root].
  ModelStore(this.root);

  /// The models folder.
  final String root;

  static const String _record = '.installed.json';

  /// The folder of model [name].
  String dirOf(String name) => p.join(root, name);

  /// The partial download of [model].
  File partOf(OfflineModel model) => File(
    p.join(root, '.downloads', '${model.name}-${model.sha256.substring(0, 12)}'
        '.tar.gz.part'),
  );

  /// The installed copy of [name], or null.
  InstalledModel? installed(String name) {
    final record = File(p.join(dirOf(name), _record));
    if (!record.existsSync()) return null;
    try {
      final json = jsonDecode(record.readAsStringSync());
      if (json is! Map) return null;
      return InstalledModel(
        name: name,
        version: '${json['version']}',
        sha256: '${json['sha256']}',
        dir: dirOf(name),
      );
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] bad install record for $name: $e');
      return null;
    }
  }

  /// Every installed model by name.
  Map<String, InstalledModel> installedAll() => {
    for (final n in OfflineModelCatalog.names) n: ?installed(n),
  };

  /// Bytes already downloaded for [model].
  int partialBytes(OfflineModel model) {
    final f = partOf(model);
    return f.existsSync() ? f.lengthSync() : 0;
  }

  /// SHA-256 (hex) of [file], computed off the UI isolate.
  static Future<String> hashOf(File file) => Isolate.run(() async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  });

  /// Unpacks the verified [archive] of [model] and records it; the old
  /// copy is replaced only once the new one is complete. The archive is
  /// deleted afterwards.
  Future<InstalledModel> install(OfflineModel model, File archive) async {
    final target = dirOf(model.name);
    final fresh = '$target.new';
    final archivePath = archive.path;
    await Isolate.run(() async {
      final out = Directory(fresh);
      if (out.existsSync()) out.deleteSync(recursive: true);
      out.createSync(recursive: true);
      final tar = TarDecoder().decodeBytes(
        const GZipDecoder().decodeBytes(File(archivePath).readAsBytesSync()),
      );
      {
        for (final entry in tar) {
          final name = p.normalize(entry.name);
          // Never write outside the model's folder.
          if (p.isAbsolute(name) || name.split(p.separator).contains('..')) {
            continue;
          }
          final path = p.join(fresh, name);
          if (entry.isFile) {
            var bytes = entry.content;
            if (p.basename(name) == 'tokens.txt') {
              // Windows line endings break the native token reader (it then
              // ends the app): line feeds only.
              bytes = Uint8List.fromList([
                for (final b in bytes)
                  if (b != 13) b,
              ]);
            }
            File(path)
              ..createSync(recursive: true)
              ..writeAsBytesSync(bytes);
          } else {
            Directory(path).createSync(recursive: true);
          }
        }
      }
    });
    final old = Directory(target);
    if (old.existsSync()) await old.delete(recursive: true);
    await Directory(fresh).rename(target);
    await File(p.join(target, _record)).writeAsString(
      jsonEncode({
        'name': model.name,
        'version': model.version,
        'sha256': model.sha256,
        'installed_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    try {
      await archive.delete();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] could not delete ${archive.path}: $e');
    }
    return InstalledModel(
      name: model.name,
      version: model.version,
      sha256: model.sha256,
      dir: target,
    );
  }

  // ── Crash guard ─────────────────────────────────────────────────────────
  //
  // The native engines end the whole app on a bad model file. Before an
  // engine loads, a marker names the files it uses; it is removed once the
  // load returns. A marker found at the next start means that load never
  // returned: after [crashLimit] such starts in a row, those files are
  // marked broken — not loaded, not downloaded again — until the user
  // downloads the voices again (Settings → Pagsusuri ng boses).

  /// Unfinished loads in a row that mark a model broken.
  static const int crashLimit = 2;

  File _marker(String engine) => File(p.join(root, '.loading-$engine'));
  File get _brokenFile => File(p.join(root, '.broken.json'));

  /// Models (by archive SHA-256) that ended the app while loading.
  Set<String> broken() {
    try {
      final f = _brokenFile;
      if (!f.existsSync()) return const {};
      final list = jsonDecode(f.readAsStringSync());
      return list is List ? {for (final e in list) '$e'} : const {};
    } on Object {
      return const {};
    }
  }

  /// Checks [engine]'s marker before loading [models]: false if the
  /// loads of the same files keep ending the app (they are then marked
  /// broken and removed). Otherwise writes the marker and returns true.
  bool beginLoad(String engine, List<InstalledModel> models) {
    try {
      Directory(root).createSync(recursive: true);
      final marker = _marker(engine);
      final shas = [for (final m in models) m.sha256]..sort();
      var tries = 0;
      if (marker.existsSync()) {
        final previous = jsonDecode(marker.readAsStringSync());
        if (previous is Map && '${previous['shas']}' == '$shas') {
          tries = (previous['tries'] as num?)?.toInt() ?? 0;
        }
      }
      if (tries >= crashLimit) {
        debugPrint('[OFFLINE VOICE] $engine ended the app $tries times: broken');
        _brokenFile.writeAsStringSync(jsonEncode([...broken(), ...shas]));
        for (final m in models) {
          final dir = Directory(m.dir);
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
        marker.deleteSync();
        return false;
      }
      marker.writeAsStringSync(jsonEncode({'shas': '$shas', 'tries': tries + 1}));
      return true;
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] load marker for $engine: $e');
      return true;
    }
  }

  /// The load of [engine] returned (whether or not it worked).
  void endLoad(String engine) {
    try {
      final marker = _marker(engine);
      if (marker.existsSync()) marker.deleteSync();
    } on Object catch (e) {
      debugPrint('[OFFLINE VOICE] load marker for $engine: $e');
    }
  }

  /// Rewrites the `tokens.txt` files of installed models that still have
  /// Windows line endings (see [install]).
  void repairTokens() {
    for (final m in installedAll().values) {
      final f = File(p.join(m.dir, 'tokens.txt'));
      try {
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        if (!bytes.contains(13)) continue;
        f.writeAsBytesSync([
          for (final b in bytes)
            if (b != 13) b,
        ]);
        debugPrint('[OFFLINE VOICE] ${m.name}: tokens.txt line endings fixed');
      } on Object catch (e) {
        debugPrint('[OFFLINE VOICE] ${m.name}: tokens.txt not checked: $e');
      }
    }
  }

  /// Removes every model and partial download.
  Future<void> deleteAll() async {
    final dir = Directory(root);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Bytes the models take on the tablet.
  int usedBytes() {
    final dir = Directory(root);
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }
}
