import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  /// App name. Not translated.
  ///
  /// In fil, this message translates to:
  /// **'Percipere'**
  String get appName;

  /// First line of the Welcome title; the app name follows on the next line. Kept in English to match the approved design.
  ///
  /// In fil, this message translates to:
  /// **'Welcome to'**
  String get welcomeTitleLine1;

  /// Welcome tagline. Kept in English to match the approved design.
  ///
  /// In fil, this message translates to:
  /// **'An app built on your behalf'**
  String get welcomeSubtitle;

  /// Question shown in the Speaking Zone on the Welcome screen.
  ///
  /// In fil, this message translates to:
  /// **'Paano mo gustong mag-navigate sa app?'**
  String get welcomePrompt;

  /// Button: choose voice navigation.
  ///
  /// In fil, this message translates to:
  /// **'Pa-boses (Voice)'**
  String get navModeVoice;

  /// Button: choose gesture navigation.
  ///
  /// In fil, this message translates to:
  /// **'Pa-galaw (Gestures)'**
  String get navModeGestures;

  /// Question shown in the Speaking Zone on the Capture Method screen.
  ///
  /// In fil, this message translates to:
  /// **'Paano mo gustong i-capture ang iyong dokyumento?'**
  String get capturePrompt;

  /// Button: upload a file (image, PDF, DOCX).
  ///
  /// In fil, this message translates to:
  /// **'Mag-upload'**
  String get captureUpload;

  /// Button: capture a document with the camera.
  ///
  /// In fil, this message translates to:
  /// **'Gamit ang Camera'**
  String get captureCamera;

  /// Screen-reader label and faint visible hint of the Gesture Pad.
  ///
  /// In fil, this message translates to:
  /// **'Lugar ng galaw (Gesture area)'**
  String get gestureAreaLabel;

  /// Screen-reader hint of the Gesture Pad on menu screens.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para lumipat ng pagpipilian. I-double tap para pumili. Pindutin nang matagal para magsalita.'**
  String get gestureAreaHintMenu;

  /// Screen-reader hint of the Gesture Pad on the Reader screen.
  ///
  /// In fil, this message translates to:
  /// **'I-tap para basahin o i-pause. Mag-swipe pakanan o pakaliwa para sa susunod o nakaraang pangungusap. Mag-swipe pataas o pababa para bilisan o bagalan.'**
  String get gestureAreaHintReader;

  /// Speaking Zone line showing what the speech recognizer heard.
  ///
  /// In fil, this message translates to:
  /// **'Narinig: “{text}”'**
  String heardLabel(String text);

  /// Document Box loading state while text is being extracted.
  ///
  /// In fil, this message translates to:
  /// **'Binabasa ang dokumento…'**
  String get readerLoading;

  /// Screen-reader label of the Document Box.
  ///
  /// In fil, this message translates to:
  /// **'Dokumento'**
  String get readerDocumentLabel;

  /// Document Box state when no document text is available.
  ///
  /// In fil, this message translates to:
  /// **'Walang tekstong mababasa.'**
  String get readerEmpty;

  /// Spoken name of the Capture Method screen.
  ///
  /// In fil, this message translates to:
  /// **'Pagkuha ng dokumento'**
  String get screenCapture;

  /// Spoken name of the Reader screen.
  ///
  /// In fil, this message translates to:
  /// **'Pagbasa'**
  String get screenReader;

  /// Spoken on entering the Welcome screen.
  ///
  /// In fil, this message translates to:
  /// **'Maligayang pagdating sa Percipere, isang app na ginawa para sa iyo. Paano mo gustong mag-navigate sa app? I-double tap kahit saan sa screen para sa pa-boses. Mag-swipe pakanan para sa pa-galaw. I-tap para marinig ulit ito.'**
  String get welcomeIntro;

  /// Spoken help on the Welcome screen.
  ///
  /// In fil, this message translates to:
  /// **'I-double tap: pa-boses. Mag-swipe pakanan: pa-galaw. I-tap: ulitin ang tanong.'**
  String get helpWelcome;

  /// Confirmation after choosing voice navigation.
  ///
  /// In fil, this message translates to:
  /// **'Napili mo ang pa-boses.'**
  String get modeChosenVoice;

  /// Confirmation after choosing gesture navigation.
  ///
  /// In fil, this message translates to:
  /// **'Napili mo ang pa-galaw.'**
  String get modeChosenGestures;

  /// Spoken on entering the Reader with a document.
  ///
  /// In fil, this message translates to:
  /// **'Handa na ang dokumento.'**
  String get readerReady;

  /// Lists a screen's options in its entry announcement.
  ///
  /// In fil, this message translates to:
  /// **'Mga pagpipilian: {items}.'**
  String optionsList(String items);

  /// Joins the last two items of a spoken list.
  ///
  /// In fil, this message translates to:
  /// **'o'**
  String get wordOr;

  /// Spoken when focus moves to an option.
  ///
  /// In fil, this message translates to:
  /// **'{label}, {position} sa {total}.'**
  String focusedItem(String label, int position, int total);

  /// End of a screen announcement in gesture mode.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para lumipat, at i-double tap para pumili.'**
  String get modeHintGestures;

  /// End of a screen announcement in voice mode.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang utos pagkatapos ng tunog, o pindutin nang matagal ang lugar ng galaw. Gumagana rin ang mga galaw.'**
  String get modeHintVoice;

  /// End of a screen announcement when TalkBack is on.
  ///
  /// In fil, this message translates to:
  /// **'Gamitin ang mga galaw ng TalkBack para pumili.'**
  String get modeHintTalkBack;

  /// Double-tap with nothing focused.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang napili. Mag-swipe pakanan para pumili.'**
  String get nothingFocused;

  /// A gesture or command the current screen doesn't support.
  ///
  /// In fil, this message translates to:
  /// **'Hindi magagamit ang utos na iyan dito.'**
  String get commandNotAvailable;

  /// Back gesture with no previous screen.
  ///
  /// In fil, this message translates to:
  /// **'Nasa unang screen ka na.'**
  String get alreadyAtStart;

  /// Start of the spoken help.
  ///
  /// In fil, this message translates to:
  /// **'Tulong para sa {screen}.'**
  String helpTitle(String screen);

  /// Spoken help listing the menu gestures.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. I-tap: ulitin ang tanong. Mag-swipe pababa gamit ang dalawang daliri: bumalik. Pindutin nang matagal: magsalita ng utos. I-double tap gamit ang dalawang daliri: patigilin ang pagsasalita. I-tap gamit ang tatlong daliri: tulong.'**
  String get helpGesturesMenu;

  /// Spoken once per launch when TalkBack is on.
  ///
  /// In fil, this message translates to:
  /// **'Naka-on ang TalkBack, kaya ang mga galaw ng TalkBack ang gagamitin sa halip na mga galaw ng Percipere. Gumagana pa rin ang mga utos sa boses.'**
  String get talkBackNotice;

  /// Intentionally English in every locale: spoken when no Filipino voice can speak it.
  ///
  /// In fil, this message translates to:
  /// **'The Filipino voice is not installed on this phone, so Percipere will speak English for now. To install it, open text-to-speech settings, choose Speech Services by Google, and download the Filipino voice.'**
  String get ttsFilipinoMissing;

  /// Intentionally English in every locale. Welcome screen only.
  ///
  /// In fil, this message translates to:
  /// **'Swipe up now to open text-to-speech settings.'**
  String get ttsFilipinoMissingSwipeUp;

  /// Intentionally English in every locale.
  ///
  /// In fil, this message translates to:
  /// **'Opening text-to-speech settings.'**
  String get ttsOpeningSettings;

  /// Spoken when the Filipino voice becomes available after returning to the app.
  ///
  /// In fil, this message translates to:
  /// **'Handa na ang boses na Filipino.'**
  String get filipinoVoiceReady;

  /// Added to the Welcome prompt when the microphone is already allowed.
  ///
  /// In fil, this message translates to:
  /// **'Maaari mo ring sabihin ang “boses” o “galaw”.'**
  String get welcomeSayHint;

  /// Speaking Zone subtitle while listening for a command.
  ///
  /// In fil, this message translates to:
  /// **'Nakikinig…'**
  String get listening;

  /// Unrecognized voice command; lists what can be said.
  ///
  /// In fil, this message translates to:
  /// **'Pasensya na, hindi ko naintindihan. Maaari mong sabihin: {commands}.'**
  String voiceUnknown(String commands);

  /// App-wide commands listed after the screen's own options.
  ///
  /// In fil, this message translates to:
  /// **'susunod, nakaraan, piliin, ulitin, bumalik, o tulong'**
  String get voiceCommonCommands;

  /// Ask-back when a voice command is unclear.
  ///
  /// In fil, this message translates to:
  /// **'Ang ibig mo bang sabihin ay “{phrase}”? Sabihin ang oo o hindi.'**
  String voiceDidYouMean(String phrase);

  /// User said no to an ask-back or offer.
  ///
  /// In fil, this message translates to:
  /// **'Sige.'**
  String get voiceCancelled;

  /// User said only the wake word ("Percipere").
  ///
  /// In fil, this message translates to:
  /// **'Nakikinig ako.'**
  String get voiceWakeReply;

  /// A long-press listen ended in silence.
  ///
  /// In fil, this message translates to:
  /// **'Wala akong narinig.'**
  String get voiceNothingHeard;

  /// Auto-listening stopped after a minute without activity.
  ///
  /// In fil, this message translates to:
  /// **'Hihinto muna ako sa pakikinig. Pindutin nang matagal ang lugar ng galaw para kausapin ulit ako.'**
  String get voiceListeningPaused;

  /// Spoken right before the Android microphone permission dialog.
  ///
  /// In fil, this message translates to:
  /// **'Hihingi ngayon ang Android ng pahintulot na gamitin ng Percipere ang mikropono, para marinig ko ang iyong mga utos. Piliin ang “Habang ginagamit ang app”.'**
  String get micPermissionExplain;

  /// Microphone permission refused.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko magagamit ang mikropono, kaya mga galaw muna ang gagamitin.'**
  String get micDenied;

  /// Microphone permanently refused; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Naka-block ang mikropono para sa Percipere. Maaari itong payagan sa settings ng app.'**
  String get micDeniedPermanent;

  /// Ends an offer (e.g. to open Settings).
  ///
  /// In fil, this message translates to:
  /// **'I-double tap, o sabihin ang “oo”, para ituloy.'**
  String get offerConfirmHint;

  /// No recognizer on the phone; app switches to gestures.
  ///
  /// In fil, this message translates to:
  /// **'Walang speech recognition ang teleponong ito, kaya mga galaw ang gagamitin.'**
  String get voiceUnavailable;

  /// Offline speech pack missing and no connection; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Walang internet, at hindi pa naka-install ang offline na pagkilala sa boses. Maaari itong i-download sa Settings, sa voice input.'**
  String get voiceOfflineMissing;

  /// Command for a screen that isn't built yet (history, settings, report).
  ///
  /// In fil, this message translates to:
  /// **'Wala pa ang bahaging iyan sa bersyong ito.'**
  String get featureNotReady;

  /// Appended to help in voice mode.
  ///
  /// In fil, this message translates to:
  /// **'Mga utos sa boses: {commands}.'**
  String helpVoiceCommands(String commands);

  /// Spoken name of the camera screen.
  ///
  /// In fil, this message translates to:
  /// **'Camera'**
  String get screenCamera;

  /// Spoken on entering the camera screen.
  ///
  /// In fil, this message translates to:
  /// **'Itutok ang camera sa dokumento, mga tatlumpung sentimetro ang layo. Sasabihin ko kung ilalapit o ilalayo. I-double tap o sabihin ang “kunan” para kumuha ng litrato. Kusa rin akong kukuha kapag malinaw na ang teksto.'**
  String get cameraIntro;

  /// Camera screen button / action label.
  ///
  /// In fil, this message translates to:
  /// **'Kunan ang litrato'**
  String get cameraCaptureButton;

  /// Camera guidance: preview is too dark.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong madilim. Humanap ng mas maliwanag na lugar.'**
  String get guideTooDark;

  /// Camera guidance: no text in the frame.
  ///
  /// In fil, this message translates to:
  /// **'Walang nakikitang teksto.'**
  String get guideNoText;

  /// Camera guidance: text too small.
  ///
  /// In fil, this message translates to:
  /// **'Ilapit pa.'**
  String get guideMoveCloser;

  /// Camera guidance: text fills the frame and is cut off.
  ///
  /// In fil, this message translates to:
  /// **'Ilayo nang kaunti.'**
  String get guideMoveBack;

  /// Camera guidance: text is clear; hold still.
  ///
  /// In fil, this message translates to:
  /// **'Handa na, hawakan nang maayos.'**
  String get guideReady;

  /// Spoken as the photo is taken.
  ///
  /// In fil, this message translates to:
  /// **'Kinukunan na.'**
  String get cameraCapturing;

  /// Taking the photo failed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi nakuha ang litrato. Subukan ulit.'**
  String get cameraCaptureFailed;

  /// Spoken right before the Android camera permission dialog.
  ///
  /// In fil, this message translates to:
  /// **'Hihingi ngayon ang Android ng pahintulot na gamitin ng Percipere ang camera. Piliin ang “Habang ginagamit ang app”.'**
  String get cameraPermissionExplain;

  /// Camera permission refused.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko magagamit ang camera. Maaari kang mag-upload ng litrato sa halip.'**
  String get cameraDenied;

  /// Camera permanently refused; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Naka-block ang camera para sa Percipere. Maaari itong payagan sa settings ng app.'**
  String get cameraDeniedPermanent;

  /// In-app camera failed; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Hindi mabuksan ang camera. Maaari kong buksan ang camera app ng telepono.'**
  String get cameraUnavailable;

  /// Spoken help on the camera screen.
  ///
  /// In fil, this message translates to:
  /// **'I-double tap: kunan ang litrato. I-tap: ulitin ang gabay. Mag-swipe pababa gamit ang dalawang daliri: bumalik.'**
  String get helpCamera;

  /// Spoken as the system file picker opens.
  ///
  /// In fil, this message translates to:
  /// **'Pumili ng larawan, PDF, o Word na file.'**
  String get uploadOpening;

  /// File picker closed without a file.
  ///
  /// In fil, this message translates to:
  /// **'Walang napiling file.'**
  String get uploadCancelled;

  /// Progress while reading a multi-page PDF.
  ///
  /// In fil, this message translates to:
  /// **'Binabasa ang pahina {page} sa {total}.'**
  String readerExtractingPage(int page, int total);

  /// Extraction finished. No plural form: Filipino plural rules put 2, 3, 5… in the 'one' category, and the noun doesn't change anyway.
  ///
  /// In fil, this message translates to:
  /// **'Handa na ang dokumento, may {count} talata.'**
  String readerReadyParagraphs(int count);

  /// Extracted text looks partly misread.
  ///
  /// In fil, this message translates to:
  /// **'Maaaring hindi malinaw ang pagkabasa sa ilang bahagi ng teksto.'**
  String get readerLowQuality;

  /// No text found.
  ///
  /// In fil, this message translates to:
  /// **'Wala akong mabasang teksto.'**
  String get readerNoText;

  /// Suggestions after a poor photo.
  ///
  /// In fil, this message translates to:
  /// **'Subukan sa mas maliwanag na lugar, at hawakan nang tuwid at hindi gumagalaw ang telepono.'**
  String get readerPhotoTips;

  /// Offer to retake; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang kumuha ulit ng litrato?'**
  String get readerRetakeOffer;

  /// Corrupt or unreadable file.
  ///
  /// In fil, this message translates to:
  /// **'Hindi mabuksan ang file na ito. Maaaring sira ito.'**
  String get readerUnreadable;

  /// Unsupported file type.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko pa kayang basahin ang ganitong file. Pumili ng larawan, PDF, o Word na file.'**
  String get readerUnsupported;

  /// Password-protected PDF.
  ///
  /// In fil, this message translates to:
  /// **'May password ang PDF na ito, kaya hindi ko ito mabasa.'**
  String get readerPasswordProtected;

  /// Ends the Reader's ready announcement.
  ///
  /// In fil, this message translates to:
  /// **'I-tap, o sabihin ang “basahin”, para magsimula.'**
  String get readerStartHint;

  /// Reopened from history at a saved position.
  ///
  /// In fil, this message translates to:
  /// **'Magpapatuloy sa pangungusap {position} sa {total}.'**
  String readerResumeAt(int position, int total);

  /// Reading reached the end.
  ///
  /// In fil, this message translates to:
  /// **'Tapos na ang dokumento.'**
  String get readerFinished;

  /// Reading paused.
  ///
  /// In fil, this message translates to:
  /// **'Naka-pause.'**
  String get readerPaused;

  /// Caption and speech after changing reading speed.
  ///
  /// In fil, this message translates to:
  /// **'Bilis: {rate}x'**
  String readerSpeed(String rate);

  /// Caption after saving (documents are also auto-saved).
  ///
  /// In fil, this message translates to:
  /// **'Na-save sa kasaysayan.'**
  String get readerSaved;

  /// Previous sentence/paragraph at the start.
  ///
  /// In fil, this message translates to:
  /// **'Ito na ang simula.'**
  String get readerAtStart;

  /// Next sentence/paragraph at the end.
  ///
  /// In fil, this message translates to:
  /// **'Ito na ang huling pangungusap.'**
  String get readerAtEnd;

  /// Restarting from the beginning.
  ///
  /// In fil, this message translates to:
  /// **'Mula sa simula.'**
  String get readerFromStart;

  /// Intentionally English in every locale: only spoken when no Filipino voice exists.
  ///
  /// In fil, this message translates to:
  /// **'This document is in Filipino, but no Filipino voice is installed, so it will be read with an English voice and may be hard to understand.'**
  String get readerFilipinoNoVoice;

  /// Spoken help on the Reader.
  ///
  /// In fil, this message translates to:
  /// **'I-tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pakanan o pakaliwa gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-double tap: ulitin ang pangungusap. Mag-swipe pababa gamit ang dalawang daliri: bumalik. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, ulitin, mula sa simula, i-save, at bumalik.'**
  String get helpReader;

  /// Capture screen: open Reading History.
  ///
  /// In fil, this message translates to:
  /// **'Kasaysayan'**
  String get captureHistory;

  /// Capture screen: open Settings.
  ///
  /// In fil, this message translates to:
  /// **'Mga Setting'**
  String get captureSettings;

  /// Spoken name of the Settings screen.
  ///
  /// In fil, this message translates to:
  /// **'Mga Setting'**
  String get screenSettings;

  /// Settings entry prompt.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili ng setting, at pataas o pababa para baguhin ito.'**
  String get settingsIntro;

  /// Spoken help on Settings.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng setting. Mag-swipe pataas o pababa: baguhin ang halaga. I-double tap: susunod na pagpipilian, o buksan. Mag-swipe pababa gamit ang dalawang daliri: bumalik.'**
  String get helpSettings;

  /// A setting and its value, e.g. "Bilis ng pagbasa: 1.2x".
  ///
  /// In fil, this message translates to:
  /// **'{label}: {value}'**
  String settingValue(String label, String value);

  /// Setting: reading speed.
  ///
  /// In fil, this message translates to:
  /// **'Bilis ng pagbasa'**
  String get setReadingRate;

  /// Setting: voice pitch.
  ///
  /// In fil, this message translates to:
  /// **'Tono ng boses'**
  String get setPitch;

  /// Setting: UI and prompt language.
  ///
  /// In fil, this message translates to:
  /// **'Wika'**
  String get setLanguage;

  /// Setting: which voice reads documents.
  ///
  /// In fil, this message translates to:
  /// **'Boses ng dokumento'**
  String get setDocumentVoice;

  /// Setting: text size.
  ///
  /// In fil, this message translates to:
  /// **'Laki ng teksto'**
  String get setTextSize;

  /// Setting: font.
  ///
  /// In fil, this message translates to:
  /// **'Font'**
  String get setFont;

  /// Setting: color theme.
  ///
  /// In fil, this message translates to:
  /// **'Kulay'**
  String get setColors;

  /// Setting: voice or gestures.
  ///
  /// In fil, this message translates to:
  /// **'Paraan ng pag-navigate'**
  String get setNavMode;

  /// Setting: vibration cues.
  ///
  /// In fil, this message translates to:
  /// **'Pag-vibrate'**
  String get setHaptics;

  /// Setting: how much the app says.
  ///
  /// In fil, this message translates to:
  /// **'Haba ng mga paliwanag'**
  String get setVerbosity;

  /// Setting: camera auto-capture.
  ///
  /// In fil, this message translates to:
  /// **'Kusang pagkuha ng litrato'**
  String get setAutoCapture;

  /// Setting row: open Account.
  ///
  /// In fil, this message translates to:
  /// **'Account'**
  String get setAccount;

  /// Setting row: open Android TTS settings.
  ///
  /// In fil, this message translates to:
  /// **'Mga boses ng pagbasa'**
  String get setTtsVoices;

  /// Toggle value.
  ///
  /// In fil, this message translates to:
  /// **'Naka-on'**
  String get valueOn;

  /// Toggle value.
  ///
  /// In fil, this message translates to:
  /// **'Naka-off'**
  String get valueOff;

  /// Document voice: detect per document.
  ///
  /// In fil, this message translates to:
  /// **'Awtomatiko'**
  String get valueAuto;

  /// Language name.
  ///
  /// In fil, this message translates to:
  /// **'Filipino'**
  String get langFilipino;

  /// Language name.
  ///
  /// In fil, this message translates to:
  /// **'Ingles'**
  String get langEnglish;

  /// Color theme.
  ///
  /// In fil, this message translates to:
  /// **'Karaniwan: cream at navy'**
  String get paletteDefault;

  /// Color theme.
  ///
  /// In fil, this message translates to:
  /// **'Puti sa itim'**
  String get paletteHighContrast;

  /// Color theme.
  ///
  /// In fil, this message translates to:
  /// **'Dilaw sa itim'**
  String get paletteYellow;

  /// Color theme.
  ///
  /// In fil, this message translates to:
  /// **'Itim sa puti'**
  String get paletteBlackOnWhite;

  /// Verbosity level.
  ///
  /// In fil, this message translates to:
  /// **'Maikli'**
  String get verbosityBrief;

  /// Verbosity level.
  ///
  /// In fil, this message translates to:
  /// **'Karaniwan'**
  String get verbosityNormal;

  /// Verbosity level.
  ///
  /// In fil, this message translates to:
  /// **'Detalyado'**
  String get verbosityDetailed;

  /// Navigation mode value.
  ///
  /// In fil, this message translates to:
  /// **'Pa-boses'**
  String get navVoice;

  /// Navigation mode value.
  ///
  /// In fil, this message translates to:
  /// **'Pa-galaw'**
  String get navGestures;

  /// Account row value when logged out.
  ///
  /// In fil, this message translates to:
  /// **'Walang naka-login'**
  String get accountNone;

  /// Account row value when logged in.
  ///
  /// In fil, this message translates to:
  /// **'Naka-login si {name}'**
  String accountAs(String name);

  /// Reading voices row value.
  ///
  /// In fil, this message translates to:
  /// **'May boses na Filipino'**
  String get ttsFilipinoInstalled;

  /// Reading voices row value.
  ///
  /// In fil, this message translates to:
  /// **'Walang boses na Filipino. I-double tap para mag-install.'**
  String get ttsFilipinoNotInstalled;

  /// Settings row button.
  ///
  /// In fil, this message translates to:
  /// **'Dagdagan'**
  String get actionIncrease;

  /// Settings row button.
  ///
  /// In fil, this message translates to:
  /// **'Bawasan'**
  String get actionDecrease;

  /// Settings row button (cycle).
  ///
  /// In fil, this message translates to:
  /// **'Palitan'**
  String get actionChange;

  /// Settings row button (open).
  ///
  /// In fil, this message translates to:
  /// **'Buksan'**
  String get actionOpen;

  /// Spoken name of Reading History.
  ///
  /// In fil, this message translates to:
  /// **'Kasaysayan ng Pagbasa'**
  String get screenHistory;

  /// History entry prompt (count > 0). No plural form on purpose.
  ///
  /// In fil, this message translates to:
  /// **'May {count} na dokumento. Mag-swipe pakanan para marinig ang bawat isa, at i-double tap para buksan.'**
  String historyIntro(int count);

  /// History has no documents.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang nababasang dokumento. Magbasa muna gamit ang Mag-upload o ang Camera.'**
  String get historyEmpty;

  /// A history entry as spoken and shown.
  ///
  /// In fil, this message translates to:
  /// **'{title}, {source}, {date}'**
  String historyItem(String title, String source, String date);

  /// Source type: camera photo.
  ///
  /// In fil, this message translates to:
  /// **'litrato'**
  String get sourceCamera;

  /// Source type: uploaded image.
  ///
  /// In fil, this message translates to:
  /// **'larawan'**
  String get sourceImage;

  /// Source type.
  ///
  /// In fil, this message translates to:
  /// **'PDF'**
  String get sourcePdf;

  /// Source type.
  ///
  /// In fil, this message translates to:
  /// **'Word'**
  String get sourceDocx;

  /// Search results count.
  ///
  /// In fil, this message translates to:
  /// **'{count} resulta para sa “{query}”.'**
  String historyResults(int count, String query);

  /// Search found nothing.
  ///
  /// In fil, this message translates to:
  /// **'Walang nahanap para sa “{query}”.'**
  String historyNoResults(String query);

  /// Search cleared.
  ///
  /// In fil, this message translates to:
  /// **'Ipinapakita muli ang lahat.'**
  String get historyShowAll;

  /// Options for a document (after swipe up).
  ///
  /// In fil, this message translates to:
  /// **'Mga opsyon para sa {title}. Mag-swipe para pumili: Buksan, Palitan ang pangalan, o Burahin. I-double tap para piliin.'**
  String historyOptions(String title);

  /// History option.
  ///
  /// In fil, this message translates to:
  /// **'Buksan'**
  String get optOpen;

  /// History option.
  ///
  /// In fil, this message translates to:
  /// **'Palitan ang pangalan'**
  String get optRename;

  /// History option.
  ///
  /// In fil, this message translates to:
  /// **'Burahin'**
  String get optDelete;

  /// Before dictating a new title.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang bagong pangalan pagkatapos ng tunog.'**
  String get historyRenamePrompt;

  /// After renaming.
  ///
  /// In fil, this message translates to:
  /// **'Pinalitan ang pangalan: {title}.'**
  String historyRenamed(String title);

  /// Delete confirmation; followed by the offer hint.
  ///
  /// In fil, this message translates to:
  /// **'Burahin ang “{title}”?'**
  String historyDeleteConfirm(String title);

  /// After deleting.
  ///
  /// In fil, this message translates to:
  /// **'Nabura ang “{title}”.'**
  String historyDeleted(String title);

  /// Search field hint and voice keyword.
  ///
  /// In fil, this message translates to:
  /// **'Hanapin'**
  String get historySearch;

  /// Spoken help on History.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng dokumento. I-double tap: buksan at ituloy ang pagbasa. Mag-swipe pataas: mga opsyon, gaya ng palitan ang pangalan at burahin. Sabihin ang “hanapin” at ang salita para maghanap. Mag-swipe pababa gamit ang dalawang daliri: bumalik.'**
  String get helpHistory;

  /// Spoken name of the Account screen.
  ///
  /// In fil, this message translates to:
  /// **'Account'**
  String get screenAccount;

  /// Account prompt when logged out.
  ///
  /// In fil, this message translates to:
  /// **'Ginagamit ang Percipere nang walang account. Gumawa ng profile para mai-save ang iyong mga setting.'**
  String get accountIntroGuest;

  /// Account prompt when logged in.
  ///
  /// In fil, this message translates to:
  /// **'Naka-login si {name}.'**
  String accountIntroUser(String name);

  /// Account action.
  ///
  /// In fil, this message translates to:
  /// **'Gumawa ng profile'**
  String get accountCreate;

  /// Account action.
  ///
  /// In fil, this message translates to:
  /// **'Mag-login'**
  String get accountLogin;

  /// Account action.
  ///
  /// In fil, this message translates to:
  /// **'Mag-logout'**
  String get accountLogout;

  /// After logout.
  ///
  /// In fil, this message translates to:
  /// **'Naka-logout na. Ginagamit ang mga setting ng teleponong ito.'**
  String get accountLoggedOut;

  /// After login.
  ///
  /// In fil, this message translates to:
  /// **'Maligayang pagbabalik, {name}.'**
  String accountLoggedIn(String name);

  /// After creating a profile.
  ///
  /// In fil, this message translates to:
  /// **'Nagawa ang profile ni {name}, at naka-login na.'**
  String accountCreated(String name);

  /// Spoken name of the create-profile screen.
  ///
  /// In fil, this message translates to:
  /// **'Bagong profile'**
  String get screenCreateProfile;

  /// Create profile step 1.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang iyong pangalan? Pindutin nang matagal ang lugar ng galaw at sabihin ito, o i-type.'**
  String get profileAskName;

  /// Name captured.
  ///
  /// In fil, this message translates to:
  /// **'Pangalan: {name}. I-double tap para ituloy, o pindutin nang matagal para ulitin.'**
  String profileNameIs(String name);

  /// Create profile step 2 (optional).
  ///
  /// In fil, this message translates to:
  /// **'Email, kung mayroon. Pindutin nang matagal para sabihin ito, o i-type. Mag-swipe pakanan para laktawan.'**
  String get profileAskEmail;

  /// Email captured.
  ///
  /// In fil, this message translates to:
  /// **'Email: {email}. I-double tap para ituloy.'**
  String profileEmailIs(String email);

  /// Create profile step 3.
  ///
  /// In fil, this message translates to:
  /// **'Gumawa ng apat na numerong PIN. Mag-swipe pataas o pababa para pumili ng numero at i-double tap para ilagay ito. Maaari mo ring pindutin nang matagal at sabihin ang apat na numero.'**
  String get profileAskPin;

  /// Create profile step 4.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ulit ang PIN para makumpirma.'**
  String get profileConfirmPin;

  /// Confirmation PIN differs.
  ///
  /// In fil, this message translates to:
  /// **'Hindi magkapareho ang PIN. Subukan ulit.'**
  String get profilePinMismatch;

  /// Continue without a name.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan muna ng pangalan.'**
  String get profileNameMissing;

  /// Form field label.
  ///
  /// In fil, this message translates to:
  /// **'Pangalan'**
  String get fieldName;

  /// Form field label.
  ///
  /// In fil, this message translates to:
  /// **'Email (opsyonal)'**
  String get fieldEmail;

  /// Form field label.
  ///
  /// In fil, this message translates to:
  /// **'PIN'**
  String get fieldPin;

  /// Wizard action.
  ///
  /// In fil, this message translates to:
  /// **'Ituloy'**
  String get actionContinue;

  /// Wizard action.
  ///
  /// In fil, this message translates to:
  /// **'Laktawan'**
  String get actionSkip;

  /// Spoken name of the login screen.
  ///
  /// In fil, this message translates to:
  /// **'Mag-login'**
  String get screenLogin;

  /// Login step 1.
  ///
  /// In fil, this message translates to:
  /// **'Pumili ng profile.'**
  String get loginChooseProfile;

  /// Login step 2.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang PIN ni {name}.'**
  String loginAskPin(String name);

  /// Wrong PIN.
  ///
  /// In fil, this message translates to:
  /// **'Mali ang PIN. Subukan ulit.'**
  String get loginWrongPin;

  /// No profiles to log into.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang profile sa teleponong ito.'**
  String get loginNoProfiles;

  /// A PIN digit was entered (the digit itself isn't repeated).
  ///
  /// In fil, this message translates to:
  /// **'Numero {count} sa {total}.'**
  String pinDigitEntered(int count, int total);

  /// Last PIN digit removed.
  ///
  /// In fil, this message translates to:
  /// **'Binura ang huling numero.'**
  String get pinDeleted;

  /// Voice PIN didn't have four digits.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang apat na numero, halimbawa: isa, dalawa, tatlo, apat.'**
  String get pinSayFour;

  /// Keypad delete key.
  ///
  /// In fil, this message translates to:
  /// **'Burahin'**
  String get pinDelete;

  /// Spoken help while entering a PIN.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pataas o pababa: pumili ng numero. I-double tap: ilagay ang numero. Mag-swipe pakaliwa: burahin ang huling numero. Pindutin nang matagal: sabihin ang apat na numero.'**
  String get helpPin;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
