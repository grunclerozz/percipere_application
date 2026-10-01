import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// A local account (or the device's guest profile).
@immutable
class Account {
  /// Creates an account.
  const Account({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.email,
    this.isGuest = false,
    this.isLegacy = false,
    this.profilingCompleted = false,
    this.fingerprintEnabled = false,
    this.securityQuestion,
    this.synced = false,
    this.serverId,
  });

  /// `users.id` (UUID).
  final String id;

  /// First name.
  final String firstName;

  /// Last name.
  final String lastName;

  /// Email = username (unique on the device). Null for guests and legacy
  /// PIN accounts that haven't set one yet.
  final String? email;

  /// The device's "Subukan muna" profile: never synced, no password.
  final bool isGuest;

  /// An old name + PIN account that must set an email and password.
  final bool isLegacy;

  /// Finished the guided setup at least once.
  final bool profilingCompleted;

  /// Fingerprint login turned on.
  final bool fingerprintEnabled;

  /// Id of the security question (see [SecurityQuestion]), if set.
  final String? securityQuestion;

  /// The web app has this version (Phase 7).
  final bool synced;

  /// Id on the web app, once synced.
  final String? serverId;

  /// "Juan dela Cruz".
  String get name => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.email == email &&
      other.isGuest == isGuest &&
      other.isLegacy == isLegacy &&
      other.profilingCompleted == profilingCompleted &&
      other.fingerprintEnabled == fingerprintEnabled &&
      other.securityQuestion == securityQuestion &&
      other.synced == synced &&
      other.serverId == serverId;

  @override
  int get hashCode => Object.hash(
    id,
    firstName,
    lastName,
    email,
    isGuest,
    isLegacy,
    profilingCompleted,
    fingerprintEnabled,
    securityQuestion,
    synced,
    serverId,
  );
}

/// The security questions offered at registration (spoken list).
enum SecurityQuestion {
  /// Name of the first pet.
  firstPet,

  /// Town of birth.
  birthTown,

  /// Mother's maiden name.
  motherMaidenName,

  /// First school.
  firstSchool,

  /// Favorite food.
  favoriteFood;

  /// The question text.
  String text(AppLocalizations l) => switch (this) {
    firstPet => l.securityQFirstPet,
    birthTown => l.securityQBirthTown,
    motherMaidenName => l.securityQMotherMaiden,
    firstSchool => l.securityQFirstSchool,
    favoriteFood => l.securityQFavoriteFood,
  };

  /// Parses a stored id, or null.
  static SecurityQuestion? tryParse(String? id) {
    for (final q in values) {
      if (q.name == id) return q;
    }
    return null;
  }
}
