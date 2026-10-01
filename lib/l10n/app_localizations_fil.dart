// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appName => 'Percipere';

  @override
  String get welcomeTitleLine1 => 'Welcome to';

  @override
  String get welcomeSubtitle => 'An app built on your behalf';

  @override
  String get welcomePrompt => 'Paano mo gustong mag-navigate sa app?';

  @override
  String get navModeVoice => 'Pa-boses (Voice)';

  @override
  String get navModeGestures => 'Pa-galaw (Gestures)';

  @override
  String get capturePrompt =>
      'Paano mo gustong i-capture ang iyong dokyumento?';

  @override
  String get captureUpload => 'Mag-upload';

  @override
  String get captureCamera => 'Gamit ang Camera';

  @override
  String get gestureAreaLabel => 'Lugar ng galaw (Gesture area)';

  @override
  String get gestureAreaHintMenu =>
      'Mag-swipe pakanan o pakaliwa para lumipat ng pagpipilian. I-double tap para pumili. Pindutin nang matagal para magsalita.';

  @override
  String get gestureAreaHintReader =>
      'I-tap para basahin o i-pause. Mag-swipe pakanan o pakaliwa para sa susunod o nakaraang pangungusap. Mag-swipe pataas o pababa para bilisan o bagalan.';

  @override
  String heardLabel(String text) {
    return 'Narinig: “$text”';
  }

  @override
  String get readerLoading => 'Binabasa ang dokumento…';

  @override
  String get readerDocumentLabel => 'Dokumento';

  @override
  String get readerEmpty => 'Walang tekstong mababasa.';

  @override
  String get screenCapture => 'Pagkuha ng dokumento';

  @override
  String get screenReader => 'Pagbasa';

  @override
  String get welcomeIntro =>
      'Maligayang pagdating sa Percipere, isang app na ginawa para sa iyo. Paano mo gustong mag-navigate sa app? I-double tap kahit saan sa screen para sa pa-boses. Mag-swipe pakanan para sa pa-galaw. I-tap para marinig ulit ito.';

  @override
  String get helpWelcome =>
      'I-double tap: pa-boses. Mag-swipe pakanan: pa-galaw. I-tap: ulitin ang tanong.';

  @override
  String get modeChosenVoice => 'Napili mo ang pa-boses.';

  @override
  String get modeChosenGestures => 'Napili mo ang pa-galaw.';

  @override
  String get readerReady => 'Handa na ang dokumento.';

  @override
  String optionsList(String items) {
    return 'Mga pagpipilian: $items.';
  }

  @override
  String get wordOr => 'o';

  @override
  String focusedItem(String label, int position, int total) {
    return '$label, $position sa $total.';
  }

  @override
  String get modeHintGestures =>
      'Mag-swipe pakanan o pakaliwa para lumipat, at i-double tap para pumili.';

  @override
  String get modeHintVoice =>
      'Sabihin ang utos pagkatapos ng tunog, o pindutin nang matagal ang lugar ng galaw. Gumagana rin ang mga galaw.';

  @override
  String get modeHintTalkBack =>
      'Gamitin ang mga galaw ng TalkBack para pumili.';

  @override
  String get nothingFocused =>
      'Wala pang napili. Mag-swipe pakanan para pumili.';

  @override
  String get commandNotAvailable => 'Hindi magagamit ang utos na iyan dito.';

  @override
  String get alreadyAtStart => 'Nasa unang screen ka na.';

  @override
  String helpTitle(String screen) {
    return 'Tulong para sa $screen.';
  }

  @override
  String get helpGesturesMenu =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. I-tap: ulitin ang tanong. Mag-swipe pababa gamit ang dalawang daliri: bumalik. Pindutin nang matagal: magsalita ng utos. I-double tap gamit ang dalawang daliri: patigilin ang pagsasalita. I-tap gamit ang tatlong daliri: tulong.';

  @override
  String get talkBackNotice =>
      'Naka-on ang TalkBack, kaya ang mga galaw ng TalkBack ang gagamitin sa halip na mga galaw ng Percipere. Gumagana pa rin ang mga utos sa boses.';

  @override
  String get ttsFilipinoMissing =>
      'The Filipino voice is not installed on this phone, so Percipere will speak English for now. To install it, open text-to-speech settings, choose Speech Services by Google, and download the Filipino voice.';

  @override
  String get ttsFilipinoMissingSwipeUp =>
      'Swipe up now to open text-to-speech settings.';

  @override
  String get ttsOpeningSettings => 'Opening text-to-speech settings.';

  @override
  String get filipinoVoiceReady => 'Handa na ang boses na Filipino.';

  @override
  String get welcomeSayHint => 'Maaari mo ring sabihin ang “boses” o “galaw”.';

  @override
  String get listening => 'Nakikinig…';

  @override
  String voiceUnknown(String commands) {
    return 'Pasensya na, hindi ko naintindihan. Maaari mong sabihin: $commands.';
  }

  @override
  String get voiceCommonCommands =>
      'susunod, nakaraan, piliin, ulitin, bumalik, o tulong';

  @override
  String voiceDidYouMean(String phrase) {
    return 'Ang ibig mo bang sabihin ay “$phrase”? Sabihin ang oo o hindi.';
  }

  @override
  String get voiceCancelled => 'Sige.';

  @override
  String get voiceWakeReply => 'Nakikinig ako.';

  @override
  String get voiceNothingHeard => 'Wala akong narinig.';

  @override
  String get voiceListeningPaused =>
      'Hihinto muna ako sa pakikinig. Pindutin nang matagal ang lugar ng galaw para kausapin ulit ako.';

  @override
  String get micPermissionExplain =>
      'Hihingi ngayon ang Android ng pahintulot na gamitin ng Percipere ang mikropono, para marinig ko ang iyong mga utos. Piliin ang “Habang ginagamit ang app”.';

  @override
  String get micDenied =>
      'Hindi ko magagamit ang mikropono, kaya mga galaw muna ang gagamitin.';

  @override
  String get micDeniedPermanent =>
      'Naka-block ang mikropono para sa Percipere. Maaari itong payagan sa settings ng app.';

  @override
  String get offerConfirmHint =>
      'I-double tap, o sabihin ang “oo”, para ituloy.';

  @override
  String get voiceUnavailable =>
      'Walang speech recognition ang teleponong ito, kaya mga galaw ang gagamitin.';

  @override
  String get voiceOfflineMissing =>
      'Walang internet, at hindi pa naka-install ang offline na pagkilala sa boses. Maaari itong i-download sa Settings, sa voice input.';

  @override
  String get featureNotReady => 'Wala pa ang bahaging iyan sa bersyong ito.';

  @override
  String helpVoiceCommands(String commands) {
    return 'Mga utos sa boses: $commands.';
  }

  @override
  String get screenCamera => 'Camera';

  @override
  String get cameraIntro =>
      'Itutok ang camera sa dokumento, mga tatlumpung sentimetro ang layo. Sasabihin ko kung ilalapit o ilalayo. I-double tap o sabihin ang “kunan” para kumuha ng litrato. Kusa rin akong kukuha kapag malinaw na ang teksto.';

  @override
  String get cameraCaptureButton => 'Kunan ang litrato';

  @override
  String get guideTooDark =>
      'Masyadong madilim. Humanap ng mas maliwanag na lugar.';

  @override
  String get guideNoText => 'Walang nakikitang teksto.';

  @override
  String get guideMoveCloser => 'Ilapit pa.';

  @override
  String get guideMoveBack => 'Ilayo nang kaunti.';

  @override
  String get guideReady => 'Handa na, hawakan nang maayos.';

  @override
  String get cameraCapturing => 'Kinukunan na.';

  @override
  String get cameraCaptureFailed => 'Hindi nakuha ang litrato. Subukan ulit.';

  @override
  String get cameraPermissionExplain =>
      'Hihingi ngayon ang Android ng pahintulot na gamitin ng Percipere ang camera. Piliin ang “Habang ginagamit ang app”.';

  @override
  String get cameraDenied =>
      'Hindi ko magagamit ang camera. Maaari kang mag-upload ng litrato sa halip.';

  @override
  String get cameraDeniedPermanent =>
      'Naka-block ang camera para sa Percipere. Maaari itong payagan sa settings ng app.';

  @override
  String get cameraUnavailable =>
      'Hindi mabuksan ang camera. Maaari kong buksan ang camera app ng telepono.';

  @override
  String get helpCamera =>
      'I-double tap: kunan ang litrato. I-tap: ulitin ang gabay. Mag-swipe pababa gamit ang dalawang daliri: bumalik.';

  @override
  String get uploadOpening => 'Pumili ng larawan, PDF, o Word na file.';

  @override
  String get uploadCancelled => 'Walang napiling file.';

  @override
  String readerExtractingPage(int page, int total) {
    return 'Binabasa ang pahina $page sa $total.';
  }

  @override
  String readerReadyParagraphs(int count) {
    return 'Handa na ang dokumento, may $count talata.';
  }

  @override
  String get readerLowQuality =>
      'Maaaring hindi malinaw ang pagkabasa sa ilang bahagi ng teksto.';

  @override
  String get readerNoText => 'Wala akong mabasang teksto.';

  @override
  String get readerPhotoTips =>
      'Subukan sa mas maliwanag na lugar, at hawakan nang tuwid at hindi gumagalaw ang telepono.';

  @override
  String get readerRetakeOffer => 'Gusto mo bang kumuha ulit ng litrato?';

  @override
  String get readerUnreadable =>
      'Hindi mabuksan ang file na ito. Maaaring sira ito.';

  @override
  String get readerUnsupported =>
      'Hindi ko pa kayang basahin ang ganitong file. Pumili ng larawan, PDF, o Word na file.';

  @override
  String get readerPasswordProtected =>
      'May password ang PDF na ito, kaya hindi ko ito mabasa.';

  @override
  String get readerStartHint =>
      'I-tap, o sabihin ang “basahin”, para magsimula.';

  @override
  String readerResumeAt(int position, int total) {
    return 'Magpapatuloy sa pangungusap $position sa $total.';
  }

  @override
  String get readerFinished => 'Tapos na ang dokumento.';

  @override
  String get readerPaused => 'Naka-pause.';

  @override
  String readerSpeed(String rate) {
    return 'Bilis: ${rate}x';
  }

  @override
  String get readerSaved => 'Na-save sa kasaysayan.';

  @override
  String get readerAtStart => 'Ito na ang simula.';

  @override
  String get readerAtEnd => 'Ito na ang huling pangungusap.';

  @override
  String get readerFromStart => 'Mula sa simula.';

  @override
  String get readerFilipinoNoVoice =>
      'This document is in Filipino, but no Filipino voice is installed, so it will be read with an English voice and may be hard to understand.';

  @override
  String get helpReader =>
      'I-tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pakanan o pakaliwa gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-double tap: ulitin ang pangungusap. Mag-swipe pababa gamit ang dalawang daliri: bumalik. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, ulitin, mula sa simula, i-save, at bumalik.';

  @override
  String get captureHistory => 'Kasaysayan';

  @override
  String get captureSettings => 'Mga Setting';

  @override
  String get screenSettings => 'Mga Setting';

  @override
  String get settingsIntro =>
      'Mag-swipe pakanan o pakaliwa para pumili ng setting, at pataas o pababa para baguhin ito.';

  @override
  String get helpSettings =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng setting. Mag-swipe pataas o pababa: baguhin ang halaga. I-double tap: susunod na pagpipilian, o buksan. Mag-swipe pababa gamit ang dalawang daliri: bumalik.';

  @override
  String settingValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get setReadingRate => 'Bilis ng pagbasa';

  @override
  String get setPitch => 'Tono ng boses';

  @override
  String get setLanguage => 'Wika';

  @override
  String get setDocumentVoice => 'Boses ng dokumento';

  @override
  String get setTextSize => 'Laki ng teksto';

  @override
  String get setFont => 'Font';

  @override
  String get setColors => 'Kulay';

  @override
  String get setNavMode => 'Paraan ng pag-navigate';

  @override
  String get setHaptics => 'Pag-vibrate';

  @override
  String get setVerbosity => 'Haba ng mga paliwanag';

  @override
  String get setAutoCapture => 'Kusang pagkuha ng litrato';

  @override
  String get setAccount => 'Account';

  @override
  String get setTtsVoices => 'Mga boses ng pagbasa';

  @override
  String get valueOn => 'Naka-on';

  @override
  String get valueOff => 'Naka-off';

  @override
  String get valueAuto => 'Awtomatiko';

  @override
  String get langFilipino => 'Filipino';

  @override
  String get langEnglish => 'Ingles';

  @override
  String get paletteDefault => 'Karaniwan: cream at navy';

  @override
  String get paletteHighContrast => 'Puti sa itim';

  @override
  String get paletteYellow => 'Dilaw sa itim';

  @override
  String get paletteBlackOnWhite => 'Itim sa puti';

  @override
  String get verbosityBrief => 'Maikli';

  @override
  String get verbosityNormal => 'Karaniwan';

  @override
  String get verbosityDetailed => 'Detalyado';

  @override
  String get navVoice => 'Pa-boses';

  @override
  String get navGestures => 'Pa-galaw';

  @override
  String get accountNone => 'Walang naka-login';

  @override
  String accountAs(String name) {
    return 'Naka-login si $name';
  }

  @override
  String get ttsFilipinoInstalled => 'May boses na Filipino';

  @override
  String get ttsFilipinoNotInstalled =>
      'Walang boses na Filipino. I-double tap para mag-install.';

  @override
  String get actionIncrease => 'Dagdagan';

  @override
  String get actionDecrease => 'Bawasan';

  @override
  String get actionChange => 'Palitan';

  @override
  String get actionOpen => 'Buksan';

  @override
  String get screenHistory => 'Kasaysayan ng Pagbasa';

  @override
  String historyIntro(int count) {
    return 'May $count na dokumento. Mag-swipe pakanan para marinig ang bawat isa, at i-double tap para buksan.';
  }

  @override
  String get historyEmpty =>
      'Wala pang nababasang dokumento. Magbasa muna gamit ang Mag-upload o ang Camera.';

  @override
  String historyItem(String title, String source, String date) {
    return '$title, $source, $date';
  }

  @override
  String get sourceCamera => 'litrato';

  @override
  String get sourceImage => 'larawan';

  @override
  String get sourcePdf => 'PDF';

  @override
  String get sourceDocx => 'Word';

  @override
  String historyResults(int count, String query) {
    return '$count resulta para sa “$query”.';
  }

  @override
  String historyNoResults(String query) {
    return 'Walang nahanap para sa “$query”.';
  }

  @override
  String get historyShowAll => 'Ipinapakita muli ang lahat.';

  @override
  String historyOptions(String title) {
    return 'Mga opsyon para sa $title. Mag-swipe para pumili: Buksan, Palitan ang pangalan, o Burahin. I-double tap para piliin.';
  }

  @override
  String get optOpen => 'Buksan';

  @override
  String get optRename => 'Palitan ang pangalan';

  @override
  String get optDelete => 'Burahin';

  @override
  String get historyRenamePrompt =>
      'Sabihin ang bagong pangalan pagkatapos ng tunog.';

  @override
  String historyRenamed(String title) {
    return 'Pinalitan ang pangalan: $title.';
  }

  @override
  String historyDeleteConfirm(String title) {
    return 'Burahin ang “$title”?';
  }

  @override
  String historyDeleted(String title) {
    return 'Nabura ang “$title”.';
  }

  @override
  String get historySearch => 'Hanapin';

  @override
  String get helpHistory =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng dokumento. I-double tap: buksan at ituloy ang pagbasa. Mag-swipe pataas: mga opsyon, gaya ng palitan ang pangalan at burahin. Sabihin ang “hanapin” at ang salita para maghanap. Mag-swipe pababa gamit ang dalawang daliri: bumalik.';

  @override
  String get screenAccount => 'Account';

  @override
  String get accountIntroGuest =>
      'Ginagamit ang Percipere nang walang account. Gumawa ng profile para mai-save ang iyong mga setting.';

  @override
  String accountIntroUser(String name) {
    return 'Naka-login si $name.';
  }

  @override
  String get accountCreate => 'Gumawa ng profile';

  @override
  String get accountLogin => 'Mag-login';

  @override
  String get accountLogout => 'Mag-logout';

  @override
  String get accountLoggedOut =>
      'Naka-logout na. Ginagamit ang mga setting ng teleponong ito.';

  @override
  String accountLoggedIn(String name) {
    return 'Maligayang pagbabalik, $name.';
  }

  @override
  String accountCreated(String name) {
    return 'Nagawa ang profile ni $name, at naka-login na.';
  }

  @override
  String get screenCreateProfile => 'Bagong profile';

  @override
  String get profileAskName =>
      'Ano ang iyong pangalan? Pindutin nang matagal ang lugar ng galaw at sabihin ito, o i-type.';

  @override
  String profileNameIs(String name) {
    return 'Pangalan: $name. I-double tap para ituloy, o pindutin nang matagal para ulitin.';
  }

  @override
  String get profileAskEmail =>
      'Email, kung mayroon. Pindutin nang matagal para sabihin ito, o i-type. Mag-swipe pakanan para laktawan.';

  @override
  String profileEmailIs(String email) {
    return 'Email: $email. I-double tap para ituloy.';
  }

  @override
  String get profileAskPin =>
      'Gumawa ng apat na numerong PIN. Mag-swipe pataas o pababa para pumili ng numero at i-double tap para ilagay ito. Maaari mo ring pindutin nang matagal at sabihin ang apat na numero.';

  @override
  String get profileConfirmPin => 'Ilagay ulit ang PIN para makumpirma.';

  @override
  String get profilePinMismatch => 'Hindi magkapareho ang PIN. Subukan ulit.';

  @override
  String get profileNameMissing => 'Kailangan muna ng pangalan.';

  @override
  String get fieldName => 'Pangalan';

  @override
  String get fieldEmail => 'Email (opsyonal)';

  @override
  String get fieldPin => 'PIN';

  @override
  String get actionContinue => 'Ituloy';

  @override
  String get actionSkip => 'Laktawan';

  @override
  String get screenLogin => 'Mag-login';

  @override
  String get loginChooseProfile => 'Pumili ng profile.';

  @override
  String loginAskPin(String name) {
    return 'Ilagay ang PIN ni $name.';
  }

  @override
  String get loginWrongPin => 'Mali ang PIN. Subukan ulit.';

  @override
  String get loginNoProfiles => 'Wala pang profile sa teleponong ito.';

  @override
  String pinDigitEntered(int count, int total) {
    return 'Numero $count sa $total.';
  }

  @override
  String get pinDeleted => 'Binura ang huling numero.';

  @override
  String get pinSayFour =>
      'Sabihin ang apat na numero, halimbawa: isa, dalawa, tatlo, apat.';

  @override
  String get pinDelete => 'Burahin';

  @override
  String get helpPin =>
      'Mag-swipe pataas o pababa: pumili ng numero. I-double tap: ilagay ang numero. Mag-swipe pakaliwa: burahin ang huling numero. Pindutin nang matagal: sabihin ang apat na numero.';
}
