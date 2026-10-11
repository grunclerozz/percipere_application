abstract final class Ids {
  /// Controls tutorial.
  static const String tutorial = 'tutorial';

  /// Tutorial: skip.
  static const String tutorialSkip = 'tutorial.skip';

  /// Settings: replay the controls tutorial.
  static const String settingTutorial = 'settings.tutorial';

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

  /// Capture: describe a picture (Maglarawan).
  static const String captureDescribe = 'capture.describe';

  /// Maglarawan: choose camera or upload.
  static const String describeSource = 'describe.source';

  /// Maglarawan source: use the camera.
  static const String describeSourceCamera = 'describe.source.camera';

  /// Maglarawan source: upload a picture.
  static const String describeSourceUpload = 'describe.source.upload';

  /// Description screen.
  static const String describe = 'describe';

  /// Description: say it again.
  static const String describeRepeat = 'describe.repeat';

  /// Description: online detailed description.
  static const String describeMore = 'describe.more';

  /// Description: read the text found in the picture.
  static const String describeReadText = 'describe.readText';

  /// Description: save to history.
  static const String describeSave = 'describe.save';

  /// Description: start over with another picture.
  static const String describeNew = 'describe.new';

  /// Camera screen.
  static const String camera = 'camera';

  /// Camera: take the photo.
  static const String cameraCapture = 'camera.capture';

  /// Reader screen.
  static const String reader = 'reader';

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

  /// Setting row: female or male reading voice.
  static const String settingReadingVoice = 'settings.readingVoice';

  /// Setting row: plays a sample in the reading voice.
  static const String settingVoicePreview = 'settings.voicePreview';

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

  /// Setting row.
  static const String settingDescribeConsent = 'settings.describeConsent';

  /// Settings: Percy's politeness (po / casual).
  static const String settingPercyPoliteness = 'settings.percyPoliteness';

  /// Settings: how much Percy says.
  static const String settingPercyTalk = 'settings.percyTalk';

  /// Settings: keep Percy's turn log for retraining.
  static const String settingPercyLogging = 'settings.percyLogging';

  /// Settings (developer builds): the ElevenLabs Percy instead.
  static const String settingPercyElevenLabs = 'settings.percyElevenLabs';

  /// Settings (developer builds): export Percy's turn log as CSV.
  static const String settingPercyExport = 'settings.percyExport';

  /// Settings (developer builds): the web app's address.
  static const String settingServerAddress = 'settings.serverAddress';

  /// Home: what do you want to do?
  static const String home = 'home';

  /// Home: read something new (Capture).
  static const String homeRead = 'home.read';

  /// Home: open the Library.
  static const String homeLibrary = 'home.library';

  /// Home: open Settings.
  static const String homeSettings = 'home.settings';

  /// Home: report an issue.
  static const String homeReport = 'home.report';

  /// "Mag-report ng problema" (each page: `report.<page>`).
  static const String reportIssue = 'report';

  /// "Aking mga report".
  static const String myReports = 'myReports';

  /// Setting row: report an issue.
  static const String settingReportIssue = 'settings.reportIssue';

  /// Setting row: my reports.
  static const String settingMyReports = 'settings.myReports';

  /// Library screen (Aklatan).
  static const String library = 'library';

  /// Library item details; each action adds `.<name>`.
  static const String libraryItem = 'libraryItem';

  /// Favorites list of one item.
  static const String favorites = 'favorites';

  /// Chapters list of one item.
  static const String chapters = 'chapters';

  /// Picker for the collection to add an item to.
  static const String collectionPicker = 'collectionPicker';

  /// Reader: save the current spot as a favorite.
  static const String readerFavorite = 'reader.favorite';

  /// Setting row.
  static const String settingTextColor = 'settings.textColor';

  /// Setting row.
  static const String settingAutoRead = 'settings.autoRead';

  /// Setting: listen while reading (barge-in).
  static const String settingListenWhileReading = 'settings.listenWhileReading';

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

  /// Verify email (the emailed code, web app accounts).
  static const String verifyEmail = 'verifyEmail';

  /// Verify email: submit.
  static const String verifySubmit = 'verifyEmail.submit';

  /// Verify email: send a new code.
  static const String verifyResend = 'verifyEmail.resend';

  /// Forgot password with an emailed code (web app accounts).
  static const String resetPassword = 'resetPassword';

  /// Reset password: submit.
  static const String resetSubmit = 'resetPassword.submit';

  /// Reset password: send a new code.
  static const String resetResend = 'resetPassword.resend';

  /// Old PIN account: claim screen.
  static const String legacyAccount = 'legacyAccount';

  /// Old PIN account: set email and password.
  static const String upgradeAccount = 'upgradeAccount';

  /// Upgrade: submit.
  static const String upgradeSubmit = 'upgradeAccount.submit';

  /// Guided setup (profiling); each step adds `.<step>`.
  static const String setup = 'setup';
}
