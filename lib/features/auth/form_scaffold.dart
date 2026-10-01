import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../core/widgets/eye_logo.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../l10n/app_localizations.dart';

/// The layout of the Register / Login mockups: eye logo, title, Speaking
/// Zone, the form, and the Gesture Pad below. Scrolls when the text is
/// large.
class FormScaffold extends StatelessWidget {
  /// Creates the layout.
  const FormScaffold({
    super.key,
    required this.screenId,
    required this.title,
    required this.subtitle,
    required this.child,
    this.padHint,
  });

  /// Screen id (for the live subtitle).
  final String screenId;

  /// "Register", "Login".
  final String title;

  /// What the Speaking Zone shows before anything is spoken.
  final String subtitle;

  /// The form (fields and buttons).
  final Widget child;

  /// Screen-reader hint for the Gesture Pad; defaults to the form hint.
  final String? padHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GesturePadLayout(
      padHint: padHint ?? l10n.formSubmitHint,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EyeLogo(),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: context.palette.primary),
              ),
            ),
            const SizedBox(height: 10),
            LiveSpeakingZone(screenId: screenId, fallback: subtitle),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
