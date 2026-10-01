import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/router.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'account_repository.dart';
import 'pin_input.dart';

enum _Step { name, email, pin, confirm }

/// Creating a profile, one spoken step at a time: name → email (optional)
/// → PIN → confirm PIN. Name and email can be dictated (long-press) or
/// typed; the PIN by gestures, keypad or voice. The new profile starts with
/// the current settings and is logged in.
class CreateProfileScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  _Step _step = _Step.name;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String? _firstPin;
  late final PinEntry _pin = PinEntry(onComplete: _onPin);

  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  CommandBus get _bus => ref.read(commandBusProvider);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  String _prompt(AppLocalizations l) => switch (_step) {
    _Step.name => l.profileAskName,
    _Step.email => l.profileAskEmail,
    _Step.pin => l.profileAskPin,
    _Step.confirm => l.profileConfirmPin,
  };

  Future<void> _goTo(_Step step) async {
    setState(() => _step = step);
    _pin.clear();
    await _bus.say(_prompt(_l));
  }

  Future<void> _dictateName(CommandBus bus) async {
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (said == null || !mounted) return;
    _name.text = said.trim();
    await bus.say(_l.profileNameIs(_name.text));
  }

  Future<void> _dictateEmail(CommandBus bus) async {
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (said == null || !mounted) return;
    _email.text = normalizeSpokenEmail(said);
    await bus.say(_l.profileEmailIs(_email.text));
  }

  Future<void> _continue(CommandBus bus) async {
    switch (_step) {
      case _Step.name:
        if (_name.text.trim().isEmpty) {
          unawaited(ref.read(hapticsProvider).error());
          return bus.say(_l.profileNameMissing);
        }
        return _goTo(_Step.email);
      case _Step.email:
        return _goTo(_Step.pin);
      case _Step.pin:
      case _Step.confirm:
        return bus.notAvailable();
    }
  }

  Future<void> _onPin(String pin) async {
    if (_step == _Step.pin) {
      _firstPin = pin;
      return _goTo(_Step.confirm);
    }
    if (pin != _firstPin) {
      unawaited(ref.read(hapticsProvider).error());
      await _bus.say(_l.profilePinMismatch);
      _firstPin = null;
      setState(() => _step = _Step.pin);
      return;
    }
    final account = await ref
        .read(accountRepositoryProvider)
        .create(name: _name.text, email: _email.text, pin: pin);
    await ref.read(currentAccountProvider.notifier).login(account);
    unawaited(ref.read(hapticsProvider).confirm());
    await _bus.say(_l.accountCreated(account.name), protect: true);
    if (mounted) ref.read(routerProvider).pop();
  }

  ScreenRegistration _registration(WidgetRef ref) {
    final step = _step;
    final entering = step == _Step.pin || step == _Step.confirm;
    return ScreenRegistration(
      id: Ids.createProfile,
      title: (l) => l.screenCreateProfile,
      prompt: _prompt,
      listOptions: false,
      includeModeHint: false,
      help: entering ? (l) => l.helpPin : null,
      onUtterance: (text, bus) async {
        if (entering) return _pin.takeSpoken(text, bus, _l);
        return false;
      },
      actions: [
        if (!entering)
          A11yAction(
            id: 'profile.continue',
            label: (l) => l.actionContinue,
            voiceSynonyms: const ['ituloy', 'susunod', 'continue', 'next'],
            confirmation: (_) => '',
            onActivate: _continue,
          ),
        if (step == _Step.email)
          A11yAction(
            id: 'profile.skip',
            label: (l) => l.actionSkip,
            voiceSynonyms: const ['laktawan', 'skip', 'wala'],
            confirmation: (_) => '',
            onActivate: (_) {
              _email.clear();
              return _goTo(_Step.pin);
            },
          ),
      ],
      intentHandlers: entering
          ? _pin.intents(ref, () => _l)
          : {
              NavIntent.activate: _continue,
              NavIntent.listen: step == _Step.name
                  ? _dictateName
                  : _dictateEmail,
              if (step == _Step.email)
                NavIntent.next: (_) {
                  _email.clear();
                  return _goTo(_Step.pin);
                },
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bus = ref.read(commandBusProvider);
    final entering = _step == _Step.pin || _step == _Step.confirm;

    return AccessibleScreen(
      registration: _registration,
      dependencies: [_step],
      child: GesturePadLayout(
        padHint: entering ? l10n.helpPin : l10n.gestureAreaHintMenu,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.screenCreateProfile,
                  style: textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_prompt(l10n), style: textTheme.bodyLarge),
              ),
              const SizedBox(height: 16),
              if (_step == _Step.name)
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.fieldName,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _continue(bus),
                ),
              if (_step == _Step.email)
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.fieldEmail,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _continue(bus),
                ),
              if (entering)
                PinPad(
                  entry: _pin,
                  onDigit: (d) {
                    tickFor(ref);
                    unawaited(_pin.add(d, bus, _l));
                  },
                  onDelete: () => unawaited(_pin.deleteLast(bus, _l)),
                ),
              if (!entering) ...[
                const SizedBox(height: 16),
                PillButton(
                  label: l10n.actionContinue,
                  onPressed: () => bus.activate('profile.continue'),
                ),
              ],
              if (_step == _Step.email) ...[
                const SizedBox(height: AppDimens.buttonGap),
                PillButton(
                  label: l10n.actionSkip,
                  variant: PillVariant.secondary,
                  onPressed: () => bus.activate('profile.skip'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
