import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'tts_service.dart';

/// The language used for spoken prompts (and their subtitles).
///
/// Follows the UI locale, except that Filipino falls back to English when no
/// Filipino voice is installed — Filipino text must never be read by an
/// English voice.
@immutable
class SpeechLanguage {
  /// Creates a speech language.
  const SpeechLanguage({required this.locale, required this.ttsTag});

  /// Locale of the prompt strings.
  final Locale locale;

  /// TTS voice tag to speak them with.
  final String ttsTag;

  /// Prompt strings in [locale].
  AppLocalizations get strings => lookupAppLocalizations(locale);

  /// Whether prompts fell back from Filipino to English.
  bool fellBackFrom(Locale uiLocale) => uiLocale != locale;
}

/// Prompt language derived from the UI locale and voice availability.
final speechLanguageProvider = Provider<SpeechLanguage>((ref) {
  final ui = ref.watch(appLocaleProvider);
  final voices = ref.watch(voiceStatusProvider);
  if (ui.languageCode == 'fil' && voices.filipinoReady) {
    return SpeechLanguage(locale: ui, ttsTag: voices.filipinoTag);
  }
  return SpeechLanguage(locale: AppLocales.english, ttsTag: voices.englishTag);
});
