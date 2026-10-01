import 'package:flutter/material.dart';

/// The user-selectable color themes (Accessibility Settings → Color theme).
enum PaletteId {
  /// Cream background with navy accents — the design from the screenshots.
  defaultCream,

  /// White on black.
  highContrast,

  /// Yellow on black.
  yellowOnBlack,

  /// Black on white.
  blackOnWhite,
}

/// Every color the UI uses, as a [ThemeExtension] so widgets can read it with
/// `context.palette`.
///
/// Widgets must take colors from here (or from the derived [ThemeData]), never
/// hard-code them, so that palette changes in Settings apply everywhere.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Creates a palette. Prefer the presets via [AppPalette.of].
  const AppPalette({
    required this.id,
    required this.brightness,
    required this.background,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryOutline,
    required this.heading,
    required this.body,
    required this.muted,
    required this.border,
    required this.waveform,
    required this.highlight,
    required this.onHighlight,
    required this.focusRing,
    required this.shadow,
  });

  /// Which preset this is.
  final PaletteId id;

  /// Overall light/dark brightness, used for system chrome and Material defaults.
  final Brightness brightness;

  /// Screen background.
  final Color background;

  /// Primary pill button fill, scrollbar thumb, general accent.
  final Color primary;

  /// Text/icons on [primary].
  final Color onPrimary;

  /// Secondary pill button fill.
  final Color secondary;

  /// Text/icons on [secondary].
  final Color onSecondary;

  /// Outline drawn around secondary buttons (transparent when the fill alone
  /// separates it from the background).
  final Color secondaryOutline;

  /// Headings (e.g. "Welcome to").
  final Color heading;

  /// Body text, subtitles, document text.
  final Color body;

  /// Faint text such as the Gesture Pad hint and the "Narinig" line.
  final Color muted;

  /// Bordered panel strokes.
  final Color border;

  /// Speaking Zone waveform bars.
  final Color waveform;

  /// Background of the sentence currently being read.
  final Color highlight;

  /// Text on [highlight].
  final Color onHighlight;

  /// Ring drawn around the item that has accessibility focus.
  final Color focusRing;

  /// Drop shadow under pill buttons.
  final Color shadow;

  /// Cream/navy design from the screenshots.
  static const AppPalette defaultCream = AppPalette(
    id: PaletteId.defaultCream,
    brightness: Brightness.light,
    background: Color(0xFFF8F4EC),
    primary: Color(0xFF0B2A45),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFEDE3D6),
    onSecondary: Color(0xFF0B2A45),
    secondaryOutline: Color(0x00000000),
    heading: Color(0xFF111111),
    body: Color(0xFF0B2A45),
    muted: Color(0x800B2A45),
    border: Color(0xFF0B2A45),
    waveform: Color(0xFF111111),
    highlight: Color(0xFFD6E2EF),
    onHighlight: Color(0xFF0B2A45),
    focusRing: Color(0xFF111111),
    shadow: Color(0x40000000),
  );

  /// White on black.
  static const AppPalette highContrast = AppPalette(
    id: PaletteId.highContrast,
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    secondary: Color(0xFF1A1A1A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryOutline: Color(0xFFFFFFFF),
    heading: Color(0xFFFFFFFF),
    body: Color(0xFFFFFFFF),
    muted: Color(0xB3FFFFFF),
    border: Color(0xFFFFFFFF),
    waveform: Color(0xFFFFFFFF),
    highlight: Color(0xFFFFFFFF),
    onHighlight: Color(0xFF000000),
    focusRing: Color(0xFFFFFFFF),
    shadow: Color(0x00000000),
  );

  /// Yellow on black.
  static const AppPalette yellowOnBlack = AppPalette(
    id: PaletteId.yellowOnBlack,
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    primary: Color(0xFFFFE600),
    onPrimary: Color(0xFF000000),
    secondary: Color(0xFF1A1A1A),
    onSecondary: Color(0xFFFFE600),
    secondaryOutline: Color(0xFFFFE600),
    heading: Color(0xFFFFE600),
    body: Color(0xFFFFE600),
    muted: Color(0xB3FFE600),
    border: Color(0xFFFFE600),
    waveform: Color(0xFFFFE600),
    highlight: Color(0xFFFFE600),
    onHighlight: Color(0xFF000000),
    focusRing: Color(0xFFFFE600),
    shadow: Color(0x00000000),
  );

  /// Black on white.
  static const AppPalette blackOnWhite = AppPalette(
    id: PaletteId.blackOnWhite,
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFEBEBEB),
    onSecondary: Color(0xFF000000),
    secondaryOutline: Color(0xFF000000),
    heading: Color(0xFF000000),
    body: Color(0xFF000000),
    muted: Color(0x99000000),
    border: Color(0xFF000000),
    waveform: Color(0xFF000000),
    highlight: Color(0xFFFFE600),
    onHighlight: Color(0xFF000000),
    focusRing: Color(0xFF000000),
    shadow: Color(0x33000000),
  );

  /// All presets, in the order they are offered in Settings.
  static const List<AppPalette> presets = [
    defaultCream,
    highContrast,
    yellowOnBlack,
    blackOnWhite,
  ];

  /// Looks up the preset for [id].
  static AppPalette of(PaletteId id) => presets.firstWhere((p) => p.id == id);

  @override
  AppPalette copyWith({
    Color? background,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryOutline,
    Color? heading,
    Color? body,
    Color? muted,
    Color? border,
    Color? waveform,
    Color? highlight,
    Color? onHighlight,
    Color? focusRing,
    Color? shadow,
  }) {
    return AppPalette(
      id: id,
      brightness: brightness,
      background: background ?? this.background,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryOutline: secondaryOutline ?? this.secondaryOutline,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      waveform: waveform ?? this.waveform,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
      focusRing: focusRing ?? this.focusRing,
      shadow: shadow ?? this.shadow,
    );
  }

  /// Palettes switch instantly; interpolating between e.g. cream and black
  /// would pass through unreadable mid-tones.
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Shorthand for reading the active [AppPalette].
extension AppPaletteContext on BuildContext {
  /// The active palette. Falls back to [AppPalette.defaultCream] outside an
  /// app theme (e.g. in isolated widget tests).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.defaultCream;
}
