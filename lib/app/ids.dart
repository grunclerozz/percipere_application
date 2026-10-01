/// Stable screen and action ids, shared by screens, the command bus and
/// (later) usage logs. Never rename a shipped id: logs are keyed on them.
abstract final class Ids {
  /// Welcome screen.
  static const String welcome = 'welcome';

  /// Welcome: choose voice navigation.
  static const String welcomeVoice = 'welcome.voice';

  /// Welcome: choose gesture navigation.
  static const String welcomeGestures = 'welcome.gestures';

  /// Capture method screen.
  static const String capture = 'capture';

  /// Capture: upload a file.
  static const String captureUpload = 'capture.upload';

  /// Capture: use the camera.
  static const String captureCamera = 'capture.camera';

  /// Camera screen.
  static const String camera = 'camera';

  /// Camera: take the photo.
  static const String cameraCapture = 'camera.capture';

  /// Reader screen.
  static const String reader = 'reader';

  /// Capture: open Reading History.
  static const String captureHistory = 'capture.history';

  /// Capture: open Settings.
  static const String captureSettings = 'capture.settings';

  /// Settings screen.
  static const String settings = 'settings';

  /// Setting rows (action ids).
  static const String settingReadingRate = 'settings.readingRate';

  /// Setting row.
  static const String settingPitch = 'settings.pitch';

  /// Setting row.
  static const String settingLanguage = 'settings.language';

  /// Setting row.
  static const String settingDocumentVoice = 'settings.documentVoice';

  /// Setting row.
  static const String settingTextSize = 'settings.textSize';

  /// Setting row.
  static const String settingFont = 'settings.font';

  /// Setting row.
  static const String settingColors = 'settings.colors';

  /// Setting row.
  static const String settingNavMode = 'settings.navMode';

  /// Setting row.
  static const String settingHaptics = 'settings.haptics';

  /// Setting row.
  static const String settingVerbosity = 'settings.verbosity';

  /// Setting row.
  static const String settingAutoCapture = 'settings.autoCapture';

  /// Setting row.
  static const String settingAccount = 'settings.account';

  /// Setting row.
  static const String settingTtsVoices = 'settings.ttsVoices';

  /// Reading History screen.
  static const String history = 'history';

  /// Account screen.
  static const String account = 'account';

  /// Account: create a profile.
  static const String accountCreate = 'account.create';

  /// Account: log in.
  static const String accountLogin = 'account.login';

  /// Account: log out.
  static const String accountLogout = 'account.logout';

  /// Create-profile screen.
  static const String createProfile = 'createProfile';

  /// Login screen.
  static const String login = 'login';
}
