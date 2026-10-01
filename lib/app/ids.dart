abstract final class Ids {
  /// Welcome screen.
  static const String welcome = 'welcome';

  /// Welcome: log in.
  static const String welcomeLogin = 'welcome.login';

  /// Welcome: register.
  static const String welcomeRegister = 'welcome.register';

  /// Welcome: try first (guest).
  static const String welcomeGuest = 'welcome.guest';

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
  static const String settingTtsVoices = 'settings.ttsVoices';

  /// Reading History screen.
  static const String history = 'history';

  /// Setting row.
  static const String settingTextColor = 'settings.textColor';

  /// Setting row.
  static const String settingAutoRead = 'settings.autoRead';

  /// Setting row.
  static const String settingStayLoggedIn = 'settings.stayLoggedIn';

  /// Setting row.
  static const String settingFingerprint = 'settings.fingerprint';

  /// Setting row (guests): register an account.
  static const String settingRegister = 'settings.register';

  /// Setting row: redo the guided setup.
  static const String settingRedoSetup = 'settings.redoSetup';

  /// Setting row: log out.
  static const String settingLogout = 'settings.logout';

  /// Register screen.
  static const String register = 'register';

  /// Register: submit.
  static const String registerSubmit = 'register.submit';

  /// Login screen.
  static const String login = 'login';

  /// Login: submit.
  static const String loginSubmit = 'login.submit';

  /// Login: forgot password.
  static const String loginForgot = 'login.forgot';

  /// Login: use fingerprint.
  static const String loginFingerprint = 'login.fingerprint';

  /// Login: old PIN account.
  static const String loginLegacy = 'login.legacy';

  /// "Log in or register?" screen (after logout / expired session).
  static const String authChoice = 'authChoice';

  /// Auth choice: log in.
  static const String authChoiceLogin = 'authChoice.login';

  /// Auth choice: register.
  static const String authChoiceRegister = 'authChoice.register';

  /// Security question screen.
  static const String securityQuestion = 'securityQuestion';

  /// Security question: submit the answer.
  static const String securitySubmit = 'securityQuestion.submit';

  /// Fingerprint offer screen.
  static const String fingerprintOffer = 'fingerprintOffer';

  /// Forgot password screen.
  static const String forgotPassword = 'forgotPassword';

  /// Forgot password: submit the current step.
  static const String forgotSubmit = 'forgotPassword.submit';

  /// Old PIN account: claim screen.
  static const String legacyAccount = 'legacyAccount';

  /// Old PIN account: set email and password.
  static const String upgradeAccount = 'upgradeAccount';

  /// Upgrade: submit.
  static const String upgradeSubmit = 'upgradeAccount.submit';

  /// Guided setup (profiling); each step adds `.<step>`.
  static const String setup = 'setup';
}
