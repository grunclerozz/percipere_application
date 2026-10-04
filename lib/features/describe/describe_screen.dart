import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/widgets/document_box.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import 'describe_controller.dart';

/// The Description screen: the picture's thumbnail and the description in the
/// Document Box, the options on the Gesture Pad.
///
/// Swipe right/left moves between options and double-tap uses one — ulitin,
/// mas detalyado, basahin ang teksto (only if text was found), i-save,
/// bagong larawan — or say them. Pinch the box, tap A−/A+ or say
/// "palakihin" / "paliitin" to resize the text, as in the Reader.
class DescribeScreen extends ConsumerWidget {
  /// Creates the screen for [subject].
  const DescribeScreen({super.key, required this.subject});

  /// Screen id.
  static const String screenId = Ids.describe;

  /// The picture (or saved description) shown.
  final DescribeSubject subject;

  ScreenRegistration _registration(WidgetRef ref) {
    final provider = describeControllerProvider(subject);
    DescribeController controller() => ref.read(provider.notifier);
    final hasText = ref.read(provider).foundText != null;
    return ScreenRegistration(
      id: screenId,
      title: (l) => l.screenDescribe,
      // The description itself is spoken by the controller when it is ready.
      prompt: (l) => '',
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpDescribe,
      actions: [
        A11yAction(
          id: Ids.describeRepeat,
          label: (l) => l.describeRepeat,
          voiceSynonyms: const ['ulitin', 'repeat', 'ulit'],
          confirmation: (_) => '',
          onActivate: (_) => controller().repeat(),
        ),
        A11yAction(
          id: Ids.describeMore,
          label: (l) => l.describeMore,
          voiceSynonyms: const ['mas detalyado', 'more detail', 'detalyado'],
          onActivate: (_) => controller().requestDetail(),
        ),
        A11yAction(
          id: Ids.describeReadText,
          label: (l) => l.describeReadText,
          voiceSynonyms: const [
            'basahin ang teksto',
            'read the text',
            'read text',
          ],
          focusable: hasText,
          onActivate: (_) => controller().readText(),
        ),
        A11yAction(
          id: Ids.describeSave,
          label: (l) => l.describeSave,
          voiceSynonyms: const ['i-save', 'save', 'itago'],
          onActivate: (_) => controller().save(),
        ),
        A11yAction(
          id: Ids.describeNew,
          label: (l) => l.describeNew,
          voiceSynonyms: const [
            'bagong larawan',
            'new picture',
            'another picture',
          ],
          onActivate: (_) async => controller().newPicture(),
        ),
      ],
      intentHandlers: {
        NavIntent.repeat: (_) => controller().repeat(),
        NavIntent.textBigger: (_) => controller().changeTextSize(1),
        NavIntent.textSmaller: (_) => controller().changeTextSize(-1),
        NavIntent.save: (_) => controller().save(),
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(describeControllerProvider(subject));
    final ready = s.phase == DescribePhase.ready;
    final picture = s.picturePath;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [s.phase, s.foundText != null],
      child: GesturePadLayout(
        padHint: l10n.gestureAreaHintMenu,
        content: DocumentBox(
          text: ready ? s.fullText : null,
          isLoading: s.phase == DescribePhase.working,
          loadingMessage: l10n.describeWorking,
          emptyMessage: s.phase == DescribePhase.failed
              ? l10n.describeUnreadable
              : null,
          caption: s.caption,
          header: picture == null
              ? null
              : Semantics(
                  image: true,
                  label: l10n.describeThumbnailLabel,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Image.file(
                        File(picture),
                        fit: BoxFit.contain,
                        cacheWidth: 640,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
          onTextSize: ready
              ? (direction) => ref
                    .read(commandBusProvider)
                    .dispatch(
                      direction > 0
                          ? NavIntent.textBigger
                          : NavIntent.textSmaller,
                    )
              : null,
        ),
      ),
    );
  }
}
