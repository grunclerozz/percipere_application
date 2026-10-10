import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../db/daos/preferences_dao.dart';

/// How many times the current user has opened each screen (by screen id),
/// so announcements can get shorter as the app becomes familiar
/// (`Verbosity.auto`). Saved per user (the device before anyone logs in).
class Familiarity extends Notifier<Map<String, int>> {
  String _scope = PreferencesDao.deviceScope;

  @override
  Map<String, int> build() {
    final account = ref.watch(currentAccountProvider);
    _scope = account?.id ?? PreferencesDao.deviceScope;
    scheduleMicrotask(_load);
    return const {};
  }

  Future<void> _load() async {
    final scope = _scope;
    try {
      final saved = await ref
          .read(userPrefsProvider)
          .get(PrefKeys.screenVisits, userId: scope);
      if (!ref.mounted || scope != _scope || saved is! Map) return;
      state = {
        for (final e in saved.entries)
          if (e.value is int) e.key.toString(): e.value as int,
        // Visits counted before loading finished.
        for (final e in state.entries)
          e.key: ((saved[e.key] as int?) ?? 0) + e.value,
      };
    } on Object catch (e) {
      debugPrint('Familiarity load failed: $e');
    }
  }

  /// Times [screenId] was opened before.
  int visits(String screenId) => state[screenId] ?? 0;

  /// Counts one more visit to [screenId].
  void noteVisit(String screenId) {
    state = {...state, screenId: visits(screenId) + 1};
    final scope = _scope;
    final snapshot = state;
    unawaited(
      ref
          .read(userPrefsProvider)
          .set(PrefKeys.screenVisits, snapshot, userId: scope)
          .catchError((Object e) => debugPrint('Familiarity save failed: $e')),
    );
  }
}

/// Screen visit counts of the current user.
final familiarityProvider = NotifierProvider<Familiarity, Map<String, int>>(
  Familiarity.new,
);
