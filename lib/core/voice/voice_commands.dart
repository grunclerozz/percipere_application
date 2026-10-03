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
  NavIntent.history: ['kasaysayan', 'history'],
  NavIntent.settings: ['settings', 'setting', 'ayos', 'mga setting'],
  NavIntent.help: ['tulong', 'help'],
  NavIntent.home: ['home', 'simula', 'umpisa'],
  NavIntent.report: ['ulat', 'report', 'feedback', 'puna'],
  NavIntent.voiceMode: ['pa-boses', 'voice mode'],
  NavIntent.gestureMode: ['pa-galaw', 'gesture mode'],
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
