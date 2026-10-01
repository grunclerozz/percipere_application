import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android system settings pages. Abstract so tests can fake it.
abstract interface class SystemSettings {
  /// Opens Settings → Text-to-speech output (to install voices / pick engine).
  Future<bool> openTtsSettings();

  /// Opens Settings → Voice input (to download offline speech recognition).
  Future<bool> openVoiceInputSettings();
}

/// [SystemSettings] via Android intents.
class AndroidSystemSettings implements SystemSettings {
  /// Creates the Android implementation.
  const AndroidSystemSettings();

  @override
  Future<bool> openTtsSettings() => _open('com.android.settings.TTS_SETTINGS');

  @override
  Future<bool> openVoiceInputSettings() =>
      _open('android.settings.VOICE_INPUT_SETTINGS');

  Future<bool> _open(String action) async {
    try {
      await AndroidIntent(
        action: action,
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      return true;
    } on Object catch (e) {
      debugPrint('Could not open $action: $e');
      return false;
    }
  }
}

/// System settings launcher.
final systemSettingsProvider = Provider<SystemSettings>(
  (ref) => const AndroidSystemSettings(),
);
