import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/discovery_config.dart';
import '../../config/env.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/announcer.dart';
import '../tts/speech_language.dart';
import 'api_dio.dart';
import 'server_address.dart';
import 'server_discovery.dart';

/// Keeps the app pointed at a dashboard that answers.
///
/// [ensure] tries the saved address, then `API_BASE_URL`, then (on Wi-Fi)
/// scans the subnet ([ServerDiscovery]); the first match is saved and used
/// from then on. It runs at startup and whenever a request to the server
/// could not reach it ([serverUnreachableHook]). It never blocks anything:
/// callers do not wait for it, and offline features do not use it. It says
/// "Hinahanap ang server…" when a scan starts and "Hindi maabot ang server"
/// when nothing is found.
class ServerConnection {
  /// Creates the connection keeper. [discovery] and [clock] are for tests.
  ServerConnection(
    this._ref, {
    ServerDiscovery? discovery,
    DateTime Function()? clock,
  }) : _discovery =
           discovery ??
           ServerDiscovery(probe: httpProbe(), network: const DeviceNetwork()),
       _clock = clock ?? DateTime.now;

  final Ref _ref;
  final ServerDiscovery _discovery;
  final DateTime Function() _clock;

  bool _busy = false;
  DateTime? _failedAt;

  /// Whether a search is running.
  bool get busy => _busy;

  /// Looks for the server unless a search is running. [failedCall]: a
  /// request just failed (so "Hindi maabot ang server" is said even when no
  /// scan could run, e.g. off Wi-Fi); after a search found nothing, the next
  /// one waits [DiscoveryConfig.cooldown].
  Future<void> ensure({bool failedCall = false}) async {
    if (_busy) return;
    final failed = _failedAt;
    if (failed != null &&
        _clock().difference(failed) < DiscoveryConfig.cooldown) {
      return;
    }
    _busy = true;
    try {
      final address = _ref.read(serverAddressProvider);
      final result = await _discovery.locate(
        saved: address,
        built: Env.apiBaseUrl,
        onScanStart: () => unawaited(_say((l) => l.serverSearching)),
      );
      final found = result.address;
      if (found != null) {
        _failedAt = null;
        await _ref.read(serverAddressProvider.notifier).save(found);
        debugPrint('[DISCOVERY] using $found (scanned: ${result.scanned})');
      } else {
        _failedAt = _clock();
        debugPrint('[DISCOVERY] no server found (scanned: ${result.scanned})');
        if (result.scanned || failedCall) {
          unawaited(_say((l) => l.serverNotFound));
        }
      }
    } on Object catch (e) {
      debugPrint('[DISCOVERY] failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _say(String Function(AppLocalizations l) text) async {
    try {
      final strings = _ref.read(speechLanguageProvider).strings;
      await _ref
          .read(announcerProvider.notifier)
          .say(text(strings), interrupt: false);
    } on Object catch (e) {
      debugPrint('[DISCOVERY] could not speak: $e');
    }
  }
}

/// Whether the app looks for the dashboard when it starts (tests turn it
/// off so no real request is made).
final serverSearchAtStartupProvider = Provider<bool>((ref) => true);

/// The server connection keeper. Reading it starts listening for requests
/// that can't reach the server.
final serverConnectionProvider = Provider<ServerConnection>((ref) {
  final connection = ServerConnection(ref);
  void onUnreachable(Uri failed) {
    final host = Uri.tryParse(ref.read(serverAddressProvider))?.host;
    // Only the dashboard counts (not the model downloads from elsewhere).
    if (host != null && failed.host == host) {
      unawaited(connection.ensure(failedCall: true));
    }
  }

  serverUnreachableHook = onUnreachable;
  ref.onDispose(() {
    if (serverUnreachableHook == onUnreachable) serverUnreachableHook = null;
  });
  return connection;
});
