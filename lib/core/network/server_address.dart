import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';

/// Why a typed server address was not accepted.
enum ServerAddressProblem {
  /// Nothing typed.
  empty,

  /// Not an `http://` or `https://` address with a host.
  notAnAddress,

  /// `http://` to a host this build does not allow plain HTTP for
  /// (`Env.allowsCleartext`): use `https://` or rebuild with
  /// `API_CLEARTEXT_HOSTS`.
  cleartextNotAllowed,
}

/// The result of checking a typed address.
typedef ServerAddressCheck = ({String? address, ServerAddressProblem? problem});

/// Rules for the web app's address.
abstract final class ServerAddressRules {
  /// Cleans [text] (spaces, trailing slashes, `/api/v1` on the end) and
  /// checks it.
  static ServerAddressCheck check(String text) {
    var t = text.trim();
    if (t.isEmpty) return (address: null, problem: ServerAddressProblem.empty);
    t = t.replaceAll(RegExp(r'/+$'), '');
    t = t.replaceAll(RegExp(r'/api/v1$', caseSensitive: false), '');
    final uri = Uri.tryParse(t);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return (address: null, problem: ServerAddressProblem.notAnAddress);
    }
    if (uri.scheme == 'http' && !Env.allowsCleartext(uri.host)) {
      return (address: null, problem: ServerAddressProblem.cleartextNotAllowed);
    }
    return (address: t, problem: null);
  }
}

/// The address saved on this device (developer settings), or null.
Future<String?> readSavedServerAddress(PreferencesDao prefs) async {
  final value = await prefs.get(PrefKeys.serverAddress);
  return value is String && value.isNotEmpty ? value : null;
}

/// The address the app starts with: the one saved in the developer settings,
/// else the one it was built with. Overridden at startup.
final initialServerAddressProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// The web app's address (the dashboard folder, without `/api/v1`). The
/// clients for books, accounts and reports follow it, so changing it needs
/// no new build.
class ServerAddressNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(initialServerAddressProvider);

  /// Whether this is the address the app was built with.
  bool get isBuildDefault => state == Env.apiBaseUrl;

  /// Uses (and remembers) [address], already checked by
  /// [ServerAddressRules.check].
  Future<void> save(String address) async {
    state = address;
    final prefs = PreferencesDao(ref.read(appDatabaseProvider).db);
    await prefs.set(PrefKeys.serverAddress, address);
  }

  /// Goes back to the address the app was built with.
  Future<void> reset() async {
    state = Env.apiBaseUrl;
    final prefs = PreferencesDao(ref.read(appDatabaseProvider).db);
    await prefs.remove(PrefKeys.serverAddress);
  }
}

/// The current web app address.
final serverAddressProvider = NotifierProvider<ServerAddressNotifier, String>(
  ServerAddressNotifier.new,
);

/// Whether a web app is configured at all.
bool hasServer(String address) => address != Env.noServer;
