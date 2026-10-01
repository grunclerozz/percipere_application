import '../db/daos/preferences_dao.dart';
import 'account.dart';

/// "Naka-save ito sa phone na ito lamang. Mag-register para hindi ito
/// mawala." — said to a guest at most once per moment: after the first save
/// to history (delivered on the next Capture announcement, never during
/// reading or setup) and the first time Settings opens.
class GuestReminders {
  /// Creates the helper over the preferences table.
  GuestReminders(this._prefs);

  final PreferencesDao _prefs;

  static const String _due = 'due';

  /// A document was saved to history: schedule the reminder, once.
  Future<void> historySaved(Account account) async {
    if (!account.isGuest) return;
    final state = await _prefs.get(
      PrefKeys.guestReminderHistory,
      userId: account.id,
    );
    if (state == null) {
      await _prefs.set(PrefKeys.guestReminderHistory, _due, userId: account.id);
    }
  }

  /// Whether the history reminder should be said now; marks it said.
  Future<bool> takeHistoryReminder(Account? account) async {
    if (account == null || !account.isGuest) return false;
    final state = await _prefs.get(
      PrefKeys.guestReminderHistory,
      userId: account.id,
    );
    if (state != _due) return false;
    await _prefs.set(PrefKeys.guestReminderHistory, true, userId: account.id);
    return true;
  }
}
