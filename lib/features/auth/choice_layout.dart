import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';

/// One button of a [ChoiceLayout].
class ChoiceButton {
  /// Creates a button for action [id].
  const ChoiceButton(this.id, this.label, {this.primary = false});

  /// Action id.
  final String id;

  /// Label.
  final String label;

  /// Primary (navy) style; otherwise secondary.
  final bool primary;
}

/// The "Nais mo bang mag login?" mockup layout: eye logo, title, Speaking
/// Zone with the question, pill buttons, and the Gesture Pad.
class ChoiceLayout extends ConsumerWidget {
  /// Creates the layout.
  const ChoiceLayout({
    super.key,
    required this.screenId,
    required this.title,
    required this.question,
    required this.buttons,
  });

  /// Screen id.
  final String screenId;

  /// Title ("Login").
  final String title;

  /// Question shown before it is spoken.
  final String question;

  /// Buttons in focus order.
  final List<ChoiceButton> buttons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    return FormScaffold(
      screenId: screenId,
      title: title,
      subtitle: question,
      padHint: AppLocalizations.of(context).helpChooseList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          for (final b in buttons) ...[
            PillButton(
              label: b.label,
              variant: b.primary ? PillVariant.primary : PillVariant.secondary,
              focused: focused == b.id,
              onPressed: () => bus.activate(b.id),
            ),
            const SizedBox(height: AppDimens.buttonGap),
          ],
        ],
      ),
    );
  }
}
