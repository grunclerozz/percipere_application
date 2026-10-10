import 'command_matcher.dart';

/// Questions the app answers from what it knows right now (not commands
/// bound to a button).
enum Question {
  /// "Nasaan ako?" — which screen, what is focused (Reader: how far).
  whereAmI,

  /// "Ano ang pwede kong gawin?" — the commands that work here.
  whatCanIDo,

  /// "Anong oras na?"
  time,

  /// "Anong petsa ngayon?"
  date,

  /// "Paano gamitin?" — the controls tutorial.
  tutorial,

  /// Reader: "Ano ito?" — what kind of document.
  docType,

  /// Reader: "Magkano?" — the total or amount due.
  total,

  /// Reader: "Kailan ang due?"
  due,

  /// Reader: "Kailan mapapaso?" — expiry date.
  expiry,

  /// Reader: "Paano inumin?" — dosage instructions.
  dosage,

  /// Reader: "Ibuod mo." — a short summary.
  summary,

  /// Reader: "Ilan pa?" — how much is left.
  progress,
}

/// The Reader-only questions (about the open document).
const Set<Question> documentQuestions = {
  Question.docType,
  Question.total,
  Question.due,
  Question.expiry,
  Question.dosage,
  Question.summary,
  Question.progress,
};

/// "Basahin / buksan / ituloy ang <title>" said on any screen.
typedef TitleCommand = ({TitleVerb verb, String title, bool last});

/// What to do with the named document.
enum TitleVerb {
  /// Open it in the Reader and start reading.
  read,

  /// Open it (Reader, at the saved spot).
  open,

  /// Carry on where the user left off.
  resume,
}

/// Turns how people actually talk into what the command matcher expects.
///
/// Recognition vocabulary (Filipino, English and Taglish), not UI copy, so
/// it lives here rather than in the ARB files — like `voice_commands.dart`.
abstract final class Understanding {
  // ── Cleaning ─────────────────────────────────────────────────────────────

  /// Polite or filler openings dropped before matching ("pwede bang
  /// basahin" → "basahin"). Longest first.
  static const List<List<String>> _openings = [
    ['pwede', 'mo', 'bang'],
    ['puwede', 'mo', 'bang'],
    ['maaari', 'mo', 'bang'],
    ['pwede', 'bang'],
    ['puwede', 'bang'],
    ['maaari', 'bang'],
    ['gusto', 'ko', 'na'],
    ['gusto', 'kong'],
    ['nais', 'kong'],
    ['i', 'would', 'like', 'to'],
    ['i', 'want', 'to'],
    ['id', 'like', 'to'],
    ['can', 'you'],
    ['could', 'you'],
    ['would', 'you'],
    ['pakisuyo'],
    ['paki'],
    ['please'],
    ['kindly'],
    ['lets'],
  ];

  /// Particles that never change what is asked ("basahin mo nga po").
  static const Set<String> _particles = {
    'po',
    'nga',
    'naman',
    'lang',
    'ba',
    'mo',
    'ninyo',
    'nyo',
    'please',
    'kindly',
    'muna',
  };

  /// Everyday verb forms → the command word the matcher knows.
  static const Map<String, String> _verbForms = {
    'pakibasa': 'basahin',
    'pakibasahin': 'basahin',
    'babasahin': 'basahin',
    'binabasa': 'basahin',
    'basa': 'basahin',
    'pakibuksan': 'buksan',
    'pakibukas': 'buksan',
    'bubuksan': 'buksan',
    'pakiulit': 'ulitin',
    'pakiulitin': 'ulitin',
    'uulitin': 'ulitin',
    'pakitigil': 'itigil',
    'pakihinto': 'itigil',
    'hinto': 'itigil',
    'huminto': 'itigil',
    'tumigil': 'itigil',
    'ihinto': 'itigil',
    'pakibilisan': 'bilisan',
    'pakibilis': 'bilisan',
    'pakibagalan': 'bagalan',
    'pakibagal': 'bagalan',
    'pakilakihan': 'palakihin',
    'pakilaki': 'palakihin',
    'pakiliitan': 'paliitin',
    'pakiliit': 'paliitin',
    'pakituloy': 'ituloy',
    'ipagpatuloy': 'ituloy',
    'pakisave': 'isave',
    'pakihanap': 'hanapin',
    'pakihanapin': 'hanapin',
    'pakikunan': 'kunan',
    'pakibalik': 'bumalik',
    'bumalik': 'bumalik',
  };

  /// [text] as the matcher should see it: normalized, verb forms mapped,
  /// particles and polite openings removed. Returns the normalized text
  /// unchanged when cleaning would leave nothing.
  static String clean(String text) {
    final words = CommandMatcher.tokens(text)
        .map((w) => _verbForms[w] ?? w)
        .toList();
    var start = 0;
    var changed = true;
    while (changed) {
      changed = false;
      for (final o in _openings) {
        if (_startsWith(words, o, start)) {
          start += o.length;
          changed = true;
          break;
        }
      }
    }
    final kept = [
      for (final w in words.skip(start))
        if (!_particles.contains(w)) w,
    ];
    if (kept.isEmpty) return words.join(' ');
    return kept.join(' ');
  }

  static bool _startsWith(List<String> words, List<String> prefix, int at) {
    if (words.length - at <= prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (words[at + i] != prefix[i]) return false;
    }
    return true;
  }

  // ── Questions ────────────────────────────────────────────────────────────

  /// How each question is asked (longest phrase wins at the same spot).
  static const Map<Question, List<String>> questionPhrases = {
    Question.whereAmI: [
      'nasaan ako',
      'nasan ako',
      'saan ako',
      'nasaan na ako',
      'anong screen ito',
      'anong screen',
      'ano ang nasa screen',
      'where am i',
      'what screen is this',
      'what screen',
      'whats on the screen',
      'what is on the screen',
    ],
    Question.whatCanIDo: [
      'ano ang pwede kong gawin',
      'ano ang puwede kong gawin',
      'anong pwede kong gawin',
      'ano ang pwede kong sabihin',
      'anong pwede kong sabihin',
      'ano ang magagawa ko',
      'anong pwede',
      'ano ang mga utos',
      'anong mga utos',
      'mga utos',
      'ano ang mga pagpipilian',
      'what can i do',
      'what can i say',
      'what are my options',
      'what are the commands',
      'list commands',
    ],
    Question.time: [
      'anong oras na',
      'anong oras',
      'ano ang oras',
      'what time is it',
      'what time',
      'whats the time',
    ],
    Question.date: [
      'anong petsa ngayon',
      'anong petsa',
      'ano ang petsa',
      'anong araw ngayon',
      'what day is it',
      'whats the date',
      'what is the date',
      'what date is it',
      'todays date',
    ],
    Question.tutorial: [
      'paano gamitin ang app',
      'paano gamitin',
      'paano ito gamitin',
      'turuan mo ako',
      'turuan ako',
      'tutorial',
      'how do i use this',
      'how do i use',
      'how to use',
      'teach me',
    ],
    Question.docType: [
      'anong klaseng dokumento',
      'anong klase ng dokumento',
      'ano ang dokumentong ito',
      'anong dokumento ito',
      'ano ito',
      'what kind of document',
      'what is this document',
      'what document is this',
      'what is this',
    ],
    Question.total: [
      'magkano ang babayaran',
      'magkano ang total',
      'magkano ang kabuuan',
      'magkano lahat',
      'magkano',
      'ano ang total',
      'kabuuan',
      'how much do i pay',
      'how much is it',
      'how much',
      'what is the total',
      'whats the total',
      'total',
      'amount',
    ],
    Question.due: [
      'kailan ang due',
      'kailan ang deadline',
      'kailan dapat bayaran',
      'kailan babayaran',
      'hanggang kailan',
      'kailan',
      'due date',
      'when is it due',
      'when do i pay',
      'deadline',
    ],
    Question.expiry: [
      'kailan mapapaso',
      'kailan mag expire',
      'kailan ang expiry',
      'mapapaso',
      'expiry date',
      'expiration date',
      'expiry',
      'expiration',
      'when does it expire',
    ],
    Question.dosage: [
      'paano inumin',
      'ilang beses iinumin',
      'ilang beses',
      'gaano karami',
      'ano ang dosage',
      'dosage',
      'dose',
      'how do i take it',
      'how to take',
      'how often',
      'how many times',
    ],
    Question.summary: [
      'ibuod mo',
      'ibuod',
      'ano ang buod',
      'buod',
      'ano ang laman',
      'ano ang nilalaman',
      'tungkol saan ito',
      'tungkol saan',
      'summarize',
      'summarise',
      'summary',
      'what does it say',
      'what is it about',
    ],
    Question.progress: [
      'ilan pa',
      'gaano pa kahaba',
      'ilang talata pa',
      'malapit na bang matapos',
      'how much is left',
      'how much left',
      'how far am i',
      'how long is left',
    ],
  };

  static const CommandMatcher _strict = CommandMatcher(
    acceptThreshold: 0.88,
    askThreshold: 0.88,
  );

  static final List<CommandPhrase> _general = _phrasesFor(
    Question.values.where((q) => !documentQuestions.contains(q)),
  );

  static final List<CommandPhrase> _document = _phrasesFor(documentQuestions);

  static List<CommandPhrase> _phrasesFor(Iterable<Question> qs) => [
    for (final q in qs)
      for (final p in questionPhrases[q]!)
        CommandPhrase(p, ValueTarget<Question>(q)),
  ];

  /// The app-wide question asked in [text], if any.
  static Question? question(String text) => _find(text, _general);

  /// The question about the open document asked in [text], if any.
  static Question? documentQuestion(String text) => _find(text, _document);

  static Question? _find(String text, List<CommandPhrase> phrases) {
    final result = _strict.match(clean(text), phrases);
    if (result is Matched) {
      final t = result.target;
      if (t is ValueTarget<Question>) return t.value;
    }
    return null;
  }

  // ── Documents by name ────────────────────────────────────────────────────

  static const Map<TitleVerb, List<List<String>>> _titleVerbs = {
    TitleVerb.resume: [
      ['ituloy'],
      ['continue'],
      ['resume'],
    ],
    TitleVerb.read: [
      ['basahin'],
      ['read'],
    ],
    TitleVerb.open: [
      ['buksan'],
      ['open'],
    ],
  };

  /// Little words between the verb and the title.
  static const Set<String> _articles = {
    'ang',
    'yung',
    'iyong',
    'ung',
    'yong',
    'aking',
    'ko',
    'the',
    'my',
    'si',
    'sa',
    'ng',
  };

  /// Saying one of these instead of a title means the most recent one.
  static const Set<String> _lastWords = {
    'huli',
    'huling',
    'huling binasa',
    'huling dokumento',
    'iyon',
    'yun',
    'yon',
    'pagbasa',
    'pagbabasa',
    'binabasa',
    'binabasa ko',
    'last',
    'last one',
    'last document',
    'that',
    'that one',
    'it',
    'reading',
  };

  /// Phrases that mean "the most recent document" ([_lastWords]).
  static bool isLast(String title) =>
      _lastWords.contains(CommandMatcher.normalize(title));

  /// "Basahin ang Liham kay Nanay", "pakibukas yung resibo", "continue the
  /// last one": the verb and the title as said (original words), or null.
  static TitleCommand? titleCommand(String text) {
    final raw = text.trim().split(RegExp(r'\s+'));
    final mapped = [
      for (final w in raw)
        () {
          final n = CommandMatcher.normalize(w);
          return _verbForms[n] ?? n;
        }(),
    ];
    // Skip polite openings and particles before the verb.
    var i = 0;
    var moved = true;
    while (moved && i < mapped.length) {
      moved = false;
      if (_particles.contains(mapped[i])) {
        i++;
        moved = true;
        continue;
      }
      for (final o in _openings) {
        if (_startsWith(mapped, o, i)) {
          i += o.length;
          moved = true;
          break;
        }
      }
    }
    for (final entry in _titleVerbs.entries) {
      for (final verb in entry.value) {
        if (i + verb.length > mapped.length) continue;
        var ok = true;
        for (var j = 0; j < verb.length; j++) {
          if (mapped[i + j] != verb[j]) ok = false;
        }
        if (!ok) continue;
        var k = i + verb.length;
        while (k < mapped.length &&
            (_particles.contains(mapped[k]) || _articles.contains(mapped[k]))) {
          k++;
        }
        final words = raw.sublist(k).toList();
        // Trailing particles ("… po").
        while (words.isNotEmpty &&
            _particles.contains(CommandMatcher.normalize(words.last))) {
          words.removeLast();
        }
        final title = words.join(' ').trim();
        if (title.isEmpty) return null;
        return (verb: entry.key, title: title, last: isLast(title));
      }
    }
    return null;
  }

  /// Multi-word starts of [titleCommand]: a partial result that is only
  /// this much waits for the title instead of running "basahin" at once.
  static const List<String> titlePrefixes = [
    'basahin ang',
    'basahin yung',
    'buksan ang',
    'buksan yung',
    'ituloy ang',
    'ituloy yung',
    'read the',
    'read my',
    'open the',
    'open my',
    'continue the',
  ];
}
