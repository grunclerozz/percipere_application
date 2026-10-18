import '../../core/auth/account_api.dart';
import '../../l10n/app_localizations.dart';

/// What to say when the web app refused or couldn't be reached (the cases
/// a screen doesn't handle itself).
String serverErrorText(AccountApiException e, AppLocalizations l) =>
    switch (e.error) {
      AccountApiError.offline => l.serverUnreachable,
      AccountApiError.tooManyAttempts => l.lockoutStarted(
        e.retryAfter.inSeconds,
      ),
      AccountApiError.accountSuspended => l.accountSuspended,
      AccountApiError.pendingApproval => l.accountPendingApproval,
      AccountApiError.emailTaken => l.emailTakenServer,
      _ => l.serverProblem,
    };
