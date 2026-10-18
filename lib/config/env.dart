/// Build-time environment configuration.
///
/// Override at build/run time, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://admin.example.ph --dart-define=USE_MOCK_API=false`
abstract final class Env {
  /// [apiBaseUrl] when no web app is configured.
  static const String noServer = 'https://percipere-admin.invalid';

  /// Base URL of the Percipere web admin app (the dashboard folder, e.g.
  /// `http://192.168.1.61/website/percipere_dashboard`).
  /// An `http://` address also lets the Android build use plain HTTP
  /// (`android/app/build.gradle.kts`); a public server must use `https://`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: noServer,
  );

  /// Extra hosts (comma separated, e.g. `192.168.1.70,192.168.1.71`) that
  /// may use plain `http://`, besides the host of [apiBaseUrl]. Every other
  /// host needs `https://`. `--dart-define=API_CLEARTEXT_HOSTS=...`; the
  /// Android build reads the same value (`android/app/build.gradle.kts`).
  static const String cleartextHosts = String.fromEnvironment(
    'API_CLEARTEXT_HOSTS',
  );

  /// Whether [host] is on a private network or this device: `localhost`,
  /// `127.x`, `10.x`, `172.16`-`172.31` and `192.168.x` (a phone hotspot or
  /// a school Wi-Fi). Plain HTTP stays on the local network.
  static bool isPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost') return true;
    final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(h);
    if (m == null) return false;
    final p = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
    if (p.any((n) => n > 255)) return false;
    return p[0] == 10 ||
        p[0] == 127 ||
        (p[0] == 172 && p[1] >= 16 && p[1] <= 31) ||
        (p[0] == 192 && p[1] == 168);
  }

  /// Whether plain `http://` to [host] is allowed: private-network
  /// addresses and `localhost` ([isPrivateHost]), the host the app was built
  /// for (when that address is `http://`) and [cleartextHosts]. Everything
  /// else needs `https://`.
  static bool allowsCleartext(String host) {
    final h = host.toLowerCase();
    if (isPrivateHost(h)) return true;
    final built = Uri.tryParse(apiBaseUrl);
    if (built != null &&
        built.scheme == 'http' &&
        built.host.toLowerCase() == h) {
      return true;
    }
    return cleartextHosts
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .contains(h);
  }

  /// Whether accounts live on the web app (register with an email code,
  /// login, password reset; `docs/api-contract.md` → Accounts). On by
  /// default once [apiBaseUrl] is set; `--dart-define=USE_ACCOUNT_SERVER=false`
  /// keeps accounts on the phone only (the pre-server behaviour).
  static const bool accountServer = bool.fromEnvironment(
    'USE_ACCOUNT_SERVER',
    defaultValue: apiBaseUrl != noServer,
  );

  /// Whether accounts are kept on the web app when one is configured (false
  /// only with `--dart-define=USE_ACCOUNT_SERVER=false`).
  static const bool accountServerAllowed = bool.fromEnvironment(
    'USE_ACCOUNT_SERVER',
    defaultValue: true,
  );

  /// ElevenLabs agent id of the voice assistant ("Percy"); the user's own
  /// agent by default (2026-10-07). Not a secret. Another agent:
  /// `--dart-define=ELEVENLABS_AGENT_ID=agent_...`; empty turns Percy off.
  static const String elevenLabsAgentId = String.fromEnvironment(
    'ELEVENLABS_AGENT_ID',
    defaultValue: 'agent_1601m4b0j87se7x8tmtehq4znmas',
  );

  /// ElevenLabs voice the assistant speaks with.
  static const String elevenLabsVoiceId = String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: 'EST9Ui6982FZPSi7gCHi',
  );

  /// Whether the app sets the assistant's language, first message and voice
  /// for each call. Only works when the agent allows these overrides
  /// (dashboard → Security → Overrides); otherwise ElevenLabs ends the call
  /// at once ("Override for field … is not allowed"). Off by default: the
  /// agent's own dashboard settings are used.
  static const bool elevenLabsUseOverrides = bool.fromEnvironment(
    'ELEVENLABS_USE_OVERRIDES',
  );

  /// For a private agent: URL of the token service
  /// (`assistant/server/token_server.py`) that returns
  /// `{"token": "..."}`. Empty: the agent is public and only its id is used.
  static const String elevenLabsTokenUrl = String.fromEnvironment(
    'ELEVENLABS_TOKEN_URL',
  );

  /// Shared secret for the token service (`PERCIPERE_APP_KEY` on the
  /// server), if one is set. Optional.
  static const String elevenLabsAppKey = String.fromEnvironment(
    'ELEVENLABS_APP_KEY',
  );

  /// Developer build: shows hidden Settings rows (the ElevenLabs Percy
  /// switch, exporting Percy's turn log). `--dart-define=PERCIPERE_DEV=true`.
  static const bool devTools = bool.fromEnvironment('PERCIPERE_DEV');

  /// When true, the network layer uses an in-memory mock instead of [apiBaseUrl].
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );
}
