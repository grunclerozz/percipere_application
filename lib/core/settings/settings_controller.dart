import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final old = before.toPrefs();
    for (final MapEntry(:key, :value) in after.toPrefs().entries) {
      if (old[key] != value) await _dao.set(key, value, userId: _scope);
    }
    return after;
  }

  /// Switches to another profile's settings (or the device's).
  ///
  /// A profile with no saved settings yet starts from the current ones (so
  /// creating an account keeps what the user already set up).
  Future<void> switchScope(String scope) async {
    final dao = _dao;
    final stored = await dao.getAll(userId: scope);
    final AppSettings next;
    if (stored.isEmpty) {
      next = state;
      for (final MapEntry(:key, :value) in next.toPrefs().entries) {
        await dao.set(key, value, userId: scope);
      }
    } else {
      next = AppSettings.fromPrefs(stored);
    }
    _scope = scope;
    if (next.pitch != state.pitch) {
      await ref.read(ttsServiceProvider).setPitch(next.pitch);
    }
    state = next;
  }
}

/// User settings.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
