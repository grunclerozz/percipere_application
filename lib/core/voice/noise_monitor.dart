import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/voice_config.dart';

/// What the developer voice-state overlay shows about capture: which
/// recognizer and audio source the last session used and the room's noise.
class VoiceCaptureStatus extends ChangeNotifier {
  String _source = '–';
  double? _level;
  double? _floor;
  bool _noisy = false;

  /// The recognizer and audio source of the last session, e.g. `app mic:
  /// voiceRecognition AEC NS` or `Android recognizer`.
  String get source => _source;

  /// The last microphone level (about −2 silent .. 10 loud).
  double? get level => _level;

  /// The room's measured level (null: not measured since the app spoke).
  double? get floor => _floor;

  /// Whether the room counts as noisy now.
  bool get noisy => _noisy;

  /// Sets the source.
  void setSource(String source) {
    if (source == _source) return;
    _source = source;
    notifyListeners();
  }

  /// Updates the noise numbers (notifies only when the shown value moves).
  void setNoise({double? level, double? floor, required bool noisy}) {
    String shown(double? v) => v?.toStringAsFixed(0) ?? '';
    final changed =
        shown(level) != shown(_level) ||
        shown(floor) != shown(_floor) ||
        noisy != _noisy;
    _level = level;
    _floor = floor;
    _noisy = noisy;
    if (changed) notifyListeners();
  }
}

/// The capture status ([VoiceCaptureStatus]).
final voiceCaptureProvider = Provider<VoiceCaptureStatus>((ref) {
  final status = VoiceCaptureStatus();
  ref.onDispose(status.dispose);
  return status;
});

/// Measures the room's noise floor from microphone levels (about −2 silent
/// to 10 loud, Android's rms dB scale) and says whether the room is really
/// noisy.
///
/// Only levels of the room itself count: none while the app speaks or for
/// [VoiceConfig.noiseSettle] after (echo), none after a tone, and none
/// from the user's own words ([userSpoke] drops the readings just before
/// them too, [VoiceConfig.noiseOnsetLag]). Each time the app stops
/// speaking the floor is measured afresh. The room is noisy only when the
/// readings stayed at or above [VoiceConfig.noisyLevel] for
/// [VoiceConfig.noiseSustain] (2026-10-17 tablet test: "Medyo maingay po"
/// came in a quiet room, from the app's own voice and from the user's
/// first word).
class NoiseMonitor {
  /// Creates a monitor; [clock] is for tests.
  NoiseMonitor({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Queue<(DateTime, double)> _readings = Queue();

  bool _appSpeaking = false;
  DateTime? _quietFrom;
  bool _userTalking = false;
  double? _last;

  /// The last level heard (any reading, for the developer overlay).
  double? get lastLevel => _last;

  /// The room's level: the median of the counted readings; null when none.
  double? get floor {
    if (_readings.isEmpty) return null;
    final sorted = [for (final r in _readings) r.$2]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// The app started (true) or stopped (false) speaking. On stop, the
  /// floor is measured afresh after [VoiceConfig.noiseSettle].
  void appSpeaking(bool speaking) {
    if (speaking == _appSpeaking) return;
    _appSpeaking = speaking;
    if (!speaking) {
      _readings.clear();
      _quietFrom = _clock().add(VoiceConfig.noiseSettle);
    }
  }

  /// A short sound of the app's own (a tone) just played.
  void appSound() {
    final until = _clock().add(VoiceConfig.noiseToneSettle);
    final from = _quietFrom;
    if (from == null || until.isAfter(from)) _quietFrom = until;
  }

  /// A new listening session opened: the user hasn't spoken in it yet.
  void sessionStarted() => _userTalking = false;

  /// The user's words were recognized (first partial result, or the voice
  /// detector heard speech): later readings are their voice, and so were
  /// the ones just before.
  void userSpoke() {
    if (_userTalking) return;
    _userTalking = true;
    final cut = _clock().subtract(VoiceConfig.noiseOnsetLag);
    while (_readings.isNotEmpty && !_readings.last.$1.isBefore(cut)) {
      _readings.removeLast();
    }
  }

  /// A microphone [level] reading.
  void add(double level) {
    _last = level;
    if (_appSpeaking || _userTalking) return;
    final now = _clock();
    final from = _quietFrom;
    if (from != null && now.isBefore(from)) return;
    _readings.add((now, level));
    final old = now.subtract(VoiceConfig.noiseWindow);
    while (_readings.isNotEmpty && _readings.first.$1.isBefore(old)) {
      _readings.removeFirst();
    }
  }

  /// Whether the room is noisy: enough readings, spanning at least
  /// [VoiceConfig.noiseSustain], mostly ([VoiceConfig.noisyShare]) at or
  /// above [VoiceConfig.noisyLevel].
  bool get noisy {
    if (_readings.length < VoiceConfig.noisyMinReadings) return false;
    final span = _readings.last.$1.difference(_readings.first.$1);
    if (span < VoiceConfig.noiseSustain) return false;
    final loud = _readings.where((r) => r.$2 >= VoiceConfig.noisyLevel).length;
    return loud / _readings.length >= VoiceConfig.noisyShare;
  }
}
