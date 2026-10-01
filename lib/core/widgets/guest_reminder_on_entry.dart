import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/action_registry.dart';
import '../accessibility/announcer.dart';
import '../auth/guest_reminders.dart';
import '../auth/session.dart';
import '../db/daos/preferences_dao.dart';
import '../tts/speech_language.dart';

/// When a guest is reminded to register.
enum GuestReminderMoment {
  /// After the first save to history (said on the next Capture visit).
  history,

  /// The first time Settings opens.
  settings,
}

/// Says the guest registration reminder once, after [screenId]'s own
/// announcement, at [moment]. Never used on Reader or setup screens.
class GuestReminderOnEntry extends ConsumerStatefulWidget {
  /// Wraps [child] (the screen).
  const GuestReminderOnEntry({
    super.key,
    required this.screenId,
    required this.moment,
    required this.child,
  });

  /// The screen that triggers it.
  final String screenId;

  /// Which reminder.
  final GuestReminderMoment moment;

  /// The screen.
  final Widget child;

  @override
  ConsumerState<GuestReminderOnEntry> createState() =>
      _GuestReminderOnEntryState();
}

class _GuestReminderOnEntryState extends ConsumerState<GuestReminderOnEntry> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(activeScreenProvider, (previous, next) {
      if (next?.id == widget.screenId && previous?.id != widget.screenId) {
        unawaited(_remind());
      }
    });
  }

  Future<bool> _due() async {
    final account = ref.read(currentAccountProvider);
    if (account == null || !account.isGuest) return false;
    final prefs = ref.read(userPrefsProvider);
    switch (widget.moment) {
      case GuestReminderMoment.history:
        return GuestReminders(prefs).takeHistoryReminder(account);
      case GuestReminderMoment.settings:
        final said = await prefs.get(
          PrefKeys.guestReminderSettings,
          userId: account.id,
        );
        if (said == true) return false;
        await prefs.set(
          PrefKeys.guestReminderSettings,
          true,
          userId: account.id,
        );
        return true;
    }
  }

  Future<void> _remind() async {
    if (!await _due() || !mounted) return;
    // After the screen's own announcement, queued (never cutting it off).
    final announcer = ref.read(announcerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await announcer.idle();
    if (!mounted || ref.read(activeScreenProvider)?.id != widget.screenId) {
      return;
    }
    await announcer.say(
      ref.read(speechLanguageProvider).strings.guestReminder,
      interrupt: false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
