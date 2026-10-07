import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import '../upload/document_picker.dart';
import 'describe_controller.dart';

/// Maglarawan, step 1: where the picture comes from — the camera (with its
/// audio guidance) or an uploaded image.
class DescribeSourceScreen extends ConsumerWidget {
  /// Creates the screen.
  const DescribeSourceScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.describeSource;

  static ScreenRegistration _registration(WidgetRef ref) {
    Future<void> upload(CommandBus bus) async {
      final l = bus.strings;
      await bus.say(l.uploadOpening, protect: true);
      final result = await ref.read(documentPickerProvider).pickImage();
      switch (result) {
        case Picked(:final file):
          unawaited(
            ref
                .read(routerProvider)
                .push(AppRoutes.describe, extra: NewImage(file.path)),
          );
        case PickCancelled():
          await bus.say(l.uploadCancelled);
        case PickUnsupported():
          await bus.notAvailable();
          await bus.say(l.readerUnsupported);
        case PickFailed():
          await bus.notAvailable();
          await bus.say(l.uploadFailed);
      }
    }

    return ScreenRegistration(
      id: screenId,
      title: (l) => l.screenDescribe,
      prompt: (l) => l.describeSourcePrompt,
      actions: [
        A11yAction(
          id: Ids.describeSourceCamera,
          label: (l) => l.captureCamera,
          voiceSynonyms: const ['camera', 'kamera'],
          onActivate: (_) => unawaited(
            ref.read(routerProvider).push(AppRoutes.camera, extra: true),
          ),
        ),
        A11yAction(
          id: Ids.describeSourceUpload,
          label: (l) => l.captureUpload,
          voiceSynonyms: const ['mag-upload', 'upload', 'i-upload'],
          onActivate: upload,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);

    return AccessibleScreen(
      registration: _registration,
      child: GesturePadLayout(
        padHint: l10n.gestureAreaHintMenu,
        content: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  LiveSpeakingZone(
                    screenId: screenId,
                    fallback: l10n.describeSourcePrompt,
                  ),
                  const SizedBox(height: 32),
                  const Spacer(flex: 2),
                  PillButton(
                    label: l10n.captureCamera,
                    focused: focused == Ids.describeSourceCamera,
                    onPressed: () => bus.activate(Ids.describeSourceCamera),
                  ),
                  const SizedBox(height: AppDimens.buttonGap),
                  PillButton(
                    label: l10n.captureUpload,
                    variant: PillVariant.secondary,
                    focused: focused == Ids.describeSourceUpload,
                    onPressed: () => bus.activate(Ids.describeSourceUpload),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
