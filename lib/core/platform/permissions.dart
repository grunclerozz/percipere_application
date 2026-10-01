import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Runtime permissions the app asks for.
enum AppPermission {
  /// Voice commands.
  microphone,

  /// Document capture.
  camera,
}

/// State of a runtime permission.
enum PermissionAccess {
  /// Allowed.
  granted,

  /// Not (yet) allowed; asking again shows the Android dialog.
  denied,

  /// Blocked; only the app's Settings page can allow it now.
  permanentlyDenied,
}

/// Runtime permissions. Abstract so tests can fake it.
abstract interface class PermissionService {
  /// Current state of [permission], without asking.
  Future<PermissionAccess> status(AppPermission permission);

  /// Shows the Android permission dialog for [permission] if needed.
  Future<PermissionAccess> request(AppPermission permission);

  /// Opens this app's page in Android Settings.
  Future<bool> openAppSettings();
}

/// [PermissionService] via `permission_handler`.
class DevicePermissionService implements PermissionService {
  /// Creates the device implementation.
  const DevicePermissionService();

  static ph.Permission _of(AppPermission p) => switch (p) {
    AppPermission.microphone => ph.Permission.microphone,
    AppPermission.camera => ph.Permission.camera,
  };

  static PermissionAccess _map(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionAccess.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return PermissionAccess.permanentlyDenied;
    }
    return PermissionAccess.denied;
  }

  @override
  Future<PermissionAccess> status(AppPermission permission) async =>
      _map(await _of(permission).status);

  @override
  Future<PermissionAccess> request(AppPermission permission) async =>
      _map(await _of(permission).request());

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}

/// Runtime permission access.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const DevicePermissionService(),
);
