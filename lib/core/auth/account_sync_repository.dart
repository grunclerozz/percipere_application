import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';

/// Sends accounts to the web admin app (Phase 7). Accounts are created
/// offline first; `users.synced` / `users.server_id` track what the server
/// has. Guests are never sent.
abstract interface class AccountSyncRepository {
  /// Queues [account] for upload (after registration or a profile change).
  Future<void> enqueue(Account account);

  /// Uploads everything queued; returns how many accounts were sent.
  Future<int> syncPending();
}

/// Placeholder until the web app exists: remembers what would be sent and
/// sends nothing, so `synced` stays 0 and Phase 7 picks everything up.
class MockAccountSyncRepository implements AccountSyncRepository {
  /// Account ids queued so far (this run).
  final List<String> queued = [];

  @override
  Future<void> enqueue(Account account) async {
    if (account.isGuest) return;
    queued.add(account.id);
    // Only the id: never log personal data or credentials.
    debugPrint('Account sync (mock): queued ${account.id}');
  }

  @override
  Future<int> syncPending() async => 0;
}

/// Account sync.
final accountSyncRepositoryProvider = Provider<AccountSyncRepository>(
  (ref) => MockAccountSyncRepository(),
);
