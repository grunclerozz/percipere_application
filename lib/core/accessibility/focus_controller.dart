import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action_registry.dart';

/// Id of the focused action on the active screen, or null.
///
/// Resets whenever the active screen changes. Widgets watch this to draw the
/// focus ring; the command bus moves it.
class FocusController extends Notifier<String?> {
  @override
  String? build() {
    // Rebuilds (→ null) when another screen becomes active (not when the
    // same screen re-registers with updated actions).
    ref.watch(activeScreenProvider.select((s) => s?.id));
    return null;
  }

  /// Moves focus by [delta] through the active screen's focusable actions,
  /// wrapping at the ends. Returns the new index, or null if the screen has
  /// nothing focusable.
  int? move(int delta) {
    final items = ref.read(activeScreenProvider)?.focusables ?? const [];
    if (items.isEmpty) return null;
    final current = items.indexWhere((a) => a.id == state);
    final int next;
    if (current == -1) {
      next = delta >= 0 ? 0 : items.length - 1;
    } else {
      next = (current + delta) % items.length;
    }
    state = items[next].id;
    return next;
  }

  /// Focuses [actionId] directly (e.g. after a visual tap).
  void focus(String? actionId) => state = actionId;
}

/// Focused action id.
final focusControllerProvider = NotifierProvider<FocusController, String?>(
  FocusController.new,
);
