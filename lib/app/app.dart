import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/accessibility_host.dart';
import '../core/auth/session_guard.dart';
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
      builder: (context, child) => UiTextScale(
        child: SessionGuard(
          child: AccessibilityHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Keeps the screen layout fixed: buttons, fields and boxes keep their
/// design size, so nothing overlaps or needs scrolling.
///
/// The in-app text size only enlarges the reading text inside its box (the
/// Document Box and the setup preview; see `AppTheme.documentText`). Android's
/// own font size still applies to the rest, but at most [maxUiScale].
class UiTextScale extends StatelessWidget {
  /// Caps the ambient text scaler for [child].
  const UiTextScale({super.key, required this.child});

  /// Largest system font scale applied to UI text.
  static const double maxUiScale = 1.3;

  /// Subtree to scale.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: maxUiScale),
      ),
      child: child,
    );
  }
}
