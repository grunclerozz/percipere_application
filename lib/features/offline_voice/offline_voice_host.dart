import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/offline_voice/offline_voice_setup.dart';

/// Keeps the offline voices coming without the first-launch screen: after
/// startup it finishes a download that was set aside or interrupted, or
/// gets a newer version from the server (the controller itself resumes when
/// the internet comes back), and when a
/// download finishes away from that screen it says "Handa na. Gumagana na
/// ang boses kahit walang internet." once the app isn't talking.
class OfflineVoiceHost extends ConsumerStatefulWidget {
  /// Wraps [child].
  const OfflineVoiceHost({super.key, required this.child});

  /// The app.
  final Widget child;

  @override
  ConsumerState<OfflineVoiceHost> createState() => _OfflineVoiceHostState();
}

class _OfflineVoiceHostState extends ConsumerState<OfflineVoiceHost> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(offlineVoiceProvider, (previous, next) {
      final finished =
          next.status == OfflineVoiceStatus.ready &&
          previous != null &&
          previous.status != OfflineVoiceStatus.ready &&
          previous.status != OfflineVoiceStatus.idle;
      if (!finished) return;
      if (ref.read(activeScreenProvider)?.id == Ids.offlineVoice) return;
      unawaited(_announceReady());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(offlineVoiceProvider);
      final pending = ref.read(offlineVoiceSetupPendingProvider);
      // Finishes a download that was set aside, or fetches a newer version
      // listed on the server (offline, an installed set just stays ready).
      if (!pending && state.status != OfflineVoiceStatus.unavailable) {
        unawaited(ref.read(offlineVoiceProvider.notifier).ensure());
      }
    });
  }

  Future<void> _announceReady() async {
    final announcer = ref.read(announcerProvider.notifier);
    await announcer.idle();
    if (!mounted) return;
    final bus = ref.read(commandBusProvider);
    await announcer.say(bus.strings.offlineVoiceReady, interrupt: false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
