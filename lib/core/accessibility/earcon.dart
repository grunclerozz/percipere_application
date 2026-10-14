import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short non-speech sounds. Abstract so tests can record them.
abstract interface class Earcon {
  /// A short beep the moment a voice command is recognized, before the
  /// action finishes, so the user knows they were heard.
  Future<void> heard();

  /// A softer, shorter blip the moment listening starts after the app has
  /// spoken: "your turn".
  Future<void> listening();

  /// A low, short tone when listening stops without having heard a
  /// command (a one-off listen that heard nothing, listening paused).
  Future<void> stopped();
}

/// [Earcon] played by Android's `ToneGenerator` (no sound file to load).
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
