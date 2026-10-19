import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';

/// The address the app starts with: the one saved by the last successful
/// search, else the one it was built with (`API_BASE_URL`). Overridden at
/// startup.
final initialServerAddressProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// The saved address, or null (device scope).
Future<String?> readSavedServerAddress(PreferencesDao prefs) async {
  final value = await prefs.get(PrefKeys.serverAddress);
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  final valid =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  return valid ? value.replaceAll(RegExp(r'/+$'), '') : null;
}

/// The web app's address (the dashboard folder, without `/api/v1`). There is
/// no setting screen for it: it starts as the build's `API_BASE_URL` (default
/// the emulator's `http://10.0.2.2/website/percipere_dashboard`), and the
/// server search ([ServerConnection]) replaces it when the dashboard answers
/// somewhere else on the Wi-Fi. Every client (accounts, books, reports,
/// health, describe, voice models) watches it, so they all follow the change.
class ServerAddressNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(initialServerAddressProvider);

  /// Uses (and remembers) [address].
  Future<void> save(String address) async {
    if (address == state) return;
    state = address;
    try {
      final prefs = PreferencesDao(ref.read(appDatabaseProvider).db);
      await prefs.set(PrefKeys.serverAddress, address);
    } on Object catch (e) {
      debugPrint('Saving the server address failed: $e');
    }
  }
}

/// The current web app address.
final serverAddressProvider = NotifierProvider<ServerAddressNotifier, String>(
  ServerAddressNotifier.new,
);

/// Whether a web app is configured at all.
bool hasServer(String address) => address != Env.noServer;
