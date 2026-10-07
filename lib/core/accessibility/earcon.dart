import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short non-speech sounds. Abstract so tests can record them.
abstract interface class Earcon {
  /// A short beep the moment a voice command is recognized, before the
  /// action finishes, so the user knows they were heard.
  Future<void> heard();
}

/// [Earcon] played by Android's `ToneGenerator` (no sound file to load).
class DeviceEarcon implements Earcon {
  /// Creates the device earcon.
  const DeviceEarcon();

  static const MethodChannel _channel = MethodChannel(
    'ph.bataan.percipere/sound',
  );

  @override
  Future<void> heard() async {
    try {
      await _channel.invokeMethod<bool>('heard');
    } on Object catch (e) {
      debugPrint('Earcon failed: $e'); // The haptic pulse still confirms.
    }
  }
}

/// The app's earcons; overridden in tests.
final earconProvider = Provider<Earcon>((ref) => const DeviceEarcon());
