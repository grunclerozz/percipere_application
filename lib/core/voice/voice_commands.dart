import '../accessibility/nav_intent.dart';

/// Spoken phrases (Filipino and English) for the app-wide voice commands.
///
/// These are recognition vocabulary, not UI copy, so they live here rather
/// than in the ARB files. Screen-specific commands come from each action's
/// label and `voiceSynonyms` and take precedence over these.
const Map<NavIntent, List<String>> globalVoiceCommands = {
  NavIntent.activate: ['piliin', 'select', 'ok', 'okay', 'buksan', 'open'],
  NavIntent.read: ['basahin', 'read', 'basa'],
  NavIntent.pause: ['i-pause', 'pause', 'sandali'],
  NavIntent.resume: ['ituloy', 'resume', 'continue', 'tuloy'],
  NavIntent.stopSpeech: ['itigil', 'stop', 'tigil', 'tahimik'],
  NavIntent.repeat: ['ulitin', 'repeat', 'ulit', 'again'],
  NavIntent.next: ['susunod', 'next', 'sunod'],
  NavIntent.previous: ['nakaraan', 'previous'],
  NavIntent.nextParagraph: ['susunod na talata', 'next paragraph'],
  NavIntent.previousParagraph: ['nakaraang talata', 'previous paragraph'],
  NavIntent.readFromStart: [
    'mula sa simula',
    'basahin mula sa simula',
    'from the beginning',
    'start over',
    'umpisahan ulit',
  ],
  NavIntent.back: [
    'bumalik',
    'bumalik ng page',
    'balik',
    'bumalik sa nakaraang page',
    'back',
    'go back',
  ],
  NavIntent.faster: ['bilisan', 'faster', 'mas mabilis'],
  NavIntent.slower: ['bagalan', 'slower', 'mas mabagal'],
  NavIntent.textBigger: ['palakihin', 'lakihan', 'bigger', 'zoom in'],
  NavIntent.textSmaller: ['paliitin', 'liitan', 'smaller', 'zoom out'],
  NavIntent.camera: ['camera', 'kamera'],
  NavIntent.capture: ['kunan', 'capture', 'take picture'],
  NavIntent.upload: ['mag-upload', 'upload', 'i-upload'],
  NavIntent.save: ['i-save', 'save', 'itago'],
  NavIntent.library: [
    'aklatan',
    'library',
    'mga aklat',
    'kasaysayan',
    'history',
  ],
  NavIntent.nextChapter: ['susunod na kabanata', 'next chapter'],
  NavIntent.previousChapter: ['nakaraang kabanata', 'previous chapter'],
  NavIntent.favorite: [
    'favorite',
    'paborito',
    'i-favorite ito',
    'ifavorite ito',
  ],
  NavIntent.favorites: ['mga paborito ko', 'mga paborito', 'my favorites'],
  NavIntent.settings: ['settings', 'setting', 'ayos', 'mga setting'],
  NavIntent.help: ['tulong', 'help'],
  NavIntent.home: ['home', 'simula', 'umpisa'],
  NavIntent.report: ['ulat', 'report', 'feedback', 'puna'],
  NavIntent.voiceMode: ['pa-boses', 'voice mode'],
  NavIntent.gestureMode: ['pa-galaw', 'gesture mode'],
  NavIntent.assistant: [
    'percy',
    'hey percy',
    'kausapin si percy',
    'tawagin si percy',
    'katulong',
    'assistant',
    'voice assistant',
  ],
};

/// Saying just the app name re-arms listening; as a prefix it is ignored
/// ("Percipere, camera").
const List<String> wakeWords = ['percipere', 'persipere', 'perchipere'];

/// Answers to "Ang ibig mo bang sabihin ay …?" and to offers.
const List<String> yesWords = [
  'oo',
  'opo',
  'oho',
  'yes',
  'yeah',
  'tama',
  'sige',
];

/// Negative answers.
const List<String> noWords = ['hindi', 'huwag', 'no', 'mali', 'ayoko'];

/// The only commands accepted while a document is being read aloud
/// (barge-in): the microphone also hears the app's own voice, so the list is
/// kept to what controls the reading.
const Set<NavIntent> readingControlIntents = {
  NavIntent.pause,
  NavIntent.stopSpeech,
  NavIntent.back,
  NavIntent.faster,
  NavIntent.slower,
  NavIntent.textBigger,
  NavIntent.textSmaller,
  NavIntent.favorite,
  NavIntent.repeat,
  NavIntent.assistant,
};
