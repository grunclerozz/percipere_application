import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/app/theme/app_palette.dart';
import 'package:percipere_app/app/theme/app_theme.dart';
import 'package:percipere_app/app/theme/theme_settings.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('every palette meets WCAG AA contrast', () {
    for (final p in AppPalette.presets) {
      test(p.id.name, () {
        expect(contrast(p.body, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.heading, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onSecondary, p.secondary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onHighlight, p.highlight), greaterThanOrEqualTo(4.5));
        // Non-text UI components (panel borders): 3:1.
        expect(contrast(p.border, p.background), greaterThanOrEqualTo(3));
      });
    }
  });

  test('default palette matches the design tokens', () {
    const p = AppPalette.defaultCream;
    expect(p.background, const Color(0xFFF8F4EC));
    expect(p.primary, const Color(0xFF0B2A45));
    expect(p.secondary, const Color(0xFFEDE3D6));
    expect(p.heading, const Color(0xFF111111));
  });

  test('theme reflects settings (palette, font)', () {
    final theme = AppTheme.build(
      const ThemeSettings(
        palette: PaletteId.yellowOnBlack,
        font: AppFont.atkinsonHyperlegible,
      ),
    );
    expect(theme.extension<AppPalette>()!.id, PaletteId.yellowOnBlack);
    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyLarge!.fontFamily, 'AtkinsonHyperlegible');
  });

  test('text scale is clamped', () {
    expect(
      const ThemeSettings().copyWith(textScale: 9).textScale,
      ThemeSettings.maxTextScale,
    );
    expect(
      const ThemeSettings().copyWith(textScale: 0.1).textScale,
      ThemeSettings.minTextScale,
    );
  });
}
