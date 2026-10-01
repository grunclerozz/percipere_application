import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_repository.dart';
import 'setting_items.dart';

/// Accessibility Settings.
///
/// Swipe right/left moves between settings (each spoken with its value);
/// swipe up/down changes the focused one; double-tap cycles it or opens it.
/// Every change is saved at once and spoken back — reading speed at the new
/// speed. Rows also have −/+ buttons for sighted helpers, and TalkBack users
/// get standard adjustable controls.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the Settings screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<String, GlobalKey> _rowKeys = {
    for (final item in settingItems) item.id: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    // Keep the focused row in view.
    ref.listenManual(focusControllerProvider, (_, id) {
      final ctx = _rowKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  static SettingContext _shifted(SettingContext c, SettingItem item, int d) =>
      SettingContext(item.adjust!(c.settings, d), c.l, c.ref);

  SettingContext _context(AppLocalizations l) =>
      SettingContext(ref.read(settingsProvider), l, ref);

  /// Changes [item] one step in [direction] and speaks the result.
  Future<void> _change(SettingItem item, int direction) async {
    final adjust = item.adjust;
    if (adjust == null) return;
    ref.read(focusControllerProvider.notifier).focus(item.id);
    final before = ref.read(settingsProvider);
    final after = adjust(before, direction);
    final haptics = ref.read(hapticsProvider);
    if (after == before) {
      unawaited(haptics.error()); // at the limit
    } else {
      await ref.read(settingsProvider.notifier).update((_) => after);
      unawaited(ref.read(hapticsProvider).tick());
    }
    if (!mounted) return;
    // Spoken in the (possibly new) language; speed at the new speed.
    final l = ref.read(speechLanguageProvider).strings;
    await ref
        .read(announcerProvider.notifier)
        .say(
          l.settingValue(item.label(l), item.value(_context(l))),
          rate: item.id == Ids.settingReadingRate ? after.readingRate : 1.0,
        );
    if (after.navMode == NavMode.voice && before.navMode != NavMode.voice) {
      await ref
          .read(voiceControllerProvider.notifier)
          .ensureReady(requestPermission: true);
    }
  }

  Future<void> _activate(SettingItem item, CommandBus bus) async {
    if (item.kind == SettingKind.link) {
      ref.read(focusControllerProvider.notifier).focus(item.id);
      await item.open!(ref, bus);
    } else {
      await _change(item, 1);
    }
  }

  Future<void> _adjustFocused(CommandBus bus, int direction) async {
    final id = ref.read(focusControllerProvider);
    final item = settingItems.where((i) => i.id == id).firstOrNull;
    if (item == null) {
      unawaited(ref.read(hapticsProvider).error());
      return bus.say(bus.strings.nothingFocused);
    }
    if (item.kind == SettingKind.link) return bus.notAvailable();
    return _change(item, direction);
  }

  ScreenRegistration _registration(WidgetRef ref) => ScreenRegistration(
    id: Ids.settings,
    title: (l) => l.screenSettings,
    prompt: (l) => l.settingsIntro,
    listOptions: false,
    includeModeHint: false,
    help: (l) => l.helpSettings,
    actions: [
      for (final item in settingItems)
        A11yAction(
          id: item.id,
          // Spoken when focused: "Bilis ng pagbasa: 1.0x".
          label: (l) => l.settingValue(item.label(l), item.value(_context(l))),
          // The change itself is spoken (with the new value).
          confirmation: (_) => '',
          onActivate: (bus) => _activate(item, bus),
        ),
    ],
    intentHandlers: {
      NavIntent.faster: (bus) => _adjustFocused(bus, 1),
      NavIntent.slower: (bus) => _adjustFocused(bus, -1),
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Rebuild on any settings change (values, theme) and account change.
    ref
      ..watch(settingsProvider)
      ..watch(currentAccountProvider);
    final focused = ref.watch(focusControllerProvider);
    final c = SettingContext(ref.read(settingsProvider), l10n, ref);

    return AccessibleScreen(
      registration: _registration,
      child: GesturePadLayout(
        padHint: l10n.helpSettings,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.screenSettings,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: settingItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = settingItems[i];
                  return _SettingRow(
                    key: _rowKeys[item.id],
                    item: item,
                    label: item.label(l10n),
                    value: item.value(c),
                    // What TalkBack says a swipe up/down would change it to.
                    increasedValue: item.adjust == null
                        ? null
                        : item.value(_shifted(c, item, 1)),
                    decreasedValue: item.adjust == null
                        ? null
                        : item.value(_shifted(c, item, -1)),
                    focused: focused == item.id,
                    onChange: (d) => _change(item, d),
                    onOpen: () => _activate(item, ref.read(commandBusProvider)),
                    onFocus: () {
                      ref.read(focusControllerProvider.notifier).focus(item.id);
                      final l = ref.read(speechLanguageProvider).strings;
                      unawaited(
                        ref
                            .read(commandBusProvider)
                            .say(
                              l.settingValue(
                                item.label(l),
                                item.value(_context(l)),
                              ),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.item,
    required this.label,
    required this.value,
    required this.increasedValue,
    required this.decreasedValue,
    required this.focused,
    required this.onChange,
    required this.onOpen,
    required this.onFocus,
  });

  final SettingItem item;
  final String label;
  final String value;
  final String? increasedValue;
  final String? decreasedValue;
  final bool focused;
  final void Function(int direction) onChange;
  final VoidCallback onOpen;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLink = item.kind == SettingKind.link;
    final canStep =
        item.kind == SettingKind.stepper || item.kind == SettingKind.choice;

    Widget button(IconData icon, String tooltip, VoidCallback onTap) =>
        Listener(
          onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
          child: IconButton(
            onPressed: onTap,
            tooltip: tooltip,
            icon: Icon(icon, color: p.primary),
            iconSize: 28,
            constraints: const BoxConstraints(
              minWidth: AppDimens.minTouchTarget,
              minHeight: AppDimens.minTouchTarget,
            ),
          ),
        );

    return Semantics(
      container: true,
      label: label,
      value: value,
      increasedValue: isLink ? null : increasedValue,
      decreasedValue: canStep ? decreasedValue : null,
      button: isLink,
      onTap: isLink ? onOpen : () => onChange(1),
      onIncrease: isLink ? null : () => onChange(1),
      onDecrease: canStep ? () => onChange(-1) : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fade,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppDimens.panelRadius),
          ),
          border: Border.all(
            color: focused ? p.focusRing : p.border,
            width: focused ? 3 : AppDimens.panelBorderWidth,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onFocus,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.heading,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(value, style: textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ),
            if (isLink)
              button(Icons.chevron_right, l10n.actionOpen, onOpen)
            else if (canStep) ...[
              button(Icons.remove, l10n.actionDecrease, () => onChange(-1)),
              button(Icons.add, l10n.actionIncrease, () => onChange(1)),
            ] else
              button(Icons.swap_horiz, l10n.actionChange, () => onChange(1)),
          ],
        ),
      ),
    );
  }
}
