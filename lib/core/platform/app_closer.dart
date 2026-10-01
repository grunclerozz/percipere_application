import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Closes the app (back on the first screen, after confirmation).
/// Overridden in tests.
final appCloserProvider = Provider<void Function()>(
  (ref) =>
      () => SystemNavigator.pop(),
);
