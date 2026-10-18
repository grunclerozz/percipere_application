import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/voice_config.dart';

/// Where the microphone is in the half-duplex turn.
enum MicPhase {
  /// Nothing going on: listening may start.
  idle,

  /// The app is speaking (a prompt, Percy, the document): never listening.
  speaking,

  /// The app has just stopped speaking: listening waits
  /// [VoiceConfig.speechGuard] for the speaker's echo to die away.
  wait,

  /// A listening session is open.
  listening,

  /// The session ended (a result, a silence, cancelled).
  done,

  /// The session never ended by itself and was closed by force.
  timeout,
}

/// Half-duplex turn-taking: speaking → wait → listening → done / timeout.
///
/// - While the app speaks the microphone is not allowed ([micAllowed]).
/// - When it stops, [VoiceConfig.speechGuard] passes before it is.
/// - Every listening session has a watchdog: still open
///   [VoiceConfig.listenWatchdogSlack] after its own limit, it is ended
///   ([onTimeout]) so no state can stay "listening" (2026-10-18 tablet
///   test: "the listening tone sometimes gets stuck").
/// - [reset] (screen change, app paused) ends everything.
class MicTurn extends ChangeNotifier {
  /// Creates the turn; [onTimeout] closes a session the watchdog ended.
  MicTurn({this.onTimeout});

  /// Called when the watchdog ends a session.
  void Function()? onTimeout;

  MicPhase _phase = MicPhase.idle;
  Timer? _guard;
  Timer? _watchdog;
  final List<Completer<void>> _waiting = [];

  /// The phase now.
  MicPhase get phase => _phase;

  /// Whether the microphone may take audio now (not while speaking, nor
  /// during the wait after it).
  bool get micAllowed =>
      _phase != MicPhase.speaking && _phase != MicPhase.wait;

  void _set(MicPhase phase) {
    if (phase == _phase) return;
    _phase = phase;
    if (micAllowed) _release();
    notifyListeners();
  }

  void _release() {
    final waiting = List.of(_waiting);
    _waiting.clear();
    for (final c in waiting) {
      if (!c.isCompleted) c.complete();
    }
  }

  /// The app started (true) or stopped (false) speaking.
  void speaking(bool on) {
    if (on) {
      _guard?.cancel();
      _guard = null;
      _watchdog?.cancel();
      _watchdog = null;
      _set(MicPhase.speaking);
      return;
    }
    if (_phase != MicPhase.speaking) return;
    _set(MicPhase.wait);
    _guard = Timer(VoiceConfig.speechGuard, () {
      _guard = null;
      if (_phase == MicPhase.wait) _set(MicPhase.idle);
    });
  }

  /// A listening session opened; it may last [limit]. Ends the wait (the
  /// caller already waited, e.g. push-to-talk after stopping the speech).
  void listening(Duration limit) {
    _guard?.cancel();
    _guard = null;
    _watchdog?.cancel();
    _set(MicPhase.listening);
    _watchdog = Timer(limit + VoiceConfig.listenWatchdogSlack, () {
      _watchdog = null;
      if (_phase != MicPhase.listening) return;
      _set(MicPhase.timeout);
      onTimeout?.call();
    });
  }

  /// The listening session ended.
  void ended() {
    _watchdog?.cancel();
    _watchdog = null;
    if (_phase == MicPhase.listening) _set(MicPhase.done);
  }

  /// Ends everything (screen change, app paused): idle, no timers.
  void reset() {
    _guard?.cancel();
    _guard = null;
    _watchdog?.cancel();
    _watchdog = null;
    _set(MicPhase.idle);
  }

  /// Completes once the microphone is allowed (at most [max]).
  Future<void> ready({Duration max = const Duration(seconds: 2)}) {
    if (micAllowed) return Future.value();
    final c = Completer<void>();
    _waiting.add(c);
    return c.future.timeout(max, onTimeout: () {});
  }

  @override
  void dispose() {
    _guard?.cancel();
    _watchdog?.cancel();
    _release();
    super.dispose();
  }
}
