import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short non-speech sounds. Abstract so tests can record them.
abstract interface class Earcon {
  /// A short beep the moment a voice command is recognized, before the
  /// action finishes, so the user knows they were heard.
  Future<void> heard();

  /// A softer, shorter blip the moment listening starts after the app has
  /// spoken: "your turn". Completes when the tone has ended.
  Future<void> listening();

  /// A low, short tone when listening stops without having heard a
  /// command (a one-off listen that heard nothing, listening paused).
  Future<void> stopped();

  /// Silences a tone that is playing (screen change, app paused).
  Future<void> stop();
}

/// [Earcon] played by the app's native tone player: a fixed-length tone
/// that always ends (2026-10-18: Android's `ToneGenerator` sometimes kept
/// sounding on the tablet). Each call completes when its tone has ended.
class DeviceEarcon implements Earcon {
  /// Creates the device earcon.
  const DeviceEarcon();

  static const MethodChannel _channel = MethodChannel(
    'ph.bataan.percipere/sound',
  );

  @override
  Future<void> heard() => _play('heard');

  @override
  Future<void> listening() => _play('listening');

  @override
  Future<void> stopped() => _play('stopped');

  @override
  Future<void> stop() => _play('stop');

  Future<void> _play(String sound) async {
    try {
      await _channel.invokeMethod<bool>(sound);
    } on Object catch (e) {
      debugPrint('Earcon failed: $e'); // The haptic pulse still confirms.
    }
  }
}

/// The app's earcons; overridden in tests.
final earconProvider = Provider<Earcon>((ref) => const DeviceEarcon());
