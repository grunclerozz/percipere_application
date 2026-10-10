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

  /// A file was chosen but could not be read or copied (not a cancel).
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko makuha ang file na pinili mo. Subukan ulit, o pumili ng ibang file.'**
  String get uploadFailed;

  /// The chosen file or photo no longer exists when reading starts.
  ///
  /// In fil, this message translates to:
  /// **'Nawala ang file bago ko ito nabasa. Pakisubukan ulit.'**
  String get readerFileMissing;

  /// The OCR engine failed; the file itself is fine.
  ///
  /// In fil, this message translates to:
  /// **'Hindi gumana ang pagbasa ng teksto sa phone na ito ngayon. Hindi sira ang file. Pakisubukan ulit.'**
  String get readerOcrFailed;

  /// Reading the text failed for an unexpected reason (not a damaged file, not the OCR engine). The real error is in the [CAPTURE] log.
  ///
  /// In fil, this message translates to:
  /// **'Nagkaproblema habang binabasa ko ang file. Malamang hindi ito sira. Pakisubukan ulit.'**
  String get readerExtractFailed;

  /// The text was read but saving it to the Library failed.
  ///
  /// In fil, this message translates to:
  /// **'Mababasa mo ito, pero hindi ko ito na-save sa Aklatan.'**
  String get readerSaveFailed;

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
  /// **'Na-save sa Aklatan.'**
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
  /// **'I-double tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pababa o pataas gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-tap: ulitin ang pangungusap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin ang A plus o A minus sa taas ng kahon, o i-pinch ang kahon ng dokumento, para palakihin o paliitin ang teksto. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, palakihin, paliitin, ulitin, mula sa simula, i-save, at bumalik. Habang nagbabasa, puwede mong sabihin agad ang i-pause, itigil, bilisan, bagalan, palakihin, paliitin, paborito, ulitin, o bumalik. Mas maaasahan ito kung naka-earphones ka. Pindutin nang matagal ang gesture area para huminto agad at makinig.'**
  String get helpReader;

  /// Capture button: describe what is in a picture.
  ///
  /// In fil, this message translates to:
  /// **'Maglarawan'**
  String get captureDescribe;

  /// Added to the Capture announcement.
  ///
  /// In fil, this message translates to:
  /// **'Pwede mo ring gamitin ang bago naming feature: Maglarawan. Sasabihin nito kung ano ang nasa isang larawan.'**
  String get describeAnnouncement;

  /// Full explanation of Maglarawan: read once on the first Capture visit, and on request.
  ///
  /// In fil, this message translates to:
  /// **'Ang Maglarawan ay para sa mga larawang walang teksto, o kung gusto mong malaman kung ano ang nasa larawan. Kumuha ng litrato gamit ang camera o mag-upload ng larawan, at sasabihin namin kung ano ang nakikita namin. Kung may internet, maaari kang humingi ng mas detalyadong paglalarawan.'**
  String get describeExplanation;

  /// Name of the Maglarawan screens.
  ///
  /// In fil, this message translates to:
  /// **'Maglarawan'**
  String get screenDescribe;

  /// Maglarawan: choose camera or upload.
  ///
  /// In fil, this message translates to:
  /// **'Paano mo gustong kunin ang larawan?'**
  String get describeSourcePrompt;

  /// Said when looking at the picture takes more than a second.
  ///
  /// In fil, this message translates to:
  /// **'Tinitingnan ang larawan…'**
  String get describeWorking;

  /// Offline description. Items are already joined (a, b, at c).
  ///
  /// In fil, this message translates to:
  /// **'Mukhang may {items} sa larawan.'**
  String describeLooksLike(String items);

  /// Joins the last two labels.
  ///
  /// In fil, this message translates to:
  /// **'at'**
  String get describeAnd;

  /// No label was confident enough.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko matiyak kung ano ang nasa larawan. Subukan ulit na may mas maliwanag na ilaw.'**
  String get describeNothing;

  /// Added when a label suggests medicine, pills or money.
  ///
  /// In fil, this message translates to:
  /// **'Paalala: kumpirmahin ito sa taong pinagkakatiwalaan mo bago gamitin.'**
  String get describeReminder;

  /// OCR found readable text in the picture.
  ///
  /// In fil, this message translates to:
  /// **'May nakita rin akong teksto. Gusto mo bang basahin ito?'**
  String get describeTextFound;

  /// Read the text, but there is none.
  ///
  /// In fil, this message translates to:
  /// **'Walang nakitang teksto sa larawang ito.'**
  String get describeNoText;

  /// Offered when online.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo ba ng mas detalyadong paglalarawan?'**
  String get describeDetailOffer;

  /// Detailed description asked for while offline.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng internet para sa mas detalyadong paglalarawan. Subukan ulit kapag may internet.'**
  String get describeNeedsInternet;

  /// Privacy consent, asked before the first detailed description.
  ///
  /// In fil, this message translates to:
  /// **'Ipapadala ang larawan sa aming server at sa serbisyo ng Google para mailarawan ito. Sige ba?'**
  String get describeConsentAsk;

  /// The user said no to sending the image.
  ///
  /// In fil, this message translates to:
  /// **'Sige, hindi ko ipapadala ang larawan. Mababago mo ito sa Settings.'**
  String get describeConsentDeclined;

  /// The server could not describe the image.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko makuha ang detalyadong paglalarawan ngayon. Subukan ulit mamaya.'**
  String get describeDetailFailed;

  /// The image file could not be opened.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko mabasa ang larawang ito.'**
  String get describeUnreadable;

  /// Description action: say it again.
  ///
  /// In fil, this message translates to:
  /// **'Ulitin'**
  String get describeRepeat;

  /// Description action: online detailed description.
  ///
  /// In fil, this message translates to:
  /// **'Mas detalyado'**
  String get describeMore;

  /// Description action: open the found text in the Reader.
  ///
  /// In fil, this message translates to:
  /// **'Basahin ang teksto'**
  String get describeReadText;

  /// Description action: save to history.
  ///
  /// In fil, this message translates to:
  /// **'I-save'**
  String get describeSave;

  /// Description action: start over with another picture.
  ///
  /// In fil, this message translates to:
  /// **'Bagong larawan'**
  String get describeNew;

  /// Screen-reader label of the picture on the Description screen.
  ///
  /// In fil, this message translates to:
  /// **'Ang larawan'**
  String get describeThumbnailLabel;

  /// Spoken help on the Description screen.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili ng opsyon, at i-double tap para gamitin. Mga opsyon: ulitin, mas detalyado, basahin ang teksto, i-save, at bagong larawan. I-pinch ang kahon para palakihin o paliitin ang teksto. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.'**
  String get helpDescribe;

  /// Source type in Reading History: a described image.
  ///
  /// In fil, this message translates to:
  /// **'larawan (Maglarawan)'**
  String get sourceDescription;

  /// Setting: allow sending images to the server for a detailed description.
  ///
  /// In fil, this message translates to:
  /// **'Detalyadong paglalarawan'**
  String get setDescribeConsent;

  /// Consent not given or refused yet.
  ///
  /// In fil, this message translates to:
  /// **'Itatanong muna'**
  String get valueConsentAsk;

  /// Sending images is allowed.
  ///
  /// In fil, this message translates to:
  /// **'Pinapayagan'**
  String get valueConsentAllowed;

  /// Sending images is not allowed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pinapayagan'**
  String get valueConsentDeclined;

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

  /// Setting name: in voice mode, keep the microphone on while a document is read aloud so reading commands work at once.
  ///
  /// In fil, this message translates to:
  /// **'Makinig habang nagbabasa'**
  String get setListenWhileReading;

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

  /// Spoken name of the Home screen.
  ///
  /// In fil, this message translates to:
  /// **'Home'**
  String get screenHome;

  /// Home screen question.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang gusto mong gawin?'**
  String get homePrompt;

  /// Home button: read something new (Capture).
  ///
  /// In fil, this message translates to:
  /// **'Magbasa ng bago'**
  String get homeRead;

  /// Home button: open the Library.
  ///
  /// In fil, this message translates to:
  /// **'Aklatan'**
  String get homeLibrary;

  /// Spoken name of the Library.
  ///
  /// In fil, this message translates to:
  /// **'Aklatan'**
  String get screenLibrary;

  /// Library entry prompt.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para lumipat ng aytem, at pataas o pababa para lumipat ng istante. I-double tap para buksan ang detalye.'**
  String get libraryPrompt;

  /// Said when the catalog has books the user has not seen. No number on purpose.
  ///
  /// In fil, this message translates to:
  /// **'May mga bagong aklat sa Aklatan.'**
  String get libraryNewBooks;

  /// Name of the top row (search, filter, new collection).
  ///
  /// In fil, this message translates to:
  /// **'Paghahanap at mga filter'**
  String get shelfControls;

  /// Shelf: items started but not finished.
  ///
  /// In fil, this message translates to:
  /// **'Ituloy ang pagbasa'**
  String get shelfContinue;

  /// Shelf: the user's own documents.
  ///
  /// In fil, this message translates to:
  /// **'Aking mga dokumento'**
  String get shelfDocuments;

  /// Shelf: the user's collections.
  ///
  /// In fil, this message translates to:
  /// **'Mga koleksyon'**
  String get shelfCollections;

  /// Shelf: admin books (category name is used when grouped).
  ///
  /// In fil, this message translates to:
  /// **'Mga aklat'**
  String get shelfBooks;

  /// Shelf: search or filter results.
  ///
  /// In fil, this message translates to:
  /// **'Mga resulta'**
  String get shelfResults;

  /// Entering a shelf. No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'{title}, {count} aytem'**
  String shelfAnnounce(String title, int count);

  /// Empty shelf.
  ///
  /// In fil, this message translates to:
  /// **'Wala ka pang sinisimulang basahin.'**
  String get emptyContinue;

  /// Empty shelf.
  ///
  /// In fil, this message translates to:
  /// **'Wala ka pang dokumento. Mag-scan o mag-upload para magsimula.'**
  String get emptyDocuments;

  /// Empty shelf.
  ///
  /// In fil, this message translates to:
  /// **'Wala ka pang koleksyon. Sabihin ang “gumawa ng koleksyon” para gumawa.'**
  String get emptyCollections;

  /// Empty shelf.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang aklat sa ngayon. Kailangan ng internet para makita ang mga aklat.'**
  String get emptyBooks;

  /// Filter or search found nothing.
  ///
  /// In fil, this message translates to:
  /// **'Walang tugma sa napili mo.'**
  String get emptyResults;

  /// Empty collection.
  ///
  /// In fil, this message translates to:
  /// **'Walang laman ang koleksyong ito.'**
  String get emptyCollection;

  /// Library control: search.
  ///
  /// In fil, this message translates to:
  /// **'Hanapin'**
  String get libSearch;

  /// Library control: change the filter.
  ///
  /// In fil, this message translates to:
  /// **'Salain'**
  String get libFilter;

  /// Library control: new collection.
  ///
  /// In fil, this message translates to:
  /// **'Gumawa ng koleksyon'**
  String get libNewCollection;

  /// Filter.
  ///
  /// In fil, this message translates to:
  /// **'Lahat'**
  String get filterAll;

  /// Filter.
  ///
  /// In fil, this message translates to:
  /// **'Aking mga dokumento'**
  String get filterDocuments;

  /// Filter.
  ///
  /// In fil, this message translates to:
  /// **'Mga aklat'**
  String get filterBooks;

  /// Filter.
  ///
  /// In fil, this message translates to:
  /// **'Na-download'**
  String get filterDownloaded;

  /// Filter.
  ///
  /// In fil, this message translates to:
  /// **'Tapos na'**
  String get filterFinished;

  /// Filter: items with favorites.
  ///
  /// In fil, this message translates to:
  /// **'May paborito'**
  String get filterFavorites;

  /// Filter changed. No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'Salain: {name}, {count} aytem.'**
  String filterChanged(String name, int count);

  /// Before dictating a search.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang hinahanap pagkatapos ng tunog.'**
  String get librarySearchPrompt;

  /// Item line start for a book.
  ///
  /// In fil, this message translates to:
  /// **'{title}, ni {author}'**
  String libraryItemTitleAuthor(String title, String author);

  /// Item line start for an own document.
  ///
  /// In fil, this message translates to:
  /// **'{title}, {type}'**
  String libraryItemTitleType(String title, String type);

  /// Progress, spoken.
  ///
  /// In fil, this message translates to:
  /// **'{percent} porsiyento'**
  String libraryPercent(int percent);

  /// Item is finished.
  ///
  /// In fil, this message translates to:
  /// **'tapos na'**
  String get libraryFinishedWord;

  /// Item not started.
  ///
  /// In fil, this message translates to:
  /// **'hindi pa nasisimulan'**
  String get libraryNotStartedWord;

  /// When the item was last opened.
  ///
  /// In fil, this message translates to:
  /// **'huling binasa {when}'**
  String libraryLastRead(String when);

  /// New book label.
  ///
  /// In fil, this message translates to:
  /// **'Bago'**
  String get libraryNewLabel;

  /// Book is on the phone.
  ///
  /// In fil, this message translates to:
  /// **'naka-download'**
  String get libraryDownloadedWord;

  /// Book removed by the admin.
  ///
  /// In fil, this message translates to:
  /// **'hindi na available'**
  String get libraryUnavailableWord;

  /// Relative date.
  ///
  /// In fil, this message translates to:
  /// **'ngayon'**
  String get whenToday;

  /// Relative date.
  ///
  /// In fil, this message translates to:
  /// **'kahapon'**
  String get whenYesterday;

  /// Relative date (2 or more days). No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'{days} araw na ang nakalipas'**
  String whenDaysAgo(int days);

  /// Type of a book.
  ///
  /// In fil, this message translates to:
  /// **'EPUB'**
  String get formatEpub;

  /// A collection tile, spoken.
  ///
  /// In fil, this message translates to:
  /// **'Koleksyon: {name}, {count} aytem'**
  String libraryCollectionLine(String name, int count);

  /// A book that is not on the phone, while offline.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng internet para mabasa ito. I-download ito kapag may internet.'**
  String get libraryNeedsInternet;

  /// Opening an item by voice.
  ///
  /// In fil, this message translates to:
  /// **'Binubuksan ang {title}.'**
  String libraryOpening(String title);

  /// Voice command named an item that is not there.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko nahanap ang “{query}” sa Aklatan.'**
  String libraryNotFound(String query);

  /// Before dictating a collection name.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin ang pangalan ng koleksyon pagkatapos ng tunog.'**
  String get collectionNamePrompt;

  /// Collection created.
  ///
  /// In fil, this message translates to:
  /// **'Nagawa ang koleksyon na {name}.'**
  String collectionCreated(String name);

  /// Options for a collection (swipe up).
  ///
  /// In fil, this message translates to:
  /// **'Mga opsyon para sa koleksyong {name}. Mag-swipe para pumili: Buksan, Palitan ang pangalan, o Burahin.'**
  String collectionOptions(String name);

  /// Collection renamed.
  ///
  /// In fil, this message translates to:
  /// **'Pinalitan ang pangalan ng koleksyon: {name}.'**
  String collectionRenamed(String name);

  /// Confirm deleting a collection.
  ///
  /// In fil, this message translates to:
  /// **'Burahin ang koleksyong {name}? Hindi mabubura ang mga laman nito.'**
  String collectionDeleteConfirm(String name);

  /// Collection deleted.
  ///
  /// In fil, this message translates to:
  /// **'Nabura ang koleksyong {name}.'**
  String collectionDeleted(String name);

  /// Collection opened as a filter.
  ///
  /// In fil, this message translates to:
  /// **'Koleksyon: {name}, {count} aytem.'**
  String collectionOpened(String name, int count);

  /// Told at a catalog refresh.
  ///
  /// In fil, this message translates to:
  /// **'Inalis na ang {title} sa Aklatan. Nasa iyo pa rin ang iyong progreso.'**
  String bookRemovedNotice(String title);

  /// Spoken name of the item details screen.
  ///
  /// In fil, this message translates to:
  /// **'Detalye'**
  String get screenItemDetails;

  /// Details: progress.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pa nasisimulan.'**
  String get detailsNotStarted;

  /// Details: progress.
  ///
  /// In fil, this message translates to:
  /// **'Tapos mo nang basahin.'**
  String get detailsFinished;

  /// Details: progress.
  ///
  /// In fil, this message translates to:
  /// **'{percent} porsiyento ang nabasa.'**
  String detailsProgress(int percent);

  /// Details: estimated time left. No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'Mga {minutes} minuto pa ang natitira.'**
  String detailsMinutesLeft(int minutes);

  /// Details: almost done.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang isang minuto ang natitira.'**
  String get detailsLessThanMinute;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Ituloy'**
  String get actContinue;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Basahin'**
  String get actRead;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Basahin mula sa simula'**
  String get actFromStart;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Mga paborito'**
  String get actFavorites;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Mga kabanata'**
  String get actChapters;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Idagdag sa koleksyon'**
  String get actAddToCollection;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'I-download'**
  String get actDownload;

  /// Details action with the file size.
  ///
  /// In fil, this message translates to:
  /// **'I-download, {size}'**
  String actDownloadSized(String size);

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Alisin ang download'**
  String get actRemoveDownload;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Markahan bilang tapos na'**
  String get actMarkFinished;

  /// Details action.
  ///
  /// In fil, this message translates to:
  /// **'Markahan bilang hindi pa tapos'**
  String get actMarkUnfinished;

  /// File size.
  ///
  /// In fil, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(String size);

  /// File size.
  ///
  /// In fil, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(String size);

  /// Fetching a book to read online.
  ///
  /// In fil, this message translates to:
  /// **'Kinukuha ang aklat…'**
  String get bookLoading;

  /// Book fetch progress.
  ///
  /// In fil, this message translates to:
  /// **'{percent} porsiyento na.'**
  String bookLoadingPercent(int percent);

  /// Reading the downloaded file into text.
  ///
  /// In fil, this message translates to:
  /// **'Inihahanda ang aklat…'**
  String get bookPreparing;

  /// Download finished.
  ///
  /// In fil, this message translates to:
  /// **'Na-download ang {title}.'**
  String downloadDone(String title);

  /// Download removed.
  ///
  /// In fil, this message translates to:
  /// **'Naalis ang download ng {title}.'**
  String downloadRemoved(String title);

  /// Low storage warning (offer).
  ///
  /// In fil, this message translates to:
  /// **'Kaunti na lang ang espasyo ng phone. Mga {size} ang kailangan para dito. Gusto mo bang ituloy pa rin?'**
  String downloadLowStorage(String size);

  /// Book removed by the admin.
  ///
  /// In fil, this message translates to:
  /// **'Hindi na available ang {title}.'**
  String bookUnavailable(String title);

  /// DRM-protected EPUB.
  ///
  /// In fil, this message translates to:
  /// **'Protektado ng DRM ang EPUB na ito, kaya hindi ito mabubuksan ng app.'**
  String get bookDrm;

  /// Invalid EPUB or PDF.
  ///
  /// In fil, this message translates to:
  /// **'Sira o hindi wastong aklat ang file na ito.'**
  String get bookInvalid;

  /// Book has no readable text.
  ///
  /// In fil, this message translates to:
  /// **'Walang nabasang teksto sa aklat na ito.'**
  String get bookEmpty;

  /// Book fetch or read failed.
  ///
  /// In fil, this message translates to:
  /// **'May problema sa pagkuha ng aklat. Subukan ulit mamaya.'**
  String get bookFailed;

  /// Offer to update a downloaded book.
  ///
  /// In fil, this message translates to:
  /// **'May bagong bersyon ang {title}. I-update ang download? Mananatili ang iyong progreso.'**
  String bookUpdateOffer(String title);

  /// Download updated.
  ///
  /// In fil, this message translates to:
  /// **'Na-update ang {title}.'**
  String bookUpdated(String title);

  /// Marked finished.
  ///
  /// In fil, this message translates to:
  /// **'Minarkahan na tapos na ang {title}.'**
  String markedFinished(String title);

  /// Marked unfinished.
  ///
  /// In fil, this message translates to:
  /// **'Minarkahan na hindi pa tapos ang {title}.'**
  String markedUnfinished(String title);

  /// Choosing a collection.
  ///
  /// In fil, this message translates to:
  /// **'Idagdag ang {title} sa aling koleksyon? Mag-swipe para pumili, i-double tap para idagdag o alisin.'**
  String collectionPickIntro(String title);

  /// No collections to pick.
  ///
  /// In fil, this message translates to:
  /// **'Wala ka pang koleksyon. Gumawa muna ng isa sa Aklatan.'**
  String get collectionPickNone;

  /// A collection that already holds the item.
  ///
  /// In fil, this message translates to:
  /// **'{name}, nandito na'**
  String collectionPickIn(String name);

  /// Item added to a collection.
  ///
  /// In fil, this message translates to:
  /// **'Naidagdag ang {title} sa {name}.'**
  String collectionAdded(String title, String name);

  /// Item removed from a collection.
  ///
  /// In fil, this message translates to:
  /// **'Naalis ang {title} sa {name}.'**
  String collectionItemRemoved(String title, String name);

  /// First time a guest downloads a book (offer).
  ///
  /// In fil, this message translates to:
  /// **'Paalala: Naka-save lang ang iyong mga aklat sa phone na ito. Kapag nabura ang app, mawawala ang mga ito. Mag-register para ma-save ang iyong Aklatan at mabuksan ito sa ibang device. Gusto mo bang mag-register ngayon?'**
  String get guestDownloadWarning;

  /// Privacy note about own documents.
  ///
  /// In fil, this message translates to:
  /// **'Ang mga dokumentong sinu-scan o ina-upload mo ay mananatili sa phone na ito at hindi ipinapadala sa server, para sa iyong privacy.'**
  String get guestDocumentsStayHere;

  /// Spoken name of the favorites list.
  ///
  /// In fil, this message translates to:
  /// **'Mga paborito'**
  String get screenFavorites;

  /// Favorites prompt. No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'Mga paborito sa {title}. {count} ang naka-save. Mag-swipe para pumili, i-double tap para pumunta roon.'**
  String favoritesIntro(String title, int count);

  /// No favorites.
  ///
  /// In fil, this message translates to:
  /// **'Wala ka pang paborito sa {title}. Sabihin ang “paborito” habang nagbabasa.'**
  String favoritesEmpty(String title);

  /// A favorite with its chapter.
  ///
  /// In fil, this message translates to:
  /// **'{chapter}: {label}'**
  String favoriteLine(String chapter, String label);

  /// Favorite option.
  ///
  /// In fil, this message translates to:
  /// **'Pumunta dito'**
  String get optGoHere;

  /// Options for a favorite (swipe up).
  ///
  /// In fil, this message translates to:
  /// **'Mga opsyon: Pumunta dito, o Burahin. Mag-swipe para pumili.'**
  String get favoriteOptions;

  /// Confirm deleting a favorite.
  ///
  /// In fil, this message translates to:
  /// **'Burahin ang paborito na “{label}”?'**
  String favoriteDeleteConfirm(String label);

  /// Favorite deleted.
  ///
  /// In fil, this message translates to:
  /// **'Nabura ang paborito.'**
  String get favoriteDeleted;

  /// Reader button: save this spot as a favorite.
  ///
  /// In fil, this message translates to:
  /// **'Paborito'**
  String get readerFavorite;

  /// Favorite saved.
  ///
  /// In fil, this message translates to:
  /// **'Na-save bilang paborito'**
  String get readerFavoriteSaved;

  /// Chapter title announced when a chapter starts.
  ///
  /// In fil, this message translates to:
  /// **'{title}.'**
  String readerChapter(String title);

  /// Next/previous chapter on a document without chapters.
  ///
  /// In fil, this message translates to:
  /// **'Walang kabanata ang dokumentong ito.'**
  String get readerNoChapters;

  /// Last sentence read.
  ///
  /// In fil, this message translates to:
  /// **'Tapos mo nang basahin ang {title}.'**
  String readerFinishedTitle(String title);

  /// Spoken name of the chapters list.
  ///
  /// In fil, this message translates to:
  /// **'Mga kabanata'**
  String get screenChapters;

  /// Chapters prompt. No plural on purpose.
  ///
  /// In fil, this message translates to:
  /// **'Mga kabanata ng {title}. {count} lahat. Mag-swipe para pumili, i-double tap para pumunta roon.'**
  String chaptersIntro(String title, int count);

  /// No chapters.
  ///
  /// In fil, this message translates to:
  /// **'Walang kabanata ang aytem na ito.'**
  String get chaptersNone;

  /// A chapter in the list.
  ///
  /// In fil, this message translates to:
  /// **'{number}. {title}'**
  String chapterLine(int number, String title);

  /// Name of a chapter that has no title.
  ///
  /// In fil, this message translates to:
  /// **'Kabanata {number}'**
  String chapterFallback(int number);

  /// Help for Home.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili, at i-double tap para buksan. Sabihin ang “magbasa ng bago” o “aklatan”.'**
  String get helpHome;

  /// Help for the Library.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para lumipat ng aytem. Mag-swipe pataas o pababa para lumipat ng istante. I-double tap para buksan ang detalye. Sabihin ang “ituloy ang” at ang pamagat para ituloy agad, o “hanapin” para maghanap.'**
  String get helpLibrary;

  /// Help for item details.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili ng aksyon, at i-double tap para gawin ito. Ang una ay ang pagbasa.'**
  String get helpItemDetails;

  /// Help for favorites.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili ng paborito. I-double tap para pumunta roon. Mag-swipe pataas para sa mga opsyon.'**
  String get helpFavorites;

  /// Help for chapters.
  ///
  /// In fil, this message translates to:
  /// **'Mag-swipe pakanan o pakaliwa para pumili ng kabanata, at i-double tap para pumunta roon.'**
  String get helpChapters;

  /// Swiped past the last item of a shelf.
  ///
  /// In fil, this message translates to:
  /// **'Dulo ng istante.'**
  String get libraryEdgeSide;

  /// Swiped up from the first shelf.
  ///
  /// In fil, this message translates to:
  /// **'Nasa pinakaitaas ka na.'**
  String get libraryEdgeTop;

  /// Swiped down from the last shelf.
  ///
  /// In fil, this message translates to:
  /// **'Nasa pinakababa ka na.'**
  String get libraryEdgeBottom;

  /// Verbosity that shortens as the user gets used to a screen.
  ///
  /// In fil, this message translates to:
  /// **'Awtomatiko'**
  String get verbosityAuto;

  /// Answer to 'nasaan ako?'.
  ///
  /// In fil, this message translates to:
  /// **'Nasa {screen} ka.'**
  String whereAmIScreen(String screen);

  /// The focused option, in 'where am I'.
  ///
  /// In fil, this message translates to:
  /// **'Naka-focus: {item}.'**
  String whereAmIFocused(String item);

  /// Answer to 'ano ang pwede kong gawin?'.
  ///
  /// In fil, this message translates to:
  /// **'Dito, pwede mong sabihin: {commands}.'**
  String whatCanIDo(String commands);

  /// Tells the user questions work.
  ///
  /// In fil, this message translates to:
  /// **'Pwede mo rin akong tanungin, halimbawa: “nasaan ako?” o “anong oras na?”.'**
  String get askMeHint;

  /// Answer to 'anong oras na?'.
  ///
  /// In fil, this message translates to:
  /// **'{time} na ngayon.'**
  String timeNow(String time);

  /// Answer to 'anong petsa?'.
  ///
  /// In fil, this message translates to:
  /// **'Ngayon ay {date}.'**
  String dateToday(String date);

  /// No match: the closest commands.
  ///
  /// In fil, this message translates to:
  /// **'Hindi kita naintindihan. Baka ang ibig mo ay: {options}.'**
  String voiceSuggest(String options);

  /// No match and nothing close.
  ///
  /// In fil, this message translates to:
  /// **'Hindi kita naintindihan. Sabihin ang “ano ang pwede kong gawin” para marinig ang mga utos.'**
  String get voiceNotUnderstood;

  /// After several misses in a row.
  ///
  /// In fil, this message translates to:
  /// **'Kung nalilito ka, sabihin ang “paano gamitin” para sa maikling pag-aaral.'**
  String get voiceOfferHelp;

  /// Two documents match the name said.
  ///
  /// In fil, this message translates to:
  /// **'Alin sa dalawa: {first}, o {second}? Sabihin ang pangalan.'**
  String voiceWhichOne(String first, String second);

  /// Document question asked outside the Reader.
  ///
  /// In fil, this message translates to:
  /// **'Magbukas muna ng dokumento, saka mo ito itanong.'**
  String get docNeedsOpenDoc;

  /// Detected document type.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang resibo ito.'**
  String get docTypeReceipt;

  /// Detected document type.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang bill o singilin ito.'**
  String get docTypeBill;

  /// Detected document type.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang label ng gamot o reseta ito.'**
  String get docTypeMedicine;

  /// Detected document type.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang liham ito.'**
  String get docTypeLetter;

  /// Detected document type.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang form ito na may mga pupunan.'**
  String get docTypeForm;

  /// No type detected.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko matiyak kung anong klaseng dokumento ito.'**
  String get docTypeOther;

  /// Store, company or sender.
  ///
  /// In fil, this message translates to:
  /// **'Mula sa: {from}.'**
  String docFrom(String from);

  /// Who a letter is for.
  ///
  /// In fil, this message translates to:
  /// **'Para kay {name}.'**
  String docLetterTo(String name);

  /// Total or amount due.
  ///
  /// In fil, this message translates to:
  /// **'Kabuuan: {amount} piso.'**
  String docTotal(String amount);

  /// Bill due date.
  ///
  /// In fil, this message translates to:
  /// **'Dapat bayaran bago o sa {date}.'**
  String docDue(String date);

  /// Medicine expiry date.
  ///
  /// In fil, this message translates to:
  /// **'Mapapaso sa {date}.'**
  String docExpiry(String date);

  /// Dosage line from a medicine label.
  ///
  /// In fil, this message translates to:
  /// **'Paano inumin: {dosage}'**
  String docDosage(String dosage);

  /// Asked for a total that isn't there.
  ///
  /// In fil, this message translates to:
  /// **'Wala akong nakitang halaga o total sa dokumentong ito.'**
  String get docNoTotal;

  /// docNoDue
  ///
  /// In fil, this message translates to:
  /// **'Wala akong nakitang due date sa dokumentong ito.'**
  String get docNoDue;

  /// docNoExpiry
  ///
  /// In fil, this message translates to:
  /// **'Wala akong nakitang expiry date sa dokumentong ito.'**
  String get docNoExpiry;

  /// docNoDosage
  ///
  /// In fil, this message translates to:
  /// **'Wala akong nakitang paraan ng pag-inom sa dokumentong ito.'**
  String get docNoDosage;

  /// Offline summary of the document.
  ///
  /// In fil, this message translates to:
  /// **'Buod: {text}'**
  String docSummary(String text);

  /// docNoSummary
  ///
  /// In fil, this message translates to:
  /// **'Masyadong maikli ang dokumento para ibuod.'**
  String get docNoSummary;

  /// After the key facts of a new document.
  ///
  /// In fil, this message translates to:
  /// **'Pwede mo akong tanungin tungkol dito, halimbawa: “magkano?” o “ibuod mo”.'**
  String get docAskHint;

  /// Reader: how far.
  ///
  /// In fil, this message translates to:
  /// **'Nasa pangungusap {current} ng {total} ka, mga {percent} porsiyento.'**
  String readerProgress(String current, String total, String percent);

  /// Reader: which chapter.
  ///
  /// In fil, this message translates to:
  /// **'Kabanata {chapter} ng {chapters}.'**
  String readerProgressChapter(String chapter, String chapters);

  /// Settings link to the controls tutorial.
  ///
  /// In fil, this message translates to:
  /// **'Paano gamitin ang app'**
  String get setTutorial;

  /// Value text of that link.
  ///
  /// In fil, this message translates to:
  /// **'Pag-aaral ng mga kontrol'**
  String get setTutorialValue;

  /// Tutorial screen name.
  ///
  /// In fil, this message translates to:
  /// **'Pag-aaral ng mga kontrol'**
  String get screenTutorial;

  /// Skip the tutorial.
  ///
  /// In fil, this message translates to:
  /// **'Laktawan'**
  String get tutorialSkip;

  /// Tutorial first step.
  ///
  /// In fil, this message translates to:
  /// **'Tuturuan kita kung paano gamitin ang Percipere gamit ang daliri at boses. Mga dalawang minuto lang ito. I-double tap kahit saan sa screen para magsimula. Para laktawan, mag-swipe pakanan gamit ang dalawang daliri, o sabihin ang “laktawan”.'**
  String get tutorialIntro;

  /// tutorialSwipeRight
  ///
  /// In fil, this message translates to:
  /// **'Para lumipat sa susunod na pagpipilian, mag-swipe pakanan gamit ang isang daliri. Subukan mo ngayon.'**
  String get tutorialSwipeRight;

  /// tutorialSwipeLeft
  ///
  /// In fil, this message translates to:
  /// **'Para bumalik sa nakaraang pagpipilian, mag-swipe pakaliwa. Subukan mo.'**
  String get tutorialSwipeLeft;

  /// tutorialDoubleTap
  ///
  /// In fil, this message translates to:
  /// **'Para piliin ang pagpipilian, mag-double tap kahit saan sa screen. Subukan mo.'**
  String get tutorialDoubleTap;

  /// tutorialTap
  ///
  /// In fil, this message translates to:
  /// **'Para marinig ulit ang huling sinabi ko, mag-tap nang isang beses. Subukan mo.'**
  String get tutorialTap;

  /// tutorialBack
  ///
  /// In fil, this message translates to:
  /// **'Para bumalik sa nakaraang screen, mag-swipe pakanan gamit ang dalawang daliri. Subukan mo.'**
  String get tutorialBack;

  /// tutorialHelp
  ///
  /// In fil, this message translates to:
  /// **'Para humingi ng tulong sa kahit anong screen, mag-tap gamit ang tatlong daliri. Subukan mo.'**
  String get tutorialHelp;

  /// tutorialLongPress
  ///
  /// In fil, this message translates to:
  /// **'Para magsalita ng utos, pindutin nang matagal ang screen hanggang may marinig kang tunog. Subukan mo.'**
  String get tutorialLongPress;

  /// Voice practice.
  ///
  /// In fil, this message translates to:
  /// **'Ngayon, sabihin ang “tulong”.'**
  String get tutorialSay;

  /// Voice tips.
  ///
  /// In fil, this message translates to:
  /// **'Kapag naka-boses, nakikinig ako pagkatapos kong magsalita, kaya hindi mo na kailangang pumindot. Habang nagbabasa ako, pwede mong sabihin ang “i-pause” o “bilisan”. Pwede mo rin akong tanungin: “nasaan ako?”, “ano ang pwede kong gawin?”, at kapag may bukas na dokumento, “magkano?” o “ibuod mo”. I-double tap para magpatuloy.'**
  String get tutorialVoiceInfo;

  /// Tutorial summary.
  ///
  /// In fil, this message translates to:
  /// **'Tapos na! Tandaan: swipe para lumipat, double-tap para pumili, dalawang daliri pakanan para bumalik, at pindutin nang matagal para magsalita. Sabihin ang “paano gamitin” anumang oras para ulitin ito. I-double tap para magpatuloy.'**
  String get tutorialDone;

  /// Correct gesture.
  ///
  /// In fil, this message translates to:
  /// **'Magaling!'**
  String get tutorialGood;

  /// Correct gesture (variety).
  ///
  /// In fil, this message translates to:
  /// **'Tama!'**
  String get tutorialGoodAlt;

  /// Wrong gesture in the tutorial.
  ///
  /// In fil, this message translates to:
  /// **'Hindi iyon ang hinihintay ko. Subukan ulit.'**
  String get tutorialWrong;

  /// After three wrong tries.
  ///
  /// In fil, this message translates to:
  /// **'Ayos lang. Lilipat na tayo sa susunod.'**
  String get tutorialMovingOn;

  /// tutorialSkipped
  ///
  /// In fil, this message translates to:
  /// **'Nilaktawan ang pag-aaral. Sabihin ang “paano gamitin” kung gusto mo itong gawin mamaya.'**
  String get tutorialSkipped;

  /// Back gesture in the middle of the tutorial.
  ///
  /// In fil, this message translates to:
  /// **'Gusto mo bang laktawan ang pag-aaral?'**
  String get tutorialSkipQuestion;

  /// tutorialNoMic
  ///
  /// In fil, this message translates to:
  /// **'Hindi pa pinapayagan ang mikropono, kaya lalaktawan natin ang pagsasanay sa boses.'**
  String get tutorialNoMic;

  /// No ElevenLabs agent id was built into the app.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pa naka-set up si Percy, ang voice assistant. Gamitin muna ang karaniwang mga utos.'**
  String get assistantNotSetUp;

  /// No description provided for @assistantOffline.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng internet para kay Percy. Gumagana pa rin ang karaniwang mga utos.'**
  String get assistantOffline;

  /// First use of the voice assistant: privacy consent (yes/no).
  ///
  /// In fil, this message translates to:
  /// **'Ito ang online na bersyon ni Percy para sa mga developer, na gumagamit ng internet. Ang sasabihin mo, at ang teksto ng dokumento kapag tinanong mo siya tungkol dito, ay ipapadala sa ElevenLabs para maintindihan ka. Payag ka ba?'**
  String get assistantConsentAsk;

  /// No description provided for @assistantConsentDeclined.
  ///
  /// In fil, this message translates to:
  /// **'Sige, hindi muna gagamitin si Percy. Pwede mo siyang tawagin ulit kapag gusto mo.'**
  String get assistantConsentDeclined;

  /// No description provided for @assistantMicNeeded.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ni Percy ang mikropono. Payagan ito sa settings ng app.'**
  String get assistantMicNeeded;

  /// No description provided for @assistantConnecting.
  ///
  /// In fil, this message translates to:
  /// **'Tinatawag si Percy.'**
  String get assistantConnecting;

  /// No description provided for @assistantEnded.
  ///
  /// In fil, this message translates to:
  /// **'Tapos na ang usapan kay Percy.'**
  String get assistantEnded;

  /// No description provided for @assistantFailed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi makakonekta kay Percy ngayon. Subukan ulit mamaya. Gumagana pa rin ang karaniwang mga utos.'**
  String get assistantFailed;

  /// What the ElevenLabs agent says first.
  ///
  /// In fil, this message translates to:
  /// **'Kumusta po! Ako si Percy. Ano po ang maitutulong ko?'**
  String get assistantFirstMessage;

  /// Added to help: how to start and end the voice assistant.
  ///
  /// In fil, this message translates to:
  /// **'Para tawagin si Percy, ang voice assistant, mag-swipe pakaliwa gamit ang dalawang daliri, o sabihin ang “Percy”. Para tapusin, sabihin ang “paalam” o gumawa ng kahit anong galaw.'**
  String get assistantHowToCall;

  /// How the assistant addresses a guest (no name).
  ///
  /// In fil, this message translates to:
  /// **'kaibigan'**
  String get assistantGuestName;

  /// Settings row: Percy's politeness.
  ///
  /// In fil, this message translates to:
  /// **'Paraan ng pagsalita ni Percy'**
  String get setPercyPoliteness;

  /// No description provided for @valuePercyPo.
  ///
  /// In fil, this message translates to:
  /// **'Magalang (may po)'**
  String get valuePercyPo;

  /// No description provided for @valuePercyCasual.
  ///
  /// In fil, this message translates to:
  /// **'Kaswal'**
  String get valuePercyCasual;

  /// Settings row: how much Percy says.
  ///
  /// In fil, this message translates to:
  /// **'Haba ng sagot ni Percy'**
  String get setPercyTalk;

  /// No description provided for @valuePercyBrief.
  ///
  /// In fil, this message translates to:
  /// **'Maikli'**
  String get valuePercyBrief;

  /// No description provided for @valuePercyNormal.
  ///
  /// In fil, this message translates to:
  /// **'Katamtaman'**
  String get valuePercyNormal;

  /// No description provided for @valuePercyChatty.
  ///
  /// In fil, this message translates to:
  /// **'Madaldal'**
  String get valuePercyChatty;

  /// Settings row: keep Percy's turn log on the phone for retraining.
  ///
  /// In fil, this message translates to:
  /// **'I-save ang usapan kay Percy (pang-training)'**
  String get setPercyLogging;

  /// Hidden developer row: use the ElevenLabs Percy instead of the self-built one.
  ///
  /// In fil, this message translates to:
  /// **'Percy online (ElevenLabs, developer)'**
  String get setPercyElevenLabs;

  /// Hidden developer row: export Percy's turn log.
  ///
  /// In fil, this message translates to:
  /// **'I-export ang log ni Percy (CSV)'**
  String get setPercyExport;

  /// Value of the export row.
  ///
  /// In fil, this message translates to:
  /// **'{count} na pangungusap'**
  String percyExportCount(String count);

  /// Export with an empty log.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang naka-log na usapan kay Percy.'**
  String get percyExportEmpty;

  /// After the export opened the share sheet.
  ///
  /// In fil, this message translates to:
  /// **'Inihanda ko na ang CSV. Piliin kung saan ito ipapadala.'**
  String get percyExportDone;

  /// Export failed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko ma-export ang log ngayon.'**
  String get percyExportFailed;

  /// Percy can't start without the microphone.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ni Percy ang mikropono para marinig ka. Payagan ito sa settings ng app.'**
  String get percyMicNeeded;

  /// Percy's model failed to load.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ko mabuksan si Percy ngayon. Gumagana pa rin ang karaniwang mga utos.'**
  String get percyUnavailable;

  /// Spoken when a command was cut off and listening could not be restarted after a few tries.
  ///
  /// In fil, this message translates to:
  /// **'Pasensya na po, pakiulit.'**
  String get voiceSayAgain;

  /// Label of the speed strip at the right edge of the Gesture Area.
  ///
  /// In fil, this message translates to:
  /// **'Bilis'**
  String get speedStripLabel;

  /// Screen-reader description of the speed strip.
  ///
  /// In fil, this message translates to:
  /// **'Bilis, {rate} na beses'**
  String speedStripValue(String rate);

  /// Spoken after the speed strip stops moving.
  ///
  /// In fil, this message translates to:
  /// **'Bilis {rate}'**
  String speedSpoken(String rate);

  /// Accessibility action on the speed strip: increase speed.
  ///
  /// In fil, this message translates to:
  /// **'Bilisan'**
  String get speedIncrease;

  /// Accessibility action on the speed strip: decrease speed.
  ///
  /// In fil, this message translates to:
  /// **'Bagalan'**
  String get speedDecrease;

  /// Settings row: female or male reading voice.
  ///
  /// In fil, this message translates to:
  /// **'Boses sa pagbasa'**
  String get setReadingVoice;

  /// Reading voice not chosen yet: the engine's default voice.
  ///
  /// In fil, this message translates to:
  /// **'Karaniwan'**
  String get valueVoiceDefault;

  /// No description provided for @valueVoiceFemale.
  ///
  /// In fil, this message translates to:
  /// **'Babae'**
  String get valueVoiceFemale;

  /// No description provided for @valueVoiceMale.
  ///
  /// In fil, this message translates to:
  /// **'Lalaki'**
  String get valueVoiceMale;

  /// A voice whose gender is unknown, shown by its name.
  ///
  /// In fil, this message translates to:
  /// **'Boses {number} ({name})'**
  String valueVoiceNamed(String number, String name);

  /// Reading voice row when the phone has only one voice for this language.
  ///
  /// In fil, this message translates to:
  /// **'Iisa lang ang boses'**
  String get valueVoiceOnlyOne;

  /// Spoken when the reading voice row is opened and only one voice exists.
  ///
  /// In fil, this message translates to:
  /// **'Iisa lang ang boses sa teleponong ito para sa wikang ito, kaya hindi ito mapapalitan.'**
  String get voiceOnlyOne;

  /// Spoken (in the new voice) after the reading voice changed.
  ///
  /// In fil, this message translates to:
  /// **'Napalitan na ang boses: {voice}.'**
  String voiceChanged(String voice);

  /// Settings row that plays a sample in the chosen reading voice.
  ///
  /// In fil, this message translates to:
  /// **'Pakinggan ang boses'**
  String get setVoicePreview;

  /// No description provided for @valueVoicePreview.
  ///
  /// In fil, this message translates to:
  /// **'I-play ang halimbawa'**
  String get valueVoicePreview;

  /// Sample sentence spoken by the voice preview.
  ///
  /// In fil, this message translates to:
  /// **'Ganito ang tunog ng boses na babasa ng iyong mga dokumento.'**
  String get voicePreviewSample;
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
