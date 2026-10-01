import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/settings_controller.dart';
import '../features/account/account_screen.dart';
import '../features/account/create_profile_screen.dart';
import '../features/account/login_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/history/history_screen.dart';
import '../features/reader/reader_controller.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/welcome/welcome_screen.dart';

/// Route paths. Use these instead of string literals.
abstract final class AppRoutes {
  /// Welcome / navigation mode selection.
  static const String welcome = '/';

  /// Capture method (upload or camera).
  static const String capture = '/capture';

  /// Camera capture with audio guidance.
  static const String camera = '/camera';

  /// Reader. Pass a `ReaderSource` (or plain text) as `extra`.
  static const String reader = '/reader';

  /// Accessibility Settings.
  static const String settings = '/settings';

  /// Reading History.
  static const String history = '/history';

  /// Account (profile, login, logout).
  static const String account = '/account';

  /// Create a profile.
  static const String createProfile = '/account/create';

  /// Log in.
  static const String login = '/account/login';
}

/// Builds the app router.
GoRouter buildRouter({String initialLocation = AppRoutes.welcome}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
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
        path: AppRoutes.account,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.createProfile,
        builder: (context, state) => const CreateProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
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

/// The app-wide router. Starts on Welcome until a navigation mode has been
/// chosen, then on Capture.
final routerProvider = Provider<GoRouter>((ref) {
  final chosen = ref.read(settingsProvider).navMode != null;
  final router = buildRouter(
    initialLocation: chosen ? AppRoutes.capture : AppRoutes.welcome,
  );
  ref.onDispose(router.dispose);
  return router;
});
