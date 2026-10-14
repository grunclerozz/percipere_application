import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone is online right now. A function so tests can script it.
/// A local check of the phone's network state (no request is sent): fast
/// enough to ask before each listening session, but never awaited there.
final isOnlineProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  },
);

/// Fires when the phone's connection comes back (tests override it).
final connectionRestoredProvider = Provider<Stream<void>>((ref) {
  try {
    return Connectivity().onConnectivityChanged
        .where((results) => results.any((r) => r != ConnectivityResult.none))
        .map((_) {});
  } on Object catch (e) {
    debugPrint('Connectivity unavailable: $e');
    return const Stream<void>.empty();
  }
});
