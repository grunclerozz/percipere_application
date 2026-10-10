/// Build-time environment configuration.
///
/// Override at build/run time, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://admin.example.ph --dart-define=USE_MOCK_API=false`
abstract final class Env {
  /// [apiBaseUrl] when no web app is configured.
  static const String noServer = 'https://percipere-admin.invalid';

  /// Base URL of the Percipere web admin app (the dashboard folder, e.g.
  /// `http://192.168.1.61/website/percipere_web/percipere_dashboard`).
  /// An `http://` address also lets the Android build use plain HTTP
  /// (`android/app/build.gradle.kts`); a public server must use `https://`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: noServer,
  );

  /// Whether accounts live on the web app (register with an email code,
  /// login, password reset; `docs/api-contract.md` → Accounts). On by
  /// default once [apiBaseUrl] is set; `--dart-define=USE_ACCOUNT_SERVER=false`
  /// keeps accounts on the phone only (the pre-server behaviour).
  static const bool accountServer = bool.fromEnvironment(
    'USE_ACCOUNT_SERVER',
    defaultValue: apiBaseUrl != noServer,
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
