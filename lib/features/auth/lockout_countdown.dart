import 'dart:async';

import '../../l10n/app_localizations.dart';

/// The spoken countdown while a login is locked: the time left every 10
/// seconds and the last 3 seconds, then "Maaari ka nang sumubok muli."
class LockoutCountdown {
  /// Creates a countdown that redraws via [onTick] and speaks via [speak].
  LockoutCountdown({
    required this.onTick,
    required this.speak,
    required this.strings,
  });

  /// Called every second (redraw).
  final void Function() onTick;

  /// Speaks a line.
  final Future<void> Function(String text) speak;

  /// Current prompt strings.
  final AppLocalizations Function() strings;

  Timer? _timer;
  int _seconds = 0;

  /// Whole seconds left; 0 when not locked.
  int get seconds => _seconds;

  /// Starts (or restarts) counting down [wait]. With [announce], the
  /// starting time is spoken too (callers usually say it themselves).
  void start(Duration wait, {bool announce = true}) {
    _timer?.cancel();
    _seconds = (wait.inMilliseconds / 1000).ceil();
    if (announce) unawaited(speak(strings().lockoutWait(_seconds)));
    onTick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    _seconds--;
    onTick();
    if (_seconds <= 0) {
      _seconds = 0;
      _timer?.cancel();
      _timer = null;
      unawaited(speak(strings().lockoutOver));
    } else if (_seconds % 10 == 0 || _seconds <= 3) {
      unawaited(speak('$_seconds'));
    }
  }

  /// Stops counting.
  void dispose() => _timer?.cancel();
}
