import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_registration.dart';

/// Stack of registered screens; the last one is active.
///
/// Screens are removed by identity (not popped), because with `go()` the new
/// screen registers before the old one is disposed.
class ActionRegistry extends Notifier<List<ScreenRegistration>> {
  @override
  List<ScreenRegistration> build() => const [];

  /// The active screen, if any.
  ScreenRegistration? get top => state.isEmpty ? null : state.last;

  /// Registers [registration] as the active screen.
  void register(ScreenRegistration registration) {
    if (!ref.mounted) return;
    state = [...state.where((r) => !identical(r, registration)), registration];
  }

  /// Swaps [old] for [next] in place (same stack position), e.g. when a
  /// screen's list of actions changes. Registers [next] if [old] is gone.
  void replace(ScreenRegistration old, ScreenRegistration next) {
    if (!ref.mounted) return;
    final i = state.indexWhere((r) => identical(r, old));
    if (i == -1) return register(next);
    state = [...state]..[i] = next;
  }

  /// Removes [registration] wherever it is in the stack.
  void unregister(ScreenRegistration registration) {
    // The whole scope may already be gone (app teardown).
    if (!ref.mounted) return;
    if (!state.any((r) => identical(r, registration))) return;
    state = [...state.where((r) => !identical(r, registration))];
  }
}

/// Registered screens.
final actionRegistryProvider =
    NotifierProvider<ActionRegistry, List<ScreenRegistration>>(
      ActionRegistry.new,
    );

/// The active screen registration.
final activeScreenProvider = Provider<ScreenRegistration?>((ref) {
  final stack = ref.watch(actionRegistryProvider);
  return stack.isEmpty ? null : stack.last;
});
