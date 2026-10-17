import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';
import '../core/auth/account.dart';
import '../core/auth/account_repository.dart';
import '../core/auth/password_hasher.dart';
import '../core/auth/session.dart';
import '../core/auth/session_store.dart';
import '../core/db/app_database.dart';
import '../core/db/daos/preferences_dao.dart';
import '../core/network/server_address.dart';
import '../core/offline_voice/hybrid_tts_service.dart';
import '../core/offline_voice/model_catalog.dart';
import '../core/offline_voice/model_store.dart';
import '../core/offline_voice/offline_engines.dart';
import '../core/offline_voice/offline_voice_setup.dart';
import '../core/platform/permissions.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_controller.dart';
import '../core/tts/tts_service.dart';
import '../core/voice/voice_controller.dart';
import '../core/voice/voice_readiness.dart';

/// Startup work that must finish before the first frame: open the database,
/// restore the session, load that account's settings (or the device's),
/// start TTS and check which voices exist.
///
/// Returns provider overrides for the root `ProviderScope`.
Future<List<Override>> bootstrap() async {
  await _logBuild();
  final database = await AppDatabase.open();
  final prefs = PreferencesDao(database.db);
  const sessions = SecureSessionStore();

  final restored = await restoreSession(database, prefs, sessions);
  final settings = restored.settings;

  // The app's own offline voices and command recognizer, when already
  // downloaded (first launch downloads them: OfflineVoiceSetupScreen).
  final engines = OfflineEngines();
  final store = await _modelStore();
  if (store != null && store.installedAll().isNotEmpty) {
    unawaited(engines.load(store));
  }

  final tts = HybridTtsService(await FlutterTtsService.create(), engines);
  await tts.setPitch(settings.pitch);
  await tts.setVoicePreference(settings.readingVoice);
  final voices = await tts.checkVoices();
  debugPrint(
    'Percipere voices: filipinoReady=${voices.filipinoReady}, '
    'english=${voices.englishTag}',
  );
  // Remembered so reports/diagnostics can tell prompts fell back to English;
  // re-checked on every launch and on resume.
  await prefs.set(PrefKeys.ttsFilipinoFallback, !voices.filipinoReady);

  // A developer build can point at another web app address (Settings); a
  // saved address the build does not allow (plain http to another host) is
  // ignored.
  var serverAddress = Env.apiBaseUrl;
  if (Env.devTools) {
    final saved = await readSavedServerAddress(prefs);
    if (saved != null && ServerAddressRules.check(saved).address != null) {
      serverAddress = saved;
    }
  }

  // First launch (on this tablet): download the offline voices first.
  final setupPending =
      store != null &&
      store.installedAll().length < OfflineModelCatalog.names.length &&
      await prefs.get(PrefKeys.offlineVoiceSetupShown) != true;

  final micGranted =
      await const DevicePermissionService().status(AppPermission.microphone) ==
      PermissionAccess.granted;

  return [
    appDatabaseProvider.overrideWithValue(database),
    sessionStoreProvider.overrideWithValue(sessions),
    initialSettingsProvider.overrideWithValue(settings),
    initialSettingsScopeProvider.overrideWithValue(restored.scope),
    initialAccountProvider.overrideWithValue(restored.account),
    initialSessionExpiredProvider.overrideWithValue(restored.expired),
    initialServerAddressProvider.overrideWithValue(serverAddress),
    initialMicGrantedProvider.overrideWithValue(micGranted),
    ttsServiceProvider.overrideWithValue(tts),
    offlineEnginesProvider.overrideWithValue(engines),
    modelStoreProvider.overrideWithValue(store),
    offlineVoiceSetupPendingProvider.overrideWithValue(setupPending),
    voiceStatusProvider.overrideWith(() => VoiceStatusNotifier(voices)),
    startupScreenProvider.overrideWithValue(true),
  ];
}

/// The folder of the offline models (app-private storage), or null if the
/// storage can't be reached.
Future<ModelStore?> _modelStore() async {
  try {
    final support = await getApplicationSupportDirectory();
    return ModelStore(p.join(support.path, 'voice_models'));
  } on Object catch (e) {
    debugPrint('[OFFLINE VOICE] model folder unavailable: $e');
    return null;
  }
}

/// Logs which app and build is running (`adb logcat -s flutter | findstr
/// CAPTURE`), so a test on the tablet can be matched to the APK it used.
Future<void> _logBuild() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final mode = kReleaseMode
        ? 'release'
        : (kProfileMode ? 'profile' : 'debug');
    debugPrint(
      '[CAPTURE] app ${info.packageName} '
      '${info.version}+${info.buildNumber} ($mode build)',
    );
  } on Object catch (e) {
    debugPrint('[CAPTURE] app build info unavailable: $e');
  }
}

/// The session found at startup.
typedef RestoredSession = ({
  Account? account,
  bool expired,
  String scope,
  AppSettings settings,
});

/// Finds who is logged in: the secure-storage session (or, once, the
/// pre-6B PIN login kept in preferences). An account with "stay logged in"
/// off starts logged out (`expired`). Settings come from the account, or
/// from the device when no one is logged in.
Future<RestoredSession> restoreSession(
  AppDatabase database,
  PreferencesDao prefs,
  SessionStore sessions,
) async {
  final repo = AccountRepository(database.db, const PasswordHasher());
  var userId = await sessions.readUserId();

  // Phase 6 kept the logged-in PIN profile in preferences: move it.
  final legacy = await prefs.get(PrefKeys.currentUser);
  if (legacy is String) {
    userId ??= legacy;
    await sessions.writeUserId(legacy);
    await prefs.remove(PrefKeys.currentUser);
  }

  var account = userId == null ? null : await repo.get(userId);
  if (userId != null && account == null) await sessions.clearUserId();

  var expired = false;
  final userSettings = account == null
      ? null
      : AppSettings.fromPrefs(await prefs.getAll(userId: account.id));
  if (account != null && !account.isGuest && !userSettings!.stayLoggedIn) {
    await sessions.clearUserId();
    expired = true;
    account = null;
    // Logged out, but the look and voice stay as the user had them.
    for (final MapEntry(:key, :value) in userSettings.toPrefs().entries) {
      await prefs.set(key, value);
    }
  }

  final scope = account?.id ?? PreferencesDao.deviceScope;
  final settings = userSettings ?? AppSettings.fromPrefs(await prefs.getAll());
  return (account: account, expired: expired, scope: scope, settings: settings);
}
