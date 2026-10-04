import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/tts/speech_language.dart';

/// On each user's first visit to [screenId] (Capture) after Maglarawan was
/// added, reads the full explanation once, queued after the screen's own
/// announcement. Afterwards only the short announcement is heard.
class DescribeIntroOnEntry extends ConsumerStatefulWidget {
  /// Wraps [child] (the screen).
  const DescribeIntroOnEntry({
    super.key,
    required this.screenId,
    required this.child,
  });

  /// The screen that triggers it.
  final String screenId;

  /// The screen.
  final Widget child;

  @override
  ConsumerState<DescribeIntroOnEntry> createState() =>
      _DescribeIntroOnEntryState();
}

class _DescribeIntroOnEntryState extends ConsumerState<DescribeIntroOnEntry> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == widget.screenId && previous?.id != widget.screenId) {
        unawaited(_explain().catchError(_failed));
      }
    });
  }

  Timer? _delay;

  /// A pause that is dropped with the screen (no timer outlives it).
  Future<void> _wait(Duration duration) {
    final done = Completer<void>();
    _delay = Timer(duration, done.complete);
    return done.future;
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  /// The explanation is a nicety: a failing preference or speech call must
  /// never surface as an error on the Capture screen.
  void _failed(Object error) => debugPrint('Maglarawan intro failed: $error');

  Future<void> _explain() async {
    final prefs = ref.read(userPrefsProvider);
    // Per user (a guest has their own id); the device before anyone logs in.
    final userId =
        ref.read(currentAccountProvider)?.id ?? PreferencesDao.deviceScope;
    final seen = await prefs.get(PrefKeys.describeIntroSeen, userId: userId);
    if (!mounted || seen == true) {
      return;
    }
    await prefs.set(PrefKeys.describeIntroSeen, true, userId: userId);
    if (!mounted) return;
    // After the screen's own announcement, queued (never cutting it off).
    final announcer = ref.read(announcerProvider.notifier);
    await _wait(const Duration(milliseconds: 300));
    if (!mounted) return;
    await announcer.idle();
    if (!mounted || ref.read(activeScreenProvider)?.id != widget.screenId) {
      return;
    }
    await announcer.say(
      ref.read(speechLanguageProvider).strings.describeExplanation,
      interrupt: false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
