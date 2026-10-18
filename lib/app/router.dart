import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/account.dart';
import '../core/auth/session.dart';
import '../core/offline_voice/offline_voice_setup.dart';
import '../core/voice/voice_readiness.dart';
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
import '../features/describe/describe_controller.dart';
import '../features/describe/describe_screen.dart';
import '../features/describe/describe_source_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/chapters_screen.dart';
import '../features/library/favorites_screen.dart';
import '../features/library/item_details_screen.dart';
import '../features/library/library_screen.dart';
import '../features/offline_voice/offline_voice_setup_screen.dart';
import '../features/reader/reader_controller.dart';
import '../features/reader/reader_screen.dart';
import '../features/report/my_reports_screen.dart';
import '../features/report/report_issue_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/voice_check_screen.dart';
import '../features/settings/wer_test_screen.dart';
import '../features/setup/profiling_screen.dart';
import '../features/startup/startup_screen.dart';
import '../features/tutorial/tutorial_screen.dart';
import '../features/welcome/welcome_screen.dart';

/// Route paths. Use these instead of string literals.
abstract final class AppRoutes {
  /// Welcome: Login, Register, Subukan muna.
  static const String welcome = '/';

  /// Controls tutorial. `extra`: true when replayed (finishing goes back).
  static const String tutorial = '/tutorial';

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

  /// "Mag-report ng problema". `extra`: the id of the screen it was opened
  /// from.
  static const String reportIssue = '/report';

  /// "Aking mga report".
  static const String myReports = '/report/mine';

  /// "Pagsusuri ng boses" (Voice check).
  static const String voiceCheck = '/settings/voice-check';

  /// Hidden developer screen: speech recognition test (WER).
  static const String werTest = '/settings/wer-test';

  /// First launch: downloading the offline voices. `extra`: an
  /// `OfflineVoiceNext` (where to go afterwards).
  static const String offlineVoice = '/voice-setup';

  /// Every cold start: the loading screen ("Pakihintay po, inihahanda ang
  /// Percipere."). `extra`: an `OfflineVoiceNext` (the first real screen).
  static const String startup = '/start';

  /// Claim an old name + PIN account.
  static const String legacyAccount = '/login/legacy';

  /// An old PIN account sets its email and password. `extra`: account id.
  static const String upgradeAccount = '/account/upgrade';

  /// "Nais mo bang mag login?" (after logout / expired session).
  /// `extra`: true when the session expired.
  static const String authChoice = '/auth';

  /// Guided setup (profiling). `extra`: a [SetupMode].
  static const String setup = '/setup';

  /// Home: "Magbasa ng bago" or "Aklatan". The base of the back stack.
  static const String home = '/home';

  /// Capture method (upload, camera or Maglarawan); opened from Home.
  static const String capture = '/capture';

  /// Camera capture with audio guidance. `extra`: true when the photo is to
  /// be described (Maglarawan) instead of read.
  static const String camera = '/camera';

  /// Maglarawan: choose camera or upload.
  static const String describeSource = '/describe/source';

  /// Description of a picture. `extra`: a `DescribeSubject`.
  static const String describe = '/describe';

  /// Reader. Pass a `ReaderSource` (or plain text) as `extra`.
  static const String reader = '/reader';

  /// Accessibility Settings.
  static const String settings = '/settings';

  /// The Library (Aklatan).
  static const String library = '/library';

  /// Details of one library item. `extra`: the item id.
  static const String libraryItem = '/library/item';

  /// Favorites of one item. `extra`: a `FavoritesArgs`.
  static const String favorites = '/library/favorites';

  /// Chapters of one item. `extra`: the item id.
  static const String chapters = '/library/chapters';

  /// Where a logged-in [account] goes: set an email/password (old PIN
  /// account), finish the setup, or Home.
  static String landing(Account account) {
    if (account.isLegacy) return upgradeAccount;
    if (!account.profilingCompleted) return setup;
    return home;
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
        path: AppRoutes.tutorial,
        builder: (context, state) =>
            TutorialScreen(replay: state.extra == true),
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
        path: AppRoutes.reportIssue,
        builder: (context, state) => ReportIssueScreen(
          sourceScreen: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: AppRoutes.myReports,
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.voiceCheck,
        builder: (context, state) => const VoiceCheckScreen(),
      ),
      GoRoute(
        path: AppRoutes.werTest,
        builder: (context, state) => const WerTestScreen(),
      ),
      GoRoute(
        path: AppRoutes.offlineVoice,
        builder: (context, state) => OfflineVoiceSetupScreen(
          next: state.extra is OfflineVoiceNext
              ? state.extra! as OfflineVoiceNext
              : const OfflineVoiceNext(AppRoutes.welcome),
        ),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => StartupScreen(
          next: state.extra is OfflineVoiceNext
              ? state.extra! as OfflineVoiceNext
              : const OfflineVoiceNext(AppRoutes.welcome),
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
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) =>
            CameraScreen(forDescription: state.extra == true),
      ),
      GoRoute(
        path: AppRoutes.describeSource,
        builder: (context, state) => const DescribeSourceScreen(),
      ),
      GoRoute(
        path: AppRoutes.describe,
        builder: (context, state) => DescribeScreen(
          subject: state.extra is DescribeSubject
              ? state.extra! as DescribeSubject
              : const SavedDescription(''),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.libraryItem,
        builder: (context, state) => ItemDetailsScreen(
          itemId: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => FavoritesScreen(
          args: state.extra is FavoritesArgs
              ? state.extra! as FavoritesArgs
              : const FavoritesArgs(''),
        ),
      ),
      GoRoute(
        path: AppRoutes.chapters,
        builder: (context, state) => ChaptersScreen(
          itemId: state.extra is String ? state.extra! as String : '',
        ),
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

/// The app-wide router. Starts where the saved session leads: "log in again" if it expired,
/// otherwise the account's home. With no session: the controls tutorial on the first launch
/// (before Welcome, so a new user can learn the controls before registering), then Welcome.
final routerProvider = Provider<GoRouter>((ref) {
  final account = ref.read(initialAccountProvider);
  final expired = ref.read(initialSessionExpiredProvider);
  final tutorialSeen = ref.read(initialTutorialSeenProvider);
  final location = account != null
      ? AppRoutes.landing(account)
      : expired
      ? AppRoutes.authChoice
      : tutorialSeen
      ? AppRoutes.welcome
      : AppRoutes.tutorial;
  final extra = account == null && expired ? true : null;
  // Every cold start: the loading screen first (then the first screen).
  final loading = ref.read(startupScreenProvider);
  final first = loading
      ? OfflineVoiceNext(
          AppRoutes.startup,
          extra: OfflineVoiceNext(location, extra: extra),
        )
      : OfflineVoiceNext(location, extra: extra);
  // First launch: the offline voices are downloaded before anything else.
  final setup = ref.read(offlineVoiceSetupPendingProvider);
  final router = buildRouter(
    initialLocation: setup ? AppRoutes.offlineVoice : first.location,
    initialExtra: setup ? first : first.extra,
  );
  ref.onDispose(router.dispose);
  return router;
});
