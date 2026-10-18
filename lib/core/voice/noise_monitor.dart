import 'dart:collection';
import 'dart:math' as math;

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
  void setNoise({
    double? level,
    double? floor,
    required bool noisy,
    double? threshold,
  }) {
    String shown(double? v) => v?.toStringAsFixed(0) ?? '';
    final changed =
        shown(level) != shown(_level) ||
        shown(floor) != shown(_floor) ||
        shown(threshold) != shown(_threshold) ||
        noisy != _noisy;
    _level = level;
    _floor = floor;
    _noisy = noisy;
    _threshold = threshold;
    if (changed) notifyListeners();
  }

  // ── 2026-10-18: turn state, last result, output voice ───────────────────

  double? _threshold;
  String _mic = '–';
  String _heard = '–';
  double _confidence = -1;
  String _match = '–';
  String _output = '–';

  /// The speech threshold from the measured room (null: not measured).
  double? get threshold => _threshold;

  /// The microphone's turn state (`MicPhase` name).
  String get mic => _mic;

  /// The last transcript (dots while a password is filled in).
  String get heard => _heard;

  /// Its confidence, 0..1; −1 when the recognizer gave none.
  double get confidence => _confidence;

  /// What the last transcript matched (a command, Percy, nothing).
  String get match => _match;

  /// The voice the app speaks with: language, engine route, speed.
  String get output => _output;

  /// Sets the microphone's turn state.
  void setMic(String phase) {
    if (phase == _mic) return;
    _mic = phase;
    notifyListeners();
  }

  /// Sets the last transcript and its confidence; the match is unknown yet.
  void setHeard(String text, double confidence) {
    _heard = text;
    _confidence = confidence;
    _match = '…';
    notifyListeners();
  }

  /// Sets what the last transcript matched.
  void setMatch(String match) {
    if (match == _match) return;
    _match = match;
    notifyListeners();
  }

  /// Sets the output voice.
  void setOutput(String output) {
    if (output == _output) return;
    _output = output;
    notifyListeners();
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
    _addReading(now, level);
    // A second of the room's own sound: the room is measured.
    if (_readings.last.$1.difference(_readings.first.$1) >=
        VoiceConfig.calibrationTime) {
      _setBaseline(floor!, now);
    }
  }

  void _addReading(DateTime at, double level) {
    _readings.add((at, level));
    final old = at.subtract(VoiceConfig.noiseWindow);
    while (_readings.isNotEmpty && _readings.first.$1.isBefore(old)) {
      _readings.removeFirst();
    }
  }

  // ── Calibration (2026-10-18) ─────────────────────────────────────────────

  double? _baseline;
  DateTime? _baselineAt;

  /// The room's calibrated level: from a [VoiceConfig.calibrationTime]
  /// measurement ([calibrate], at warm-up and on noisy screens), or from a
  /// second of quiet before the user spoke. Null: never measured.
  double? get baseline => _baseline;

  void _setBaseline(double level, DateTime at) {
    _baseline = level;
    _baselineAt = at;
  }

  /// Takes a measurement of the room ([levels] in order, the last one just
  /// now, spread over [VoiceConfig.calibrationTime]). Ignored while the app
  /// speaks or the user talks, or with fewer than 3 readings. The readings
  /// count toward [noisy] like the ones before a session.
  void calibrate(List<double> levels) {
    if (levels.length < 3 || _appSpeaking || _userTalking) return;
    final now = _clock();
    final step =
        VoiceConfig.calibrationTime.inMicroseconds ~/ (levels.length - 1);
    for (var i = 0; i < levels.length; i++) {
      final at = now.subtract(
        Duration(microseconds: step * (levels.length - 1 - i)),
      );
      final from = _quietFrom;
      if (from != null && at.isBefore(from)) continue;
      _addReading(at, levels[i]);
    }
    final sorted = [...levels]..sort();
    _setBaseline(sorted[sorted.length ~/ 2], now);
  }

  /// Whether the room should be measured again when a screen opens: never
  /// measured, measured more than [VoiceConfig.noiseStale] ago, or it was
  /// noisy (at or above [VoiceConfig.noisyLevel]).
  bool get needsCalibration {
    final at = _baselineAt;
    final level = _baseline;
    return at == null ||
        level == null ||
        _clock().difference(at) > VoiceConfig.noiseStale ||
        level >= VoiceConfig.noisyLevel;
  }

  /// The level a sound must reach to count as the user's speech: the
  /// measured room plus [VoiceConfig.speechMargin], at least
  /// [VoiceConfig.speechStartLevel]. Null until the room was measured.
  double? get speechThreshold {
    final room = _baseline;
    if (room == null) return null;
    return math.max(
      VoiceConfig.speechStartLevel,
      room + VoiceConfig.speechMargin,
    );
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
