import '../../config/voice_config.dart';
import '../accessibility/nav_intent.dart';
import 'command_matcher.dart';
import 'voice_commands.dart';

/// Listening while the app reads a document aloud ("barge-in"): telling the
/// user's commands apart from the app's own voice, which the microphone
/// hears too.
abstract final class BargeIn {
  /// The words of [heard] that are not the app's own voice: words found in
  /// [readAloud] (the sentences just read) are removed, also when the
  /// recognizer got them slightly wrong.
  static List<String> residual(String heard, Iterable<String> readAloud) {
    final echo = <String>{
      for (final sentence in readAloud) ...CommandMatcher.tokens(sentence),
    };
    return [
      for (final word in CommandMatcher.tokens(heard))
        if (!_isEcho(word, echo)) word,
    ];
  }

  /// Whether [heard] is only the app's own voice.
  static bool isEcho(String heard, Iterable<String> readAloud) =>
      residual(heard, readAloud).isEmpty;

  static bool _isEcho(String word, Set<String> echo) {
    if (echo.contains(word)) return true;
    if (word.length < VoiceConfig.echoMinFuzzyLength) return false;
    for (final e in echo) {
      if (e.length >= VoiceConfig.echoMinFuzzyLength &&
          CommandMatcher.similarity(word, e) >=
              VoiceConfig.echoWordSimilarity) {
        return true;
      }
    }
    return false;
  }

  /// The reading command the user said in [heard], or null.
  ///
  /// Only [readingControlIntents] count, and only when found in what is left
  /// after removing the app's own voice: word for word, or at least
  /// [VoiceConfig.partialAcceptScore] similar. Anything else (the app's own
  /// voice, unclear speech, other commands) is ignored.
  static NavIntent? command(String heard, Iterable<String> readAloud) {
    final rest = residual(heard, readAloud);
    if (rest.isEmpty) return null;
    final result = const CommandMatcher().match(rest.join(' '), _phrases);
    if (result
        case Matched(target: ValueTarget(:final NavIntent value), :final score)
        when score >= VoiceConfig.partialAcceptScore) {
      return value;
    }
    return null;
  }

  static final List<CommandPhrase> _phrases = [
    for (final e in globalVoiceCommands.entries)
      if (readingControlIntents.contains(e.key))
        for (final p in e.value) CommandPhrase(p, ValueTarget(e.key)),
  ];

  /// Phrases the recognizer should expect while reading.
  static List<String> get phrases => [for (final p in _phrases) p.phrase];
}
