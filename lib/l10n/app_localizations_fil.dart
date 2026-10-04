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
      'I-double tap para basahin o i-pause. Mag-swipe pakanan o pakaliwa para sa susunod o nakaraang pangungusap. Mag-swipe pataas o pababa para bilisan o bagalan.';

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
  String get helpWelcome =>
      'Mag-swipe pakanan o pakaliwa: lumipat sa Login, Register, o Subukan muna. I-double tap: pindutin. I-tap: ulitin ang tanong. Pindutin nang matagal: magsalita. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get modeChosenVoice => 'Napili mo ang pa-boses.';

  @override
  String get modeChosenGestures => 'Napili mo ang pa-galaw.';

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
  String get alreadyAtStart => 'Nasa simula ka na.';

  @override
  String helpTitle(String screen) {
    return 'Tulong para sa $screen.';
  }

  @override
  String get helpGesturesMenu =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. I-tap: ulitin ang tanong. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin nang matagal: magsalita ng utos. I-double tap gamit ang dalawang daliri: patigilin ang pagsasalita. I-tap gamit ang tatlong daliri: tulong.';

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
  String get voiceRepeatedError =>
      'Hindi gumagana ang pakikinig ng boses ko ngayon. Hihinto muna ako. Pindutin nang matagal ang lugar ng galaw para subukan ulit, o gumamit ng mga galaw.';

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
      'I-double tap: kunan ang litrato. I-tap: ulitin ang gabay. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

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
      'Mag-double-tap para simulan ang pagbasa, o sabihin ang “basahin”.';

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
  String readerSize(int size) {
    return 'Laki: $size';
  }

  @override
  String get readerSizeMax => 'Pinakamalaki na.';

  @override
  String get readerSizeMin => 'Pinakamaliit na.';

  @override
  String get readerTextBigger => 'Palakihin ang teksto';

  @override
  String get readerTextSmaller => 'Paliitin ang teksto';

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
      'I-double tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pababa o pataas gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-tap: ulitin ang pangungusap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin ang A plus o A minus sa taas ng kahon, o i-pinch ang kahon ng dokumento, para palakihin o paliitin ang teksto. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, palakihin, paliitin, ulitin, mula sa simula, i-save, at bumalik.';

  @override
  String get captureDescribe => 'Maglarawan';

  @override
  String get describeAnnouncement =>
      'Pwede mo ring gamitin ang bago naming feature: Maglarawan. Sasabihin nito kung ano ang nasa isang larawan.';

  @override
  String get describeExplanation =>
      'Ang Maglarawan ay para sa mga larawang walang teksto, o kung gusto mong malaman kung ano ang nasa larawan. Kumuha ng litrato gamit ang camera o mag-upload ng larawan, at sasabihin namin kung ano ang nakikita namin. Kung may internet, maaari kang humingi ng mas detalyadong paglalarawan.';

  @override
  String get screenDescribe => 'Maglarawan';

  @override
  String get describeSourcePrompt => 'Paano mo gustong kunin ang larawan?';

  @override
  String get describeWorking => 'Tinitingnan ang larawan…';

  @override
  String describeLooksLike(String items) {
    return 'Mukhang may $items sa larawan.';
  }

  @override
  String get describeAnd => 'at';

  @override
  String get describeNothing =>
      'Hindi ko matiyak kung ano ang nasa larawan. Subukan ulit na may mas maliwanag na ilaw.';

  @override
  String get describeReminder =>
      'Paalala: kumpirmahin ito sa taong pinagkakatiwalaan mo bago gamitin.';

  @override
  String get describeTextFound =>
      'May nakita rin akong teksto. Gusto mo bang basahin ito?';

  @override
  String get describeNoText => 'Walang nakitang teksto sa larawang ito.';

  @override
  String get describeDetailOffer =>
      'Gusto mo ba ng mas detalyadong paglalarawan?';

  @override
  String get describeNeedsInternet =>
      'Kailangan ng internet para sa mas detalyadong paglalarawan. Subukan ulit kapag may internet.';

  @override
  String get describeConsentAsk =>
      'Ipapadala ang larawan sa aming server at sa serbisyo ng Google para mailarawan ito. Sige ba?';

  @override
  String get describeConsentDeclined =>
      'Sige, hindi ko ipapadala ang larawan. Mababago mo ito sa Settings.';

  @override
  String get describeDetailFailed =>
      'Hindi ko makuha ang detalyadong paglalarawan ngayon. Subukan ulit mamaya.';

  @override
  String get describeUnreadable => 'Hindi ko mabasa ang larawang ito.';

  @override
  String get describeRepeat => 'Ulitin';

  @override
  String get describeMore => 'Mas detalyado';

  @override
  String get describeReadText => 'Basahin ang teksto';

  @override
  String get describeSave => 'I-save';

  @override
  String get describeNew => 'Bagong larawan';

  @override
  String get describeThumbnailLabel => 'Ang larawan';

  @override
  String get helpDescribe =>
      'Mag-swipe pakanan o pakaliwa para pumili ng opsyon, at i-double tap para gamitin. Mga opsyon: ulitin, mas detalyado, basahin ang teksto, i-save, at bagong larawan. I-pinch ang kahon para palakihin o paliitin ang teksto. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get sourceDescription => 'larawan (Maglarawan)';

  @override
  String get setDescribeConsent => 'Detalyadong paglalarawan';

  @override
  String get valueConsentAsk => 'Itatanong muna';

  @override
  String get valueConsentAllowed => 'Pinapayagan';

  @override
  String get valueConsentDeclined => 'Hindi pinapayagan';

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
      'Mag-swipe pakanan o pakaliwa: lumipat ng setting. Mag-swipe pataas o pababa: baguhin ang halaga. I-double tap: susunod na pagpipilian, o buksan. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

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
  String get setNavMode => 'Paraan ng pag-navigate';

  @override
  String get setHaptics => 'Pag-vibrate';

  @override
  String get setVerbosity => 'Haba ng mga paliwanag';

  @override
  String get setAutoCapture => 'Kusang pagkuha ng litrato';

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
      'Mag-swipe pakanan o pakaliwa: lumipat ng dokumento. I-double tap: buksan at ituloy ang pagbasa. Mag-swipe pataas: mga opsyon, gaya ng palitan ang pangalan at burahin. Sabihin ang “hanapin” at ang salita para maghanap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get fieldEmail => 'Email Address';

  @override
  String get fieldPin => 'PIN';

  @override
  String get actionSkip => 'Laktawan';

  @override
  String get screenLogin => 'Login';

  @override
  String loginAskPin(String name) {
    return 'Ilagay ang PIN ni $name.';
  }

  @override
  String get loginWrongPin => 'Mali ang PIN. Subukan ulit.';

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

  @override
  String get screenWelcome => 'Welcome';

  @override
  String get welcomeHasAccount => 'Meron ka na bang account?';

  @override
  String get welcomeAccountPrompt =>
      'Meron ka na bang account? Kung wala pa, mag-register ka.';

  @override
  String get welcomeHintVoice =>
      'Sabihin ang “login”, “register”, o “subukan”, o mag-swipe para pumili at mag-double-tap para pindutin.';

  @override
  String get welcomeHintGestures =>
      'Mag-swipe pakanan para pumili, at mag-double-tap para pindutin. I-tap para marinig ulit ito.';

  @override
  String get welcomeVoiceReady =>
      'Maaari mo nang sabihin ang “login”, “register”, o “subukan”.';

  @override
  String get actionLogin => 'Login';

  @override
  String get actionRegister => 'Register';

  @override
  String get actionTryFirst => 'Subukan muna (Try first)';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionClear => 'Burahin';

  @override
  String get actionOkay => 'Okay';

  @override
  String get actionFinishSetup => 'Tama, tapusin';

  @override
  String get actionForgotPassword => 'Nakalimutan ang password';

  @override
  String get actionUseFingerprint => 'Gamitin ang fingerprint';

  @override
  String get actionLegacyAccount => 'Lumang account (PIN)';

  @override
  String get answerYes => 'Oo';

  @override
  String get answerNo => 'Hindi';

  @override
  String get guestName => 'Bisita';

  @override
  String get guestValue => 'Bisita: naka-save lamang sa phone na ito';

  @override
  String get guestReminder =>
      'Naka-save ito sa phone na ito lamang. Mag-register para hindi ito mawala.';

  @override
  String get backUnsavedConfirm =>
      'May hindi pa naka-save. Sigurado ka bang babalik?';

  @override
  String get closeAppQuestion => 'Gusto mo bang isara ang app?';

  @override
  String backReturnedTo(String screen) {
    return 'Bumalik sa $screen.';
  }

  @override
  String get formIntro => 'Sagutin ang bawat tanong sa boses, o i-type ito.';

  @override
  String get formSubmitHint =>
      'Pindutin ng dalawang beses ang gesture area o sabihin ang salitang submit or tapos na';

  @override
  String formFieldEmpty(String field) {
    return '$field, walang laman';
  }

  @override
  String formFieldValue(String field, String value) {
    return '$field: $value';
  }

  @override
  String formPasswordLength(int count) {
    return '$count titik';
  }

  @override
  String formHeard(String field, String value) {
    return '$field: $value.';
  }

  @override
  String formComplete(String hint) {
    return 'Kumpleto na. $hint';
  }

  @override
  String formChange(String field) {
    return '$field. Magsalita o mag-type para palitan.';
  }

  @override
  String formCleared(String field, String prompt) {
    return 'Binura ang $field. $prompt';
  }

  @override
  String formMissing(String fields) {
    return 'Kulang pa: $fields.';
  }

  @override
  String get helpForm =>
      'Magsalita para sagutin ang tanong, o i-type ito. Mag-swipe pakanan o pakaliwa: lumipat ng field. I-tap: ulitin ang tanong. Pindutin nang matagal: magsalita. I-double tap, o sabihin ang “submit” o “tapos na”: ipasa. Sabihin ang “burahin”: burahin ang field. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get fieldFirstName => 'First Name';

  @override
  String get fieldLastName => 'Last Name';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldNewPassword => 'Bagong password';

  @override
  String get fieldAnswer => 'Sagot';

  @override
  String get askFirstName => 'Ano ang iyong pangalan (first name)?';

  @override
  String get askLastName => 'Ano ang iyong apelyido (last name)?';

  @override
  String get askEmail => 'Ano ang iyong email address?';

  @override
  String get askNewPassword => 'Gumawa ng password na hindi bababa sa 8 titik.';

  @override
  String get askPassword => 'Ano ang iyong password?';

  @override
  String askAnswer(String question) {
    return '$question Sabihin o i-type ang sagot.';
  }

  @override
  String get emailInvalid =>
      'Mukhang mali ang email address. Halimbawa: juan@gmail.com. Sa boses, sabihin ang “at” para sa @ at “dot” para sa tuldok.';

  @override
  String get emailTaken =>
      'May account na sa phone na ito ang email na iyan. Mag-login ka, o gumamit ng ibang email.';

  @override
  String passwordTooShort(int count) {
    return 'Ang password ay dapat hindi bababa sa 8 titik. $count pa lang ang nailagay.';
  }

  @override
  String get screenRegister => 'Register';

  @override
  String get registerWorking => 'Ginagawa ang iyong account…';

  @override
  String registerDone(String name) {
    return 'Nagawa na ang iyong account, $name.';
  }

  @override
  String get helpLogin =>
      'Magsalita o mag-type para sagutin ang email at password. I-double tap, o sabihin ang “submit” o “tapos na”: mag-login. Sabihin ang “nakalimutan”: i-reset ang password. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get loginFingerprintIntro =>
      'Ilagay ang iyong daliri sa fingerprint sensor para mag-login, o gamitin ang iyong password.';

  @override
  String get loginWrong => 'Mali ang email o password.';

  @override
  String loginAttemptsLeft(int count) {
    return '$count pang subok bago maghintay.';
  }

  @override
  String loginWelcomeBack(String name) {
    return 'Maligayang pagbabalik, $name.';
  }

  @override
  String lockoutStarted(int seconds) {
    return 'Masyadong maraming maling subok. Maghintay ng $seconds segundo bago sumubok muli.';
  }

  @override
  String lockoutWait(int seconds) {
    return 'Maghintay ng $seconds segundo.';
  }

  @override
  String get lockoutOver => 'Maaari ka nang sumubok muli.';

  @override
  String get fingerprintReason =>
      'Gamitin ang fingerprint para mag-login sa Percipere';

  @override
  String fingerprintFailed(String prompt) {
    return 'Hindi nakilala ang fingerprint. Gamitin ang iyong password. $prompt';
  }

  @override
  String fingerprintUnavailable(String prompt) {
    return 'Hindi magamit ang fingerprint ngayon. Gamitin ang iyong password. $prompt';
  }

  @override
  String get authChoiceQuestion => 'Nais mo bang mag login sa iyong account?';

  @override
  String get sessionExpired => 'Natapos na ang iyong session.';

  @override
  String get helpChooseList =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. Maaari mo ring sabihin ang pagpipilian. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get screenSecurityQuestion => 'Tanong pangseguridad';

  @override
  String get securityChoose =>
      'Pumili ng tanong pangseguridad. Gagamitin ito kapag nakalimutan mo ang iyong password.';

  @override
  String get securityQFirstPet => 'Ano ang pangalan ng una mong alagang hayop?';

  @override
  String get securityQBirthTown => 'Saang bayan ka ipinanganak?';

  @override
  String get securityQMotherMaiden =>
      'Ano ang apelyido ng iyong nanay noong dalaga pa siya?';

  @override
  String get securityQFirstSchool => 'Ano ang pangalan ng una mong paaralan?';

  @override
  String get securityQFavoriteFood => 'Ano ang paborito mong pagkain?';

  @override
  String get securitySaved => 'Na-save ang iyong tanong pangseguridad.';

  @override
  String get securityRequired =>
      'Kailangan ang tanong pangseguridad para ma-reset ang password. Pumili ng isa.';

  @override
  String get screenFingerprint => 'Fingerprint';

  @override
  String get fingerprintOffer =>
      'Gusto mo bang gamitin ang iyong fingerprint sa pag-login?';

  @override
  String get fingerprintOn => 'Naka-on na ang fingerprint login.';

  @override
  String get fingerprintNotSet =>
      'Hindi na-on ang fingerprint login. Maaari mo itong i-on mamaya sa Mga Setting.';

  @override
  String get fingerprintSkipped => 'Sige, password na lang.';

  @override
  String get fingerprintNoSensor =>
      'Walang naka-set na fingerprint sa phone na ito.';

  @override
  String get screenForgotPassword => 'Nakalimutan ang password';

  @override
  String get forgotIntro =>
      'Sasagutin mo ang iyong tanong pangseguridad para makagawa ng bagong password.';

  @override
  String get forgotAdmin =>
      'Maaari ring i-reset ng administrator ang iyong account.';

  @override
  String get forgotNoQuestion =>
      'Walang account na may tanong pangseguridad para sa email na ito sa phone na ito.';

  @override
  String get forgotWrongAnswer => 'Mali ang sagot.';

  @override
  String get forgotDone => 'Napalitan na ang password. Mag-login ka na.';

  @override
  String get screenLegacyAccount => 'Lumang account';

  @override
  String get legacyChoose => 'Pumili ng iyong lumang account na may PIN.';

  @override
  String get legacyNone => 'Walang lumang account sa phone na ito.';

  @override
  String legacyClaimed(String name) {
    return 'Tama ang PIN, $name. Ngayon, maglagay ng email at password.';
  }

  @override
  String get screenUpgradeAccount => 'I-update ang account';

  @override
  String get upgradeIntro =>
      'Hindi na ginagamit ang PIN. Maglagay ng email at password; mananatili ang iyong mga setting at kasaysayan.';

  @override
  String get upgradeDone => 'Na-update na ang iyong account.';

  @override
  String get upgradeLeave =>
      'Kung babalik ka, lalabas ka sa account na ito. Sigurado ka ba?';

  @override
  String setupProgress(int step, int total) {
    return 'Hakbang $step ng $total.';
  }

  @override
  String get setupSummaryTitle => 'Buod.';

  @override
  String get setupChoiceHow =>
      'Sabihin ang iyong sagot, o mag-swipe pakanan para pumili at mag-double-tap para pindutin.';

  @override
  String get setupNavHowVoice =>
      'Sabihin ang “boses” o “galaw”, o mag-swipe pakanan para pumili at mag-double-tap para pindutin.';

  @override
  String get setupSeesQuestion =>
      'Nakakakita ka ba ng kahit kaunting teksto sa screen?';

  @override
  String get setupSizeQuestion => 'Nababasa mo ba ng maayos ang texto?';

  @override
  String get setupSizeHow =>
      'Mag-swipe pataas o sabihin ang “palakihin” para lumaki; mag-swipe pababa o sabihin ang “paliitin” para lumiit. I-double tap o sabihin ang “okay” kapag tama na.';

  @override
  String setupSizeValue(int size) {
    return 'Laki ng teksto: $size.';
  }

  @override
  String get setupColorQuestion => 'Anong kulay ang nais mo sa texto?';

  @override
  String get setupCycleHow =>
      'Mag-swipe pakanan o pakaliwa, o sabihin ang “susunod” o “nakaraan”, para palitan. I-double tap o sabihin ang “okay” kapag tama na.';

  @override
  String setupColorValue(String color) {
    return 'Kulay: $color.';
  }

  @override
  String get setupLanguageQuestion =>
      'Gusto mo ba ang boses sa Ingles o sa Tagalog?';

  @override
  String get setupLanguageHow =>
      'Mag-swipe pakanan para marinig ang bawat isa, at mag-double-tap para pumili. O sabihin ang “Tagalog” o “Ingles”.';

  @override
  String get setupVoiceSample => 'Ito ang boses sa Tagalog.';

  @override
  String get setupFilipinoMissing =>
      'Walang boses na Filipino sa phone na ito. Gusto mo bang buksan ang text-to-speech settings para i-install ito?';

  @override
  String setupLanguageChosen(String language) {
    return 'Napili: $language.';
  }

  @override
  String get setupSpeedQuestion => 'Gusto mo bang bilisan ang boses?';

  @override
  String get setupSpeedHow =>
      'Mag-swipe pataas o sabihin ang “bilisan”; mag-swipe pababa o sabihin ang “bagalan”. I-double tap o sabihin ang “okay” kapag tama na.';

  @override
  String setupSpeedValue(String rate) {
    return 'Bilis: ${rate}x.';
  }

  @override
  String get setupPitchQuestion => 'Gusto mo bang palitan ang tono ng boses?';

  @override
  String get setupPitchHow =>
      'Mag-swipe pataas o sabihin ang “taasan”; mag-swipe pababa o sabihin ang “babaan”. I-double tap o sabihin ang “okay” kapag tama na.';

  @override
  String setupPitchValue(String pitch) {
    return 'Tono: $pitch.';
  }

  @override
  String get setupThemeQuestion => 'Anong tema ang gusto mong simulan?';

  @override
  String setupThemeValue(String theme) {
    return 'Tema: $theme.';
  }

  @override
  String get themeCreamNavy => 'Cream at Navy';

  @override
  String get themeDarkYellow => 'Dark mode na dilaw ang teksto';

  @override
  String get themeDarkWhite => 'Dark mode na puti ang teksto';

  @override
  String get textColorReset => 'Pinalitan ang kulay ng teksto para mas mabasa.';

  @override
  String get setupVibrationQuestion =>
      'Gusto mo bang mag-vibrate ang phone kapag may ginagawa ka?';

  @override
  String get setupAutoReadQuestion =>
      'Gusto mo bang awtomatikong basahin ang dokumento pagkatapos itong i-upload o i-scan?';

  @override
  String get setupSummaryQuestion => 'Tama ba ang lahat?';

  @override
  String setupSummaryPrompt(String items) {
    return 'Ito ang iyong mga napili: $items. Tama ba ang lahat? I-double tap o sabihin ang “oo” para tapusin. Para baguhin ang isa, sabihin halimbawa ang “bumalik sa bilis”, o mag-swipe at mag-double-tap.';
  }

  @override
  String summaryNavMode(String value) {
    return 'Paraan: $value';
  }

  @override
  String summaryLanguage(String value) {
    return 'Wika ng boses: $value';
  }

  @override
  String summaryVibration(String value) {
    return 'Vibrate: $value';
  }

  @override
  String summaryAutoRead(String value) {
    return 'Awtomatikong pagbasa: $value';
  }

  @override
  String setupAtLimit(String value) {
    return 'Hanggang dito na lang. $value';
  }

  @override
  String get setupSkipped => 'Nilaktawan. Ginamit ang karaniwang setting.';

  @override
  String get setupLeave =>
      'Ito ang unang hakbang. Gusto mo bang bumalik sa Welcome? Lalabas ka sa account.';

  @override
  String get setupFinished =>
      'Tapos na ang setup. Maaari mo itong baguhin anumang oras sa Mga Setting.';

  @override
  String get setupSample =>
      'Ang Percipere ay tumutulong sa iyo na mabasa ang mga liham, resibo, at aklat. Ganito ang magiging hitsura ng teksto.';

  @override
  String get setupPreviewLabel => 'Halimbawang teksto';

  @override
  String get helpSetupChoice =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng sagot. I-double tap: piliin. O sabihin ang sagot.';

  @override
  String get helpSetupVertical =>
      'Mag-swipe pataas o pababa: baguhin. I-double tap o sabihin ang “okay”: tama na.';

  @override
  String get helpSetupHorizontal =>
      'Mag-swipe pakanan o pakaliwa: baguhin. I-double tap o sabihin ang “okay”: tama na.';

  @override
  String get helpSetupCommon =>
      'I-tap o sabihin ang “ulitin”: ulitin ang tanong. Sabihin ang “laktawan”: laktawan at gamitin ang karaniwan. Mag-swipe pakanan gamit ang dalawang daliri, o sabihin ang “bumalik”: nakaraang hakbang.';

  @override
  String get helpSetupSummary =>
      'I-double tap o sabihin ang “oo”: tapusin. Mag-swipe pakanan o pakaliwa: lumipat sa mga napili, at i-double tap para baguhin. O sabihin ang “bumalik sa” at ang pangalan, halimbawa “bumalik sa bilis”.';

  @override
  String get langTagalog => 'Tagalog';

  @override
  String get langEnglishBoth => 'Ingles (English)';

  @override
  String get setTheme => 'Tema';

  @override
  String get setTextColor => 'Kulay ng teksto';

  @override
  String get setAutoRead => 'Awtomatikong pagbasa';

  @override
  String get setStayLoggedIn => 'Manatiling naka-login';

  @override
  String get setFingerprint => 'Fingerprint login';

  @override
  String get setRedoSetup => 'Ulitin ang setup';

  @override
  String get setRedoSetupValue => 'Sagutin ulit ang mga tanong';

  @override
  String get setLogout => 'Logout';

  @override
  String get logoutConfirm => 'Sigurado ka bang gusto mong mag-logout?';

  @override
  String get logoutGuestConfirm =>
      'Lalabas ka sa bisitang profile. Mananatili ito sa phone na ito. Sigurado ka ba?';

  @override
  String get loggedOut => 'Naka-logout ka na.';

  @override
  String get setupSpeedSample => 'Ganito kabilis ang boses.';

  @override
  String get setupPitchSample => 'Ganito ang tono ng boses.';
}
