import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// How the user prefers to drive the app.
enum NavMode {
  /// Voice commands first (gestures still work as backup).
  voice,

  /// Gestures only; long-press still opens voice listening.
  gestures;

  /// Parses a stored value, or null.
  static NavMode? tryParse(Object? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// The chosen navigation mode (null until chosen on Welcome); a view of
/// [settingsProvider], saved with the other settings.
class NavModeNotifier extends Notifier<NavMode?> {
  @override
  NavMode? build() => ref.watch(settingsProvider.select((s) => s.navMode));

  /// Chooses and saves [mode].
  Future<void> set(NavMode mode) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(navMode: mode));
}

/// Current navigation mode.
final navigationModeProvider = NotifierProvider<NavModeNotifier, NavMode?>(
  NavModeNotifier.new,
);

/// Whether TalkBack (or another screen reader) is active. Kept in sync by
/// `AccessibilityHost`.
class TalkBackNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Updates the flag.
  void set(bool active) {
    if (state != active) state = active;
  }
}

/// TalkBack active flag.
final talkBackProvider = NotifierProvider<TalkBackNotifier, bool>(
  TalkBackNotifier.new,
);
