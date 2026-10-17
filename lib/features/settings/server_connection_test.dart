import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/command_bus.dart';
import '../../core/network/server_address.dart';
import '../../core/network/server_health.dart';
import '../../l10n/app_localizations.dart';

/// The spoken result of a health check.
String serverHealthMessage(AppLocalizations l, ServerHealth h) =>
    switch (h.status) {
      ServerHealthStatus.ok => l.serverTestOk,
      ServerHealthStatus.notConfigured => l.serverTestNotConfigured,
      ServerHealthStatus.noNetwork => l.serverTestNoNetwork,
      ServerHealthStatus.wrongAddress => l.serverTestWrongAddress,
      ServerHealthStatus.unreachable => l.serverTestUnreachable,
      ServerHealthStatus.serverDown => l.serverTestServerDown,
      ServerHealthStatus.httpBlocked => l.serverTestHttpBlocked,
      ServerHealthStatus.timeout => l.serverTestTimeout,
    };

/// Hidden developer setting: checks the saved server address
/// (`GET /api/v1/health`) and speaks the result or the exact reason.
Future<void> testServerConnection(WidgetRef ref, CommandBus bus) async {
  await bus.say(bus.strings.serverTestRunning);
  final health = await ref
      .read(serverHealthCheckerProvider)
      .check(ref.read(serverAddressProvider));
  await bus.say(serverHealthMessage(bus.strings, health));
}
