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

  /// Gesture Pad hint on the Reader.
  ///
  /// In fil, this message translates to:
  /// **'I-double tap para basahin o i-pause. Mag-swipe pakanan o pakaliwa para sa susunod o nakaraang pangungusap. Mag-swipe pataas o pababa para bilisan o bagalan.'**
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

  /// Spoken help on Welcome.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat sa Login, Register, o Subukan muna. I-double tap: pindutin. I-tap: ulitin ang tanong. Pindutin nang matagal: magsalita. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
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

  /// Back with no previous screen.
  ///
  /// In fil, this message translates to:
  /// **'Nasa simula ka na.'**
  String get alreadyAtStart;

  /// Start of the spoken help.
  ///
  /// In fil, this message translates to:
  /// **'Tulong para sa {screen}.'**
  String helpTitle(String screen);

  /// Default spoken help.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. I-tap: ulitin ang tanong. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin nang matagal: magsalita ng utos. I-double tap gamit ang dalawang daliri: patigilin ang pagsasalita. I-tap gamit ang tatlong daliri: tulong.'**
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

  /// Voice recognition failed the same way several times in a row; listening stops instead of retrying forever.
  ///
  /// In fil, this message translates to:
  /// **'Hindi gumagana ang pakikinig ng boses ko ngayon. Hihinto muna ako. Pindutin nang matagal ang lugar ng galaw para subukan ulit, o gumamit ng mga galaw.'**
  String get voiceRepeatedError;

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

  /// Spoken help on the camera.
  ///
  /// In fil, this message translates to:
  /// **'I-double tap: kunan ang litrato. I-tap: ulitin ang gabay. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
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

  /// Auto-read off: how to start.
  ///
  /// In fil, this message translates to:
  /// **'Mag-double-tap para simulan ang pagbasa, o sabihin ang “basahin”.'**
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

  /// Caption and speech after changing the Reader text size (sp).
  ///
  /// In fil, this message translates to:
  /// **'Laki: {size}'**
  String readerSize(int size);

  /// Text size is already at its largest.
  ///
  /// In fil, this message translates to:
  /// **'Pinakamalaki na.'**
  String get readerSizeMax;

  /// Text size is already at its smallest.
  ///
  /// In fil, this message translates to:
  /// **'Pinakamaliit na.'**
  String get readerSizeMin;

  /// Spoken label of the A+ button above the Document Box.
  ///
  /// In fil, this message translates to:
  /// **'Palakihin ang teksto'**
  String get readerTextBigger;

  /// Spoken label of the A- button above the Document Box.
  ///
  /// In fil, this message translates to:
  /// **'Paliitin ang teksto'**
  String get readerTextSmaller;

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
  /// **'I-double tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pababa o pataas gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-tap: ulitin ang pangungusap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin ang A plus o A minus sa taas ng kahon, o i-pinch ang kahon ng dokumento, para palakihin o paliitin ang teksto. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, palakihin, paliitin, ulitin, mula sa simula, i-save, at bumalik.'**
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

  /// Spoken help in Settings.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng setting. Mag-swipe pataas o pababa: baguhin ang halaga. I-double tap: susunod na pagpipilian, o buksan. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
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

  /// Spoken help in History.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng dokumento. I-double tap: buksan at ituloy ang pagbasa. Mag-swipe pataas: mga opsyon, gaya ng palitan ang pangalan at burahin. Sabihin ang “hanapin” at ang salita para maghanap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
  String get helpHistory;

  /// Field (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Email Address'**
  String get fieldEmail;

  /// Form field label.
  ///
  /// In fil, this message translates to:
  /// **'PIN'**
  String get fieldPin;

  /// Wizard action.
  ///
  /// In fil, this message translates to:
  /// **'Laktawan'**
  String get actionSkip;

  /// Screen name (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Login'**
  String get screenLogin;

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

  /// Spoken name of the Welcome screen.
  ///
  /// In fil, this message translates to:
  /// **'Welcome'**
  String get screenWelcome;

  /// Welcome Speaking Zone before speech (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Meron ka na bang account?'**
  String get welcomeHasAccount;

  /// Welcome question (spoken).
  ///
  /// In fil, this message translates to:
  /// **'Meron ka na bang account? Kung wala pa, mag-register ka.'**
  String get welcomeAccountPrompt;

  /// Welcome: how to answer, microphone allowed.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang “login”, “register”, o “subukan”, o mag-swipe para pumili at mag-double-tap para pindutin.'**
  String get welcomeHintVoice;

  /// Welcome: how to answer, no microphone.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan para pumili, at mag-double-tap para pindutin. I-tap para marinig ulit ito.'**
  String get welcomeHintGestures;

  /// After the microphone is allowed on Welcome.
  ///
  /// In fil, this message translates to:
  /// **'Maaari mo nang sabihin ang “login”, “register”, o “subukan”.'**
  String get welcomeVoiceReady;

  /// Button (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Login'**
  String get actionLogin;

  /// Button (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Register'**
  String get actionRegister;

  /// Guest button (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Subukan muna (Try first)'**
  String get actionTryFirst;

  /// Form button (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// Clears the focused form field (voice only).
  ///
  /// In fil, this message translates to:
  /// **'Burahin'**
  String get actionClear;

  /// Confirms a setup step.
  ///
  /// In fil, this message translates to:
  /// **'Okay'**
  String get actionOkay;

  /// Summary: confirm everything.
  ///
  /// In fil, this message translates to:
  /// **'Tama, tapusin'**
  String get actionFinishSetup;

  /// Login link.
  ///
  /// In fil, this message translates to:
  /// **'Nakalimutan ang password'**
  String get actionForgotPassword;

  /// Login link.
  ///
  /// In fil, this message translates to:
  /// **'Gamitin ang fingerprint'**
  String get actionUseFingerprint;

  /// Login link to claim a pre-6B PIN account.
  ///
  /// In fil, this message translates to:
  /// **'Lumang account (PIN)'**
  String get actionLegacyAccount;

  /// Yes option.
  ///
  /// In fil, this message translates to:
  /// **'Oo'**
  String get answerYes;

  /// No option.
  ///
  /// In fil, this message translates to:
  /// **'Hindi'**
  String get answerNo;

  /// Name of the guest profile.
  ///
  /// In fil, this message translates to:
  /// **'Bisita'**
  String get guestName;

  /// Settings value for guests.
  ///
  /// In fil, this message translates to:
  /// **'Bisita: naka-save lamang sa phone na ito'**
  String get guestValue;

  /// Guest registration reminder (said at most once per moment).
  ///
  /// In fil, this message translates to:
  /// **'Naka-save ito sa phone na ito lamang. Mag-register para hindi ito mawala.'**
  String get guestReminder;

  /// Back with unsaved input.
  ///
  /// In fil, this message translates to:
  /// **'May hindi pa naka-save. Sigurado ka bang babalik?'**
  String get backUnsavedConfirm;

  /// Back on the first screen.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang isara ang app?'**
  String get closeAppQuestion;

  /// Announces the destination after back.
  ///
  /// In fil, this message translates to:
  /// **'Bumalik sa {screen}.'**
  String backReturnedTo(String screen);

  /// Start of a form.
  ///
  /// In fil, this message translates to:
  /// **'Sagutin ang bawat tanong sa boses, o i-type ito.'**
  String get formIntro;

  /// Form submit hint (mockup wording).
  ///
  /// In fil, this message translates to:
  /// **'Pindutin ng dalawang beses ang gesture area o sabihin ang salitang submit or tapos na'**
  String get formSubmitHint;

  /// Focused empty field.
  ///
  /// In fil, this message translates to:
  /// **'{field}, walang laman'**
  String formFieldEmpty(String field);

  /// Focused field with its value.
  ///
  /// In fil, this message translates to:
  /// **'{field}: {value}'**
  String formFieldValue(String field, String value);

  /// Password read back by length only. No plural in Filipino.
  ///
  /// In fil, this message translates to:
  /// **'{count} titik'**
  String formPasswordLength(int count);

  /// Read-back after a field is filled.
  ///
  /// In fil, this message translates to:
  /// **'{field}: {value}.'**
  String formHeard(String field, String value);

  /// All fields filled.
  ///
  /// In fil, this message translates to:
  /// **'Kumpleto na. {hint}'**
  String formComplete(String hint);

  /// Focused field that has a value.
  ///
  /// In fil, this message translates to:
  /// **'{field}. Magsalita o mag-type para palitan.'**
  String formChange(String field);

  /// Field cleared.
  ///
  /// In fil, this message translates to:
  /// **'Binura ang {field}. {prompt}'**
  String formCleared(String field, String prompt);

  /// Submit with empty fields.
  ///
  /// In fil, this message translates to:
  /// **'Kulang pa: {fields}.'**
  String formMissing(String fields);

  /// Spoken help on form screens.
  ///
  /// In fil, this message translates to:
  /// **'Magsalita para sagutin ang tanong, o i-type ito. Mag-swipe pakanan o pakaliwa: lumipat ng field. I-tap: ulitin ang tanong. Pindutin nang matagal: magsalita. I-double tap, o sabihin ang “submit” o “tapos na”: ipasa. Sabihin ang “burahin”: burahin ang field. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
  String get helpForm;

  /// Field (mockup).
  ///
  /// In fil, this message translates to:
  /// **'First Name'**
  String get fieldFirstName;

  /// Field (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Last Name'**
  String get fieldLastName;

  /// Field (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Field.
  ///
  /// In fil, this message translates to:
  /// **'Bagong password'**
  String get fieldNewPassword;

  /// Security answer field.
  ///
  /// In fil, this message translates to:
  /// **'Sagot'**
  String get fieldAnswer;

  /// Register prompt.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang iyong pangalan (first name)?'**
  String get askFirstName;

  /// Register prompt.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang iyong apelyido (last name)?'**
  String get askLastName;

  /// Prompt. Spell it: “at” for @, “dot” for a period.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang iyong email address?'**
  String get askEmail;

  /// New password prompt.
  ///
  /// In fil, this message translates to:
  /// **'Gumawa ng password na hindi bababa sa 8 titik.'**
  String get askNewPassword;

  /// Login prompt.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang iyong password?'**
  String get askPassword;

  /// Security answer prompt.
  ///
  /// In fil, this message translates to:
  /// **'{question} Sabihin o i-type ang sagot.'**
  String askAnswer(String question);

  /// Invalid email.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang mali ang email address. Halimbawa: juan@gmail.com. Sa boses, sabihin ang “at” para sa @ at “dot” para sa tuldok.'**
  String get emailInvalid;

  /// Duplicate email.
  ///
  /// In fil, this message translates to:
  /// **'May account na sa phone na ito ang email na iyan. Mag-login ka, o gumamit ng ibang email.'**
  String get emailTaken;

  /// Password too short. No plural in Filipino.
  ///
  /// In fil, this message translates to:
  /// **'Ang password ay dapat hindi bababa sa 8 titik. {count} pa lang ang nailagay.'**
  String passwordTooShort(int count);

  /// Screen name (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Register'**
  String get screenRegister;

  /// While hashing the password.
  ///
  /// In fil, this message translates to:
  /// **'Ginagawa ang iyong account…'**
  String get registerWorking;

  /// After registering.
  ///
  /// In fil, this message translates to:
  /// **'Nagawa na ang iyong account, {name}.'**
  String registerDone(String name);

  /// Spoken help on Login.
  ///
  /// In fil, this message translates to:
  /// **'Magsalita o mag-type para sagutin ang email at password. I-double tap, o sabihin ang “submit” o “tapos na”: mag-login. Sabihin ang “nakalimutan”: i-reset ang password. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
  String get helpLogin;

  /// Login with fingerprint enabled.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang iyong daliri sa fingerprint sensor para mag-login, o gamitin ang iyong password.'**
  String get loginFingerprintIntro;

  /// Failed login.
  ///
  /// In fil, this message translates to:
  /// **'Mali ang email o password.'**
  String get loginWrong;

  /// Failed login, before lockout. No plural in Filipino.
  ///
  /// In fil, this message translates to:
  /// **'{count} pang subok bago maghintay.'**
  String loginAttemptsLeft(int count);

  /// After login.
  ///
  /// In fil, this message translates to:
  /// **'Maligayang pagbabalik, {name}.'**
  String loginWelcomeBack(String name);

  /// Lockout begins.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong maraming maling subok. Maghintay ng {seconds} segundo bago sumubok muli.'**
  String lockoutStarted(int seconds);

  /// Lockout countdown.
  ///
  /// In fil, this message translates to:
  /// **'Maghintay ng {seconds} segundo.'**
  String lockoutWait(int seconds);

  /// Lockout ended.
  ///
  /// In fil, this message translates to:
  /// **'Maaari ka nang sumubok muli.'**
  String get lockoutOver;

  /// Android fingerprint dialog text.
  ///
  /// In fil, this message translates to:
  /// **'Gamitin ang fingerprint para mag-login sa Percipere'**
  String get fingerprintReason;

  /// Fingerprint failed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi nakilala ang fingerprint. Gamitin ang iyong password. {prompt}'**
  String fingerprintFailed(String prompt);

  /// Fingerprint unavailable.
  ///
  /// In fil, this message translates to:
  /// **'Hindi magamit ang fingerprint ngayon. Gamitin ang iyong password. {prompt}'**
  String fingerprintUnavailable(String prompt);

  /// After logout (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Nais mo bang mag login sa iyong account?'**
  String get authChoiceQuestion;

  /// Launch with stay-logged-in off.
  ///
  /// In fil, this message translates to:
  /// **'Natapos na ang iyong session.'**
  String get sessionExpired;

  /// Help on list/choice screens.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. Maaari mo ring sabihin ang pagpipilian. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
  String get helpChooseList;

  /// Screen name.
  ///
  /// In fil, this message translates to:
  /// **'Tanong pangseguridad'**
  String get screenSecurityQuestion;

  /// Choose a question.
  ///
  /// In fil, this message translates to:
  /// **'Pumili ng tanong pangseguridad. Gagamitin ito kapag nakalimutan mo ang iyong password.'**
  String get securityChoose;

  /// Security question.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang pangalan ng una mong alagang hayop?'**
  String get securityQFirstPet;

  /// Security question.
  ///
  /// In fil, this message translates to:
  /// **'Saang bayan ka ipinanganak?'**
  String get securityQBirthTown;

  /// Security question.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang apelyido ng iyong nanay noong dalaga pa siya?'**
  String get securityQMotherMaiden;

  /// Security question.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang pangalan ng una mong paaralan?'**
  String get securityQFirstSchool;

  /// Security question.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang paborito mong pagkain?'**
  String get securityQFavoriteFood;

  /// Saved.
  ///
  /// In fil, this message translates to:
  /// **'Na-save ang iyong tanong pangseguridad.'**
  String get securitySaved;

  /// Back on the choose step.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ang tanong pangseguridad para ma-reset ang password. Pumili ng isa.'**
  String get securityRequired;

  /// Screen name.
  ///
  /// In fil, this message translates to:
  /// **'Fingerprint'**
  String get screenFingerprint;

  /// Offer after registering.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang gamitin ang iyong fingerprint sa pag-login?'**
  String get fingerprintOffer;

  /// Enabled.
  ///
  /// In fil, this message translates to:
  /// **'Naka-on na ang fingerprint login.'**
  String get fingerprintOn;

  /// Enabling failed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi na-on ang fingerprint login. Maaari mo itong i-on mamaya sa Mga Setting.'**
  String get fingerprintNotSet;

  /// Offer declined.
  ///
  /// In fil, this message translates to:
  /// **'Sige, password na lang.'**
  String get fingerprintSkipped;

  /// No biometrics.
  ///
  /// In fil, this message translates to:
  /// **'Walang naka-set na fingerprint sa phone na ito.'**
  String get fingerprintNoSensor;

  /// Screen name.
  ///
  /// In fil, this message translates to:
  /// **'Nakalimutan ang password'**
  String get screenForgotPassword;

  /// Forgot password start.
  ///
  /// In fil, this message translates to:
  /// **'Sasagutin mo ang iyong tanong pangseguridad para makagawa ng bagong password.'**
  String get forgotIntro;

  /// Always mentioned.
  ///
  /// In fil, this message translates to:
  /// **'Maaari ring i-reset ng administrator ang iyong account.'**
  String get forgotAdmin;

  /// No account/question.
  ///
  /// In fil, this message translates to:
  /// **'Walang account na may tanong pangseguridad para sa email na ito sa phone na ito.'**
  String get forgotNoQuestion;

  /// Wrong answer.
  ///
  /// In fil, this message translates to:
  /// **'Mali ang sagot.'**
  String get forgotWrongAnswer;

  /// Reset done.
  ///
  /// In fil, this message translates to:
  /// **'Napalitan na ang password. Mag-login ka na.'**
  String get forgotDone;

  /// Screen name.
  ///
  /// In fil, this message translates to:
  /// **'Lumang account'**
  String get screenLegacyAccount;

  /// Choose an old account.
  ///
  /// In fil, this message translates to:
  /// **'Pumili ng iyong lumang account na may PIN.'**
  String get legacyChoose;

  /// None.
  ///
  /// In fil, this message translates to:
  /// **'Walang lumang account sa phone na ito.'**
  String get legacyNone;

  /// Old PIN verified.
  ///
  /// In fil, this message translates to:
  /// **'Tama ang PIN, {name}. Ngayon, maglagay ng email at password.'**
  String legacyClaimed(String name);

  /// Screen name.
  ///
  /// In fil, this message translates to:
  /// **'I-update ang account'**
  String get screenUpgradeAccount;

  /// Upgrade intro.
  ///
  /// In fil, this message translates to:
  /// **'Hindi na ginagamit ang PIN. Maglagay ng email at password; mananatili ang iyong mga setting at kasaysayan.'**
  String get upgradeIntro;

  /// Upgrade done.
  ///
  /// In fil, this message translates to:
  /// **'Na-update na ang iyong account.'**
  String get upgradeDone;

  /// Back on the upgrade screen.
  ///
  /// In fil, this message translates to:
  /// **'Kung babalik ka, lalabas ka sa account na ito. Sigurado ka ba?'**
  String get upgradeLeave;

  /// Setup progress.
  ///
  /// In fil, this message translates to:
  /// **'Hakbang {step} ng {total}.'**
  String setupProgress(int step, int total);

  /// Summary step title.
  ///
  /// In fil, this message translates to:
  /// **'Buod.'**
  String get setupSummaryTitle;

  /// How to answer a choice step.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang iyong sagot, o mag-swipe pakanan para pumili at mag-double-tap para pindutin.'**
  String get setupChoiceHow;

  /// Step 1 how to answer.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang “boses” o “galaw”, o mag-swipe pakanan para pumili at mag-double-tap para pindutin.'**
  String get setupNavHowVoice;

  /// Sight question.
  ///
  /// In fil, this message translates to:
  /// **'Nakakakita ka ba ng kahit kaunting teksto sa screen?'**
  String get setupSeesQuestion;

  /// Step 2 (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Nababasa mo ba ng maayos ang texto?'**
  String get setupSizeQuestion;

  /// Step 2 how.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pataas o sabihin ang “palakihin” para lumaki; mag-swipe pababa o sabihin ang “paliitin” para lumiit. I-double tap o sabihin ang “okay” kapag tama na.'**
  String get setupSizeHow;

  /// Step 2 value.
  ///
  /// In fil, this message translates to:
  /// **'Laki ng teksto: {size}.'**
  String setupSizeValue(int size);

  /// Step 3 (mockup).
  ///
  /// In fil, this message translates to:
  /// **'Anong kulay ang nais mo sa texto?'**
  String get setupColorQuestion;

  /// Steps 3 and 7 how.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa, o sabihin ang “susunod” o “nakaraan”, para palitan. I-double tap o sabihin ang “okay” kapag tama na.'**
  String get setupCycleHow;

  /// Step 3 value.
  ///
  /// In fil, this message translates to:
  /// **'Kulay: {color}.'**
  String setupColorValue(String color);

  /// Step 4.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo ba ang boses sa Ingles o sa Tagalog?'**
  String get setupLanguageQuestion;

  /// Step 4 how.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan para marinig ang bawat isa, at mag-double-tap para pumili. O sabihin ang “Tagalog” o “Ingles”.'**
  String get setupLanguageHow;

  /// Voice sample, spoken in each voice.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang boses sa Tagalog.'**
  String get setupVoiceSample;

  /// Step 4 without a Filipino voice (spoken in English).
  ///
  /// In fil, this message translates to:
  /// **'Walang boses na Filipino sa phone na ito. Gusto mo bang buksan ang text-to-speech settings para i-install ito?'**
  String get setupFilipinoMissing;

  /// Step 4 chosen.
  ///
  /// In fil, this message translates to:
  /// **'Napili: {language}.'**
  String setupLanguageChosen(String language);

  /// Step 5.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang bilisan ang boses?'**
  String get setupSpeedQuestion;

  /// Step 5 how.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pataas o sabihin ang “bilisan”; mag-swipe pababa o sabihin ang “bagalan”. I-double tap o sabihin ang “okay” kapag tama na.'**
  String get setupSpeedHow;

  /// Step 5 value.
  ///
  /// In fil, this message translates to:
  /// **'Bilis: {rate}x.'**
  String setupSpeedValue(String rate);

  /// Step 6.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang palitan ang tono ng boses?'**
  String get setupPitchQuestion;

  /// Step 6 how.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pataas o sabihin ang “taasan”; mag-swipe pababa o sabihin ang “babaan”. I-double tap o sabihin ang “okay” kapag tama na.'**
  String get setupPitchHow;

  /// Step 6 value.
  ///
  /// In fil, this message translates to:
  /// **'Tono: {pitch}.'**
  String setupPitchValue(String pitch);

  /// Step 7.
  ///
  /// In fil, this message translates to:
  /// **'Anong tema ang gusto mong simulan?'**
  String get setupThemeQuestion;

  /// Step 7 value.
  ///
  /// In fil, this message translates to:
  /// **'Tema: {theme}.'**
  String setupThemeValue(String theme);

  /// Theme name.
  ///
  /// In fil, this message translates to:
  /// **'Cream at Navy'**
  String get themeCreamNavy;

  /// Theme name.
  ///
  /// In fil, this message translates to:
  /// **'Dark mode na dilaw ang teksto'**
  String get themeDarkYellow;

  /// Theme name.
  ///
  /// In fil, this message translates to:
  /// **'Dark mode na puti ang teksto'**
  String get themeDarkWhite;

  /// Theme change reset the text color.
  ///
  /// In fil, this message translates to:
  /// **'Pinalitan ang kulay ng teksto para mas mabasa.'**
  String get textColorReset;

  /// Step 8.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang mag-vibrate ang phone kapag may ginagawa ka?'**
  String get setupVibrationQuestion;

  /// Step 9.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang awtomatikong basahin ang dokumento pagkatapos itong i-upload o i-scan?'**
  String get setupAutoReadQuestion;

  /// Step 10 question.
  ///
  /// In fil, this message translates to:
  /// **'Tama ba ang lahat?'**
  String get setupSummaryQuestion;

  /// Step 10.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang iyong mga napili: {items}. Tama ba ang lahat? I-double tap o sabihin ang “oo” para tapusin. Para baguhin ang isa, sabihin halimbawa ang “bumalik sa bilis”, o mag-swipe at mag-double-tap.'**
  String setupSummaryPrompt(String items);

  /// Summary line.
  ///
  /// In fil, this message translates to:
  /// **'Paraan: {value}'**
  String summaryNavMode(String value);

  /// Summary line.
  ///
  /// In fil, this message translates to:
  /// **'Wika ng boses: {value}'**
  String summaryLanguage(String value);

  /// Summary line.
  ///
  /// In fil, this message translates to:
  /// **'Vibrate: {value}'**
  String summaryVibration(String value);

  /// Summary line.
  ///
  /// In fil, this message translates to:
  /// **'Awtomatikong pagbasa: {value}'**
  String summaryAutoRead(String value);

  /// Value at its limit.
  ///
  /// In fil, this message translates to:
  /// **'Hanggang dito na lang. {value}'**
  String setupAtLimit(String value);

  /// Step skipped.
  ///
  /// In fil, this message translates to:
  /// **'Nilaktawan. Ginamit ang karaniwang setting.'**
  String get setupSkipped;

  /// Back on the first setup step.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang unang hakbang. Gusto mo bang bumalik sa Welcome? Lalabas ka sa account.'**
  String get setupLeave;

  /// Setup completed.
  ///
  /// In fil, this message translates to:
  /// **'Tapos na ang setup. Maaari mo itong baguhin anumang oras sa Mga Setting.'**
  String get setupFinished;

  /// Preview paragraph.
  ///
  /// In fil, this message translates to:
  /// **'Ang Percipere ay tumutulong sa iyo na mabasa ang mga liham, resibo, at aklat. Ganito ang magiging hitsura ng teksto.'**
  String get setupSample;

  /// Screen-reader label of the preview.
  ///
  /// In fil, this message translates to:
  /// **'Halimbawang teksto'**
  String get setupPreviewLabel;

  /// Help on choice steps.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: lumipat ng sagot. I-double tap: piliin. O sabihin ang sagot.'**
  String get helpSetupChoice;

  /// Help on up/down steps.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pataas o pababa: baguhin. I-double tap o sabihin ang “okay”: tama na.'**
  String get helpSetupVertical;

  /// Help on left/right steps.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa: baguhin. I-double tap o sabihin ang “okay”: tama na.'**
  String get helpSetupHorizontal;

  /// Help common to setup steps.
  ///
  /// In fil, this message translates to:
  /// **'I-tap o sabihin ang “ulitin”: ulitin ang tanong. Sabihin ang “laktawan”: laktawan at gamitin ang karaniwan. Mag-swipe pakanan gamit ang dalawang daliri, o sabihin ang “bumalik”: nakaraang hakbang.'**
  String get helpSetupCommon;

  /// Help on the summary.
  ///
  /// In fil, this message translates to:
  /// **'I-double tap o sabihin ang “oo”: tapusin. Mag-swipe pakanan o pakaliwa: lumipat sa mga napili, at i-double tap para baguhin. O sabihin ang “bumalik sa” at ang pangalan, halimbawa “bumalik sa bilis”.'**
  String get helpSetupSummary;

  /// Voice language option.
  ///
  /// In fil, this message translates to:
  /// **'Tagalog'**
  String get langTagalog;

  /// Voice language option.
  ///
  /// In fil, this message translates to:
  /// **'Ingles (English)'**
  String get langEnglishBoth;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Tema'**
  String get setTheme;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Kulay ng teksto'**
  String get setTextColor;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Awtomatikong pagbasa'**
  String get setAutoRead;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Manatiling naka-login'**
  String get setStayLoggedIn;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Fingerprint login'**
  String get setFingerprint;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Ulitin ang setup'**
  String get setRedoSetup;

  /// Setting value.
  ///
  /// In fil, this message translates to:
  /// **'Sagutin ulit ang mga tanong'**
  String get setRedoSetupValue;

  /// Setting name.
  ///
  /// In fil, this message translates to:
  /// **'Logout'**
  String get setLogout;

  /// Logout confirmation.
  ///
  /// In fil, this message translates to:
  /// **'Sigurado ka bang gusto mong mag-logout?'**
  String get logoutConfirm;

  /// Guest logout confirmation.
  ///
  /// In fil, this message translates to:
  /// **'Lalabas ka sa bisitang profile. Mananatili ito sa phone na ito. Sigurado ka ba?'**
  String get logoutGuestConfirm;

  /// After logout.
  ///
  /// In fil, this message translates to:
  /// **'Naka-logout ka na.'**
  String get loggedOut;

  /// Spoken at the new speed after a change.
  ///
  /// In fil, this message translates to:
  /// **'Ganito kabilis ang boses.'**
  String get setupSpeedSample;

  /// Spoken after a tone change.
  ///
  /// In fil, this message translates to:
  /// **'Ganito ang tono ng boses.'**
  String get setupPitchSample;
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
