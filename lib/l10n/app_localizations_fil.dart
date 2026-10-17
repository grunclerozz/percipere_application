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
      'Mag-swipe pakanan o pakaliwa para lumipat ng pagpipilian. I-double tap para pumili. Pindutin nang matagal habang nagsasalita, bitawan kapag tapos na.';

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
      'Mag-swipe pakanan o pakaliwa: lumipat sa Login, Register, o Subukan muna. I-double tap: pindutin. I-tap: ulitin ang tanong. Pindutin nang matagal habang nagsasalita, bitawan kapag tapos na. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

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
      'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap: piliin. I-tap: ulitin ang tanong. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin nang matagal habang nagsasalita, bitawan kapag tapos na. I-double tap gamit ang dalawang daliri: patigilin ang pagsasalita. I-tap gamit ang tatlong daliri: tulong.';

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
    return 'Ito ba ang ibig mong sabihin: “$phrase”? Sabihin ang oo o hindi.';
  }

  @override
  String voiceNoisyDidYouMean(String phrase) {
    return 'Medyo maingay po. Ito po ba ang ibig ninyong sabihin: “$phrase”? Sabihin ang oo o hindi po.';
  }

  @override
  String get voiceTrialQuiet => 'Pagsubok ng 20 utos: tahimik na kuwarto';

  @override
  String get voiceTrialNoisy => 'Pagsubok ng 20 utos: maingay na kuwarto';

  @override
  String voiceTrialSay(String number, String total, String phrase) {
    return 'Utos $number ng $total. Sabihin po: $phrase';
  }

  @override
  String voiceTrialAgain(String phrase) {
    return 'Hindi po tugma. Pakiulit po: $phrase';
  }

  @override
  String voiceTrialDone(String correct, String total) {
    return 'Tapos na po ang pagsubok. $correct sa $total ang tama. Naka-save po ang resulta.';
  }

  @override
  String get voiceTrialStop => 'Ihinto ang pagsubok';

  @override
  String get voiceTrialStopped =>
      'Inihinto po ang pagsubok. Naka-save po ang mga resulta hanggang dito.';

  @override
  String get voiceTrialExport => 'I-share ang resulta ng pagsubok (CSV)';

  @override
  String get voiceTrialExportEmpty => 'Wala pa pong resulta ng pagsubok.';

  @override
  String get voiceTrialExportFailed => 'Hindi po ma-share ang resulta.';

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
  String get gestureHoldListenAction => 'Makinig ngayon';

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
  String get uploadFailed =>
      'Hindi ko makuha ang file na pinili mo. Subukan ulit, o pumili ng ibang file.';

  @override
  String get readerFileMissing =>
      'Nawala ang file bago ko ito nabasa. Pakisubukan ulit.';

  @override
  String get readerOcrFailed =>
      'Hindi gumana ang pagbasa ng teksto sa phone na ito ngayon. Hindi sira ang file. Pakisubukan ulit.';

  @override
  String get readerExtractFailed =>
      'Nagkaproblema habang binabasa ko ang file. Malamang hindi ito sira. Pakisubukan ulit.';

  @override
  String get readerSaveFailed =>
      'Mababasa mo ito, pero hindi ko ito na-save sa Aklatan.';

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
  String get readerSaved => 'Na-save sa Aklatan.';

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
      'I-double tap: basahin o i-pause. Mag-swipe pakanan o pakaliwa: susunod o nakaraang pangungusap. Mag-swipe pababa o pataas gamit ang dalawang daliri: susunod o nakaraang talata. Mag-swipe pataas o pababa: bilisan o bagalan. I-tap: ulitin ang pangungusap. Mag-swipe pakanan gamit ang dalawang daliri: bumalik. Pindutin ang A plus o A minus sa taas ng kahon, o i-pinch ang kahon ng dokumento, para palakihin o paliitin ang teksto. Mga utos sa boses: basahin, i-pause, ituloy, susunod, nakaraan, susunod na talata, bilisan, bagalan, palakihin, paliitin, ulitin, mula sa simula, i-save, at bumalik. Habang nagbabasa, puwede mong sabihin agad ang i-pause, itigil, bilisan, bagalan, palakihin, paliitin, paborito, ulitin, o bumalik. Mas maaasahan ito kung naka-earphones ka. Pindutin nang matagal ang gesture area habang nagsasalita, bitawan kapag tapos na: hihinto agad ang pagbasa at makikinig po ako.';

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
  String get passwordVisibleNotice =>
      'Nakikita ang password habang nagta-type. Pindutin ang mata para itago.';

  @override
  String get passwordHide => 'Itago ang password';

  @override
  String get passwordShow => 'Ipakita ang password';

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
      'Magsalita para sagutin ang tanong, o i-type ito. Mag-swipe pakanan o pakaliwa: lumipat ng field. I-tap: ulitin ang tanong. Pindutin nang matagal habang nagsasalita, bitawan kapag tapos na. I-double tap, o sabihin ang “submit” o “tapos na”: ipasa. Sabihin ang “burahin”: burahin ang field. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

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
  String get setupSpeedQuestion =>
      'Bilis ng pagsasalita. Gaano kabilis ang gusto mo?';

  @override
  String get setupSpeedHow =>
      'Mag-swipe pakanan para marinig ang bawat bilis, at mag-double-tap para pumili. O sabihin ang “mabagal”, “katamtaman” o “mabilis”.';

  @override
  String get speedSlow => 'Mabagal';

  @override
  String get speedMedium => 'Katamtaman';

  @override
  String get speedFast => 'Mabilis';

  @override
  String get speedSampleSentence => 'Ganito ang bilis ng aking pagsasalita.';

  @override
  String setupSpeedChosen(String speed) {
    return 'Napili: $speed.';
  }

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
  String summarySpeed(String value) {
    return 'Bilis: $value';
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
  String get setListenWhileReading => 'Makinig habang nagbabasa';

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

  @override
  String get screenHome => 'Home';

  @override
  String get homePrompt => 'Ano ang gusto mong gawin?';

  @override
  String get homeRead => 'Magbasa ng bago';

  @override
  String get homeLibrary => 'Aklatan';

  @override
  String get screenLibrary => 'Aklatan';

  @override
  String get libraryPrompt =>
      'Mag-swipe pakanan o pakaliwa para lumipat ng aytem, at pataas o pababa para lumipat ng istante. I-double tap para buksan ang detalye.';

  @override
  String get libraryNewBooks => 'May mga bagong aklat sa Aklatan.';

  @override
  String get shelfControls => 'Paghahanap at mga filter';

  @override
  String get shelfContinue => 'Ituloy ang pagbasa';

  @override
  String get shelfDocuments => 'Aking mga dokumento';

  @override
  String get shelfCollections => 'Mga koleksyon';

  @override
  String get shelfBooks => 'Mga aklat';

  @override
  String get shelfResults => 'Mga resulta';

  @override
  String shelfAnnounce(String title, int count) {
    return '$title, $count aytem';
  }

  @override
  String get emptyContinue => 'Wala ka pang sinisimulang basahin.';

  @override
  String get emptyDocuments =>
      'Wala ka pang dokumento. Mag-scan o mag-upload para magsimula.';

  @override
  String get emptyCollections =>
      'Wala ka pang koleksyon. Sabihin ang “gumawa ng koleksyon” para gumawa.';

  @override
  String get emptyBooks =>
      'Wala pang aklat sa ngayon. Kailangan ng internet para makita ang mga aklat.';

  @override
  String get emptyResults => 'Walang tugma sa napili mo.';

  @override
  String get emptyCollection => 'Walang laman ang koleksyong ito.';

  @override
  String get libSearch => 'Hanapin';

  @override
  String get libFilter => 'Salain';

  @override
  String get libNewCollection => 'Gumawa ng koleksyon';

  @override
  String get filterAll => 'Lahat';

  @override
  String get filterDocuments => 'Aking mga dokumento';

  @override
  String get filterBooks => 'Mga aklat';

  @override
  String get filterDownloaded => 'Na-download';

  @override
  String get filterFinished => 'Tapos na';

  @override
  String get filterFavorites => 'May paborito';

  @override
  String filterChanged(String name, int count) {
    return 'Salain: $name, $count aytem.';
  }

  @override
  String get librarySearchPrompt =>
      'Sabihin ang hinahanap pagkatapos ng tunog.';

  @override
  String libraryItemTitleAuthor(String title, String author) {
    return '$title, ni $author';
  }

  @override
  String libraryItemTitleType(String title, String type) {
    return '$title, $type';
  }

  @override
  String libraryPercent(int percent) {
    return '$percent porsiyento';
  }

  @override
  String get libraryFinishedWord => 'tapos na';

  @override
  String get libraryNotStartedWord => 'hindi pa nasisimulan';

  @override
  String libraryLastRead(String when) {
    return 'huling binasa $when';
  }

  @override
  String get libraryNewLabel => 'Bago';

  @override
  String get libraryDownloadedWord => 'naka-download';

  @override
  String get libraryUnavailableWord => 'hindi na available';

  @override
  String get whenToday => 'ngayon';

  @override
  String get whenYesterday => 'kahapon';

  @override
  String whenDaysAgo(int days) {
    return '$days araw na ang nakalipas';
  }

  @override
  String get formatEpub => 'EPUB';

  @override
  String libraryCollectionLine(String name, int count) {
    return 'Koleksyon: $name, $count aytem';
  }

  @override
  String get libraryNeedsInternet =>
      'Kailangan ng internet para mabasa ito. I-download ito kapag may internet.';

  @override
  String libraryOpening(String title) {
    return 'Binubuksan ang $title.';
  }

  @override
  String libraryNotFound(String query) {
    return 'Hindi ko nahanap ang “$query” sa Aklatan.';
  }

  @override
  String get collectionNamePrompt =>
      'Sabihin ang pangalan ng koleksyon pagkatapos ng tunog.';

  @override
  String collectionCreated(String name) {
    return 'Nagawa ang koleksyon na $name.';
  }

  @override
  String collectionOptions(String name) {
    return 'Mga opsyon para sa koleksyong $name. Mag-swipe para pumili: Buksan, Palitan ang pangalan, o Burahin.';
  }

  @override
  String collectionRenamed(String name) {
    return 'Pinalitan ang pangalan ng koleksyon: $name.';
  }

  @override
  String collectionDeleteConfirm(String name) {
    return 'Burahin ang koleksyong $name? Hindi mabubura ang mga laman nito.';
  }

  @override
  String collectionDeleted(String name) {
    return 'Nabura ang koleksyong $name.';
  }

  @override
  String collectionOpened(String name, int count) {
    return 'Koleksyon: $name, $count aytem.';
  }

  @override
  String bookRemovedNotice(String title) {
    return 'Inalis na ang $title sa Aklatan. Nasa iyo pa rin ang iyong progreso.';
  }

  @override
  String get screenItemDetails => 'Detalye';

  @override
  String get detailsNotStarted => 'Hindi pa nasisimulan.';

  @override
  String get detailsFinished => 'Tapos mo nang basahin.';

  @override
  String detailsProgress(int percent) {
    return '$percent porsiyento ang nabasa.';
  }

  @override
  String detailsMinutesLeft(int minutes) {
    return 'Mga $minutes minuto pa ang natitira.';
  }

  @override
  String get detailsLessThanMinute => 'Wala pang isang minuto ang natitira.';

  @override
  String get actContinue => 'Ituloy';

  @override
  String get actRead => 'Basahin';

  @override
  String get actFromStart => 'Basahin mula sa simula';

  @override
  String get actFavorites => 'Mga paborito';

  @override
  String get actChapters => 'Mga kabanata';

  @override
  String get actAddToCollection => 'Idagdag sa koleksyon';

  @override
  String get actDownload => 'I-download';

  @override
  String actDownloadSized(String size) {
    return 'I-download, $size';
  }

  @override
  String get actRemoveDownload => 'Alisin ang download';

  @override
  String get actMarkFinished => 'Markahan bilang tapos na';

  @override
  String get actMarkUnfinished => 'Markahan bilang hindi pa tapos';

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String get bookLoading => 'Kinukuha ang aklat…';

  @override
  String bookLoadingPercent(int percent) {
    return '$percent porsiyento na.';
  }

  @override
  String get bookPreparing => 'Inihahanda ang aklat…';

  @override
  String downloadDone(String title) {
    return 'Na-download ang $title.';
  }

  @override
  String downloadRemoved(String title) {
    return 'Naalis ang download ng $title.';
  }

  @override
  String downloadLowStorage(String size) {
    return 'Kaunti na lang ang espasyo ng phone. Mga $size ang kailangan para dito. Gusto mo bang ituloy pa rin?';
  }

  @override
  String bookUnavailable(String title) {
    return 'Hindi na available ang $title.';
  }

  @override
  String get bookDrm =>
      'Protektado ng DRM ang EPUB na ito, kaya hindi ito mabubuksan ng app.';

  @override
  String get bookInvalid => 'Sira o hindi wastong aklat ang file na ito.';

  @override
  String get bookEmpty => 'Walang nabasang teksto sa aklat na ito.';

  @override
  String get bookFailed =>
      'May problema sa pagkuha ng aklat. Subukan ulit mamaya.';

  @override
  String bookUpdateOffer(String title) {
    return 'May bagong bersyon ang $title. I-update ang download? Mananatili ang iyong progreso.';
  }

  @override
  String bookUpdated(String title) {
    return 'Na-update ang $title.';
  }

  @override
  String markedFinished(String title) {
    return 'Minarkahan na tapos na ang $title.';
  }

  @override
  String markedUnfinished(String title) {
    return 'Minarkahan na hindi pa tapos ang $title.';
  }

  @override
  String collectionPickIntro(String title) {
    return 'Idagdag ang $title sa aling koleksyon? Mag-swipe para pumili, i-double tap para idagdag o alisin.';
  }

  @override
  String get collectionPickNone =>
      'Wala ka pang koleksyon. Gumawa muna ng isa sa Aklatan.';

  @override
  String collectionPickIn(String name) {
    return '$name, nandito na';
  }

  @override
  String collectionAdded(String title, String name) {
    return 'Naidagdag ang $title sa $name.';
  }

  @override
  String collectionItemRemoved(String title, String name) {
    return 'Naalis ang $title sa $name.';
  }

  @override
  String get guestDownloadWarning =>
      'Paalala: Naka-save lang ang iyong mga aklat sa phone na ito. Kapag nabura ang app, mawawala ang mga ito. Mag-register para ma-save ang iyong Aklatan at mabuksan ito sa ibang device. Gusto mo bang mag-register ngayon?';

  @override
  String get guestDocumentsStayHere =>
      'Ang mga dokumentong sinu-scan o ina-upload mo ay mananatili sa phone na ito at hindi ipinapadala sa server, para sa iyong privacy.';

  @override
  String get screenFavorites => 'Mga paborito';

  @override
  String favoritesIntro(String title, int count) {
    return 'Mga paborito sa $title. $count ang naka-save. Mag-swipe para pumili, i-double tap para pumunta roon.';
  }

  @override
  String favoritesEmpty(String title) {
    return 'Wala ka pang paborito sa $title. Sabihin ang “paborito” habang nagbabasa.';
  }

  @override
  String favoriteLine(String chapter, String label) {
    return '$chapter: $label';
  }

  @override
  String get optGoHere => 'Pumunta dito';

  @override
  String get favoriteOptions =>
      'Mga opsyon: Pumunta dito, o Burahin. Mag-swipe para pumili.';

  @override
  String favoriteDeleteConfirm(String label) {
    return 'Burahin ang paborito na “$label”?';
  }

  @override
  String get favoriteDeleted => 'Nabura ang paborito.';

  @override
  String get readerFavorite => 'Paborito';

  @override
  String get readerFavoriteSaved => 'Na-save bilang paborito';

  @override
  String readerChapter(String title) {
    return '$title.';
  }

  @override
  String get readerNoChapters => 'Walang kabanata ang dokumentong ito.';

  @override
  String readerFinishedTitle(String title) {
    return 'Tapos mo nang basahin ang $title.';
  }

  @override
  String get screenChapters => 'Mga kabanata';

  @override
  String chaptersIntro(String title, int count) {
    return 'Mga kabanata ng $title. $count lahat. Mag-swipe para pumili, i-double tap para pumunta roon.';
  }

  @override
  String get chaptersNone => 'Walang kabanata ang aytem na ito.';

  @override
  String chapterLine(int number, String title) {
    return '$number. $title';
  }

  @override
  String chapterFallback(int number) {
    return 'Kabanata $number';
  }

  @override
  String get helpHome =>
      'Mag-swipe pakanan o pakaliwa para pumili, at i-double tap para buksan. Sabihin ang “magbasa ng bago” o “aklatan”. Para ulitin ang pagtuturo, sabihin ang “tutorial”.';

  @override
  String get helpLibrary =>
      'Mag-swipe pakanan o pakaliwa para lumipat ng aytem. Mag-swipe pataas o pababa para lumipat ng istante. I-double tap para buksan ang detalye. Sabihin ang “ituloy ang” at ang pamagat para ituloy agad, o “hanapin” para maghanap.';

  @override
  String get helpItemDetails =>
      'Mag-swipe pakanan o pakaliwa para pumili ng aksyon, at i-double tap para gawin ito. Ang una ay ang pagbasa.';

  @override
  String get helpFavorites =>
      'Mag-swipe pakanan o pakaliwa para pumili ng paborito. I-double tap para pumunta roon. Mag-swipe pataas para sa mga opsyon.';

  @override
  String get helpChapters =>
      'Mag-swipe pakanan o pakaliwa para pumili ng kabanata, at i-double tap para pumunta roon.';

  @override
  String get libraryEdgeSide => 'Dulo ng istante.';

  @override
  String get libraryEdgeTop => 'Nasa pinakaitaas ka na.';

  @override
  String get libraryEdgeBottom => 'Nasa pinakababa ka na.';

  @override
  String get verbosityAuto => 'Awtomatiko';

  @override
  String whereAmIScreen(String screen) {
    return 'Nasa $screen ka.';
  }

  @override
  String whereAmIFocused(String item) {
    return 'Naka-focus: $item.';
  }

  @override
  String whatCanIDo(String commands) {
    return 'Dito, pwede mong sabihin: $commands.';
  }

  @override
  String get askMeHint =>
      'Pwede mo rin akong tanungin, halimbawa: “nasaan ako?” o “anong oras na?”.';

  @override
  String timeNow(String time) {
    return '$time na ngayon.';
  }

  @override
  String dateToday(String date) {
    return 'Ngayon ay $date.';
  }

  @override
  String voiceSuggest(String options) {
    return 'Hindi kita naintindihan. Baka ang ibig mo ay: $options.';
  }

  @override
  String get voiceNotUnderstood =>
      'Hindi kita naintindihan. Sabihin ang “ano ang pwede kong gawin” para marinig ang mga utos.';

  @override
  String get voiceOfferHelp =>
      'Kung nalilito ka, sabihin ang “paano gamitin” para sa maikling pag-aaral.';

  @override
  String voiceWhichOne(String first, String second) {
    return 'Alin sa dalawa: $first, o $second? Sabihin ang pangalan.';
  }

  @override
  String get docNeedsOpenDoc =>
      'Magbukas muna ng dokumento, saka mo ito itanong.';

  @override
  String get docTypeReceipt => 'Mukhang resibo ito.';

  @override
  String get docTypeBill => 'Mukhang bill o singilin ito.';

  @override
  String get docTypeMedicine => 'Mukhang label ng gamot o reseta ito.';

  @override
  String get docTypeLetter => 'Mukhang liham ito.';

  @override
  String get docTypeForm => 'Mukhang form ito na may mga pupunan.';

  @override
  String get docTypeOther =>
      'Hindi ko matiyak kung anong klaseng dokumento ito.';

  @override
  String docFrom(String from) {
    return 'Mula sa: $from.';
  }

  @override
  String docLetterTo(String name) {
    return 'Para kay $name.';
  }

  @override
  String docTotal(String amount) {
    return 'Kabuuan: $amount piso.';
  }

  @override
  String docDue(String date) {
    return 'Dapat bayaran bago o sa $date.';
  }

  @override
  String docExpiry(String date) {
    return 'Mapapaso sa $date.';
  }

  @override
  String docDosage(String dosage) {
    return 'Paano inumin: $dosage';
  }

  @override
  String get docNoTotal =>
      'Wala akong nakitang halaga o total sa dokumentong ito.';

  @override
  String get docNoDue => 'Wala akong nakitang due date sa dokumentong ito.';

  @override
  String get docNoExpiry =>
      'Wala akong nakitang expiry date sa dokumentong ito.';

  @override
  String get docNoDosage =>
      'Wala akong nakitang paraan ng pag-inom sa dokumentong ito.';

  @override
  String docSummary(String text) {
    return 'Buod: $text';
  }

  @override
  String get docNoSummary => 'Masyadong maikli ang dokumento para ibuod.';

  @override
  String get docAskHint =>
      'Pwede mo akong tanungin tungkol dito, halimbawa: “magkano?” o “ibuod mo”.';

  @override
  String readerProgress(String current, String total, String percent) {
    return 'Nasa pangungusap $current ng $total ka, mga $percent porsiyento.';
  }

  @override
  String readerProgressChapter(String chapter, String chapters) {
    return 'Kabanata $chapter ng $chapters.';
  }

  @override
  String get setTutorial => 'Paano gamitin ang app';

  @override
  String get setTutorialValue => 'Pag-aaral ng mga kontrol';

  @override
  String get screenTutorial => 'Pag-aaral ng mga kontrol';

  @override
  String get tutorialSkip => 'Laktawan';

  @override
  String get tutorialPercy =>
      'Kumusta! Ako si Percy, ang voice assistant ng Percipere. Tawagin mo ako sa pag-swipe pakaliwa gamit ang dalawang daliri, o sabihin ang “Percy”. Subukan ang “basahin mo”, “buksan ang Aklatan” o “bumalik”. Gumagana ako kahit walang internet. I-double tap kahit saan para magpatuloy.';

  @override
  String get tutorialIntro =>
      'Tuturuan kita kung paano gamitin ang Percipere gamit ang daliri at boses. Mga dalawang minuto lang ito. I-double tap kahit saan sa screen para magsimula. Para laktawan, mag-swipe pakanan gamit ang dalawang daliri, o sabihin ang “laktawan”.';

  @override
  String get tutorialSwipeRight =>
      'Para lumipat sa susunod na pagpipilian, mag-swipe pakanan gamit ang isang daliri. Subukan mo ngayon.';

  @override
  String get tutorialSwipeLeft =>
      'Para bumalik sa nakaraang pagpipilian, mag-swipe pakaliwa. Subukan mo.';

  @override
  String get tutorialDoubleTap =>
      'Para piliin ang pagpipilian, mag-double tap kahit saan sa screen. Subukan mo.';

  @override
  String get tutorialTap =>
      'Para marinig ulit ang huling sinabi ko, mag-tap nang isang beses. Subukan mo.';

  @override
  String get tutorialBack =>
      'Para bumalik sa nakaraang screen, mag-swipe pakanan gamit ang dalawang daliri. Subukan mo.';

  @override
  String get tutorialHelp =>
      'Para humingi ng tulong sa kahit anong screen, mag-tap gamit ang tatlong daliri. Subukan mo.';

  @override
  String get tutorialLongPress =>
      'Para magsalita ng utos: pindutin nang matagal ang screen habang nagsasalita, bitawan kapag tapos na. May tunog kapag nakikinig na po ako. Subukan mo po.';

  @override
  String get tutorialSay => 'Ngayon, sabihin ang “tulong”.';

  @override
  String get tutorialVoiceInfo =>
      'Kapag naka-boses, nakikinig ako pagkatapos kong magsalita, kaya hindi mo na kailangang pumindot. Habang nagbabasa ako, pwede mong sabihin ang “i-pause” o “bilisan”. Pwede mo rin akong tanungin: “nasaan ako?”, “ano ang pwede kong gawin?”, at kapag may bukas na dokumento, “magkano?” o “ibuod mo”. I-double tap para magpatuloy.';

  @override
  String get tutorialDone =>
      'Tapos na! Tandaan: swipe para lumipat, double-tap para pumili, dalawang daliri pakanan para bumalik, at pindutin nang matagal habang nagsasalita, bitawan kapag tapos na. Sabihin ang “paano gamitin” anumang oras para ulitin ito. I-double tap para magpatuloy.';

  @override
  String get tutorialGood => 'Magaling!';

  @override
  String get tutorialGoodAlt => 'Tama!';

  @override
  String get tutorialWrong => 'Hindi iyon ang hinihintay ko. Subukan ulit.';

  @override
  String get tutorialMovingOn => 'Ayos lang. Lilipat na tayo sa susunod.';

  @override
  String get tutorialSkipped =>
      'Nilaktawan ang pag-aaral. Sabihin ang “paano gamitin” kung gusto mo itong gawin mamaya.';

  @override
  String get tutorialSkipQuestion => 'Gusto mo bang laktawan ang pag-aaral?';

  @override
  String get tutorialNoMic =>
      'Hindi pa pinapayagan ang mikropono, kaya lalaktawan natin ang pagsasanay sa boses.';

  @override
  String get assistantNotSetUp =>
      'Hindi pa naka-set up si Percy, ang voice assistant. Gamitin muna ang karaniwang mga utos.';

  @override
  String get assistantOffline =>
      'Kailangan ng internet para kay Percy. Gumagana pa rin ang karaniwang mga utos.';

  @override
  String get assistantConsentAsk =>
      'Ito ang online na bersyon ni Percy para sa mga developer, na gumagamit ng internet. Ang sasabihin mo, at ang teksto ng dokumento kapag tinanong mo siya tungkol dito, ay ipapadala sa ElevenLabs para maintindihan ka. Payag ka ba?';

  @override
  String get assistantConsentDeclined =>
      'Sige, hindi muna gagamitin si Percy. Pwede mo siyang tawagin ulit kapag gusto mo.';

  @override
  String get assistantMicNeeded =>
      'Kailangan ni Percy ang mikropono. Payagan ito sa settings ng app.';

  @override
  String get assistantConnecting => 'Tinatawag si Percy.';

  @override
  String get assistantEnded => 'Paalam muna kay Percy.';

  @override
  String get assistantFailed =>
      'Hindi makakonekta kay Percy ngayon. Subukan ulit mamaya. Gumagana pa rin ang karaniwang mga utos.';

  @override
  String get assistantFirstMessage =>
      'Kumusta po! Ako si Percy. Ano po ang maitutulong ko?';

  @override
  String get assistantHowToCall =>
      'Para tawagin si Percy, ang voice assistant, mag-swipe pakaliwa gamit ang dalawang daliri, o sabihin ang “Percy”. Para tapusin, sabihin ang “paalam” o mag-swipe.';

  @override
  String get assistantGuestName => 'kaibigan';

  @override
  String get setPercyPoliteness => 'Paraan ng pagsalita ni Percy';

  @override
  String get valuePercyPo => 'Magalang (may po)';

  @override
  String get valuePercyCasual => 'Kaswal';

  @override
  String get setPercyTalk => 'Haba ng sagot ni Percy';

  @override
  String get valuePercyBrief => 'Maikli';

  @override
  String get valuePercyNormal => 'Katamtaman';

  @override
  String get valuePercyChatty => 'Madaldal';

  @override
  String get setPercyVoice => 'Boses ni Percy';

  @override
  String valuePercyVoiceClips(String have, String total) {
    return 'ElevenLabs (offline), $have sa $total na linya ang may clip';
  }

  @override
  String get valuePercyVoiceNone => 'Offline na boses ng app (wala pang clip)';

  @override
  String get setPercyLogging => 'I-save ang usapan kay Percy (pang-training)';

  @override
  String get setPercyElevenLabs => 'Percy online (ElevenLabs, developer)';

  @override
  String get setPercyAnalysis => 'Percy analysis (developer)';

  @override
  String get percyAnalysisTitle => 'Percy analysis';

  @override
  String get percyAnalysisEmpty => 'Wala pang sinabi kay Percy.';

  @override
  String percyAnalysisHeard(String text) {
    return 'Narinig: $text';
  }

  @override
  String percyAnalysisLanguage(String language, int fil, int en) {
    return 'Wika: $language (fil $fil · en $en)';
  }

  @override
  String get percyAnalysisLangFilipino => 'Filipino';

  @override
  String get percyAnalysisLangEnglish => 'English';

  @override
  String get percyAnalysisLangTaglish => 'Taglish';

  @override
  String percyAnalysisIntent(String intent, String confidence) {
    return 'Intent: $intent · kumpiyansa $confidence';
  }

  @override
  String get percyAnalysisNoIntent => 'Intent: — (eksaktong utos)';

  @override
  String percyAnalysisTop(String list) {
    return 'Top 3: $list';
  }

  @override
  String percyAnalysisAction(String action) {
    return 'Ginawa: $action';
  }

  @override
  String percyAnalysisCount(int count) {
    return '$count na pangungusap';
  }

  @override
  String get setPercyExport => 'I-export ang log ni Percy (CSV)';

  @override
  String percyExportCount(String count) {
    return '$count na pangungusap';
  }

  @override
  String get percyExportEmpty => 'Wala pang naka-log na usapan kay Percy.';

  @override
  String get percyExportDone =>
      'Inihanda ko na ang CSV. Piliin kung saan ito ipapadala.';

  @override
  String get percyExportFailed => 'Hindi ko ma-export ang log ngayon.';

  @override
  String get percyMicNeeded =>
      'Kailangan ni Percy ang mikropono para marinig ka. Payagan ito sa settings ng app.';

  @override
  String get percyUnavailable =>
      'Hindi ko mabuksan si Percy ngayon. Gumagana pa rin ang karaniwang mga utos.';

  @override
  String get voiceSayAgain => 'Pasensya na po, pakiulit.';

  @override
  String get speedStripLabel => 'Bilis';

  @override
  String speedStripValue(String rate) {
    return 'Bilis, $rate na beses';
  }

  @override
  String speedSpoken(String rate) {
    return 'Bilis $rate';
  }

  @override
  String get speedIncrease => 'Bilisan';

  @override
  String get speedDecrease => 'Bagalan';

  @override
  String get setReadingVoice => 'Boses sa pagbasa';

  @override
  String get valueVoiceDefault => 'Karaniwan';

  @override
  String get valueVoiceFemale => 'Babae';

  @override
  String get valueVoiceMale => 'Lalaki';

  @override
  String valueVoiceNamed(String number, String name) {
    return 'Boses $number ($name)';
  }

  @override
  String get valueVoiceOnlyOne => 'Iisa lang ang boses';

  @override
  String get voiceOnlyOne =>
      'Iisa lang ang boses sa teleponong ito para sa wikang ito, kaya hindi ito mapapalitan.';

  @override
  String voiceChanged(String voice) {
    return 'Napalitan na ang boses: $voice.';
  }

  @override
  String get setVoicePreview => 'Pakinggan ang boses';

  @override
  String get valueVoicePreview => 'I-play ang halimbawa';

  @override
  String get voicePreviewSample =>
      'Ganito ang tunog ng boses na babasa ng iyong mga dokumento.';

  @override
  String get screenVerifyEmail => 'I-verify ang email';

  @override
  String get fieldCode => 'Code';

  @override
  String get askCode =>
      'Ano ang 6 na numerong code na ipinadala sa iyong email?';

  @override
  String verifyIntro(String email) {
    return 'Nagpadala kami ng 6 na numerong code sa $email. Tingnan ang iyong email.';
  }

  @override
  String get codeNotSent =>
      'Hindi naipadala ang code. Sabihin ang “ipadala ulit” para subukan muli.';

  @override
  String get actionResendCode => 'Ipadala ulit ang code';

  @override
  String get codeResent => 'Nagpadala kami ng bagong code.';

  @override
  String get codeWrong => 'Mali o luma na ang code. Subukan ulit.';

  @override
  String get codeVoided =>
      'Masyadong maraming maling code. Sabihin ang “ipadala ulit” para sa bagong code.';

  @override
  String get codeFormat => 'Ang code ay 6 na numero.';

  @override
  String get accountPendingApproval =>
      'Hinihintay pa ang pag-apruba ng administrator sa iyong account.';

  @override
  String get accountSuspended =>
      'Naka-suspend ang account na ito. Makipag-ugnayan sa administrator.';

  @override
  String get accountSuspendedSignedOut =>
      'Naka-suspend ang iyong account, kaya na-log out ka. Makipag-ugnayan sa administrator.';

  @override
  String get serverUnreachable =>
      'Hindi makakonekta sa server. Tiyaking may internet, at subukan ulit.';

  @override
  String get serverProblem => 'May problema sa server. Subukan ulit mamaya.';

  @override
  String get loginOffline =>
      'Walang internet, kaya ang naka-save sa tablet na ito ang ginamit.';

  @override
  String get loginNeedsInternet =>
      'Kailangan ng internet sa unang pag-login sa tablet na ito.';

  @override
  String get accountMoving =>
      'Inililipat namin sa server ang iyong account. Nagpadala kami ng code sa iyong email.';

  @override
  String get emailTakenServer =>
      'May account na ang email na iyan. Mag-login ka, o gumamit ng ibang email.';

  @override
  String get resetIntro =>
      'Magpapadala kami ng code sa iyong email para makagawa ka ng bagong password.';

  @override
  String resetCodeSent(String email) {
    return 'Kung may account ang $email, nagpadala na kami ng code. Sabihin ang code, pagkatapos ang bagong password.';
  }

  @override
  String get resetDone => 'Napalitan na ang password, at naka-login ka na.';

  @override
  String get helpVerify =>
      'Sabihin ang 6 na numero ng code, o i-type ito. Sabihin ang “ipadala ulit”: bagong code. I-double tap, o sabihin ang “submit” o “tapos na”: ipasa. Mag-swipe pakanan gamit ang dalawang daliri: bumalik.';

  @override
  String get screenReportIssue => 'Mag-report ng problema';

  @override
  String get reportIntro => 'Sasagutin mo ang ilang tanong, isa-isa.';

  @override
  String get reportAskType => 'Anong uri ng report ito?';

  @override
  String get reportTypeBug => 'May sira (Bug)';

  @override
  String get reportTypeFeature => 'Mungkahi (Feature request)';

  @override
  String get reportTypeFeedback => 'Puna (General feedback)';

  @override
  String get reportAskModule => 'Saang bahagi ng app?';

  @override
  String get reportModuleOcr => 'Pagbasa ng teksto (OCR)';

  @override
  String get reportModuleCamera => 'Camera';

  @override
  String get reportModuleVoice => 'Mga utos sa boses (Voice commands)';

  @override
  String get reportModuleAccounts => 'Mga account (Accounts)';

  @override
  String get reportModuleTts => 'Boses na nagbabasa (Text-to-Speech)';

  @override
  String get reportModuleGestures => 'Gesture Pad';

  @override
  String get reportModuleLibrary => 'Aklatan (Library)';

  @override
  String get reportModuleMaglarawan => 'Maglarawan';

  @override
  String get reportModulePercy => 'Percy';

  @override
  String get reportModuleOther => 'Iba pa (Other)';

  @override
  String get reportAskSeverity => 'Gaano kalala ang problema?';

  @override
  String get reportSeverityLow => 'Mababa';

  @override
  String get reportSeverityMedium => 'Katamtaman';

  @override
  String get reportSeverityHigh => 'Mataas';

  @override
  String get reportSeverityCritical => 'Kritikal';

  @override
  String get reportSeverityLowLong => 'Mababa: maliit na abala';

  @override
  String get reportSeverityMediumLong => 'Katamtaman: gumagana pero mali';

  @override
  String get reportSeverityHighLong => 'Mataas: hindi gumagana';

  @override
  String get reportSeverityCriticalLong =>
      'Kritikal: nagsasara ang app o may nawalang data';

  @override
  String get reportAskDescription =>
      'Ano ang nangyari? Ikuwento sa boses, o i-type.';

  @override
  String get reportDescriptionHint => 'Hindi bababa sa 10 titik.';

  @override
  String get fieldDescription => 'Ano ang nangyari';

  @override
  String get actionSpeak => 'Magsalita';

  @override
  String get actionNext => 'Susunod';

  @override
  String reportHeard(String v) {
    return 'Narinig ko: $v. Tama ba?';
  }

  @override
  String get reportSayAgain => 'Sige, sabihin ulit kung ano ang nangyari.';

  @override
  String get reportDescriptionShort =>
      'Masyadong maikli. Hindi bababa sa 10 titik.';

  @override
  String get reportDescriptionLong =>
      'Masyadong mahaba. Hanggang 1000 titik lamang.';

  @override
  String reportAskEmailUse(String v) {
    return 'Gamitin ang email na ito: $v?';
  }

  @override
  String get reportAskEmail => 'Ano ang iyong email? Pwede mo itong laktawan.';

  @override
  String get reportEmailWhy =>
      'Gagamitin lang ang email para sagutin ka tungkol sa report na ito.';

  @override
  String get reportPrivacy =>
      'Ang report at email ay gagamitin lang para ayusin ang app at sagutin ka (RA 10173).';

  @override
  String get reportEmailInvalid =>
      'Mukhang mali ang email. Ulitin, o sabihin ang “laktawan”.';

  @override
  String reportEmailValue(String v) {
    return 'Email: $v.';
  }

  @override
  String get reportAskReview =>
      'Repasuhin ang iyong report. Sabihin ang “ipadala” o “baguhin”.';

  @override
  String reportLineType(String v) {
    return 'Uri: $v';
  }

  @override
  String reportLineModule(String v) {
    return 'Bahagi: $v';
  }

  @override
  String reportLineSeverity(String v) {
    return 'Kalala: $v';
  }

  @override
  String reportLineDescription(String v) {
    return 'Nangyari: $v';
  }

  @override
  String reportLineEmail(String v) {
    return 'Email: $v';
  }

  @override
  String get reportNoEmail => 'walang email';

  @override
  String reportLineDetails(
    String app,
    String os,
    String device,
    String screen,
    String date,
  ) {
    return 'Kasama rin: bersyon ng app $app, $os, $device, mula sa $screen, $date.';
  }

  @override
  String get actionSendReport => 'Ipadala';

  @override
  String get actionEditReport => 'Baguhin';

  @override
  String get reportAskEdit => 'Alin ang babaguhin?';

  @override
  String get reportPartType => 'Uri';

  @override
  String get reportPartModule => 'Bahagi ng app';

  @override
  String get reportPartSeverity => 'Kalala';

  @override
  String get reportPartDescription => 'Ano ang nangyari';

  @override
  String get reportPartEmail => 'Email';

  @override
  String get reportSending => 'Ipinapadala…';

  @override
  String get reportTicketTitle => 'Ang iyong ticket';

  @override
  String reportTicketLine(String v) {
    return 'Ticket: $v';
  }

  @override
  String reportTicketSpoken(String v) {
    return 'Ang numero ng iyong ticket ay $v.';
  }

  @override
  String reportLineDate(String v) {
    return 'Petsa: $v';
  }

  @override
  String reportLineStatus(String v) {
    return 'Katayuan: $v';
  }

  @override
  String get reportStatusSent => 'Naipadala';

  @override
  String get reportStatusPending => 'Naghihintay ipadala';

  @override
  String get reportStatusFailed => 'Hindi naipadala';

  @override
  String get reportSavedOffline =>
      'Naka-save ang report, at ipapadala ito kapag may internet.';

  @override
  String get reportThanks => 'Salamat sa iyong report.';

  @override
  String get actionRepeatTicket => 'Ulitin';

  @override
  String get actionDone => 'Tapos na';

  @override
  String get actionCancelReport => 'Kanselahin';

  @override
  String get reportCancelConfirm =>
      'Kanselahin ang report? Mawawala ang iyong mga sagot.';

  @override
  String get reportCancelled => 'Kinansela ang report.';

  @override
  String get helpReport =>
      'Mag-swipe pakanan o pakaliwa: lumipat ng pagpipilian. I-double tap, o sabihin ang pangalan: piliin. Sabihin ang “bumalik”: nakaraang tanong. Sabihin ang “kanselahin”: itigil ang report.';

  @override
  String get helpReportText =>
      'Magsalita para sumagot, o i-type. Pindutin nang matagal o sabihin ang “magsalita”: magsalita ulit. Sabihin ang “susunod”: magpatuloy. Sabihin ang “bumalik”: nakaraang tanong. Sabihin ang “kanselahin”: itigil ang report.';

  @override
  String get screenMyReports => 'Aking mga report';

  @override
  String myReportsCount(String v) {
    return 'Bilang ng report: $v. Pumili ng isa para marinig.';
  }

  @override
  String get myReportsEmpty => 'Wala ka pang report.';

  @override
  String myReportsRow(String ticket, String type, String date, String status) {
    return '$ticket: $type, $date, $status';
  }

  @override
  String get setReportIssueValue => 'Magsabi ng sira o mungkahi';

  @override
  String get setMyReportsValue => 'Mga naipadalang report at katayuan';

  @override
  String get reportSaveFailed => 'Hindi na-save ang report. Pakisubukan ulit.';

  @override
  String get reportServerOpen => 'Natanggap';

  @override
  String get reportServerInProgress => 'Ginagawa';

  @override
  String get reportServerResolved => 'Naayos na';

  @override
  String get reportServerClosed => 'Sarado';

  @override
  String get setServerAddress => 'Address ng server (developer)';

  @override
  String get serverAddressTitle => 'Address ng server';

  @override
  String get serverAddressHelp =>
      'Ang folder ng dashboard, halimbawa http://192.168.1.61/website/percipere_web/percipere_dashboard';

  @override
  String get serverAddressSave => 'I-save';

  @override
  String get serverAddressReset => 'Ibalik sa orihinal';

  @override
  String get serverAddressCancel => 'Kanselahin';

  @override
  String get serverAddressInvalid =>
      'Hindi ito tamang address. Dapat nagsisimula ito sa http:// o https://.';

  @override
  String get serverAddressCleartext =>
      'Hindi pinapayagan ng build na ito ang http:// sa host na iyon. Gumamit ng https://, o gumawa ng bagong build na may API_CLEARTEXT_HOSTS.';

  @override
  String get serverAddressSaved => 'Nai-save ang address ng server.';

  @override
  String get serverAddressResetDone =>
      'Ibinalik ang address ng server sa orihinal.';

  @override
  String get serverAddressNone => 'Walang server';

  @override
  String get voiceOfflineNone =>
      'Walang internet, at walang naka-install na offline na pagkilala sa boses, kaya hindi kita marinig ngayon. Gumamit muna ng mga galaw. Para gumana ito offline, i-download ang offline na wika sa voice input settings; nasa Settings, Pagsusuri ng boses, ang gabay.';

  @override
  String get voiceOfflineEnglish =>
      'Walang internet. Ingles na offline na pagkilala ang gamit ko ngayon, kaya mas maiintindihan ko ang mga utos sa Ingles, gaya ng next, pause o library.';

  @override
  String get screenVoiceCheck => 'Pagsusuri ng boses';

  @override
  String get setVoiceCheckValue => 'Pakikinig, boses at offline';

  @override
  String get voiceCheckIntro =>
      'Ito ang kalagayan ng pakikinig at ng boses ng app. Piliin ang Subukan para sa limang segundong pagsubok.';

  @override
  String voiceCheckRecognizer(String service) {
    return 'Pagkilala sa boses: $service.';
  }

  @override
  String voiceCheckLanguage(String locale) {
    return 'Wika ng pakikinig: $locale.';
  }

  @override
  String voiceCheckOfflineFilipino(String answer) {
    return 'Offline na Filipino: $answer.';
  }

  @override
  String voiceCheckOfflineEnglish(String answer) {
    return 'Offline na Ingles: $answer.';
  }

  @override
  String voiceCheckMode(String mode) {
    return 'Paraan ng pakikinig ngayon: $mode.';
  }

  @override
  String get voiceCheckModeOnDevice => 'sa tablet mismo, gumagana offline';

  @override
  String get voiceCheckModeOnline => 'online, kailangan ng internet';

  @override
  String get voiceCheckModeEnglish => 'offline na Ingles';

  @override
  String get voiceCheckModeNone =>
      'hindi makakarinig, walang internet at walang offline na wika';

  @override
  String voiceCheckInternet(String answer) {
    return 'Internet: $answer.';
  }

  @override
  String voiceCheckMic(String answer) {
    return 'Pahintulot sa mikropono: $answer.';
  }

  @override
  String voiceCheckTtsEngine(String engine) {
    return 'Makina ng boses: $engine.';
  }

  @override
  String voiceCheckTtsVoice(String voice, String where) {
    return 'Boses: $voice, $where.';
  }

  @override
  String get voiceCheckVoiceLocal => 'naka-install sa tablet, gumagana offline';

  @override
  String get voiceCheckVoiceNetwork => 'kailangan ng internet';

  @override
  String get voiceCheckFilipinoVoiceMissing =>
      'Wala pang Filipino na boses sa tablet; Ingles ang ginagamit.';

  @override
  String get voiceCheckYes => 'oo';

  @override
  String get voiceCheckNo => 'hindi';

  @override
  String get voiceCheckUnknown => 'hindi alam';

  @override
  String get voiceCheckTest => 'Subukan, limang segundo';

  @override
  String get voiceCheckTestSay => 'Sabihin: buksan ang Aklatan.';

  @override
  String voiceCheckTestResult(
    String heard,
    String command,
    String intent,
    String percent,
    String confidence,
    String ms,
  ) {
    return 'Narinig: $heard. Utos: $command. Percy: $intent, $percent porsiyento. Kumpiyansa ng pagkilala: $confidence. Bilis ng sagot: $ms millisecond.';
  }

  @override
  String get voiceCheckTestNothing => 'Walang narinig. Subukan ulit.';

  @override
  String get voiceCheckNone => 'wala';

  @override
  String get voiceCheckReadAgain => 'Basahin ulit';

  @override
  String get voiceCheckVoiceInput => 'Settings ng voice input';

  @override
  String get voiceCheckTtsSettings => 'Settings ng boses ng app';

  @override
  String voiceCheckDownload(String language) {
    return 'I-download ang offline na $language';
  }

  @override
  String get voiceCheckDownloadStarted =>
      'Sinimulan ang pag-download. Tingnan ang abiso ng tablet, at bumalik dito pagkatapos.';

  @override
  String get voiceCheckDownloadFailed =>
      'Hindi ito ma-download mula rito. Buksan ang Settings ng voice input at hanapin ang Offline speech recognition.';

  @override
  String get languageFilipino => 'Filipino';

  @override
  String get languageEnglish => 'Ingles';

  @override
  String get screenOfflineVoice => 'Mga boses at wika';

  @override
  String get offlineVoiceWait =>
      'Pakihintay habang dina-download namin ang mga boses at wika.';

  @override
  String offlineVoiceSize(String size) {
    return 'Mga $size megabyte ito; isang beses lang.';
  }

  @override
  String offlineVoiceProgress(String percent) {
    return '$percent porsiyento na.';
  }

  @override
  String get offlineVoiceReady =>
      'Handa na. Gumagana na ang boses kahit walang internet.';

  @override
  String get offlineVoiceNoInternet =>
      'Walang internet ngayon, kaya hindi pa ma-download ang mga boses. Puwede mo nang gamitin ang mga galaw, at ang boses kapag may internet. Itutuloy ko ang pag-download pagbalik ng internet.';

  @override
  String offlineVoiceLowStorage(String size) {
    return 'Kulang ang espasyo sa tablet para sa mga boses. Kailangan ng mga $size megabyte. Magbura ng ilang file, at susubukan ko ulit.';
  }

  @override
  String get offlineVoiceFailed =>
      'Hindi natapos ang pag-download ng mga boses. Susubukan ko ulit mamaya.';

  @override
  String get offlineVoiceContinue => 'Ituloy habang nagda-download';

  @override
  String get offlineVoiceContinueDone =>
      'Itutuloy ko ang pag-download habang ginagamit mo ang app.';

  @override
  String get offlineVoiceRetry => 'Subukan ulit';

  @override
  String offlineVoiceStatusDownloading(String percent) {
    return 'Nagda-download: $percent porsiyento';
  }

  @override
  String get offlineVoiceStatusChecking =>
      'Tinitingnan kung ano ang kailangan…';

  @override
  String voiceCheckOfflineModels(String status) {
    return 'Sariling offline na boses at utos ng Percipere: $status.';
  }

  @override
  String voiceCheckModelsInstalled(String versions) {
    return 'naka-install, bersyon $versions';
  }

  @override
  String get voiceCheckModelsPartial => 'bahagi lang ang naka-install';

  @override
  String get voiceCheckModelsMissing => 'hindi pa naka-download';

  @override
  String voiceCheckModelsDownloading(String percent) {
    return 'nagda-download, $percent porsiyento';
  }

  @override
  String get voiceCheckModelsWaiting => 'naghihintay ng internet';

  @override
  String get voiceCheckModelsLowStorage => 'kulang ang espasyo';

  @override
  String get voiceCheckModelsFailed => 'hindi natapos ang pag-download';

  @override
  String get voiceCheckModeOffline => 'offline, sariling makina ng Percipere';

  @override
  String get voiceCheckOfflineVoice => 'Percipere offline';

  @override
  String get voiceCheckRedownload => 'I-download ulit ang mga boses';

  @override
  String get voiceCheckRedownloadStarted =>
      'Sinimulan ulit ang pag-download ng mga boses.';

  @override
  String get voiceCheckDeleteModels => 'Burahin ang mga offline na boses';

  @override
  String get voiceCheckDeleteConfirm =>
      'Burahin ang mga offline na boses at utos? Kailangan ng internet para ma-download ulit.';

  @override
  String get voiceCheckModelsDeleted =>
      'Nabura na ang mga offline na boses. Kapag may internet, ida-download ko ulit.';

  @override
  String get screenWerTest => 'Pagsubok ng pagkilala sa boses';

  @override
  String get werIntro =>
      'Basahin nang malakas ang pangungusap. Pindutin ang Makinig, pagkatapos sabihin ito.';

  @override
  String werSay(String phrase) {
    return 'Sabihin: $phrase';
  }

  @override
  String get werListen => 'Makinig';

  @override
  String get werNext => 'Susunod na pangungusap';

  @override
  String get werExport => 'I-export ang mga resulta (CSV)';

  @override
  String get werClear => 'Burahin ang mga resulta';

  @override
  String get werClearConfirm => 'Burahin ang lahat ng resulta ng pagsubok?';

  @override
  String get werCleared => 'Nabura na ang mga resulta.';

  @override
  String get werEmpty => 'Wala pang resulta.';

  @override
  String get werFailed => 'Hindi ako nakinig nang maayos. Subukan ulit.';

  @override
  String werResult(String heard, String percent, String s, String d, String i) {
    return 'Narinig: $heard. WER $percent porsyento. Mali: $s, kulang: $d, sobra: $i.';
  }

  @override
  String get qualityBlurry =>
      'Malabo ang larawan. Pakihawakan nang mas matatag ang telepono.';

  @override
  String get qualityTooDark =>
      'Masyadong madilim ang larawan. Lumipat po sa mas maliwanag na lugar.';

  @override
  String get qualityTooBright =>
      'Masyadong maliwanag ang larawan. Iwasan po ang direktang ilaw.';

  @override
  String get qualityRetake => 'Gusto mo bang kunan ulit?';

  @override
  String get qualityRetaking => 'Sige, kunan natin ulit.';

  @override
  String get setServerTest => 'Subukan ang koneksyon sa server';

  @override
  String get serverTestRunning => 'Sinusubukan ang koneksyon sa server.';

  @override
  String get serverTestOk => 'Nakakonekta sa server. Handa na.';

  @override
  String get serverTestNotConfigured =>
      'Wala pang address ng server. Ilagay muna ang address.';

  @override
  String get serverTestNoNetwork =>
      'Walang network ang tablet. I-on ang Wi-Fi o ang hotspot.';

  @override
  String get serverTestWrongAddress =>
      'Mali ang address ng server. Tingnan ang IP at ang folder.';

  @override
  String get serverTestUnreachable =>
      'Hindi maabot ang server. Siguraduhing nasa parehong hotspot ang tablet at ang computer.';

  @override
  String get serverTestServerDown =>
      'Bukas ang computer pero hindi gumagana ang server. Buksan ang MAMP o XAMPP at ang database.';

  @override
  String get serverTestHttpBlocked =>
      'Hindi pinapayagan ang http sa address na iyan. Gumamit ng address sa lokal na network o ng https.';

  @override
  String get serverTestTimeout =>
      'Natagalan ang sagot ng server. Subukan ulit.';

  @override
  String get serverOnline => 'Nakakonekta sa server.';

  @override
  String get serverOffline =>
      'Walang koneksyon sa server. Offline na mga aklat lang ang magagamit.';

  @override
  String get voiceBusyWait => 'Sandali lang po.';

  @override
  String get startupTitle => 'Inihahanda ang Percipere';

  @override
  String get startupWait => 'Pakihintay po, inihahanda ang Percipere.';

  @override
  String get startupReady => 'Handa na po.';

  @override
  String get startupStillLoading =>
      'May ilang bahagi pa pong naglo-load, pero puwede na po kayong magsimula.';

  @override
  String startupProgress(String done, String total) {
    return '$done sa $total ang handa na';
  }

  @override
  String startupStepLine(String step, String status) {
    return '$step: $status';
  }

  @override
  String get startupStepSettings => 'Mga setting at datos';

  @override
  String get startupStepVoice => 'Boses ng app';

  @override
  String get startupStepRecognizer => 'Pakikinig sa boses';

  @override
  String get startupStepPercy => 'Si Percy';

  @override
  String get startupStepOcr => 'Pagbasa ng larawan';

  @override
  String get startupStepLoading => 'naglo-load';

  @override
  String get startupStepReady => 'handa na';

  @override
  String get startupStepFailed => 'hindi na-load';

  @override
  String get setVoiceStateOverlay => 'Estado ng boses (developer)';

  @override
  String voiceStateLabel(String state) {
    return 'Boses: $state';
  }

  @override
  String get voiceStateLoading => 'naglo-load';

  @override
  String get voiceStateReady => 'handa';

  @override
  String get voiceStateSpeaking => 'nagsasalita';

  @override
  String get voiceStateListening => 'nakikinig';

  @override
  String get voiceStateProcessing => 'nagpoproseso';

  @override
  String voiceStateStartup(String seconds) {
    return 'Pagbukas: $seconds s';
  }
}
