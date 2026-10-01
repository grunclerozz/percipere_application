import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';
import '../settings/settings_controller.dart';
import 'account.dart';
import 'account_repository.dart';
import 'account_sync_repository.dart';
import 'session_store.dart';

/// The account logged in at startup. Set by `bootstrap()`.
final initialAccountProvider = Provider<Account?>((ref) => null);

/// The logged-in account (or the guest profile), or null on the Welcome /
/// Login / Register screens. Logging in switches which settings are active;
/// the session is kept in secure storage ("stay logged in").
class CurrentAccount extends Notifier<Account?> {
  @override
  Account? build() => ref.read(initialAccountProvider);

  AccountRepository get _repo => ref.read(accountRepositoryProvider);
  SessionStore get _session => ref.read(sessionStoreProvider);

  /// Logs [account] in, remembers the session and switches to its settings.
  Future<void> login(Account account) async {
    await _repo.markLogin(account.id);
    await _session.writeUserId(account.id);
    await ref.read(settingsProvider.notifier).switchScope(account.id);
    state = account;
  }

  /// Starts (or resumes) the device's guest profile.
  Future<Account> startGuest(String name) async {
    final guest = await _repo.guest(name: name);
    await login(guest);
    return guest;
  }

  /// Logs a newly registered [account] in. If a guest was using the app,
  /// their settings, history and finished setup steps move to the account
  /// and the guest profile is deleted.
  Future<void> completeRegistration(Account account) async {
    final previous = state;
    await login(account);
    if (previous != null && previous.isGuest) {
      await _repo.migrateGuest(previous.id, account.id);
      await ref.read(settingsProvider.notifier).reload();
    }
    await ref.read(accountSyncRepositoryProvider).enqueue(account);
  }

  /// Logs out: forgets the session and returns to the device's settings,
  /// which keep the look and voice the user had.
  Future<void> logout() async {
    await _session.clearUserId();
    await ref
        .read(settingsProvider.notifier)
        .switchScope(PreferencesDao.deviceScope, keepCurrent: true);
    state = null;
  }

  /// Re-reads the logged-in account (after a change to it).
  Future<void> refresh() async {
    final id = state?.id;
    if (id == null) return;
    state = await _repo.get(id);
  }
}

/// Logged-in account.
final currentAccountProvider = NotifierProvider<CurrentAccount, Account?>(
  CurrentAccount.new,
);

/// Preferences of the logged-in account (setup progress, reminders).
final userPrefsProvider = Provider<PreferencesDao>(
  (ref) => PreferencesDao(ref.watch(appDatabaseProvider).db),
);

/// True when a saved session was dropped at startup because the account has
/// "stay logged in" off. Set by `bootstrap()`.
final initialSessionExpiredProvider = Provider<bool>((ref) => false);
