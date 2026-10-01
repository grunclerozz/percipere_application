import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/guest_reminder_on_entry.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/small_link.dart';
import '../../l10n/app_localizations.dart';
import '../reader/reader_controller.dart';
import '../upload/document_picker.dart';

/// Screen B — Capture method: upload a file or use the camera.
///
/// "Mag-upload" opens the system file picker (JPG/PNG/PDF/DOCX) and then the
/// Reader; "Gamit ang Camera" opens the guided camera.
class CaptureScreen extends ConsumerWidget {
  /// Creates the Capture screen.
  const CaptureScreen({super.key});

  /// Screen id.
  static const String screenId = Ids.capture;

  /// Action: upload a file.
  static const String uploadAction = Ids.captureUpload;

  /// Action: capture with the camera.
  static const String cameraAction = Ids.captureCamera;

  static ScreenRegistration _registration(WidgetRef ref) {
    Future<void> upload(CommandBus bus) async {
      final l = bus.strings;
      // Said before the system picker covers the app.
      await bus.say(l.uploadOpening, protect: true);
      final result = await ref.read(documentPickerProvider).pickDocument();
      switch (result) {
        case Picked(:final file):
          unawaited(
            ref
                .read(routerProvider)
                .push(AppRoutes.reader, extra: FileSource(file)),
          );
        case PickCancelled():
          await bus.say(l.uploadCancelled);
        case PickUnsupported():
          await bus.notAvailable();
          await bus.say(l.readerUnsupported);
      }
    }

    void camera(CommandBus _) =>
        unawaited(ref.read(routerProvider).push(AppRoutes.camera));

    return ScreenRegistration(
      id: screenId,
      title: (l) => l.screenCapture,
      prompt: (l) => l.capturePrompt,
      actions: [
        A11yAction(
          id: uploadAction,
          label: (l) => l.captureUpload,
          voiceSynonyms: const ['mag-upload', 'upload', 'i-upload'],
          onActivate: upload,
        ),
        A11yAction(
          id: cameraAction,
          label: (l) => l.captureCamera,
          voiceSynonyms: const ['camera', 'kamera'],
          onActivate: camera,
        ),
        A11yAction(
          id: Ids.captureHistory,
          label: (l) => l.captureHistory,
          voiceSynonyms: const ['kasaysayan', 'history'],
          onActivate: (bus) => bus.dispatch(NavIntent.history),
        ),
        A11yAction(
          id: Ids.captureSettings,
          label: (l) => l.captureSettings,
          voiceSynonyms: const ['settings', 'setting', 'ayos'],
          onActivate: (bus) => bus.dispatch(NavIntent.settings),
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
      child: GuestReminderOnEntry(
        screenId: screenId,
        moment: GuestReminderMoment.history,
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
                      fallback: l10n.capturePrompt,
                    ),
                    const SizedBox(height: 32),
                    const Spacer(flex: 2),
                    PillButton(
                      label: l10n.captureUpload,
                      focused: focused == uploadAction,
                      onPressed: () => bus.activate(uploadAction),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                    PillButton(
                      label: l10n.captureCamera,
                      variant: PillVariant.secondary,
                      focused: focused == cameraAction,
                      onPressed: () => bus.activate(cameraAction),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                    // Secondary destinations, smaller than the two main
                    // choices from the design.
                    // Stacked, not side by side: labels like "Kasaysayan" must
                    // never wrap mid-word, at any text size.
                    SmallLink(
                      label: l10n.captureHistory,
                      icon: Icons.history,
                      focused: focused == Ids.captureHistory,
                      onPressed: () => bus.activate(Ids.captureHistory),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                    SmallLink(
                      label: l10n.captureSettings,
                      icon: Icons.tune,
                      focused: focused == Ids.captureSettings,
                      onPressed: () => bus.activate(Ids.captureSettings),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
