import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'voice_form.dart';

/// Short voice keywords for each question.
const Map<SecurityQuestion, List<String>> _keywords = {
  SecurityQuestion.firstPet: ['alaga', 'hayop', 'pet'],
  SecurityQuestion.birthTown: ['bayan', 'sinilangan', 'town', 'birthplace'],
  SecurityQuestion.motherMaidenName: ['nanay', 'ina', 'dalaga', 'mother'],
  SecurityQuestion.firstSchool: ['paaralan', 'eskwelahan', 'school'],
  SecurityQuestion.favoriteFood: ['pagkain', 'paborito', 'food'],
};

/// Right after registering: choose a security question from a short spoken
/// list (swipe + double-tap, or say it), then answer it by voice or typing.
/// The answer is stored normalized and hashed; it lets the user reset a
/// forgotten password.
class SecurityQuestionScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SecurityQuestionScreen({super.key});

  @override
  ConsumerState<SecurityQuestionScreen> createState() =>
      _SecurityQuestionScreenState();
}

class _SecurityQuestionScreenState
    extends ConsumerState<SecurityQuestionScreen> {
  SecurityQuestion? _question;
  bool _busy = false;
  late final VoiceField _answer = VoiceField(
    id: 'security.answer',
    kind: FieldKind.text,
    label: (l) => l.fieldAnswer,
    prompt: (l) => _question == null ? '' : l.askAnswer(_question!.text(l)),
  );
  late final VoiceForm _form = VoiceForm(
    ref: ref,
    fields: [_answer],
    onSubmit: _submit,
  );

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  /// The answer step has its own screen id, so it is announced (with the
  /// question) as soon as it registers.
  void _choose(SecurityQuestion q) => setState(() => _question = q);

  Future<void> _submit(CommandBus bus) async {
    final q = _question;
    final account = ref.read(currentAccountProvider);
    if (_busy || q == null || account == null) return;
    final l = bus.strings;
    if (_answer.isEmpty) {
      return reportInvalid(
        _form,
        _answer,
        l.formMissing(l.fieldAnswer),
        bus,
        ref,
      );
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .setSecurityAnswer(account.id, q, _answer.value);
      await ref.read(currentAccountProvider.notifier).refresh();
      unawaited(ref.read(hapticsProvider).confirm());
      await bus.say(l.securitySaved, protect: true);
      if (!mounted) return;
      final fingerprint = await ref.read(biometricsProvider).available();
      if (!mounted) return;
      ref
          .read(routerProvider)
          .go(fingerprint ? AppRoutes.fingerprintOffer : AppRoutes.setup);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final q = _question;
    if (q == null) {
      return ScreenRegistration(
        id: Ids.securityQuestion,
        title: (l) => l.screenSecurityQuestion,
        prompt: (l) => l.securityChoose,
        autoListen: true,
        includeModeHint: false,
        help: (l) => l.helpChooseList,
        actions: [
          for (final question in SecurityQuestion.values)
            A11yAction(
              id: 'security.${question.name}',
              label: question.text,
              voiceSynonyms: _keywords[question]!,
              confirmation: (_) => '',
              onActivate: (_) => _choose(question),
            ),
        ],
        intentHandlers: {
          // The account exists already; a question is needed to reset it.
          NavIntent.back: (bus) => bus.say(bus.strings.securityRequired),
        },
      );
    }
    return ScreenRegistration(
      id: '${Ids.securityQuestion}.answer',
      title: (l) => l.screenSecurityQuestion,
      prompt: (l) => _form.focusStart(l),
      autoListen: true,
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpForm,
      onUtterance: _form.onUtterance,
      actions: _form.actions(Ids.securitySubmit),
      intentHandlers: {
        ..._form.intents(),
        NavIntent.back: (bus) {
          _answer.controller.clear();
          setState(() => _question = null);
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focusedId = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final q = _question;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [q],
      child: FormScaffold(
        screenId: q == null
            ? Ids.securityQuestion
            : '${Ids.securityQuestion}.answer',
        title: l10n.screenSecurityQuestion,
        subtitle: q == null
            ? l10n.securityChoose
            : l10n.askAnswer(q.text(l10n)),
        padHint: q == null ? l10n.helpChooseList : null,
        child: q == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final question in SecurityQuestion.values) ...[
                    PillButton(
                      label: question.text(l10n),
                      variant: PillVariant.secondary,
                      focused: focusedId == 'security.${question.name}',
                      onPressed: () =>
                          bus.activate('security.${question.name}'),
                    ),
                    const SizedBox(height: AppDimens.buttonGap),
                  ],
                ],
              )
            : VoiceFormView(
                form: _form,
                rows: [
                  [_answer],
                ],
                submitId: Ids.securitySubmit,
                submit: PillButton(
                  label: l10n.actionSubmit,
                  focused: focusedId == Ids.securitySubmit,
                  onPressed: _busy
                      ? null
                      : () => bus.activate(Ids.securitySubmit),
                ),
              ),
      ),
    );
  }
}
