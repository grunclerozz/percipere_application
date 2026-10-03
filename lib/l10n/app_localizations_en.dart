// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Percipere';

  @override
  String get welcomeTitleLine1 => 'Welcome to';

  @override
  String get welcomeSubtitle => 'An app built on your behalf';

  @override
  String get welcomePrompt => 'How would you like to navigate the app?';

  @override
  String get navModeVoice => 'Voice (Pa-boses)';

  @override
  String get navModeGestures => 'Gestures (Pa-galaw)';

  @override
  String get capturePrompt => 'How would you like to capture your document?';

  @override
  String get captureUpload => 'Upload';

  @override
  String get captureCamera => 'Use the Camera';

  @override
  String get gestureAreaLabel => 'Gesture area';

  @override
  String get gestureAreaHintMenu =>
      'Swipe right or left to move between options. Double-tap to choose. Long-press to speak a command.';

  @override
  String get gestureAreaHintReader =>
      'Double-tap to play or pause. Swipe right or left for the next or previous sentence. Swipe up or down to read faster or slower.';

  @override
  String heardLabel(String text) {
    return 'Heard: “$text”';
  }

  @override
  String get readerLoading => 'Reading the document…';

  @override
  String get readerDocumentLabel => 'Document';

  @override
  String get readerEmpty => 'There is no text to read.';

  @override
  String get screenCapture => 'Capture document';

  @override
  String get screenReader => 'Reader';

  @override
  String get helpWelcome =>
      'Swipe right or left: move between Login, Register and Try first. Double-tap: press. Tap: repeat the question. Long-press: speak. Two-finger swipe right: go back.';

  @override
  String get modeChosenVoice => 'You chose voice navigation.';

  @override
  String get modeChosenGestures => 'You chose gesture navigation.';

  @override
  String optionsList(String items) {
    return 'Options: $items.';
  }

  @override
  String get wordOr => 'or';

  @override
  String focusedItem(String label, int position, int total) {
    return '$label, $position of $total.';
  }

  @override
  String get modeHintGestures =>
      'Swipe right or left to move, and double-tap to choose.';

  @override
  String get modeHintVoice =>
      'Say a command after the tone, or long-press the gesture area. Gestures work too.';

  @override
  String get modeHintTalkBack => 'Use TalkBack gestures to choose.';

  @override
  String get nothingFocused =>
      'Nothing is selected yet. Swipe right to pick an option.';

  @override
  String get commandNotAvailable => 'That command isn\'t available here.';

  @override
  String get alreadyAtStart => 'You\'re already at the start.';

  @override
  String helpTitle(String screen) {
    return 'Help for $screen.';
  }

  @override
  String get helpGesturesMenu =>
      'Swipe right or left: move between options. Double-tap: choose. Tap: repeat the question. Two-finger swipe right: go back. Long-press: speak a command. Two-finger double-tap: stop speaking. Three-finger tap: help.';

  @override
  String get talkBackNotice =>
      'TalkBack is on, so TalkBack gestures replace Percipere\'s gestures. Voice commands still work.';

  @override
  String get ttsFilipinoMissing =>
      'The Filipino voice is not installed on this phone, so Percipere will speak English for now. To install it, open text-to-speech settings, choose Speech Services by Google, and download the Filipino voice.';

  @override
  String get ttsFilipinoMissingSwipeUp =>
      'Swipe up now to open text-to-speech settings.';

  @override
  String get ttsOpeningSettings => 'Opening text-to-speech settings.';

  @override
  String get filipinoVoiceReady => 'The Filipino voice is ready.';

  @override
  String get listening => 'Listening…';

  @override
  String voiceUnknown(String commands) {
    return 'Sorry, I didn\'t catch that. You can say: $commands.';
  }

  @override
  String get voiceCommonCommands =>
      'next, previous, select, repeat, back, or help';

  @override
  String voiceDidYouMean(String phrase) {
    return 'Did you mean “$phrase”? Say yes or no.';
  }

  @override
  String get voiceCancelled => 'Okay.';

  @override
  String get voiceWakeReply => 'I\'m listening.';

  @override
  String get voiceNothingHeard => 'I didn\'t hear anything.';

  @override
  String get voiceListeningPaused =>
      'I\'ll stop listening for now. Long-press the gesture area to talk to me again.';

  @override
  String get voiceRepeatedError =>
      'My voice listening isn\'t working right now, so I\'ll stop. Long-press the gesture area to try again, or use gestures.';

  @override
  String get micPermissionExplain =>
      'Android will now ask to let Percipere use the microphone, so I can hear your commands. Choose “While using the app”.';

  @override
  String get micDenied =>
      'I can\'t use the microphone, so gestures will be used for now.';

  @override
  String get micDeniedPermanent =>
      'The microphone is blocked for Percipere. You can allow it in the app\'s settings.';

  @override
  String get offerConfirmHint => 'Double-tap, or say “yes”, to continue.';

  @override
  String get voiceUnavailable =>
      'This phone has no speech recognition, so gestures will be used instead.';

  @override
  String get voiceOfflineMissing =>
      'There\'s no internet, and offline speech recognition isn\'t installed. You can download it in Settings, under voice input.';

  @override
  String get featureNotReady =>
      'That part isn\'t available in this version yet.';

  @override
  String helpVoiceCommands(String commands) {
    return 'Voice commands: $commands.';
  }

  @override
  String get screenCamera => 'Camera';

  @override
  String get cameraIntro =>
      'Point the camera at the document, about thirty centimeters away. I\'ll tell you to move closer or back. Double-tap or say “capture” to take the photo. I\'ll also take it by myself once the text is clear.';

  @override
  String get cameraCaptureButton => 'Take photo';

  @override
  String get guideTooDark => 'It\'s too dark. Find a brighter spot.';

  @override
  String get guideNoText => 'No text in view.';

  @override
  String get guideMoveCloser => 'Move closer.';

  @override
  String get guideMoveBack => 'Move back a little.';

  @override
  String get guideReady => 'Ready, hold steady.';

  @override
  String get cameraCapturing => 'Taking the photo.';

  @override
  String get cameraCaptureFailed => 'The photo didn\'t work. Please try again.';

  @override
  String get cameraPermissionExplain =>
      'Android will now ask to let Percipere use the camera. Choose “While using the app”.';

  @override
  String get cameraDenied =>
      'I can\'t use the camera. You can upload a photo instead.';

  @override
  String get cameraDeniedPermanent =>
      'The camera is blocked for Percipere. You can allow it in the app\'s settings.';

  @override
  String get cameraUnavailable =>
      'The camera couldn\'t start. I can open the phone\'s own camera app instead.';

  @override
  String get helpCamera =>
      'Double-tap: take the photo. Tap: repeat the guidance. Two-finger swipe right: go back.';

  @override
  String get uploadOpening => 'Choose a photo, PDF, or Word file.';

  @override
  String get uploadCancelled => 'No file was chosen.';

  @override
  String readerExtractingPage(int page, int total) {
    return 'Reading page $page of $total.';
  }

  @override
  String readerReadyParagraphs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragraphs',
      one: 'one paragraph',
    );
    return 'The document is ready: $_temp0.';
  }

  @override
  String get readerLowQuality =>
      'Some of the text may not have been read correctly.';

  @override
  String get readerNoText => 'I couldn\'t find any text to read.';

  @override
  String get readerPhotoTips =>
      'Try in a brighter place, and hold the phone straight and still.';

  @override
  String get readerRetakeOffer => 'Would you like to take the photo again?';

  @override
  String get readerUnreadable =>
      'This file can\'t be opened. It may be damaged.';

  @override
  String get readerUnsupported =>
      'I can\'t read this kind of file yet. Choose a photo, PDF, or Word file.';

  @override
  String get readerPasswordProtected =>
      'This PDF is password-protected, so I can\'t read it.';

  @override
  String get readerStartHint => 'Double-tap to start reading, or say “read”.';

  @override
  String readerResumeAt(int position, int total) {
    return 'Continuing from sentence $position of $total.';
  }

  @override
  String get readerFinished => 'End of the document.';

  @override
  String get readerPaused => 'Paused.';

  @override
  String readerSpeed(String rate) {
    return 'Speed: ${rate}x';
  }

  @override
  String readerSize(int size) {
    return 'Size: $size';
  }

  @override
  String get readerSizeMax => 'Already the largest.';

  @override
  String get readerSizeMin => 'Already the smallest.';

  @override
  String get readerTextBigger => 'Make the text bigger';

  @override
  String get readerTextSmaller => 'Make the text smaller';

  @override
  String get readerSaved => 'Saved to history.';

  @override
  String get readerAtStart => 'This is the beginning.';

  @override
  String get readerAtEnd => 'This is the last sentence.';

  @override
  String get readerFromStart => 'From the beginning.';

  @override
  String get readerFilipinoNoVoice =>
      'This document is in Filipino, but no Filipino voice is installed, so it will be read with an English voice and may be hard to understand.';

  @override
  String get helpReader =>
      'Double-tap: read or pause. Swipe right or left: next or previous sentence. Two-finger swipe down or up: next or previous paragraph. Swipe up or down: faster or slower. Tap: repeat the sentence. Two-finger swipe right: go back. Tap A plus or A minus above the document, or pinch the document box, to make the text bigger or smaller. Voice commands: read, pause, resume, next, previous, next paragraph, faster, slower, bigger, smaller, repeat, from the beginning, save, and back.';

  @override
  String get captureHistory => 'History';

  @override
  String get captureSettings => 'Settings';

  @override
  String get screenSettings => 'Settings';

  @override
  String get settingsIntro =>
      'Swipe right or left to pick a setting, and up or down to change it.';

  @override
  String get helpSettings =>
      'Swipe right or left: move between settings. Swipe up or down: change the value. Double-tap: next choice, or open. Two-finger swipe right: go back.';

  @override
  String settingValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get setReadingRate => 'Reading speed';

  @override
  String get setPitch => 'Voice pitch';

  @override
  String get setLanguage => 'Language';

  @override
  String get setDocumentVoice => 'Document voice';

  @override
  String get setTextSize => 'Text size';

  @override
  String get setFont => 'Font';

  @override
  String get setNavMode => 'Navigation';

  @override
  String get setHaptics => 'Vibration';

  @override
  String get setVerbosity => 'Amount of speech';

  @override
  String get setAutoCapture => 'Automatic photo';

  @override
  String get setTtsVoices => 'Reading voices';

  @override
  String get valueOn => 'On';

  @override
  String get valueOff => 'Off';

  @override
  String get valueAuto => 'Automatic';

  @override
  String get langFilipino => 'Filipino';

  @override
  String get langEnglish => 'English';

  @override
  String get verbosityBrief => 'Brief';

  @override
  String get verbosityNormal => 'Normal';

  @override
  String get verbosityDetailed => 'Detailed';

  @override
  String get navVoice => 'Voice';

  @override
  String get navGestures => 'Gestures';

  @override
  String get accountNone => 'Not logged in';

  @override
  String accountAs(String name) {
    return 'Logged in as $name';
  }

  @override
  String get ttsFilipinoInstalled => 'Filipino voice installed';

  @override
  String get ttsFilipinoNotInstalled =>
      'No Filipino voice. Double-tap to install.';

  @override
  String get actionIncrease => 'Increase';

  @override
  String get actionDecrease => 'Decrease';

  @override
  String get actionChange => 'Change';

  @override
  String get actionOpen => 'Open';

  @override
  String get screenHistory => 'Reading History';

  @override
  String historyIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents.',
      one: 'One document.',
    );
    return '$_temp0 Swipe right to hear each one, and double-tap to open it.';
  }

  @override
  String get historyEmpty =>
      'No documents yet. Read one first with Upload or the Camera.';

  @override
  String historyItem(String title, String source, String date) {
    return '$title, $source, $date';
  }

  @override
  String get sourceCamera => 'photo';

  @override
  String get sourceImage => 'image';

  @override
  String get sourcePdf => 'PDF';

  @override
  String get sourceDocx => 'Word';

  @override
  String historyResults(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: 'One result',
    );
    return '$_temp0 for “$query”.';
  }

  @override
  String historyNoResults(String query) {
    return 'Nothing found for “$query”.';
  }

  @override
  String get historyShowAll => 'Showing everything again.';

  @override
  String historyOptions(String title) {
    return 'Options for $title. Swipe to choose: Open, Rename, or Delete. Double-tap to select.';
  }

  @override
  String get optOpen => 'Open';

  @override
  String get optRename => 'Rename';

  @override
  String get optDelete => 'Delete';

  @override
  String get historyRenamePrompt => 'Say the new name after the tone.';

  @override
  String historyRenamed(String title) {
    return 'Renamed to $title.';
  }

  @override
  String historyDeleteConfirm(String title) {
    return 'Delete “$title”?';
  }

  @override
  String historyDeleted(String title) {
    return 'Deleted “$title”.';
  }

  @override
  String get historySearch => 'Search';

  @override
  String get helpHistory =>
      'Swipe right or left: move between documents. Double-tap: open and continue reading. Swipe up: options, such as rename and delete. Say “search” and a word to search. Two-finger swipe right: go back.';

  @override
  String get fieldEmail => 'Email Address';

  @override
  String get fieldPin => 'PIN';

  @override
  String get actionSkip => 'Skip';

  @override
  String get screenLogin => 'Login';

  @override
  String loginAskPin(String name) {
    return 'Enter the PIN for $name.';
  }

  @override
  String get loginWrongPin => 'Wrong PIN. Please try again.';

  @override
  String pinDigitEntered(int count, int total) {
    return 'Digit $count of $total.';
  }

  @override
  String get pinDeleted => 'Deleted the last digit.';

  @override
  String get pinSayFour =>
      'Say four digits, for example: one, two, three, four.';

  @override
  String get pinDelete => 'Delete';

  @override
  String get helpPin =>
      'Swipe up or down: choose a digit. Double-tap: enter the digit. Swipe left: delete the last digit. Long-press: say the four digits.';

  @override
  String get screenWelcome => 'Welcome';

  @override
  String get welcomeHasAccount => 'Do you already have an account?';

  @override
  String get welcomeAccountPrompt =>
      'Do you already have an account? If not, register.';

  @override
  String get welcomeHintVoice =>
      'Say “login”, “register”, or “try first”, or swipe to choose and double-tap to press.';

  @override
  String get welcomeHintGestures =>
      'Swipe right to choose, and double-tap to press. Tap to hear this again.';

  @override
  String get welcomeVoiceReady =>
      'You can now say “login”, “register”, or “try first”.';

  @override
  String get actionLogin => 'Login';

  @override
  String get actionRegister => 'Register';

  @override
  String get actionTryFirst => 'Subukan muna (Try first)';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionOkay => 'Okay';

  @override
  String get actionFinishSetup => 'Correct, finish';

  @override
  String get actionForgotPassword => 'Forgot password';

  @override
  String get actionUseFingerprint => 'Use fingerprint';

  @override
  String get actionLegacyAccount => 'Old account (PIN)';

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String get guestName => 'Guest';

  @override
  String get guestValue => 'Guest: saved on this phone only';

  @override
  String get guestReminder =>
      'This is saved on this phone only. Register so you don\'t lose it.';

  @override
  String get backUnsavedConfirm =>
      'Something isn\'t saved yet. Are you sure you want to go back?';

  @override
  String get closeAppQuestion => 'Do you want to close the app?';

  @override
  String backReturnedTo(String screen) {
    return 'Back to $screen.';
  }

  @override
  String get formIntro => 'Answer each question by voice, or type it.';

  @override
  String get formSubmitHint =>
      'Double-tap the gesture area or say submit or done';

  @override
  String formFieldEmpty(String field) {
    return '$field, empty';
  }

  @override
  String formFieldValue(String field, String value) {
    return '$field: $value';
  }

  @override
  String formPasswordLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
    );
    return '$_temp0';
  }

  @override
  String formHeard(String field, String value) {
    return '$field: $value.';
  }

  @override
  String formComplete(String hint) {
    return 'All filled in. $hint';
  }

  @override
  String formChange(String field) {
    return '$field. Speak or type to change it.';
  }

  @override
  String formCleared(String field, String prompt) {
    return '$field cleared. $prompt';
  }

  @override
  String formMissing(String fields) {
    return 'Still missing: $fields.';
  }

  @override
  String get helpForm =>
      'Speak to answer the question, or type it. Swipe right or left: move between fields. Tap: repeat the question. Long-press: speak. Double-tap, or say “submit” or “done”: submit. Say “clear”: clear the field. Two-finger swipe right: go back.';

  @override
  String get fieldFirstName => 'First Name';

  @override
  String get fieldLastName => 'Last Name';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldNewPassword => 'New password';

  @override
  String get fieldAnswer => 'Answer';

  @override
  String get askFirstName => 'What is your first name?';

  @override
  String get askLastName => 'What is your last name?';

  @override
  String get askEmail => 'What is your email address?';

  @override
  String get askNewPassword => 'Make a password of at least 8 characters.';

  @override
  String get askPassword => 'What is your password?';

  @override
  String askAnswer(String question) {
    return '$question Say or type the answer.';
  }

  @override
  String get emailInvalid =>
      'That email address doesn\'t look right. Example: juan@gmail.com. By voice, say “at” for @ and “dot” for a period.';

  @override
  String get emailTaken =>
      'That email already has an account on this phone. Log in, or use another email.';

  @override
  String passwordTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'only $count',
      one: 'only 1',
    );
    return 'The password must be at least 8 characters. It has $_temp0.';
  }

  @override
  String get screenRegister => 'Register';

  @override
  String get registerWorking => 'Creating your account…';

  @override
  String registerDone(String name) {
    return 'Your account is ready, $name.';
  }

  @override
  String get helpLogin =>
      'Speak or type your email and password. Double-tap, or say “submit” or “done”: log in. Say “forgot”: reset the password. Two-finger swipe right: go back.';

  @override
  String get loginFingerprintIntro =>
      'Put your finger on the fingerprint sensor to log in, or use your password.';

  @override
  String get loginWrong => 'Wrong email or password.';

  @override
  String loginAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more tries',
      one: '1 more try',
    );
    return '$_temp0 before you must wait.';
  }

  @override
  String loginWelcomeBack(String name) {
    return 'Welcome back, $name.';
  }

  @override
  String lockoutStarted(int seconds) {
    return 'Too many wrong tries. Wait $seconds seconds before trying again.';
  }

  @override
  String lockoutWait(int seconds) {
    return 'Wait $seconds seconds.';
  }

  @override
  String get lockoutOver => 'You can try again now.';

  @override
  String get fingerprintReason => 'Use your fingerprint to log in to Percipere';

  @override
  String fingerprintFailed(String prompt) {
    return 'The fingerprint wasn\'t recognized. Use your password. $prompt';
  }

  @override
  String fingerprintUnavailable(String prompt) {
    return 'The fingerprint can\'t be used right now. Use your password. $prompt';
  }

  @override
  String get authChoiceQuestion => 'Do you want to log in to your account?';

  @override
  String get sessionExpired => 'Your session has ended.';

  @override
  String get helpChooseList =>
      'Swipe right or left: move between choices. Double-tap: choose. You can also say the choice. Two-finger swipe right: go back.';

  @override
  String get screenSecurityQuestion => 'Security question';

  @override
  String get securityChoose =>
      'Choose a security question. It is used if you forget your password.';

  @override
  String get securityQFirstPet => 'What was the name of your first pet?';

  @override
  String get securityQBirthTown => 'In which town were you born?';

  @override
  String get securityQMotherMaiden => 'What is your mother\'s maiden name?';

  @override
  String get securityQFirstSchool => 'What was the name of your first school?';

  @override
  String get securityQFavoriteFood => 'What is your favorite food?';

  @override
  String get securitySaved => 'Your security question is saved.';

  @override
  String get securityRequired =>
      'A security question is needed to reset your password. Choose one.';

  @override
  String get screenFingerprint => 'Fingerprint';

  @override
  String get fingerprintOffer =>
      'Do you want to use your fingerprint to log in?';

  @override
  String get fingerprintOn => 'Fingerprint login is on.';

  @override
  String get fingerprintNotSet =>
      'Fingerprint login wasn\'t turned on. You can turn it on later in Settings.';

  @override
  String get fingerprintSkipped => 'Okay, password only.';

  @override
  String get fingerprintNoSensor => 'No fingerprint is set up on this phone.';

  @override
  String get screenForgotPassword => 'Forgot password';

  @override
  String get forgotIntro =>
      'You\'ll answer your security question to make a new password.';

  @override
  String get forgotAdmin => 'The administrator can also reset your account.';

  @override
  String get forgotNoQuestion =>
      'There\'s no account with a security question for this email on this phone.';

  @override
  String get forgotWrongAnswer => 'That answer is wrong.';

  @override
  String get forgotDone => 'Your password is changed. Log in now.';

  @override
  String get screenLegacyAccount => 'Old account';

  @override
  String get legacyChoose => 'Choose your old PIN account.';

  @override
  String get legacyNone => 'There are no old accounts on this phone.';

  @override
  String legacyClaimed(String name) {
    return 'Right PIN, $name. Now set an email and password.';
  }

  @override
  String get screenUpgradeAccount => 'Update account';

  @override
  String get upgradeIntro =>
      'PINs are no longer used. Set an email and password; your settings and history stay.';

  @override
  String get upgradeDone => 'Your account is updated.';

  @override
  String get upgradeLeave =>
      'Going back logs you out of this account. Are you sure?';

  @override
  String setupProgress(int step, int total) {
    return 'Step $step of $total.';
  }

  @override
  String get setupSummaryTitle => 'Summary.';

  @override
  String get setupChoiceHow =>
      'Say your answer, or swipe right to choose and double-tap to press.';

  @override
  String get setupNavHowVoice =>
      'Say “voice” or “gestures”, or swipe right to choose and double-tap to press.';

  @override
  String get setupSeesQuestion =>
      'Can you see at least some text on the screen?';

  @override
  String get setupSizeQuestion => 'Can you read the text well?';

  @override
  String get setupSizeHow =>
      'Swipe up or say “bigger” to enlarge; swipe down or say “smaller” to shrink. Double-tap or say “okay” when it\'s right.';

  @override
  String setupSizeValue(int size) {
    return 'Text size: $size.';
  }

  @override
  String get setupColorQuestion => 'Which text color do you want?';

  @override
  String get setupCycleHow =>
      'Swipe right or left, or say “next” or “previous”, to change it. Double-tap or say “okay” when it\'s right.';

  @override
  String setupColorValue(String color) {
    return 'Color: $color.';
  }

  @override
  String get setupLanguageQuestion =>
      'Do you want the voice in English or in Tagalog?';

  @override
  String get setupLanguageHow =>
      'Swipe right to hear each one, and double-tap to choose. Or say “Tagalog” or “English”.';

  @override
  String get setupVoiceSample => 'This is the English voice.';

  @override
  String get setupFilipinoMissing =>
      'There is no Filipino voice on this phone. Do you want to open text-to-speech settings to install it?';

  @override
  String setupLanguageChosen(String language) {
    return 'Chosen: $language.';
  }

  @override
  String get setupSpeedQuestion => 'Do you want the voice faster?';

  @override
  String get setupSpeedHow =>
      'Swipe up or say “faster”; swipe down or say “slower”. Double-tap or say “okay” when it\'s right.';

  @override
  String setupSpeedValue(String rate) {
    return 'Speed: ${rate}x.';
  }

  @override
  String get setupPitchQuestion => 'Do you want to change the voice\'s tone?';

  @override
  String get setupPitchHow =>
      'Swipe up or say “higher”; swipe down or say “lower”. Double-tap or say “okay” when it\'s right.';

  @override
  String setupPitchValue(String pitch) {
    return 'Tone: $pitch.';
  }

  @override
  String get setupThemeQuestion => 'Which theme do you want to start with?';

  @override
  String setupThemeValue(String theme) {
    return 'Theme: $theme.';
  }

  @override
  String get themeCreamNavy => 'Cream & Navy';

  @override
  String get themeDarkYellow => 'Dark mode with yellow text';

  @override
  String get themeDarkWhite => 'Dark mode with white text';

  @override
  String get textColorReset =>
      'The text color was changed so it\'s easier to read.';

  @override
  String get setupVibrationQuestion =>
      'Do you want the phone to vibrate when you do something?';

  @override
  String get setupAutoReadQuestion =>
      'Do you want documents read automatically after they are uploaded or scanned?';

  @override
  String get setupSummaryQuestion => 'Is everything right?';

  @override
  String setupSummaryPrompt(String items) {
    return 'Here is what you chose: $items. Is everything right? Double-tap or say “yes” to finish. To change one, say for example “back to speed”, or swipe and double-tap.';
  }

  @override
  String summaryNavMode(String value) {
    return 'Navigation: $value';
  }

  @override
  String summaryLanguage(String value) {
    return 'Voice language: $value';
  }

  @override
  String summaryVibration(String value) {
    return 'Vibration: $value';
  }

  @override
  String summaryAutoRead(String value) {
    return 'Auto-read: $value';
  }

  @override
  String setupAtLimit(String value) {
    return 'That\'s the limit. $value';
  }

  @override
  String get setupSkipped => 'Skipped. The default is kept.';

  @override
  String get setupLeave =>
      'This is the first step. Do you want to go back to Welcome? You\'ll be logged out.';

  @override
  String get setupFinished =>
      'Setup is done. You can change it any time in Settings.';

  @override
  String get setupSample =>
      'Percipere helps you read letters, receipts and books. This is how the text will look.';

  @override
  String get setupPreviewLabel => 'Sample text';

  @override
  String get helpSetupChoice =>
      'Swipe right or left: move between answers. Double-tap: choose. Or say the answer.';

  @override
  String get helpSetupVertical =>
      'Swipe up or down: change it. Double-tap or say “okay”: done.';

  @override
  String get helpSetupHorizontal =>
      'Swipe right or left: change it. Double-tap or say “okay”: done.';

  @override
  String get helpSetupCommon =>
      'Tap or say “repeat”: repeat the question. Say “skip”: skip and keep the default. Two-finger swipe right, or say “back”: previous step.';

  @override
  String get helpSetupSummary =>
      'Double-tap or say “yes”: finish. Swipe right or left: move through your choices, and double-tap to change one. Or say “back to” and its name, for example “back to speed”.';

  @override
  String get langTagalog => 'Tagalog';

  @override
  String get langEnglishBoth => 'English';

  @override
  String get setTheme => 'Theme';

  @override
  String get setTextColor => 'Text color';

  @override
  String get setAutoRead => 'Auto-read documents';

  @override
  String get setStayLoggedIn => 'Stay logged in';

  @override
  String get setFingerprint => 'Fingerprint login';

  @override
  String get setRedoSetup => 'Redo setup';

  @override
  String get setRedoSetupValue => 'Answer the questions again';

  @override
  String get setLogout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get logoutGuestConfirm =>
      'You\'ll leave the guest profile. It stays on this phone. Are you sure?';

  @override
  String get loggedOut => 'You\'re logged out.';

  @override
  String get setupSpeedSample => 'This is how fast the voice is.';

  @override
  String get setupPitchSample => 'This is how the voice sounds.';
}
