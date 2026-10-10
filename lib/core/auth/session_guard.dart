import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/haptics.dart';
import 'account.dart';
import 'account_service.dart';
import 'session.dart';

/// Asks the web app whether the logged-in account may still use it: at
/// start, after each login and whenever the app comes back to the front.
/// An account suspended in the dashboard is logged out with a spoken
/// explanation. Offline, or with accounts on the phone only, nothing happens.
class SessionGuard extends ConsumerStatefulWidget {
  /// Guards [child]'s app.
  const SessionGuard({super.key, required this.child});

  /// The app.
  final Widget child;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<Account?>(currentAccountProvider, (previous, next) {
      if (next != null && next.id != previous?.id) unawaited(_check());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final account = ref.read(currentAccountProvider);
    if (_checking || account == null || account.isGuest) return;
    _checking = true;
    try {
      final result = await ref.read(accountServiceProvider).check(account);
      if (!mounted || result != SessionCheck.suspended) return;
      // Only if the same account is still logged in.
      if (ref.read(currentAccountProvider)?.id != account.id) return;
      final bus = ref.read(commandBusProvider);
      await ref.read(currentAccountProvider.notifier).logout();
      unawaited(ref.read(hapticsProvider).error());
      await bus.say(bus.strings.accountSuspendedSignedOut, protect: true);
      if (mounted) ref.read(routerProvider).go(AppRoutes.welcome);
    } on Object catch (e) {
      debugPrint('Session check failed: $e');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
