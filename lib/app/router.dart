import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/account.dart';
import '../core/auth/session.dart';
import '../features/auth/auth_choice_screen.dart';
import '../features/auth/fingerprint_offer_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/legacy_account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/security_question_screen.dart';
import '../features/auth/upgrade_account_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/history/history_screen.dart';
import '../features/reader/reader_controller.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/profiling_screen.dart';
import '../features/welcome/welcome_screen.dart';

/// Route paths. Use these instead of string literals.
abstract final class AppRoutes {
  /// Welcome: Login, Register, Subukan muna.
  static const String welcome = '/';

  /// Register (First/Last Name, Email, Password).
  static const String register = '/register';

  /// Security question, right after registering.
  static const String securityQuestion = '/register/security';

  /// Fingerprint login offer, after the security question.
  static const String fingerprintOffer = '/register/fingerprint';

  /// Log in (Email, Password; fingerprint if enabled).
  static const String login = '/login';

  /// Forgot password (security question).
  static const String forgotPassword = '/login/forgot';

  /// Claim an old name + PIN account.
  static const String legacyAccount = '/login/legacy';

  /// An old PIN account sets its email and password. `extra`: account id.
  static const String upgradeAccount = '/account/upgrade';

  /// "Nais mo bang mag login?" (after logout / expired session).
  /// `extra`: true when the session expired.
  static const String authChoice = '/auth';

  /// Guided setup (profiling). `extra`: a [SetupMode].
  static const String setup = '/setup';

  /// Capture method (upload or camera) — the home screen.
  static const String capture = '/capture';

  /// Camera capture with audio guidance.
  static const String camera = '/camera';

  /// Reader. Pass a `ReaderSource` (or plain text) as `extra`.
  static const String reader = '/reader';

  /// Accessibility Settings.
  static const String settings = '/settings';

  /// Reading History.
  static const String history = '/history';

  /// Where a logged-in [account] goes: set an email/password (old PIN
  /// account), finish the setup, or Capture.
  static String home(Account account) {
    if (account.isLegacy) return upgradeAccount;
    if (!account.profilingCompleted) return setup;
    return capture;
  }
}

/// Builds the app router.
GoRouter buildRouter({
  String initialLocation = AppRoutes.welcome,
  Object? initialExtra,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    initialExtra: initialExtra,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.securityQuestion,
        builder: (context, state) => const SecurityQuestionScreen(),
      ),
      GoRoute(
        path: AppRoutes.fingerprintOffer,
        builder: (context, state) => const FingerprintOfferScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          email: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.legacyAccount,
        builder: (context, state) => const LegacyAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.upgradeAccount,
        builder: (context, state) => const UpgradeAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.authChoice,
        builder: (context, state) =>
            AuthChoiceScreen(expired: state.extra == true),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => ProfilingScreen(
          mode: state.extra is SetupMode
              ? state.extra! as SetupMode
              : SetupMode.firstRun,
        ),
      ),
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) => ReaderScreen(
          source: switch (state.extra) {
            final ReaderSource source => source,
            final String text => TextSource(text),
            _ => const TextSource(''),
          },
        ),
      ),
    ],
  );
}

/// The app-wide router. Starts where the saved session leads: Welcome with
/// no session, "log in again" if it expired, otherwise the account's home.
final routerProvider = Provider<GoRouter>((ref) {
  final account = ref.read(initialAccountProvider);
  final expired = ref.read(initialSessionExpiredProvider);
  final router = buildRouter(
    initialLocation: account != null
        ? AppRoutes.home(account)
        : expired
        ? AppRoutes.authChoice
        : AppRoutes.welcome,
    initialExtra: account == null && expired ? true : null,
  );
  ref.onDispose(router.dispose);
  return router;
});
