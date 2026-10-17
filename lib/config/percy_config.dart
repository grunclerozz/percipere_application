/// Percy (self-built voice assistant, Phase 9): thresholds and timings, in
/// one place so they can be tuned after testing (`docs/specs/percy-local.md`).
abstract final class PercyConfig {
  /// At or above this probability Percy acts on the intent.
  static const double actThreshold = 0.60;

  /// From here up to [actThreshold] Percy asks "Ang ibig mo bang sabihin
  /// ay …?"; below it Percy says it can't do that yet and suggests commands.
  static const double askThreshold = 0.30;

  /// When Percy or the app has asked a yes/no question, a yes/no/cancel
  /// prediction this confident answers it.
  static const double answerThreshold = 0.30;

  /// Library title match (0–1) needed to open a document by name.
  static const double titleMatch = 0.70;

  /// Most options Percy reads out when asking "which one?".
  static const int maxChoices = 3;

  /// Turns Percy remembers (dialogue context).
  static const int historyTurns = 3;

  /// "Exact short command": at most this many words, said as a known command.
  static const int exactCommandWords = 3;

  /// Silence (counted from when Percy and the app stop talking) before
  /// Percy asks once "Nandito pa ako. Ano ang maitutulong ko?".
  static const Duration silenceReprompt = Duration(seconds: 9);

  /// Further silence after that question before Percy says a short goodbye
  /// and ends the session.
  static const Duration silenceEnd = Duration(seconds: 9);

  /// Percy's pending question stays answerable this long.
  static const Duration questionValid = Duration(seconds: 30);

  /// Bundled model the app uses.
  static const String modelAsset = 'assets/percy/model.json';

  /// Persona (name, default politeness and talkativeness, greeting).
  static const String personaAsset = 'assets/percy/persona.json';

  /// What Percy says, per intent, politeness and language.
  static const String responsesAsset = 'assets/percy/responses.json';

  /// Questions and answers about Percy and the app.
  static const String knowledgeAsset = 'assets/percy/knowledge.json';

  /// A question this similar (0–1, cosine) to a knowledge question gets the
  /// answer at once.
  static const double knowledgeAnswer = 0.55;

  /// From here up to [knowledgeAnswer] Percy asks "Ito ba ang tinatanong
  /// mo?" with the closest topic; below it suggests example questions.
  static const double knowledgeAsk = 0.35;

  /// A sentence this similar to a knowledge question is answered even when
  /// the classifier did not call it a question.
  static const double knowledgeRescue = 0.85;
}
