import 'package:flutter/foundation.dart';

/// What an offline model is for.
enum OfflineModelKind {
  /// The command recognizer (Filipino + English voice commands).
  commands,

  /// The Filipino (Tagalog) voice.
  voiceFilipino,

  /// The English voice.
  voiceEnglish,
}

/// One downloadable model archive (`.tar.gz`), as listed by the dashboard's
/// `GET /api/v1/models` (or `models/manifest.json`, or the built-in list).
@immutable
class OfflineModel {
  /// Creates an entry.
  const OfflineModel({
    required this.name,
    required this.version,
    required this.size,
    required this.sha256,
    required this.url,
    this.fallbackUrl,
    this.installedSize,
  });

  /// Reads one manifest entry; null if it is incomplete or not one of ours.
  /// A relative [url] is resolved against [base] (the server address).
  static OfflineModel? fromJson(Map<String, dynamic> json, {String? base}) {
    final name = json['name'];
    final version = json['version'];
    final size = json['size'];
    final sha = '${json['sha256'] ?? ''}'
        .toLowerCase()
        .replaceFirst('sha256:', '');
    final url = json['url'];
    if (name is! String || kindOf(name) == null) return null;
    if (version == null || size is! num || size <= 0) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
    if (url is! String || url.isEmpty) return null;
    final fallback = json['fallback_url'] ?? json['fallbackUrl'];
    final installed = json['installed_size'] ?? json['installedSize'];
    return OfflineModel(
      name: name,
      version: '$version',
      size: size.toInt(),
      sha256: sha,
      url: resolve(url, base),
      fallbackUrl: fallback is String && fallback.isNotEmpty
          ? resolve(fallback, base)
          : OfflineModelCatalog.builtIn
                .where((m) => m.name == name && m.sha256 == sha)
                .firstOrNull
                ?.fallbackUrl,
      installedSize: installed is num ? installed.toInt() : null,
    );
  }

  /// `percipere-asr-fil-en`, `percipere-tts-tgl` or `percipere-tts-en`.
  final String name;

  /// Model version (a new version replaces the installed one).
  final String version;

  /// Archive size in bytes.
  final int size;

  /// Hex SHA-256 of the archive.
  final String sha256;

  /// Where to download it (the dashboard's `/models` folder).
  final String url;

  /// Where else to get the same file (the GitHub release).
  final String? fallbackUrl;

  /// Space it takes once unpacked, if the manifest says.
  final int? installedSize;

  /// What it is for.
  OfflineModelKind get kind => kindOf(name)!;

  /// Space needed to download and unpack it.
  int get spaceNeeded => size + (installedSize ?? size * 3);

  /// The kind of model a [name] stands for, or null if unknown.
  static OfflineModelKind? kindOf(String name) => switch (name) {
    OfflineModelCatalog.commandsName => OfflineModelKind.commands,
    OfflineModelCatalog.filipinoVoiceName => OfflineModelKind.voiceFilipino,
    OfflineModelCatalog.englishVoiceName => OfflineModelKind.voiceEnglish,
    _ => null,
  };

  /// [url] made absolute against [base] (`/models/x` or `models/x`).
  static String resolve(String url, String? base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (base == null || base.isEmpty) return url;
    final root = base.replaceAll(RegExp(r'/+$'), '');
    return '$root/${url.replaceFirst(RegExp('^/+'), '')}';
  }

  @override
  bool operator ==(Object other) =>
      other is OfflineModel &&
      other.name == name &&
      other.version == version &&
      other.sha256 == sha256 &&
      other.url == url;

  @override
  int get hashCode => Object.hash(name, version, sha256, url);
}

/// The models the app needs and where their list comes from.
abstract final class OfflineModelCatalog {
  /// The offline command recognizer (Whisper tiny + Silero VAD).
  static const String commandsName = 'percipere-asr-fil-en';

  /// The Tagalog voice.
  static const String filipinoVoiceName = 'percipere-tts-tgl';

  /// The English voice.
  static const String englishVoiceName = 'percipere-tts-en';

  /// Every model, in download order (commands first: the smallest and the
  /// one users notice most).
  static const List<String> names = [
    commandsName,
    filipinoVoiceName,
    englishVoiceName,
  ];

  /// The GitHub release that also holds the archives.
  static const String githubRelease =
      'https://github.com/grunclerozz/percipere_app/releases/download/voice-models-v1';

  /// The list built into the app, used when the dashboard can't be reached
  /// (or has no `/api/v1/models` yet): the same files, from the GitHub
  /// release. Kept in step with `tool/voice_models/manifest.json`.
  static const List<OfflineModel> builtIn = [
    OfflineModel(
      name: commandsName,
      version: '1',
      size: 33502464,
      sha256: 'e64fd0417d766ccd544a7cd96bb03168ad72f84994ccaf54afc23e352af22edb',
      installedSize: 44800000,
      url: '$githubRelease/$commandsName-v1.tar.gz',
      fallbackUrl: '$githubRelease/$commandsName-v1.tar.gz',
    ),
    OfflineModel(
      name: filipinoVoiceName,
      version: '1',
      size: 38395702,
      sha256: '70f00a331a2291a9e6c4bef12f4721dc9bb9c010531e9b2008061c2ffa3fac21',
      installedSize: 43450000,
      url: '$githubRelease/$filipinoVoiceName-v1.tar.gz',
      fallbackUrl: '$githubRelease/$filipinoVoiceName-v1.tar.gz',
    ),
    OfflineModel(
      name: englishVoiceName,
      version: '1',
      size: 14017873,
      sha256: '3fc2c48edfc0d90ca6855cea6748f0030d9d227a62c33f94efe23af1baded2b3',
      installedSize: 20400000,
      url: '$githubRelease/$englishVoiceName-v1.tar.gz',
      fallbackUrl: '$githubRelease/$englishVoiceName-v1.tar.gz',
    ),
  ];

  /// Reads a manifest body: `{"models": [...]}`, `{"data": [...]}` or a bare
  /// list. Unknown or incomplete entries are skipped; the newest version of
  /// each name wins.
  static List<OfflineModel> parse(Object? body, {String? base}) {
    final list = body is List
        ? body
        : body is Map
        ? (body['models'] ?? body['data'])
        : null;
    if (list is! List) return const [];
    final byName = <String, OfflineModel>{};
    for (final item in list) {
      if (item is! Map) continue;
      final model = OfflineModel.fromJson(
        item.cast<String, dynamic>(),
        base: base,
      );
      if (model == null) continue;
      final have = byName[model.name];
      if (have == null || compareVersions(model.version, have.version) > 0) {
        byName[model.name] = model;
      }
    }
    return [
      for (final n in names)
        if (byName[n] != null) byName[n]!,
    ];
  }

  /// Compares versions such as `1`, `1.2`, `2025-12-20` part by part.
  static int compareVersions(String a, String b) {
    final pa = a.split(RegExp('[.-]'));
    final pb = b.split(RegExp('[.-]'));
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
      final y = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
