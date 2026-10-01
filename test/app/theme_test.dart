import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/app/theme/app_theme.dart';
import 'package:percipere_app/app/theme/theme_settings.dart';
import 'package:percipere_app/config/palette.dart';
import 'package:percipere_app/core/settings/app_settings.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('every theme meets WCAG AA contrast', () {
    for (final p in AppPalette.presets) {
      test(p.id.name, () {
        expect(contrast(p.body, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.heading, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onSecondary, p.secondary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onSecondary, p.tertiary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onHighlight, p.highlight), greaterThanOrEqualTo(4.5));
        // Non-text UI components (panel borders): 3:1.
        expect(contrast(p.border, p.background), greaterThanOrEqualTo(3));
      });
    }
  });

  group('every text color has at least 7:1 contrast on its theme', () {
    for (final theme in ThemeId.values) {
      test(theme.name, () {
        final p = AppPalette.of(theme);
        for (final o in TextColors.forTheme(theme)) {
          expect(
            contrast(o.color, p.background),
            greaterThanOrEqualTo(7),
            reason: '${o.english} on ${theme.name}',
          );
          // Also on the dark secondary fill (#121212).
          if (p.brightness == Brightness.dark) {
            expect(contrast(o.color, p.secondary), greaterThanOrEqualTo(7));
          }
        }
      });
    }
  });

  test('color lists match the spec order; first is the default', () {
    expect(TextColors.forTheme(ThemeId.creamNavy).map((o) => o.id), [
      'navy',
      'black',
      'brown',
      'purple',
      'blue',
    ]);
    expect(
      TextColors.defaultFor(ThemeId.darkYellow).color,
      const Color(0xFFFFEB3B),
    );
    expect(
      TextColors.defaultFor(ThemeId.darkWhite).color,
      const Color(0xFFFFFFFF),
    );
    expect(TextColors.forTheme(ThemeId.darkWhite), hasLength(6));
  });

  test('Cream & Navy matches the design tokens', () {
    const p = AppPalette.creamNavy;
    expect(p.background, const Color(0xFFF8F4EC));
    expect(p.primary, const Color(0xFF0B2A45));
    expect(p.secondary, const Color(0xFFEDE3D6));
    expect(p.heading, const Color(0xFF111111));
  });

  test('both dark themes are on black', () {
    expect(AppPalette.darkYellow.background, const Color(0xFF000000));
    expect(AppPalette.darkWhite.background, const Color(0xFF000000));
  });

  test('theme reflects settings (theme, font, text color)', () {
    final theme = AppTheme.build(
      const ThemeSettings(
        theme: ThemeId.darkYellow,
        font: AppFont.atkinsonHyperlegible,
        textColor: 'lightCyan',
      ),
    );
    final p = theme.extension<AppPalette>()!;
    expect(p.id, ThemeId.darkYellow);
    expect(p.body, const Color(0xFF80DEEA));
    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyLarge!.fontFamily, 'AtkinsonHyperlegible');
  });

  test('a text color the theme does not offer falls back to its default', () {
    final p = AppPalette.withTextColor(ThemeId.creamNavy, 'yellow');
    expect(p.body, AppPalette.creamNavy.body);
  });

  test('text size: 18–48 in steps of 2', () {
    expect(TextSize.normalize(9), 18);
    expect(TextSize.normalize(99), 48);
    expect(TextSize.normalize(23), 24);
    expect(TextSize.fromLegacyScale(1.5), 28);
  });

  test('the text size sets the reading text only; UI text keeps its size', () {
    final small = AppTheme.build(const ThemeSettings());
    final big = AppTheme.build(const ThemeSettings(textSize: 48));
    expect(big.extension<AppTextMetrics>()!.textSize, 48);
    expect(
      big.textTheme.labelLarge!.fontSize,
      small.textTheme.labelLarge!.fontSize,
    );
    expect(
      big.textTheme.bodyLarge!.fontSize,
      small.textTheme.bodyLarge!.fontSize,
    );
  });

  test('pre-6B settings convert (palette names, text scale)', () {
    final s = AppSettings.fromPrefs({
      'ui.palette': 'yellowOnBlack',
      'ui.textScale': 2.0,
    });
    expect(s.themeId, ThemeId.darkYellow);
    expect(s.textSize, 36);
    expect(
      AppSettings.fromPrefs({'ui.palette': 'blackOnWhite'}).themeId,
      ThemeId.creamNavy,
    );
    expect(
      AppSettings.fromPrefs({'ui.palette': 'highContrast'}).themeId,
      ThemeId.darkWhite,
    );
  });
}
