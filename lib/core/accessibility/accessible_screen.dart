import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action_registry.dart';
import 'screen_registration.dart';

/// Registers a screen's [ScreenRegistration] with the [ActionRegistry] while
/// the screen is mounted. Becoming the active screen triggers its entry
/// announcement (see `AccessibilityHost`).
class AccessibleScreen extends ConsumerStatefulWidget {
  /// Wraps [child] and registers the result of [registration].
  const AccessibleScreen({
    super.key,
    required this.registration,
    required this.child,
    this.dependencies = const [],
  });

  /// Builds the registration. Handlers should use the given [WidgetRef]
  /// (e.g. `routerProvider`) rather than a BuildContext.
  final ScreenRegistration Function(WidgetRef ref) registration;

  /// When these change (e.g. the documents in a list), the registration is
  /// rebuilt and swapped in place — without re-announcing the screen.
  final List<Object?> dependencies;

  /// The screen UI.
  final Widget child;

  @override
  ConsumerState<AccessibleScreen> createState() => _AccessibleScreenState();
}

class _AccessibleScreenState extends ConsumerState<AccessibleScreen> {
  late ScreenRegistration _registration = widget.registration(ref);
  late final ActionRegistry _registry = ref.read(
    actionRegistryProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    // Providers can't be modified during build; register right after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registry.register(_registration);
    });
  }

  @override
  void didUpdateWidget(AccessibleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.dependencies, widget.dependencies)) {
      final old = _registration;
      final next = _registration = widget.registration(ref);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _registry.replace(old, next);
      });
    }
  }

  @override
  void dispose() {
    final registry = _registry;
    final registration = _registration;
    scheduleMicrotask(() => registry.unregister(registration));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
