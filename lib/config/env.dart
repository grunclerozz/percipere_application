/// Build-time environment configuration.
///
/// Override at build/run time, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://admin.example.ph --dart-define=USE_MOCK_API=false`
abstract final class Env {
  /// Base URL of the Percipere web admin app (reports, feedback, SUS, usage logs).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://percipere-admin.invalid',
  );

  /// When true, the network layer uses an in-memory mock instead of [apiBaseUrl].
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );
}
