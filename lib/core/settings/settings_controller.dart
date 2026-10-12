import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';
import '../tts/tts_service.dart';
import 'app_settings.dart';

/// Settings loaded at startup. Set by `bootstrap()`.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// The preference scope at startup: a user id, or
/// [PreferencesDao.deviceScope]. Set by `bootstrap()`.
final initialSettingsScopeProvider = Provider<String>(
  (ref) => PreferencesDao.deviceScope,
);

/// The single source of truth for user settings. Theme, locale, navigation
/// mode, reading speed and haptics providers all derive from it.
///
/// Changes are saved immediately, one preference key per changed field, in
/// the current [scope] (the logged-in profile, or the device).
class SettingsController extends Notifier<AppSettings> {
  late String _scope;

  /// Current preference scope.
  String get scope => _scope;

  @override
  AppSettings build() {
    _scope = ref.read(initialSettingsScopeProvider);
    return ref.read(initialSettingsProvider);
  }

  PreferencesDao get _dao => PreferencesDao(ref.read(appDatabaseProvider).db);

  /// Applies [change] and saves what changed.
  Future<AppSettings> update(AppSettings Function(AppSettings) change) async {
    final before = state;
    final after = change(before);
    if (after == before) return after;
    state = after;
    if (after.pitch != before.pitch) {
      await ref.read(ttsServiceProvider).setPitch(after.pitch);
    }
    if (after.readingVoice != before.readingVoice) {
      await ref.read(ttsServiceProvider).setVoicePreference(after.readingVoice);
    }
    final old = before.toPrefs();
    for (final MapEntry(:key, :value) in after.toPrefs().entries) {
      if (old[key] != value) await _dao.set(key, value, userId: _scope);
    }
    return after;
  }

  /// Switches to another profile's settings (or the device's).
  ///
  /// A profile with no saved settings yet starts from the current ones (so
  /// creating an account keeps what the user already set up). With
  /// [keepCurrent], [scope] takes the current settings regardless (logging
  /// out keeps the look and voice the user is used to).
  Future<void> switchScope(String scope, {bool keepCurrent = false}) async {
    final dao = _dao;
    final stored = await dao.getAll(userId: scope);
    final AppSettings next;
    if (stored.isEmpty || keepCurrent) {
      next = state;
      for (final MapEntry(:key, :value) in next.toPrefs().entries) {
        await dao.set(key, value, userId: scope);
      }
    } else {
      next = AppSettings.fromPrefs(stored);
    }
    _scope = scope;
    await _applyVoice(next);
    state = next;
  }

  /// Re-reads the current scope from the database (after another component
  /// rewrote it, e.g. guest → account migration).
  Future<void> reload() async {
    final next = AppSettings.fromPrefs(await _dao.getAll(userId: _scope));
    await _applyVoice(next);
    state = next;
  }

  /// Gives the TTS engine [next]'s pitch and reading voice, if they differ
  /// from the current ones.
  Future<void> _applyVoice(AppSettings next) async {
    final tts = ref.read(ttsServiceProvider);
    if (next.pitch != state.pitch) await tts.setPitch(next.pitch);
    if (next.readingVoice != state.readingVoice) {
      await tts.setVoicePreference(next.readingVoice);
    }
  }
}

/// User settings.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Whether this is a developer build (`--dart-define=PERCIPERE_DEV=true`).
/// Overridden in tests.
final devBuildProvider = Provider<bool>((ref) => Env.devTools);

/// Whether the online ElevenLabs Percy is really used: only in a developer
/// build with its switch on. A value saved by an older developer build is
/// ignored by a normal build, so the self-built Percy is always the default.
final elevenLabsActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(devBuildProvider) &&
      ref.watch(settingsProvider.select((s) => s.percyElevenLabs)),
);
