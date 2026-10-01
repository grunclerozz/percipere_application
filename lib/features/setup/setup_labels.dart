import '../../app/locale_provider.dart';
import '../../config/palette.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/settings/app_settings.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/voice/command_matcher.dart';
import '../../l10n/app_localizations.dart';
import 'setup_flow.dart';

/// A text color's name in the language of [l] ("Kayumanggi" / "Dark brown").
String colorName(TextColorOption o, AppLocalizations l) =>
    l.localeName.startsWith('en') ? o.english : o.filipino;

/// A theme's name.
String themeName(ThemeId id, AppLocalizations l) => switch (id) {
  ThemeId.creamNavy => l.themeCreamNavy,
  ThemeId.darkYellow => l.themeDarkYellow,
  ThemeId.darkWhite => l.themeDarkWhite,
};

/// The question of [step] (shown before it is spoken).
String stepQuestion(SetupStep step, AppLocalizations l) => switch (step) {
  SetupStep.navMode => l.welcomePrompt,
  SetupStep.seesText => l.setupSeesQuestion,
  SetupStep.textSize => l.setupSizeQuestion,
  SetupStep.textColor => l.setupColorQuestion,
  SetupStep.voiceLanguage => l.setupLanguageQuestion,
  SetupStep.speed => l.setupSpeedQuestion,
  SetupStep.pitch => l.setupPitchQuestion,
  SetupStep.theme => l.setupThemeQuestion,
  SetupStep.vibration => l.setupVibrationQuestion,
  SetupStep.autoRead => l.setupAutoReadQuestion,
  SetupStep.summary => l.setupSummaryQuestion,
};

/// The current value of [step] as shown under the question.
String stepValue(SetupStep step, AppSettings s, AppLocalizations l) =>
    switch (step) {
      SetupStep.navMode => switch (s.navMode) {
        NavMode.voice => l.navModeVoice,
        NavMode.gestures => l.navModeGestures,
        null => '',
      },
      SetupStep.seesText => '',
      SetupStep.textSize => l.setupSizeValue(s.textSize.round()),
      SetupStep.textColor => l.setupColorValue(
        colorName(s.resolvedTextColor, l),
      ),
      SetupStep.voiceLanguage =>
        s.locale == AppLocales.english ? l.langEnglish : l.langTagalog,
      SetupStep.speed => l.setupSpeedValue(ReadingRate.label(s.readingRate)),
      SetupStep.pitch => l.setupPitchValue(ReadingRate.label(s.pitch)),
      SetupStep.theme => l.setupThemeValue(themeName(s.themeId, l)),
      SetupStep.vibration => s.haptics ? l.answerYes : l.answerNo,
      SetupStep.autoRead => s.autoRead ? l.answerYes : l.answerNo,
      SetupStep.summary => '',
    };

/// One summary line: "Bilis: 1.25x" (no final period; lines are joined
/// into sentences).
String summaryLine(SetupStep step, AppSettings s, AppLocalizations l) =>
    _summaryLine(step, s, l).replaceFirst(RegExp(r'\.$'), '');

String _summaryLine(SetupStep step, AppSettings s, AppLocalizations l) =>
    switch (step) {
      SetupStep.navMode => l.summaryNavMode(stepValue(step, s, l)),
      SetupStep.voiceLanguage => l.summaryLanguage(stepValue(step, s, l)),
      SetupStep.vibration => l.summaryVibration(stepValue(step, s, l)),
      SetupStep.autoRead => l.summaryAutoRead(stepValue(step, s, l)),
      _ => stepValue(step, s, l),
    };

/// Words that name each step ("bumalik sa bilis").
const Map<SetupStep, List<String>> stepKeywords = {
  SetupStep.navMode: [
    'pag-navigate',
    'navigate',
    'navigation',
    'boses o galaw',
    'mode',
  ],
  SetupStep.textSize: ['laki', 'laki ng teksto', 'text size', 'size'],
  SetupStep.textColor: ['kulay', 'kulay ng teksto', 'color', 'text color'],
  SetupStep.voiceLanguage: ['wika', 'wika ng boses', 'language', 'boses'],
  SetupStep.speed: ['bilis', 'speed'],
  SetupStep.pitch: ['tono', 'pitch', 'tone'],
  SetupStep.theme: ['tema', 'theme'],
  SetupStep.vibration: ['vibrate', 'vibration', 'pag-vibrate'],
  SetupStep.autoRead: [
    'awtomatikong pagbasa',
    'awtomatiko',
    'auto read',
    'pagbasa',
  ],
};

final RegExp _jumpPrefix = RegExp(
  r'^(bumalik sa|balik sa|bumalik ng|go back to|back to|palitan ang|'
  r'baguhin ang|change)\s+(.+)$',
);

/// The step named in "bumalik sa bilis" / "palitan ang kulay", if it is one
/// of [items]; null otherwise (then the words are handled as a command).
SetupStep? matchStepJump(String text, List<SetupStep> items) {
  final m = _jumpPrefix.firstMatch(CommandMatcher.normalize(text));
  if (m == null) return null;
  final result = const CommandMatcher().match(m.group(2)!, [
    for (final s in items)
      for (final k in stepKeywords[s] ?? const <String>[])
        CommandPhrase(k, ValueTarget(s)),
  ]);
  return switch (result) {
    Matched(target: ValueTarget(:final value)) => value as SetupStep,
    _ => null,
  };
}
