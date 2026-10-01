import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_controller.dart';

/// Locales the app ships, Filipino first (it is the default).
abstract final class AppLocales {
  /// Filipino — the default UI and prompt language.
  static const Locale filipino = Locale('fil');

  /// English.
  static const Locale english = Locale('en');

  /// All supported locales, default first.
  static const List<Locale> supported = [filipino, english];
}

/// The app-wide UI and prompt locale; a view of [settingsProvider].
/// Defaults to Filipino regardless of the device language.
final appLocaleProvider = Provider<Locale>(
  (ref) => ref.watch(settingsProvider.select((s) => s.locale)),
);
