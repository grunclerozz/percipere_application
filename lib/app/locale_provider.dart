import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_controller.dart';

abstract final class AppLocales {
  static const Locale filipino = Locale('fil');

  static const Locale english = Locale('en');

  static const List<Locale> supported = [filipino, english];
}

final appLocaleProvider = Provider<Locale>(
  (ref) => ref.watch(settingsProvider.select((s) => s.locale)),
);
