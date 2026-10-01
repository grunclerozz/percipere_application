import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/accessibility_host.dart';
import '../l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_settings.dart';

/// Root widget: wires theme, locale, text scaling and routing.
class PercipereApp extends ConsumerWidget {
  /// Creates the root widget.
  const PercipereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final locale = ref.watch(appLocaleProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(settings),
      locale: locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => UserTextScale(
        factor: settings.textScale,
        child: AccessibilityHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Multiplies the Android system font scale by the user's in-app text size
/// setting, so both are respected.
class UserTextScale extends StatelessWidget {
  /// Applies [factor] on top of the ambient text scaler for [child].
  const UserTextScale({super.key, required this.factor, required this.child});

  /// In-app text size multiplier.
  final double factor;

  /// Subtree to scale.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _CombinedTextScaler(media.textScaler, factor),
      ),
      child: child,
    );
  }
}

class _CombinedTextScaler extends TextScaler {
  const _CombinedTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  // Required by the TextScaler interface; approximates the combined factor at
  // a typical body size.
  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _CombinedTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}
