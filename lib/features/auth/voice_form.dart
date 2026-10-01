import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/action_registry.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/validators.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_commands.dart';
import '../../core/voice/voice_controller.dart';
import '../../l10n/app_localizations.dart';

/// What a form field holds; decides how dictation is cleaned up and how the
/// value is read back.
enum FieldKind {
  /// A first or last name.
  name,

  /// An email address ("at" → @, "dot" → .).
  email,

  /// A password: never shown in the Speaking Zone, never spoken back —
  /// only its length.
  password,

  /// Free text (a security answer).
  text,
}

/// One field of a [VoiceForm].
class VoiceField {
  /// Creates a field.
  VoiceField({
    required this.id,
    required this.kind,
    required this.label,
    required this.prompt,
    String initial = '',
  }) : controller = TextEditingController(text: initial);

  /// Action id (also the focus id), e.g. `register.email`.
  final String id;

  /// Kind of value.
  final FieldKind kind;

  /// Field name, as in the mockup ("Email Address").
  final L10nText label;

  /// The spoken question ("Ano ang iyong email address?").
  final L10nText prompt;

  /// The value (typed or dictated).
  final TextEditingController controller;

  /// Keyboard focus of the text field.
  final FocusNode focusNode = FocusNode();

  /// Current value, trimmed (passwords are kept exactly).
  String get value =>
      kind == FieldKind.password ? controller.text : controller.text.trim();

  /// Whether nothing was entered.
  bool get isEmpty => value.isEmpty;

  /// "Email Address: juan@gmail.com" / "Password: 9 titik" / "First Name,
  /// walang laman".
  String describe(AppLocalizations l) {
    if (isEmpty) return l.formFieldEmpty(label(l));
    return l.formFieldValue(label(l), spokenValue(l));
  }

  /// The value as it may be spoken: passwords only by length.
  String spokenValue(AppLocalizations l) => kind == FieldKind.password
      ? l.formPasswordLength(value.length)
      : value;

  /// Cleans up dictated [heard] for this field.
  String fromSpeech(String heard) => switch (kind) {
    FieldKind.name => AuthRules.spokenName(heard),
    FieldKind.email => AuthRules.spokenEmail(heard),
    FieldKind.password => AuthRules.spokenPassword(heard),
    FieldKind.text => heard.trim(),
  };

  /// Releases the controller and focus node.
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// A spoken form: each field can be dictated or typed.
///
/// - The focused field (accessibility focus) is the one being filled. On
///   entry the first empty field is focused and its question asked.
/// - Anything said that isn't a command fills the focused field; the value
///   is read back (passwords: only the number of characters) and the next
///   empty field is asked.
/// - Swipe right/left (or "susunod"/"nakaraan") moves between fields;
///   long-press dictates the focused field; single tap repeats its question.
/// - Double-tap on the Gesture Pad, or "submit" / "tapos na", submits.
class VoiceForm {
  /// Creates a form over [fields]; [onSubmit] runs when the user submits.
  VoiceForm({
    required this.ref,
    required this.fields,
    required this.onSubmit,
  });

  /// For the bus, focus and voice controller.
  final WidgetRef ref;

  /// The fields, in order.
  final List<VoiceField> fields;

  /// Submits (validation is the screen's job).
  final Future<void> Function(CommandBus bus) onSubmit;

  /// Phrases that submit the form.
  static const List<String> submitPhrases = [
    'submit',
    'tapos na',
    'tapos',
    'ipasa',
    'isumite',
    'done',
  ];

  /// Phrases that clear the focused field.
  static const List<String> clearPhrases = ['burahin', 'linisin', 'clear'];

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;

  /// The focused field, if any.
  VoiceField? get focused {
    final id = ref.read(focusControllerProvider);
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Whether anything was entered (back then asks first).
  bool get hasInput => fields.any((f) => !f.isEmpty);

  /// The first field without a value.
  VoiceField? get firstEmpty {
    for (final f in fields) {
      if (f.isEmpty) return f;
    }
    return null;
  }

  /// Focuses [field] (or the first empty one) without speaking; returns the
  /// question to ask, or the "complete" hint when everything is filled.
  String focusStart(AppLocalizations l) {
    final f = firstEmpty;
    _focus(f);
    return f == null ? l.formComplete(l.formSubmitHint) : f.prompt(l);
  }

  void _focus(VoiceField? f) {
    ref.read(focusControllerProvider.notifier).focus(f?.id);
    ref.read(voiceControllerProvider.notifier).sensitive =
        f?.kind == FieldKind.password;
  }

  /// Focuses [f] and asks its question.
  Future<void> ask(VoiceField f, CommandBus bus) {
    _focus(f);
    return bus.say(f.isEmpty ? f.prompt(_l) : _l.formChange(f.describe(_l)));
  }

  /// Fills the focused field with [text] (spoken or typed), reads it back
  /// and asks the next empty field.
  Future<void> fill(VoiceField f, String text, CommandBus bus) async {
    f.controller.text = text;
    unawaited(ref.read(hapticsProvider).tick());
    final next = firstEmpty;
    _focus(next);
    final l = _l;
    final readback = l.formHeard(f.label(l), f.spokenValue(l));
    final then = next == null
        ? l.formComplete(l.formSubmitHint)
        : next.prompt(l);
    await bus.say('$readback $then');
  }

  /// A text field finished typing: read it back and move on.
  Future<void> typed(VoiceField f) async {
    if (f.isEmpty) return;
    await fill(f, f.controller.text, ref.read(commandBusProvider));
    final next = firstEmpty;
    if (next != null) {
      next.focusNode.requestFocus();
    } else {
      f.focusNode.unfocus();
    }
  }

  /// Takes free speech for the focused field. Returns false for commands
  /// (so the bus runs them) and when no field is focused.
  Future<bool> onUtterance(String text, CommandBus bus) async {
    final f = focused;
    if (f == null || _isCommand(text, bus.activeScreen)) return false;
    await fill(f, f.fromSpeech(text), bus);
    return true;
  }

  /// Exact command phrases win over dictation ("tapos na" submits, it is
  /// never someone's name); anything else is a value.
  static bool _isCommand(String text, ScreenRegistration? screen) {
    final said = CommandMatcher.normalize(text);
    bool same(String phrase) => CommandMatcher.normalize(phrase) == said;
    if (submitPhrases.any(same) || clearPhrases.any(same)) return true;
    for (final list in globalVoiceCommands.values) {
      if (list.any(same)) return true;
    }
    for (final a in screen?.actions ?? const <A11yAction>[]) {
      if (a.voiceSynonyms.any(same)) return true;
    }
    return false;
  }

  /// Long-press: dictate the focused field (or the first empty one).
  Future<void> dictate(CommandBus bus) async {
    final f = focused ?? firstEmpty ?? fields.first;
    _focus(f);
    await bus.say(f.prompt(_l));
    final heard = await ref.read(voiceControllerProvider.notifier).dictate();
    if (heard == null || heard.trim().isEmpty) return;
    if (_isCommand(heard, bus.activeScreen)) {
      return bus.handleUtterance(heard);
    }
    await fill(f, f.fromSpeech(heard), bus);
  }

  /// Clears the focused field.
  Future<void> clear(CommandBus bus) async {
    final f = focused;
    if (f == null) return bus.notAvailable();
    f.controller.clear();
    await bus.say(_l.formCleared(f.label(_l), f.prompt(_l)));
  }

  /// Field actions (focus order) plus Submit and Clear.
  List<A11yAction> actions(String submitId) => [
    for (final f in fields)
      A11yAction(
        id: f.id,
        label: (l) => f.describe(l),
        confirmation: (_) => '',
        onActivate: (bus) => ask(f, bus),
      ),
    A11yAction(
      id: submitId,
      label: (l) => l.actionSubmit,
      voiceSynonyms: submitPhrases,
      confirmation: (_) => '',
      onActivate: onSubmit,
    ),
    A11yAction(
      id: '$submitId.clear',
      label: (l) => l.actionClear,
      voiceSynonyms: clearPhrases,
      focusable: false,
      confirmation: (_) => '',
      onActivate: clear,
    ),
  ];

  /// Gesture behavior on a form screen.
  Map<NavIntent, BusHandler> intents() => {
    NavIntent.activate: onSubmit,
    NavIntent.listen: dictate,
    NavIntent.repeat: (bus) {
      final f = focused;
      if (f == null) return bus.announceScreen(bus.activeScreen!);
      return bus.say(f.isEmpty ? f.prompt(_l) : _l.formChange(f.describe(_l)));
    },
  };

  /// Ends password privacy and releases the fields.
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
  }
}

/// Speaks validation problems and focuses the first bad field.
Future<void> reportInvalid(
  VoiceForm form,
  VoiceField field,
  String message,
  CommandBus bus,
  WidgetRef ref,
) async {
  unawaited(ref.read(hapticsProvider).error());
  ref.read(focusControllerProvider.notifier).focus(field.id);
  ref.read(voiceControllerProvider.notifier).sensitive =
      field.kind == FieldKind.password;
  await bus.say(message);
}

/// The pill-shaped text field from the mockups. Tapping it focuses the field
/// (for typing); finishing typing reads the value back.
class VoiceTextField extends ConsumerWidget {
  /// Creates the field view for [field] of [form].
  const VoiceTextField({super.key, required this.form, required this.field});

  /// The form.
  final VoiceForm form;

  /// The field.
  final VoiceField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider) == field.id;
    final password = field.kind == FieldKind.password;
    OutlineInputBorder border(double width, Color color) => OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      borderSide: BorderSide(color: color, width: width),
    );

    return Listener(
      onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
      child: TextField(
        controller: field.controller,
        focusNode: field.focusNode,
        obscureText: password,
        enableSuggestions: !password,
        autocorrect: false,
        textAlign: TextAlign.center,
        keyboardType: switch (field.kind) {
          FieldKind.email => TextInputType.emailAddress,
          FieldKind.password => TextInputType.visiblePassword,
          FieldKind.name => TextInputType.name,
          FieldKind.text => TextInputType.text,
        },
        textCapitalization: field.kind == FieldKind.name
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: field.label(l10n),
          isDense: true,
          constraints: const BoxConstraints(
            minHeight: AppDimens.minTouchTarget,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: border(
            focused ? 3 : AppDimens.panelBorderWidth,
            focused ? p.focusRing : p.border,
          ),
          focusedBorder: border(3, p.focusRing),
        ),
        onTap: () {
          ref.read(focusControllerProvider.notifier).focus(field.id);
          ref.read(voiceControllerProvider.notifier).sensitive = password;
        },
        onSubmitted: (_) => unawaited(form.typed(field)),
      ),
    );
  }
}

/// Fields of [form] that should share a row (First/Last Name).
typedef FieldRow = List<VoiceField>;

/// The fields laid out as in the mockups, then a Submit button.
class VoiceFormView extends ConsumerWidget {
  /// Creates the view; [rows] groups fields per line.
  const VoiceFormView({
    super.key,
    required this.form,
    required this.rows,
    required this.submitId,
    required this.submit,
  });

  /// The form.
  final VoiceForm form;

  /// Fields per row.
  final List<FieldRow> rows;

  /// Submit action id.
  final String submitId;

  /// The Submit button.
  final Widget submit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          if (row.length == 1)
            VoiceTextField(form: form, field: row.single)
          else
            Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: VoiceTextField(form: form, field: row[i]),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
        submit,
      ],
    );
  }
}

/// Watches the active screen and focuses the first empty field once
/// [screenId] is active.
void focusFirstFieldWhenActive(
  WidgetRef ref,
  String screenId,
  VoiceForm Function() form,
) {
  ref.listenManual(activeScreenProvider, (previous, next) {
    if (next?.id == screenId && previous?.id != screenId) {
      scheduleMicrotask(() => form().focusStart(ref.read(commandBusProvider).strings));
    }
  });
}
