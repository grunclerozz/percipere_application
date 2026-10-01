import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/voice_controller.dart';
import '../../l10n/app_localizations.dart';

/// Spoken number words → digit (Filipino, English, and the Spanish-derived
/// numbers common in the Philippines).
const Map<String, int> _digitWords = {
  'zero': 0, 'sero': 0, 'siro': 0, //
  'one': 1, 'isa': 1, 'uno': 1, //
  'two': 2, 'dalawa': 2, 'dos': 2, //
  'three': 3, 'tatlo': 3, 'tres': 3, //
  'four': 4, 'apat': 4, 'kwatro': 4, 'kuwatro': 4, //
  'five': 5, 'lima': 5, 'singko': 5, 'sinko': 5, //
  'six': 6, 'anim': 6, 'sais': 6, //
  'seven': 7, 'pito': 7, 'siyete': 7, //
  'eight': 8, 'walo': 8, 'otso': 8, //
  'nine': 9, 'siyam': 9, 'nuwebe': 9, 'nueve': 9,
};

/// Digits in a spoken PIN: "isa dalawa tatlo apat", "1 2 3 4", "1234".
List<int> parseDigits(String spoken) {
  final digits = <int>[];
  for (final token in CommandMatcher.tokens(spoken)) {
    if (RegExp(r'^\d+$').hasMatch(token)) {
      digits.addAll(token.split('').map(int.parse));
    } else {
      final d = _digitWords[token];
      if (d != null) digits.add(d);
    }
  }
  return digits;
}

/// Legacy (pre-6B) PIN entry, used only to claim an old name + PIN account
/// once before it sets an email and password.
///
/// State of a four-digit PIN being entered by gestures, keypad or voice.
///
/// Gestures (through the screen's intents): swipe up/down picks the digit on
/// the dial (spoken), double-tap enters it, swipe left deletes the last one,
/// long-press dictates all four. Entered digits are never spoken back — only
/// how many there are.
class PinEntry extends ChangeNotifier {
  /// Creates a PIN entry that calls [onComplete] with four digits.
  PinEntry({required this.onComplete});

  /// PIN length.
  static const int length = 4;

  /// Called with the PIN once four digits are in.
  final Future<void> Function(String pin) onComplete;

  final List<int> _digits = [];
  int _dial = 0;

  /// Digits entered so far.
  int get count => _digits.length;

  /// Digit currently on the dial.
  int get dial => _dial;

  /// Clears everything.
  void clear() {
    _digits.clear();
    _dial = 0;
    notifyListeners();
  }

  /// Screen intent handlers for PIN entry, speaking via [l].
  Map<NavIntent, BusHandler> intents(
    WidgetRef ref,
    AppLocalizations Function() l,
  ) => {
    NavIntent.faster: (bus) => _turn(bus, 1),
    NavIntent.slower: (bus) => _turn(bus, -1),
    NavIntent.activate: (bus) => add(_dial, bus, l()),
    NavIntent.previous: (bus) => deleteLast(bus, l()),
    NavIntent.listen: (bus) => _dictate(ref, bus, l()),
  };

  Future<void> _turn(CommandBus bus, int d) {
    _dial = (_dial + d) % 10;
    notifyListeners();
    return bus.say('$_dial');
  }

  /// Enters [digit].
  Future<void> add(int digit, CommandBus bus, AppLocalizations l) async {
    if (_digits.length >= length) return;
    _digits.add(digit);
    _dial = 0;
    notifyListeners();
    if (_digits.length == length) {
      final pin = _digits.join();
      _digits.clear();
      notifyListeners();
      await onComplete(pin);
    } else {
      await bus.say(l.pinDigitEntered(_digits.length, length));
    }
  }

  /// Removes the last digit.
  Future<void> deleteLast(CommandBus bus, AppLocalizations l) async {
    if (_digits.isEmpty) return bus.notAvailable();
    _digits.removeLast();
    notifyListeners();
    await bus.say(l.pinDeleted);
  }

  /// Takes a whole spoken PIN. Returns false if [spoken] had no digits.
  Future<bool> takeSpoken(
    String spoken,
    CommandBus bus,
    AppLocalizations l,
  ) async {
    final digits = parseDigits(spoken);
    if (digits.isEmpty) return false;
    if (digits.length != length) {
      await bus.say(l.pinSayFour);
      return true;
    }
    _digits.clear();
    notifyListeners();
    await onComplete(digits.join());
    return true;
  }

  Future<void> _dictate(
    WidgetRef ref,
    CommandBus bus,
    AppLocalizations l,
  ) async {
    final said = await ref.read(voiceControllerProvider.notifier).dictate();
    if (said == null) return;
    if (!await takeSpoken(said, bus, l)) await bus.say(l.pinSayFour);
  }
}

/// The PIN display (filled dots, the dial digit) and a keypad for sighted
/// helpers.
class PinPad extends StatelessWidget {
  /// Creates the view for [entry]; keypad presses go to [onDigit] and
  /// [onDelete].
  const PinPad({
    super.key,
    required this.entry,
    required this.onDigit,
    required this.onDelete,
  });

  /// The PIN state.
  final PinEntry entry;

  /// A keypad digit was pressed.
  final void Function(int digit) onDigit;

  /// The delete key was pressed.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: entry,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label:
                '${l10n.fieldPin}: ${l10n.pinDigitEntered(entry.count, PinEntry.length)}',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < PinEntry.length; i++)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < entry.count ? p.primary : Colors.transparent,
                      border: Border.all(color: p.border, width: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Text(
              '${entry.dial}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
            [-1, 0, -2],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: k == -1
                        ? const SizedBox(
                            width: AppDimens.minTouchTarget + 8,
                            height: AppDimens.minTouchTarget,
                          )
                        : _Key(
                            label: k == -2 ? l10n.pinDelete : '$k',
                            icon: k == -2 ? Icons.backspace_outlined : null,
                            onTap: k == -2 ? onDelete : () => onDigit(k),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Listener(
      onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: p.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: AppDimens.minTouchTarget + 8,
              height: AppDimens.minTouchTarget + 8,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: p.onSecondary)
                    : Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: p.onSecondary),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Haptic tick helper for keypad presses.
void tickFor(WidgetRef ref) => unawaited(ref.read(hapticsProvider).tick());
