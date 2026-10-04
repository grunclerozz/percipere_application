import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone is online right now. A function so tests can script it.
final isOnlineProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  },
);
