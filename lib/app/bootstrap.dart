import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/db/app_database.dart';
import '../core/db/daos/preferences_dao.dart';
import '../core/platform/permissions.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_controller.dart';
import '../core/tts/tts_service.dart';
import '../core/voice/voice_controller.dart';
import '../features/account/account_repository.dart';

/// Startup work that must finish before the first frame: open the database,
/// load the settings of the logged-in profile (or the device), start TTS and
/// check which voices exist.
///
/// Returns provider overrides for the root `ProviderScope`.
Future<List<Override>> bootstrap() async {
  final database = await AppDatabase.open();
  final prefs = PreferencesDao(database.db);

  // Settings live with the logged-in profile; otherwise with the device.
  final device = await prefs.getAll();
  final user = device[PrefKeys.currentUser];
  final account = user is String
      ? await AccountRepository(database.db).get(user)
      : null;
  // A deleted profile falls back to the phone's own settings.
  final scope = account?.id ?? PreferencesDao.deviceScope;
  final settings = AppSettings.fromPrefs(
    scope == PreferencesDao.deviceScope
        ? device
        : await prefs.getAll(userId: scope),
  );

  final tts = await FlutterTtsService.create();
  await tts.setPitch(settings.pitch);
  final voices = await tts.checkVoices();
  debugPrint(
    'Percipere voices: filipinoReady=${voices.filipinoReady}, '
    'english=${voices.englishTag}',
  );
  // Remembered so reports/diagnostics can tell prompts fell back to English;
  // re-checked on every launch and on resume.
  await prefs.set(PrefKeys.ttsFilipinoFallback, !voices.filipinoReady);

  final micGranted =
      await const DevicePermissionService().status(AppPermission.microphone) ==
      PermissionAccess.granted;

  return [
    appDatabaseProvider.overrideWithValue(database),
    initialSettingsProvider.overrideWithValue(settings),
    initialSettingsScopeProvider.overrideWithValue(scope),
    initialAccountProvider.overrideWithValue(account),
    initialMicGrantedProvider.overrideWithValue(micGranted),
    ttsServiceProvider.overrideWithValue(tts),
    voiceStatusProvider.overrideWith(() => VoiceStatusNotifier(voices)),
  ];
}
