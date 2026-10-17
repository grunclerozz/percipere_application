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
    return 'Is this what you meant: “$phrase”? Say yes or no.';
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
  String get gestureHoldListenAction => 'Listen now';

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
  String get uploadFailed =>
      'I couldn\'t get the file you chose. Please try again, or choose another file.';

  @override
  String get readerFileMissing =>
      'The file was gone before I could read it. Please try again.';

  @override
  String get readerOcrFailed =>
      'The text reader on this phone didn\'t work just now. The file isn\'t damaged. Please try again.';

  @override
  String get readerExtractFailed =>
      'Something went wrong while I was reading the file. It\'s probably not damaged. Please try again.';

  @override
  String get readerSaveFailed =>
      'You can read it, but I couldn\'t save it to the Library.';

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
  String get readerSaved => 'Saved to the Library.';

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
      'Double-tap: read or pause. Swipe right or left: next or previous sentence. Two-finger swipe down or up: next or previous paragraph. Swipe up or down: faster or slower. Tap: repeat the sentence. Two-finger swipe right: go back. Tap A plus or A minus above the document, or pinch the document box, to make the text bigger or smaller. Voice commands: read, pause, resume, next, previous, next paragraph, faster, slower, bigger, smaller, repeat, from the beginning, save, and back. While reading, you can say pause, stop, faster, slower, bigger, smaller, favorite, repeat, or back at any time. This works best with earphones. Long-press the gesture area to stop at once and listen.';

  @override
  String get captureDescribe => 'Describe';

  @override
  String get describeAnnouncement =>
      'You can also try our new feature: Describe. It tells you what is in a picture.';

  @override
  String get describeExplanation =>
      'Describe is for pictures without text, or when you want to know what is in a picture. Take a photo with the camera or upload a picture, and we will tell you what we see. If you are online, you can ask for a more detailed description.';

  @override
  String get screenDescribe => 'Describe';

  @override
  String get describeSourcePrompt => 'How would you like to get the picture?';

  @override
  String get describeWorking => 'Looking at the picture…';

  @override
  String describeLooksLike(String items) {
    return 'It looks like there is $items in the picture.';
  }

  @override
  String get describeAnd => 'and';

  @override
  String get describeNothing =>
      'I can\'t tell what is in the picture. Try again with brighter light.';

  @override
  String get describeReminder =>
      'Reminder: please confirm this with someone you trust before using it.';

  @override
  String get describeTextFound =>
      'I also found some text. Would you like me to read it?';

  @override
  String get describeNoText => 'No text was found in this picture.';

  @override
  String get describeDetailOffer =>
      'Would you like a more detailed description?';

  @override
  String get describeNeedsInternet =>
      'A detailed description needs internet. Try again when you are online.';

  @override
  String get describeConsentAsk =>
      'The picture will be sent to our server and to Google\'s service to describe it. Is that okay?';

  @override
  String get describeConsentDeclined =>
      'Okay, I won\'t send the picture. You can change this in Settings.';

  @override
  String get describeDetailFailed =>
      'I can\'t get the detailed description right now. Try again later.';

  @override
  String get describeUnreadable => 'I can\'t open this picture.';

  @override
  String get describeRepeat => 'Repeat';

  @override
  String get describeMore => 'More detail';

  @override
  String get describeReadText => 'Read the text';

  @override
  String get describeSave => 'Save';

  @override
  String get describeNew => 'New picture';

  @override
  String get describeThumbnailLabel => 'The picture';

  @override
  String get helpDescribe =>
      'Swipe right or left to choose an option, and double-tap to use it. Options: repeat, more detail, read the text, save, and new picture. Pinch the box to make the text bigger or smaller. Two-finger swipe right: go back.';

  @override
  String get sourceDescription => 'picture (Describe)';

  @override
  String get setDescribeConsent => 'Detailed descriptions';

  @override
  String get valueConsentAsk => 'Ask first';

  @override
  String get valueConsentAllowed => 'Allowed';

  @override
  String get valueConsentDeclined => 'Not allowed';

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
  String get passwordVisibleNotice =>
      'The password is visible while you type. Press the eye to hide it.';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get passwordShow => 'Show password';

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
  String get setupSpeedQuestion => 'Speech speed. How fast do you want it?';

  @override
  String get setupSpeedHow =>
      'Swipe right to hear each speed, and double-tap to choose. Or say “slow”, “medium” or “fast”.';

  @override
  String get speedSlow => 'Slow';

  @override
  String get speedMedium => 'Medium';

  @override
  String get speedFast => 'Fast';

  @override
  String get speedSampleSentence => 'This is how fast I speak.';

  @override
  String setupSpeedChosen(String speed) {
    return 'Chosen: $speed.';
  }

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
  String summarySpeed(String value) {
    return 'Speed: $value';
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
  String get setListenWhileReading => 'Listen while reading';

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

  @override
  String get screenHome => 'Home';

  @override
  String get homePrompt => 'What would you like to do?';

  @override
  String get homeRead => 'Read something new';

  @override
  String get homeLibrary => 'Library';

  @override
  String get screenLibrary => 'Library';

  @override
  String get libraryPrompt =>
      'Swipe right or left to move between items, and up or down to move between shelves. Double-tap to open the details.';

  @override
  String get libraryNewBooks => 'There are new books in the Library.';

  @override
  String get shelfControls => 'Search and filters';

  @override
  String get shelfContinue => 'Continue reading';

  @override
  String get shelfDocuments => 'My documents';

  @override
  String get shelfCollections => 'Collections';

  @override
  String get shelfBooks => 'Books';

  @override
  String get shelfResults => 'Results';

  @override
  String shelfAnnounce(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$title, $_temp0';
  }

  @override
  String get emptyContinue => 'You have not started reading anything yet.';

  @override
  String get emptyDocuments =>
      'You have no documents yet. Scan or upload one to begin.';

  @override
  String get emptyCollections =>
      'You have no collections yet. Say “create a collection” to make one.';

  @override
  String get emptyBooks =>
      'There are no books right now. You need internet to see the books.';

  @override
  String get emptyResults => 'Nothing matches your choice.';

  @override
  String get emptyCollection => 'This collection is empty.';

  @override
  String get libSearch => 'Search';

  @override
  String get libFilter => 'Filter';

  @override
  String get libNewCollection => 'Create a collection';

  @override
  String get filterAll => 'All';

  @override
  String get filterDocuments => 'My documents';

  @override
  String get filterBooks => 'Books';

  @override
  String get filterDownloaded => 'Downloaded';

  @override
  String get filterFinished => 'Finished';

  @override
  String get filterFavorites => 'Has favorites';

  @override
  String filterChanged(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Filter: $name, $_temp0.';
  }

  @override
  String get librarySearchPrompt =>
      'Say what you are looking for after the beep.';

  @override
  String libraryItemTitleAuthor(String title, String author) {
    return '$title, by $author';
  }

  @override
  String libraryItemTitleType(String title, String type) {
    return '$title, $type';
  }

  @override
  String libraryPercent(int percent) {
    return '$percent percent';
  }

  @override
  String get libraryFinishedWord => 'finished';

  @override
  String get libraryNotStartedWord => 'not started';

  @override
  String libraryLastRead(String when) {
    return 'last read $when';
  }

  @override
  String get libraryNewLabel => 'New';

  @override
  String get libraryDownloadedWord => 'downloaded';

  @override
  String get libraryUnavailableWord => 'no longer available';

  @override
  String get whenToday => 'today';

  @override
  String get whenYesterday => 'yesterday';

  @override
  String whenDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get formatEpub => 'EPUB';

  @override
  String libraryCollectionLine(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Collection: $name, $_temp0';
  }

  @override
  String get libraryNeedsInternet =>
      'You need internet to read this. Download it when you are online.';

  @override
  String libraryOpening(String title) {
    return 'Opening $title.';
  }

  @override
  String libraryNotFound(String query) {
    return 'I could not find “$query” in the Library.';
  }

  @override
  String get collectionNamePrompt =>
      'Say the name of the collection after the beep.';

  @override
  String collectionCreated(String name) {
    return 'Created the collection $name.';
  }

  @override
  String collectionOptions(String name) {
    return 'Options for the collection $name. Swipe to choose: Open, Rename, or Delete.';
  }

  @override
  String collectionRenamed(String name) {
    return 'Collection renamed: $name.';
  }

  @override
  String collectionDeleteConfirm(String name) {
    return 'Delete the collection $name? Its items will not be deleted.';
  }

  @override
  String collectionDeleted(String name) {
    return 'Deleted the collection $name.';
  }

  @override
  String collectionOpened(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Collection: $name, $_temp0.';
  }

  @override
  String bookRemovedNotice(String title) {
    return '$title was removed from the Library. Your progress is still yours.';
  }

  @override
  String get screenItemDetails => 'Details';

  @override
  String get detailsNotStarted => 'Not started yet.';

  @override
  String get detailsFinished => 'You have finished reading this.';

  @override
  String detailsProgress(int percent) {
    return '$percent percent read.';
  }

  @override
  String detailsMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'About $_temp0 left.';
  }

  @override
  String get detailsLessThanMinute => 'Less than a minute left.';

  @override
  String get actContinue => 'Continue';

  @override
  String get actRead => 'Read';

  @override
  String get actFromStart => 'Read from the beginning';

  @override
  String get actFavorites => 'Favorites';

  @override
  String get actChapters => 'Chapters';

  @override
  String get actAddToCollection => 'Add to collection';

  @override
  String get actDownload => 'Download';

  @override
  String actDownloadSized(String size) {
    return 'Download, $size';
  }

  @override
  String get actRemoveDownload => 'Remove download';

  @override
  String get actMarkFinished => 'Mark as finished';

  @override
  String get actMarkUnfinished => 'Mark as unfinished';

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String get bookLoading => 'Getting the book…';

  @override
  String bookLoadingPercent(int percent) {
    return '$percent percent done.';
  }

  @override
  String get bookPreparing => 'Preparing the book…';

  @override
  String downloadDone(String title) {
    return '$title was downloaded.';
  }

  @override
  String downloadRemoved(String title) {
    return 'The download of $title was removed.';
  }

  @override
  String downloadLowStorage(String size) {
    return 'The phone is low on space. This needs about $size. Do you still want to go on?';
  }

  @override
  String bookUnavailable(String title) {
    return '$title is no longer available.';
  }

  @override
  String get bookDrm =>
      'This EPUB is protected by DRM, so the app cannot open it.';

  @override
  String get bookInvalid => 'This file is damaged or is not a valid book.';

  @override
  String get bookEmpty => 'No text could be read in this book.';

  @override
  String get bookFailed =>
      'There was a problem getting the book. Please try again later.';

  @override
  String bookUpdateOffer(String title) {
    return 'There is a new version of $title. Update the download? Your progress will be kept.';
  }

  @override
  String bookUpdated(String title) {
    return '$title was updated.';
  }

  @override
  String markedFinished(String title) {
    return '$title was marked as finished.';
  }

  @override
  String markedUnfinished(String title) {
    return '$title was marked as not finished.';
  }

  @override
  String collectionPickIntro(String title) {
    return 'Add $title to which collection? Swipe to choose, double-tap to add or remove.';
  }

  @override
  String get collectionPickNone =>
      'You have no collections yet. Create one in the Library first.';

  @override
  String collectionPickIn(String name) {
    return '$name, already in';
  }

  @override
  String collectionAdded(String title, String name) {
    return '$title was added to $name.';
  }

  @override
  String collectionItemRemoved(String title, String name) {
    return '$title was removed from $name.';
  }

  @override
  String get guestDownloadWarning =>
      'Reminder: your books are only saved on this phone. If the app is erased, they will be lost. Register to save your Library and open it on another device. Do you want to register now?';

  @override
  String get guestDocumentsStayHere =>
      'The documents you scan or upload stay on this phone and are never sent to the server, for your privacy.';

  @override
  String get screenFavorites => 'Favorites';

  @override
  String favoritesIntro(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are saved',
      one: '1 is saved',
    );
    return 'Favorites in $title. $_temp0. Swipe to choose, double-tap to go there.';
  }

  @override
  String favoritesEmpty(String title) {
    return 'You have no favorites in $title yet. Say “favorite” while reading.';
  }

  @override
  String favoriteLine(String chapter, String label) {
    return '$chapter: $label';
  }

  @override
  String get optGoHere => 'Go here';

  @override
  String get favoriteOptions => 'Options: Go here, or Delete. Swipe to choose.';

  @override
  String favoriteDeleteConfirm(String label) {
    return 'Delete the favorite “$label”?';
  }

  @override
  String get favoriteDeleted => 'Favorite deleted.';

  @override
  String get readerFavorite => 'Favorite';

  @override
  String get readerFavoriteSaved => 'Saved as a favorite';

  @override
  String readerChapter(String title) {
    return '$title.';
  }

  @override
  String get readerNoChapters => 'This document has no chapters.';

  @override
  String readerFinishedTitle(String title) {
    return 'You have finished reading $title.';
  }

  @override
  String get screenChapters => 'Chapters';

  @override
  String chaptersIntro(String title, int count) {
    return 'Chapters of $title. $count in all. Swipe to choose, double-tap to go there.';
  }

  @override
  String get chaptersNone => 'This item has no chapters.';

  @override
  String chapterLine(int number, String title) {
    return '$number. $title';
  }

  @override
  String chapterFallback(int number) {
    return 'Chapter $number';
  }

  @override
  String get helpHome =>
      'Swipe right or left to choose, and double-tap to open. Say “read something new” or “library”. To hear the tutorial again, say “tutorial”.';

  @override
  String get helpLibrary =>
      'Swipe right or left to move between items. Swipe up or down to move between shelves. Double-tap to open the details. Say “continue” and the title to resume at once, or “search” to look for something.';

  @override
  String get helpItemDetails =>
      'Swipe right or left to choose an action, and double-tap to do it. The first one is reading.';

  @override
  String get helpFavorites =>
      'Swipe right or left to choose a favorite. Double-tap to go there. Swipe up for options.';

  @override
  String get helpChapters =>
      'Swipe right or left to choose a chapter, and double-tap to go there.';

  @override
  String get libraryEdgeSide => 'End of the shelf.';

  @override
  String get libraryEdgeTop => 'You are at the top.';

  @override
  String get libraryEdgeBottom => 'You are at the bottom.';

  @override
  String get verbosityAuto => 'Automatic';

  @override
  String whereAmIScreen(String screen) {
    return 'You\'re on $screen.';
  }

  @override
  String whereAmIFocused(String item) {
    return 'Selected: $item.';
  }

  @override
  String whatCanIDo(String commands) {
    return 'Here you can say: $commands.';
  }

  @override
  String get askMeHint =>
      'You can also ask me, for example “where am I?” or “what time is it?”.';

  @override
  String timeNow(String time) {
    return 'It\'s $time.';
  }

  @override
  String dateToday(String date) {
    return 'Today is $date.';
  }

  @override
  String voiceSuggest(String options) {
    return 'I didn\'t catch that. Did you mean: $options?';
  }

  @override
  String get voiceNotUnderstood =>
      'I didn\'t catch that. Say “what can I do” to hear the commands.';

  @override
  String get voiceOfferHelp =>
      'If you\'re stuck, say “how to use” for a short tutorial.';

  @override
  String voiceWhichOne(String first, String second) {
    return 'Which one: $first, or $second? Say its name.';
  }

  @override
  String get docNeedsOpenDoc => 'Open a document first, then ask me that.';

  @override
  String get docTypeReceipt => 'This looks like a receipt.';

  @override
  String get docTypeBill => 'This looks like a bill.';

  @override
  String get docTypeMedicine =>
      'This looks like a medicine label or prescription.';

  @override
  String get docTypeLetter => 'This looks like a letter.';

  @override
  String get docTypeForm => 'This looks like a form to fill in.';

  @override
  String get docTypeOther => 'I\'m not sure what kind of document this is.';

  @override
  String docFrom(String from) {
    return 'From: $from.';
  }

  @override
  String docLetterTo(String name) {
    return 'Addressed to $name.';
  }

  @override
  String docTotal(String amount) {
    return 'Total: $amount pesos.';
  }

  @override
  String docDue(String date) {
    return 'Due on $date.';
  }

  @override
  String docExpiry(String date) {
    return 'Expires on $date.';
  }

  @override
  String docDosage(String dosage) {
    return 'How to take it: $dosage';
  }

  @override
  String get docNoTotal =>
      'I couldn\'t find a total or amount in this document.';

  @override
  String get docNoDue => 'I couldn\'t find a due date in this document.';

  @override
  String get docNoExpiry => 'I couldn\'t find an expiry date in this document.';

  @override
  String get docNoDosage =>
      'I couldn\'t find dosage instructions in this document.';

  @override
  String docSummary(String text) {
    return 'Summary: $text';
  }

  @override
  String get docNoSummary => 'The document is too short to summarize.';

  @override
  String get docAskHint =>
      'You can ask me about it, for example “how much?” or “summarize”.';

  @override
  String readerProgress(String current, String total, String percent) {
    return 'You\'re at sentence $current of $total, about $percent percent.';
  }

  @override
  String readerProgressChapter(String chapter, String chapters) {
    return 'Chapter $chapter of $chapters.';
  }

  @override
  String get setTutorial => 'How to use the app';

  @override
  String get setTutorialValue => 'Controls tutorial';

  @override
  String get screenTutorial => 'Learning the controls';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialPercy =>
      'Hello! I\'m Percy, the voice assistant of Percipere. Call me by swiping left with two fingers, or by saying “Percy”. Try “read it”, “open the Library” or “go back”. I work offline. Double-tap anywhere to continue.';

  @override
  String get tutorialIntro =>
      'I\'ll show you how to use Percipere with your fingers and your voice. It takes about two minutes. Double-tap anywhere on the screen to start. To skip, swipe right with two fingers, or say “skip”.';

  @override
  String get tutorialSwipeRight =>
      'To move to the next option, swipe right with one finger. Try it now.';

  @override
  String get tutorialSwipeLeft =>
      'To go back to the previous option, swipe left. Try it.';

  @override
  String get tutorialDoubleTap =>
      'To choose an option, double-tap anywhere on the screen. Try it.';

  @override
  String get tutorialTap => 'To hear what I said again, tap once. Try it.';

  @override
  String get tutorialBack =>
      'To go back to the previous screen, swipe right with two fingers. Try it.';

  @override
  String get tutorialHelp =>
      'To get help on any screen, tap with three fingers. Try it.';

  @override
  String get tutorialLongPress =>
      'To say a command, press and hold the screen until you hear a sound. Try it.';

  @override
  String get tutorialSay => 'Now say “help”.';

  @override
  String get tutorialVoiceInfo =>
      'In voice mode I listen after I finish talking, so you don\'t need to press anything. While I\'m reading you can say “pause” or “faster”. You can also ask me: “where am I?”, “what can I do?”, and with a document open, “how much?” or “summarize”. Double-tap to continue.';

  @override
  String get tutorialDone =>
      'All done! Remember: swipe to move, double-tap to choose, two fingers right to go back, and press and hold to talk. Say “how to use” any time to do this again. Double-tap to continue.';

  @override
  String get tutorialGood => 'Well done!';

  @override
  String get tutorialGoodAlt => 'That\'s right!';

  @override
  String get tutorialWrong => 'That wasn\'t the one. Try again.';

  @override
  String get tutorialMovingOn => 'That\'s okay. Let\'s move on.';

  @override
  String get tutorialSkipped =>
      'Tutorial skipped. Say “how to use” if you want to do it later.';

  @override
  String get tutorialSkipQuestion => 'Do you want to skip the tutorial?';

  @override
  String get tutorialNoMic =>
      'The microphone isn\'t allowed yet, so we\'ll skip the voice practice.';

  @override
  String get assistantNotSetUp =>
      'Percy, the voice assistant, isn\'t set up yet. Use the usual commands for now.';

  @override
  String get assistantOffline =>
      'Percy needs the internet. The usual commands still work.';

  @override
  String get assistantConsentAsk =>
      'This is the online developer version of Percy, which uses the internet. What you say, and the text of a document when you ask about it, is sent to ElevenLabs to understand you. Is that okay?';

  @override
  String get assistantConsentDeclined =>
      'Okay, Percy won\'t be used for now. You can call Percy again whenever you like.';

  @override
  String get assistantMicNeeded =>
      'Percy needs the microphone. Allow it in the app\'s settings.';

  @override
  String get assistantConnecting => 'Calling Percy.';

  @override
  String get assistantEnded => 'Goodbye from Percy for now.';

  @override
  String get assistantFailed =>
      'I can\'t reach Percy right now. Please try again later. The usual commands still work.';

  @override
  String get assistantFirstMessage => 'Hi! I\'m Percy. How can I help you?';

  @override
  String get assistantHowToCall =>
      'To call Percy, the voice assistant, swipe left with two fingers, or say “Percy”. To finish, say “goodbye” or swipe.';

  @override
  String get assistantGuestName => 'friend';

  @override
  String get setPercyPoliteness => 'Percy\'s manner';

  @override
  String get valuePercyPo => 'Polite (with po)';

  @override
  String get valuePercyCasual => 'Casual';

  @override
  String get setPercyTalk => 'Percy\'s answers';

  @override
  String get valuePercyBrief => 'Short';

  @override
  String get valuePercyNormal => 'Normal';

  @override
  String get valuePercyChatty => 'Chatty';

  @override
  String get setPercyLogging => 'Save talks with Percy (for training)';

  @override
  String get setPercyElevenLabs => 'Percy online (ElevenLabs, developer)';

  @override
  String get setPercyAnalysis => 'Percy analysis (developer)';

  @override
  String get percyAnalysisTitle => 'Percy analysis';

  @override
  String get percyAnalysisEmpty => 'Nothing has been said to Percy yet.';

  @override
  String percyAnalysisHeard(String text) {
    return 'Heard: $text';
  }

  @override
  String percyAnalysisLanguage(String language, int fil, int en) {
    return 'Language: $language (fil $fil · en $en)';
  }

  @override
  String get percyAnalysisLangFilipino => 'Filipino';

  @override
  String get percyAnalysisLangEnglish => 'English';

  @override
  String get percyAnalysisLangTaglish => 'Taglish';

  @override
  String percyAnalysisIntent(String intent, String confidence) {
    return 'Intent: $intent · confidence $confidence';
  }

  @override
  String get percyAnalysisNoIntent => 'Intent: — (exact command)';

  @override
  String percyAnalysisTop(String list) {
    return 'Top 3: $list';
  }

  @override
  String percyAnalysisAction(String action) {
    return 'Action: $action';
  }

  @override
  String percyAnalysisCount(int count) {
    return '$count sentences';
  }

  @override
  String get setPercyExport => 'Export Percy\'s log (CSV)';

  @override
  String percyExportCount(String count) {
    return '$count sentences';
  }

  @override
  String get percyExportEmpty => 'Nothing has been said to Percy yet.';

  @override
  String get percyExportDone => 'The CSV is ready. Choose where to send it.';

  @override
  String get percyExportFailed => 'I can\'t export the log right now.';

  @override
  String get percyMicNeeded =>
      'Percy needs the microphone to hear you. Allow it in the app\'s settings.';

  @override
  String get percyUnavailable =>
      'I can\'t start Percy right now. The usual commands still work.';

  @override
  String get voiceSayAgain => 'Sorry, please say that again.';

  @override
  String get speedStripLabel => 'Speed';

  @override
  String speedStripValue(String rate) {
    return 'Speed, $rate times';
  }

  @override
  String speedSpoken(String rate) {
    return 'Speed $rate';
  }

  @override
  String get speedIncrease => 'Increase speed';

  @override
  String get speedDecrease => 'Decrease speed';

  @override
  String get setReadingVoice => 'Reading voice';

  @override
  String get valueVoiceDefault => 'Default';

  @override
  String get valueVoiceFemale => 'Female';

  @override
  String get valueVoiceMale => 'Male';

  @override
  String valueVoiceNamed(String number, String name) {
    return 'Voice $number ($name)';
  }

  @override
  String get valueVoiceOnlyOne => 'Only one voice';

  @override
  String get voiceOnlyOne =>
      'This phone has only one voice for this language, so it can\'t be changed.';

  @override
  String voiceChanged(String voice) {
    return 'Voice changed to $voice.';
  }

  @override
  String get setVoicePreview => 'Preview voice';

  @override
  String get valueVoicePreview => 'Play a sample';

  @override
  String get voicePreviewSample =>
      'This is how the voice that reads your documents sounds.';

  @override
  String get screenVerifyEmail => 'Verify email';

  @override
  String get fieldCode => 'Code';

  @override
  String get askCode => 'What is the 6-digit code we emailed you?';

  @override
  String verifyIntro(String email) {
    return 'We sent a 6-digit code to $email. Check your email.';
  }

  @override
  String get codeNotSent =>
      'The code could not be sent. Say “send again” to try again.';

  @override
  String get actionResendCode => 'Send a new code';

  @override
  String get codeResent => 'We sent a new code.';

  @override
  String get codeWrong => 'That code is wrong or expired. Try again.';

  @override
  String get codeVoided =>
      'Too many wrong codes. Say “send again” for a new code.';

  @override
  String get codeFormat => 'The code has 6 digits.';

  @override
  String get accountPendingApproval =>
      'Your account is waiting for an administrator\'s approval.';

  @override
  String get accountSuspended =>
      'This account is suspended. Please contact the administrator.';

  @override
  String get accountSuspendedSignedOut =>
      'Your account was suspended, so you were logged out. Please contact the administrator.';

  @override
  String get serverUnreachable =>
      'Can\'t reach the server. Check the internet connection and try again.';

  @override
  String get serverProblem => 'The server had a problem. Try again later.';

  @override
  String get loginOffline =>
      'No internet, so the account saved on this tablet was used.';

  @override
  String get loginNeedsInternet =>
      'The first login on this tablet needs the internet.';

  @override
  String get accountMoving =>
      'We\'re moving your account to the server. We emailed you a code.';

  @override
  String get emailTakenServer =>
      'That email already has an account. Log in, or use another email.';

  @override
  String get resetIntro =>
      'We\'ll email you a code so you can make a new password.';

  @override
  String resetCodeSent(String email) {
    return 'If $email has an account, we\'ve emailed a code. Say the code, then the new password.';
  }

  @override
  String get resetDone => 'Your password is changed, and you\'re logged in.';

  @override
  String get helpVerify =>
      'Say the 6 digits of the code, or type them. Say “send again”: a new code. Double-tap, or say “submit” or “done”: submit. Two-finger swipe right: go back.';

  @override
  String get screenReportIssue => 'Report an issue';

  @override
  String get reportIntro => 'You\'ll answer a few questions, one at a time.';

  @override
  String get reportAskType => 'What kind of report is this?';

  @override
  String get reportTypeBug => 'Bug (something is broken)';

  @override
  String get reportTypeFeature => 'Feature request';

  @override
  String get reportTypeFeedback => 'General feedback';

  @override
  String get reportAskModule => 'Which part of the app?';

  @override
  String get reportModuleOcr => 'Text reading (OCR)';

  @override
  String get reportModuleCamera => 'Camera';

  @override
  String get reportModuleVoice => 'Voice commands';

  @override
  String get reportModuleAccounts => 'Accounts';

  @override
  String get reportModuleTts => 'Text-to-Speech';

  @override
  String get reportModuleGestures => 'Gesture Pad';

  @override
  String get reportModuleLibrary => 'Library (Aklatan)';

  @override
  String get reportModuleMaglarawan => 'Maglarawan (image description)';

  @override
  String get reportModulePercy => 'Percy';

  @override
  String get reportModuleOther => 'Other';

  @override
  String get reportAskSeverity => 'How bad is the problem?';

  @override
  String get reportSeverityLow => 'Low';

  @override
  String get reportSeverityMedium => 'Medium';

  @override
  String get reportSeverityHigh => 'High';

  @override
  String get reportSeverityCritical => 'Critical';

  @override
  String get reportSeverityLowLong => 'Low: a minor annoyance';

  @override
  String get reportSeverityMediumLong => 'Medium: it works, but wrong';

  @override
  String get reportSeverityHighLong => 'High: it doesn\'t work';

  @override
  String get reportSeverityCriticalLong =>
      'Critical: the app crashes or data is lost';

  @override
  String get reportAskDescription => 'What happened? Say it, or type it.';

  @override
  String get reportDescriptionHint => 'At least 10 characters.';

  @override
  String get fieldDescription => 'What happened';

  @override
  String get actionSpeak => 'Speak';

  @override
  String get actionNext => 'Next';

  @override
  String reportHeard(String v) {
    return 'I heard: $v. Is that right?';
  }

  @override
  String get reportSayAgain => 'Okay, say again what happened.';

  @override
  String get reportDescriptionShort => 'Too short. At least 10 characters.';

  @override
  String get reportDescriptionLong => 'Too long. At most 1000 characters.';

  @override
  String reportAskEmailUse(String v) {
    return 'Use this email: $v?';
  }

  @override
  String get reportAskEmail => 'What is your email? You may skip this.';

  @override
  String get reportEmailWhy =>
      'Your email is only used to reply to you about this report.';

  @override
  String get reportPrivacy =>
      'The report and email are only used to fix the app and reply to you (RA 10173).';

  @override
  String get reportEmailInvalid =>
      'That email looks wrong. Say it again, or say “skip”.';

  @override
  String reportEmailValue(String v) {
    return 'Email: $v.';
  }

  @override
  String get reportAskReview => 'Review your report. Say “send” or “edit”.';

  @override
  String reportLineType(String v) {
    return 'Type: $v';
  }

  @override
  String reportLineModule(String v) {
    return 'Part: $v';
  }

  @override
  String reportLineSeverity(String v) {
    return 'Severity: $v';
  }

  @override
  String reportLineDescription(String v) {
    return 'What happened: $v';
  }

  @override
  String reportLineEmail(String v) {
    return 'Email: $v';
  }

  @override
  String get reportNoEmail => 'no email';

  @override
  String reportLineDetails(
    String app,
    String os,
    String device,
    String screen,
    String date,
  ) {
    return 'Also attached: app version $app, $os, $device, from $screen, $date.';
  }

  @override
  String get actionSendReport => 'Send';

  @override
  String get actionEditReport => 'Edit';

  @override
  String get reportAskEdit => 'What do you want to change?';

  @override
  String get reportPartType => 'Type';

  @override
  String get reportPartModule => 'Part of the app';

  @override
  String get reportPartSeverity => 'Severity';

  @override
  String get reportPartDescription => 'What happened';

  @override
  String get reportPartEmail => 'Email';

  @override
  String get reportSending => 'Sending…';

  @override
  String get reportTicketTitle => 'Your ticket';

  @override
  String reportTicketLine(String v) {
    return 'Ticket: $v';
  }

  @override
  String reportTicketSpoken(String v) {
    return 'Your ticket number is $v.';
  }

  @override
  String reportLineDate(String v) {
    return 'Date: $v';
  }

  @override
  String reportLineStatus(String v) {
    return 'Status: $v';
  }

  @override
  String get reportStatusSent => 'Sent';

  @override
  String get reportStatusPending => 'Waiting to send';

  @override
  String get reportStatusFailed => 'Couldn\'t send';

  @override
  String get reportSavedOffline =>
      'The report is saved and will be sent when there\'s internet.';

  @override
  String get reportThanks => 'Thank you for your report.';

  @override
  String get actionRepeatTicket => 'Repeat';

  @override
  String get actionDone => 'Done';

  @override
  String get actionCancelReport => 'Cancel';

  @override
  String get reportCancelConfirm =>
      'Cancel the report? Your answers will be lost.';

  @override
  String get reportCancelled => 'Report cancelled.';

  @override
  String get helpReport =>
      'Swipe right or left: move between options. Double-tap, or say its name: choose. Say “back”: previous question. Say “cancel”: stop the report.';

  @override
  String get helpReportText =>
      'Speak to answer, or type. Long-press or say “speak”: speak again. Say “next”: go on. Say “back”: previous question. Say “cancel”: stop the report.';

  @override
  String get screenMyReports => 'My reports';

  @override
  String myReportsCount(String v) {
    return 'Reports: $v. Choose one to hear it.';
  }

  @override
  String get myReportsEmpty => 'You haven\'t sent a report yet.';

  @override
  String myReportsRow(String ticket, String type, String date, String status) {
    return '$ticket: $type, $date, $status';
  }

  @override
  String get setReportIssueValue => 'Tell us about a problem or idea';

  @override
  String get setMyReportsValue => 'Your reports and their status';

  @override
  String get reportSaveFailed =>
      'The report couldn\'t be saved. Please try again.';

  @override
  String get reportServerOpen => 'Received';

  @override
  String get reportServerInProgress => 'In progress';

  @override
  String get reportServerResolved => 'Resolved';

  @override
  String get reportServerClosed => 'Closed';

  @override
  String get setServerAddress => 'Server address (developer)';

  @override
  String get serverAddressTitle => 'Server address';

  @override
  String get serverAddressHelp =>
      'The dashboard folder, for example http://192.168.1.61/website/percipere_web/percipere_dashboard';

  @override
  String get serverAddressSave => 'Save';

  @override
  String get serverAddressReset => 'Back to the original';

  @override
  String get serverAddressCancel => 'Cancel';

  @override
  String get serverAddressInvalid =>
      'That is not a valid address. It must start with http:// or https://.';

  @override
  String get serverAddressCleartext =>
      'This build does not allow http:// to that host. Use https://, or make a new build with API_CLEARTEXT_HOSTS.';

  @override
  String get serverAddressSaved => 'Server address saved.';

  @override
  String get serverAddressResetDone =>
      'Server address set back to the original.';

  @override
  String get serverAddressNone => 'No server';

  @override
  String get voiceOfflineNone =>
      'There\'s no internet and no offline speech recognition is installed, so I can\'t hear you right now. Please use gestures for now. To make it work offline, download an offline language in the voice input settings; Settings, Voice check, has the guide.';

  @override
  String get voiceOfflineEnglish =>
      'There\'s no internet. I\'m using offline English recognition now, so commands in English, like next, pause or library, work best.';

  @override
  String get screenVoiceCheck => 'Voice check';

  @override
  String get setVoiceCheckValue => 'Listening, voice and offline';

  @override
  String get voiceCheckIntro =>
      'This is how listening and the app\'s voice are set up. Choose Test for a five-second test.';

  @override
  String voiceCheckRecognizer(String service) {
    return 'Speech recognition: $service.';
  }

  @override
  String voiceCheckLanguage(String locale) {
    return 'Listening language: $locale.';
  }

  @override
  String voiceCheckOfflineFilipino(String answer) {
    return 'Offline Filipino: $answer.';
  }

  @override
  String voiceCheckOfflineEnglish(String answer) {
    return 'Offline English: $answer.';
  }

  @override
  String voiceCheckMode(String mode) {
    return 'Listening right now: $mode.';
  }

  @override
  String get voiceCheckModeOnDevice => 'on the tablet itself, works offline';

  @override
  String get voiceCheckModeOnline => 'online, needs the internet';

  @override
  String get voiceCheckModeEnglish => 'offline English';

  @override
  String get voiceCheckModeNone =>
      'can\'t listen, no internet and no offline language';

  @override
  String voiceCheckInternet(String answer) {
    return 'Internet: $answer.';
  }

  @override
  String voiceCheckMic(String answer) {
    return 'Microphone permission: $answer.';
  }

  @override
  String voiceCheckTtsEngine(String engine) {
    return 'Speech engine: $engine.';
  }

  @override
  String voiceCheckTtsVoice(String voice, String where) {
    return 'Voice: $voice, $where.';
  }

  @override
  String get voiceCheckVoiceLocal => 'installed on the tablet, works offline';

  @override
  String get voiceCheckVoiceNetwork => 'needs the internet';

  @override
  String get voiceCheckFilipinoVoiceMissing =>
      'There\'s no Filipino voice on the tablet yet; English is used.';

  @override
  String get voiceCheckYes => 'yes';

  @override
  String get voiceCheckNo => 'no';

  @override
  String get voiceCheckUnknown => 'unknown';

  @override
  String get voiceCheckTest => 'Test, five seconds';

  @override
  String get voiceCheckTestSay => 'Say: open the Library.';

  @override
  String voiceCheckTestResult(
    String heard,
    String command,
    String intent,
    String percent,
    String confidence,
    String ms,
  ) {
    return 'Heard: $heard. Command: $command. Percy: $intent, $percent percent. Recognition confidence: $confidence. Response time: $ms milliseconds.';
  }

  @override
  String get voiceCheckTestNothing => 'Nothing was heard. Please try again.';

  @override
  String get voiceCheckNone => 'none';

  @override
  String get voiceCheckReadAgain => 'Read again';

  @override
  String get voiceCheckVoiceInput => 'Voice input settings';

  @override
  String get voiceCheckTtsSettings => 'Text-to-speech settings';

  @override
  String voiceCheckDownload(String language) {
    return 'Download offline $language';
  }

  @override
  String get voiceCheckDownloadStarted =>
      'The download has started. Check the tablet\'s notifications and come back here afterwards.';

  @override
  String get voiceCheckDownloadFailed =>
      'It can\'t be downloaded from here. Open the voice input settings and look for Offline speech recognition.';

  @override
  String get languageFilipino => 'Filipino';

  @override
  String get languageEnglish => 'English';

  @override
  String get screenOfflineVoice => 'Voices and languages';

  @override
  String get offlineVoiceWait =>
      'Please wait while we download the voices and languages.';

  @override
  String offlineVoiceSize(String size) {
    return 'It is about $size megabytes, only once.';
  }

  @override
  String offlineVoiceProgress(String percent) {
    return '$percent percent done.';
  }

  @override
  String get offlineVoiceReady =>
      'Ready. Voice now works even without internet.';

  @override
  String get offlineVoiceNoInternet =>
      'There is no internet right now, so the voices can\'t be downloaded yet. You can already use gestures, and voice while there is internet. I will continue the download when the internet is back.';

  @override
  String offlineVoiceLowStorage(String size) {
    return 'Not enough space on the tablet for the voices. About $size megabytes are needed. Delete some files, and I will try again.';
  }

  @override
  String get offlineVoiceFailed =>
      'The voice download did not finish. I will try again later.';

  @override
  String get offlineVoiceContinue => 'Continue while downloading';

  @override
  String get offlineVoiceContinueDone =>
      'I will keep downloading while you use the app.';

  @override
  String get offlineVoiceRetry => 'Try again';

  @override
  String offlineVoiceStatusDownloading(String percent) {
    return 'Downloading: $percent percent';
  }

  @override
  String get offlineVoiceStatusChecking => 'Checking what is needed…';

  @override
  String voiceCheckOfflineModels(String status) {
    return 'Percipere\'s own offline voices and commands: $status.';
  }

  @override
  String voiceCheckModelsInstalled(String versions) {
    return 'installed, version $versions';
  }

  @override
  String get voiceCheckModelsPartial => 'only partly installed';

  @override
  String get voiceCheckModelsMissing => 'not downloaded yet';

  @override
  String voiceCheckModelsDownloading(String percent) {
    return 'downloading, $percent percent';
  }

  @override
  String get voiceCheckModelsWaiting => 'waiting for internet';

  @override
  String get voiceCheckModelsLowStorage => 'not enough space';

  @override
  String get voiceCheckModelsFailed => 'the download did not finish';

  @override
  String get voiceCheckModeOffline => 'offline, Percipere\'s own engine';

  @override
  String get voiceCheckOfflineVoice => 'Percipere offline';

  @override
  String get voiceCheckRedownload => 'Download the voices again';

  @override
  String get voiceCheckRedownloadStarted => 'The voice download started again.';

  @override
  String get voiceCheckDeleteModels => 'Delete the offline voices';

  @override
  String get voiceCheckDeleteConfirm =>
      'Delete the offline voices and commands? Internet is needed to download them again.';

  @override
  String get voiceCheckModelsDeleted =>
      'The offline voices are deleted. When there is internet, I will download them again.';

  @override
  String get screenWerTest => 'Speech recognition test';

  @override
  String get werIntro => 'Read the sentence aloud. Press Listen, then say it.';

  @override
  String werSay(String phrase) {
    return 'Say: $phrase';
  }

  @override
  String get werListen => 'Listen';

  @override
  String get werNext => 'Next sentence';

  @override
  String get werExport => 'Export the results (CSV)';

  @override
  String get werClear => 'Delete the results';

  @override
  String get werClearConfirm => 'Delete all test results?';

  @override
  String get werCleared => 'The results are deleted.';

  @override
  String get werEmpty => 'No results yet.';

  @override
  String get werFailed => 'I could not listen properly. Try again.';

  @override
  String werResult(String heard, String percent, String s, String d, String i) {
    return 'Heard: $heard. WER $percent percent. Wrong: $s, missing: $d, extra: $i.';
  }

  @override
  String get qualityBlurry =>
      'The photo is blurry. Please hold the phone steadier.';

  @override
  String get qualityTooDark =>
      'The photo is too dark. Please move to a brighter place.';

  @override
  String get qualityTooBright =>
      'The photo is too bright. Please avoid direct light.';

  @override
  String get qualityRetake => 'Do you want to take it again?';

  @override
  String get qualityRetaking => 'Okay, let\'s take it again.';
}
