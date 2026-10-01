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
      'Tap to play or pause. Swipe right or left for the next or previous sentence. Swipe up or down to read faster or slower.';

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
  String get welcomeIntro =>
      'Welcome to Percipere, an app built on your behalf. How would you like to navigate the app? Double-tap anywhere on the screen for voice. Swipe right for gestures. Tap to hear this again.';

  @override
  String get helpWelcome =>
      'Double-tap: voice. Swipe right: gestures. Tap: repeat the question.';

  @override
  String get modeChosenVoice => 'You chose voice navigation.';

  @override
  String get modeChosenGestures => 'You chose gesture navigation.';

  @override
  String get readerReady => 'The document is ready.';

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
  String get alreadyAtStart => 'You\'re already on the first screen.';

  @override
  String helpTitle(String screen) {
    return 'Help for $screen.';
  }

  @override
  String get helpGesturesMenu =>
      'Swipe right or left: move between options. Double-tap: choose. Tap: repeat the question. Two-finger swipe down: go back. Long-press: speak a command. Two-finger double-tap: stop speaking. Three-finger tap: help.';

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
  String get welcomeSayHint => 'You can also say “voice” or “gestures”.';

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
      'Double-tap: take the photo. Tap: repeat the guidance. Two-finger swipe down: go back.';

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
  String get readerStartHint => 'Tap, or say “read”, to start.';

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
      'Tap: read or pause. Swipe right or left: next or previous sentence. Two-finger swipe right or left: next or previous paragraph. Swipe up or down: faster or slower. Double-tap: repeat the sentence. Two-finger swipe down: go back. Voice commands: read, pause, resume, next, previous, next paragraph, faster, slower, repeat, from the beginning, save, and back.';

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
      'Swipe right or left: move between settings. Swipe up or down: change the value. Double-tap: next option, or open. Two-finger swipe down: go back.';

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
  String get setColors => 'Colors';

  @override
  String get setNavMode => 'Navigation';

  @override
  String get setHaptics => 'Vibration';

  @override
  String get setVerbosity => 'Amount of speech';

  @override
  String get setAutoCapture => 'Automatic photo';

  @override
  String get setAccount => 'Account';

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
  String get paletteDefault => 'Default: cream and navy';

  @override
  String get paletteHighContrast => 'White on black';

  @override
  String get paletteYellow => 'Yellow on black';

  @override
  String get paletteBlackOnWhite => 'Black on white';

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
      'Swipe right or left: move between documents. Double-tap: open and continue reading. Swipe up: options such as rename and delete. Say “search” and a word to search. Two-finger swipe down: go back.';

  @override
  String get screenAccount => 'Account';

  @override
  String get accountIntroGuest =>
      'You\'re using Percipere without an account. Create a profile to save your settings.';

  @override
  String accountIntroUser(String name) {
    return 'Logged in as $name.';
  }

  @override
  String get accountCreate => 'Create a profile';

  @override
  String get accountLogin => 'Log in';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountLoggedOut => 'Logged out. Using this phone\'s settings.';

  @override
  String accountLoggedIn(String name) {
    return 'Welcome back, $name.';
  }

  @override
  String accountCreated(String name) {
    return 'Profile for $name created, and you\'re logged in.';
  }

  @override
  String get screenCreateProfile => 'New profile';

  @override
  String get profileAskName =>
      'What is your name? Long-press the gesture area and say it, or type it.';

  @override
  String profileNameIs(String name) {
    return 'Name: $name. Double-tap to continue, or long-press to say it again.';
  }

  @override
  String get profileAskEmail =>
      'Email, if you have one. Long-press to say it, or type it. Swipe right to skip.';

  @override
  String profileEmailIs(String email) {
    return 'Email: $email. Double-tap to continue.';
  }

  @override
  String get profileAskPin =>
      'Create a four-digit PIN. Swipe up or down to choose a digit and double-tap to enter it. You can also long-press and say the four digits.';

  @override
  String get profileConfirmPin => 'Enter the PIN again to confirm.';

  @override
  String get profilePinMismatch => 'The PINs don\'t match. Please try again.';

  @override
  String get profileNameMissing => 'A name is needed first.';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldEmail => 'Email (optional)';

  @override
  String get fieldPin => 'PIN';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSkip => 'Skip';

  @override
  String get screenLogin => 'Log in';

  @override
  String get loginChooseProfile => 'Choose a profile.';

  @override
  String loginAskPin(String name) {
    return 'Enter the PIN for $name.';
  }

  @override
  String get loginWrongPin => 'Wrong PIN. Please try again.';

  @override
  String get loginNoProfiles => 'There are no profiles on this phone yet.';

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
}
