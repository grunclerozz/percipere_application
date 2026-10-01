import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../app/router.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_settings.dart';
import '../../config/constants.dart';
import '../../config/palette.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/haptics.dart';
import '../../core/accessibility/nav_intent.dart';
import '../../core/accessibility/navigation_mode.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/auth/account_repository.dart';
import '../../core/auth/session.dart';
import '../../core/db/daos/preferences_dao.dart';
import '../../core/gestures/gesture_surface.dart';
import '../../core/platform/system_settings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/reading_rate.dart';
import '../../core/tts/speech_language.dart';
import '../../core/tts/tts_service.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/bordered_panel.dart';
import '../../core/widgets/boxed_list.dart';
import '../../core/widgets/eye_logo.dart';
import '../../core/widgets/gesture_pad_layout.dart';
import '../../core/widgets/live_speaking_zone.dart';
import '../../core/widgets/pill_button.dart';
import '../../l10n/app_localizations.dart';
import 'setup_flow.dart';
import 'setup_labels.dart';

export 'setup_flow.dart' show SetupMode;

/// A choice on a choice step (Pa-boses / Pa-galaw, Oo / Hindi, …).
class _Option {
  const _Option({
    required this.id,
    required this.label,
    required this.choose,
    this.synonyms = const [],
    this.onFocus,
  });

  final String id;
  final L10nText label;
  final List<String> synonyms;

  /// Applies the choice (then the step is confirmed).
  final Future<void> Function() choose;

  /// Live preview when the option gets focus (a voice sample, a buzz).
  final Future<void> Function(CommandBus bus)? onFocus;
}

/// The guided setup after login ("profiling"): one screen per step, each
/// with the eye logo, a live preview where it helps, the Speaking Zone and
/// the Gesture Pad.
///
/// Every step speaks its question and how to answer by voice and gesture,
/// announces "Hakbang 3 ng 10", previews changes at once, and supports
/// "ulitin" (tap), back (two-finger swipe right, "bumalik"), "laktawan"
/// (keeps the default) and confirm (double-tap, "okay", "sige"). Progress is
/// saved per step, so an interrupted setup resumes where it stopped.
class ProfilingScreen extends ConsumerStatefulWidget {
  /// Creates the setup for [mode].
  const ProfilingScreen({super.key, this.mode = SetupMode.firstRun});

  /// First run (only missing steps) or "Ulitin ang setup" (all steps).
  final SetupMode mode;

  @override
  ConsumerState<ProfilingScreen> createState() => _ProfilingScreenState();
}

class _ProfilingScreenState extends ConsumerState<ProfilingScreen> {
  SetupFlow? _flow;
  final Set<SetupStep> _done = {};

  CommandBus get _bus => ref.read(commandBusProvider);
  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  SettingsController get _settings => ref.read(settingsProvider.notifier);
  AppSettings get _s => ref.read(settingsProvider);
  PreferencesDao get _prefs => ref.read(userPrefsProvider);
  String get _userId => ref.read(currentAccountProvider)!.id;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final account = ref.read(currentAccountProvider);
    if (account == null) {
      ref.read(routerProvider).go(AppRoutes.welcome);
      return;
    }
    final stored = await _prefs.getAll(userId: account.id);
    final done = {
      for (final name in (stored[PrefKeys.setupDone] as List?) ?? const [])
        ?SetupStep.tryParse(name),
    };
    final seesText = stored[PrefKeys.setupSeesText];
    final flow = SetupFlow.start(
      guest: account.isGuest,
      mode: widget.mode,
      done: done,
      resumeAt: widget.mode == SetupMode.firstRun
          ? SetupStep.tryParse(stored[PrefKeys.setupStep])
          : null,
      seesText: seesText is bool ? seesText : null,
    );
    if (!mounted) return;
    _done.addAll(done);
    setState(() => _flow = flow);
    await _prefs.set(PrefKeys.setupStep, flow.step.name, userId: account.id);
  }

  // ── Flow ──────────────────────────────────────────────────────────────────

  Future<void> _go(SetupFlow next) async {
    setState(() => _flow = next);
    await _prefs.set(PrefKeys.setupStep, next.step.name, userId: _userId);
  }

  /// The current step is answered: remember it and move on.
  Future<void> _confirm() async {
    final flow = _flow!;
    unawaited(ref.read(hapticsProvider).confirm());
    _done.add(flow.step);
    await _prefs.set(PrefKeys.setupDone, [
      for (final s in _done) s.name,
    ], userId: _userId);
    if (!mounted) return;
    await _go(flow.next());
  }

  /// "Laktawan": the step keeps (goes back to) its default.
  Future<void> _skip(CommandBus bus) async {
    final step = _flow!.step;
    const d = AppSettings();
    switch (step) {
      case SetupStep.navMode:
        if (_s.navMode == null) {
          await _settings.update((s) => s.copyWith(navMode: NavMode.gestures));
        }
      case SetupStep.seesText:
        return _answerSeesText(true);
      case SetupStep.textSize:
        await _settings.update((s) => s.copyWith(textSize: d.textSize));
      case SetupStep.textColor:
        await _settings.update((s) => s.copyWith(textColor: null));
      case SetupStep.voiceLanguage:
        await _settings.update((s) => s.copyWith(locale: d.locale));
      case SetupStep.speed:
        await _settings.update((s) => s.copyWith(readingRate: d.readingRate));
      case SetupStep.pitch:
        await _settings.update((s) => s.copyWith(pitch: d.pitch));
      case SetupStep.theme:
        await _settings.update((s) => s.withTheme(d.themeId).settings);
      case SetupStep.vibration:
        await _settings.update((s) => s.copyWith(haptics: d.haptics));
      case SetupStep.autoRead:
        await _settings.update((s) => s.copyWith(autoRead: d.autoRead));
      case SetupStep.summary:
        return bus.notAvailable();
    }
    await bus.say(_l.setupSkipped, protect: true);
    await _confirm();
  }

  Future<void> _back(CommandBus bus) async {
    final previous = _flow!.back();
    if (previous != null) {
      unawaited(ref.read(hapticsProvider).confirm());
      return _go(previous);
    }
    // First step.
    if (widget.mode == SetupMode.redo && ref.read(routerProvider).canPop()) {
      return bus.back();
    }
    await bus.offer(_l.setupLeave, () async {
      await ref.read(currentAccountProvider.notifier).logout();
      ref.read(routerProvider).go(AppRoutes.welcome);
    });
  }

  Future<void> _answerSeesText(bool sees) async {
    unawaited(ref.read(hapticsProvider).confirm());
    _done.add(SetupStep.seesText);
    await _prefs.set(PrefKeys.setupSeesText, sees, userId: _userId);
    await _prefs.set(PrefKeys.setupDone, [
      for (final s in _done) s.name,
    ], userId: _userId);
    if (!mounted) return;
    await _go(_flow!.answerSeesText(sees));
  }

  Future<void> _finish(CommandBus bus) async {
    final account = ref.read(currentAccountProvider)!;
    await ref
        .read(accountRepositoryProvider)
        .setProfilingCompleted(account.id, true);
    await _prefs.remove(PrefKeys.setupStep, userId: account.id);
    await ref.read(currentAccountProvider.notifier).refresh();
    unawaited(ref.read(hapticsProvider).confirm());
    await bus.say(_l.setupFinished, protect: true);
    if (!mounted) return;
    final router = ref.read(routerProvider);
    if (widget.mode == SetupMode.redo && router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.capture);
    }
  }

  // ── Value changes (live preview) ─────────────────────────────────────────

  Future<void> _change(
    AppSettings Function(AppSettings s) change,
    String Function(AppLocalizations l, AppSettings s) spoken, {
    double rate = 1.0,
    bool useRate = false,
  }) async {
    final before = _s;
    final after = change(before);
    if (after == before) {
      unawaited(ref.read(hapticsProvider).error());
      return _bus.say(_l.setupAtLimit(spoken(_l, before)));
    }
    await _settings.update((_) => after);
    unawaited(ref.read(hapticsProvider).tick());
    if (!mounted) return;
    await ref
        .read(announcerProvider.notifier)
        .say(spoken(_l, after), rate: useRate ? after.readingRate : rate);
  }

  Future<void> _cycleColor(int d) => _change((s) {
    final options = TextColors.forTheme(s.themeId);
    final i = options.indexOf(s.resolvedTextColor);
    final next = options[(i + d) % options.length];
    return s.copyWith(
      textColor: next == TextColors.defaultFor(s.themeId) ? null : next.id,
    );
  }, (l, s) => l.setupColorValue(colorName(s.resolvedTextColor, l)));

  Future<void> _cycleTheme(int d) async {
    final before = _s;
    const themes = ThemeId.values;
    final next = themes[(themes.indexOf(before.themeId) + d) % themes.length];
    final result = before.withTheme(next);
    await _settings.update((_) => result.settings);
    unawaited(ref.read(hapticsProvider).tick());
    if (!mounted) return;
    final l = _l;
    await _bus.say(
      [
        l.setupThemeValue(themeName(next, l)),
        if (result.textColorReset) l.textColorReset,
      ].join(' '),
    );
  }

  Future<void> _sampleVoice(Locale locale, CommandBus bus) async {
    final voices = ref.read(voiceStatusProvider);
    final announcer = ref.read(announcerProvider.notifier);
    if (locale == AppLocales.english) {
      final en = lookupAppLocalizations(AppLocales.english);
      return announcer.say(en.setupVoiceSample, languageTag: voices.englishTag);
    }
    if (!voices.filipinoReady) {
      // Explained in English: there is no Filipino voice to say it with.
      final en = lookupAppLocalizations(AppLocales.english);
      return bus.offer(
        en.setupFilipinoMissing,
        () => ref.read(systemSettingsProvider).openTtsSettings(),
      );
    }
    final fil = lookupAppLocalizations(AppLocales.filipino);
    return announcer.say(fil.setupVoiceSample, languageTag: voices.filipinoTag);
  }

  // ── Registrations ────────────────────────────────────────────────────────

  String get _screenId => '${Ids.setup}.${_flow!.step.name}';

  ScreenRegistration _registration(WidgetRef ref) {
    final flow = _flow!;
    final step = flow.step;
    String title(AppLocalizations l) => step == SetupStep.summary
        ? '${l.setupProgress(flow.number, flow.total)} ${l.setupSummaryTitle}'
        : l.setupProgress(flow.number, flow.total);

    final skip = A11yAction(
      id: '$_screenId.skip',
      label: (l) => l.actionSkip,
      voiceSynonyms: const ['laktawan', 'lumaktaw', 'skip'],
      focusable: false,
      confirmation: (_) => '',
      onActivate: _skip,
    );
    final confirm = A11yAction(
      id: '$_screenId.confirm',
      label: (l) => l.actionOkay,
      voiceSynonyms: const [
        'okay',
        'ok',
        'sige',
        'tama',
        'tapos na',
        'confirm',
      ],
      focusable: false,
      confirmation: (_) => '',
      onActivate: (_) => _confirm(),
    );
    final common = <NavIntent, BusHandler>{NavIntent.back: _back};

    switch (step) {
      case SetupStep.navMode:
        final voice = ref.read(voiceControllerProvider.notifier);
        return _choice(
          title: title,
          prompt: (l) =>
              '${l.welcomePrompt} '
              '${voice.micGranted ? l.setupNavHowVoice : l.setupChoiceHow}',
          autoListen: true,
          current: _s.navMode != null,
          options: [
            _Option(
              id: '$_screenId.voice',
              label: (l) => l.navModeVoice,
              synonyms: const ['boses', 'pa-boses', 'voice'],
              choose: () async {
                await ref
                    .read(navigationModeProvider.notifier)
                    .set(NavMode.voice);
                await _bus.say(_l.modeChosenVoice, protect: true);
                await voice.ensureReady(requestPermission: true);
              },
            ),
            _Option(
              id: '$_screenId.gestures',
              label: (l) => l.navModeGestures,
              synonyms: const ['galaw', 'pa-galaw', 'gestures', 'gesture'],
              choose: () async {
                await ref
                    .read(navigationModeProvider.notifier)
                    .set(NavMode.gestures);
                await voice.stopListening();
                await _bus.say(_l.modeChosenGestures, protect: true);
              },
            ),
          ],
          skip: skip,
          common: common,
        );
      case SetupStep.seesText:
        return _choice(
          title: title,
          prompt: (l) => '${l.setupSeesQuestion} ${l.setupChoiceHow}',
          current: false,
          answers: true,
          options: [
            _Option(
              id: '$_screenId.yes',
              label: (l) => l.answerYes,
              synonyms: const ['oo', 'opo', 'yes', 'nakakakita'],
              choose: () => _answerSeesText(true),
            ),
            _Option(
              id: '$_screenId.no',
              label: (l) => l.answerNo,
              synonyms: const ['hindi', 'no', 'wala', 'hindi nakakakita'],
              choose: () => _answerSeesText(false),
            ),
          ],
          skip: skip,
          common: common,
        );
      case SetupStep.textSize:
        return _adjust(
          title: title,
          prompt: (l) =>
              '${l.setupSizeQuestion} ${l.setupSizeHow} '
              '${l.setupSizeValue(_s.textSize.round())}',
          up: () => _change(
            (s) => s.copyWith(textSize: s.textSize + TextSize.step),
            (l, s) => l.setupSizeValue(s.textSize.round()),
          ),
          down: () => _change(
            (s) => s.copyWith(textSize: s.textSize - TextSize.step),
            (l, s) => l.setupSizeValue(s.textSize.round()),
          ),
          upWords: const ['palakihin', 'lakihan', 'bigger', 'zoom in'],
          downWords: const ['paliitin', 'liitan', 'smaller', 'zoom out'],
          vertical: true,
          skip: skip,
          confirm: confirm,
          common: common,
        );
      case SetupStep.textColor:
        return _adjust(
          title: title,
          prompt: (l) =>
              '${l.setupColorQuestion} ${l.setupCycleHow} '
              '${l.setupColorValue(colorName(_s.resolvedTextColor, l))}',
          up: () => _cycleColor(1),
          down: () => _cycleColor(-1),
          vertical: false,
          skip: skip,
          confirm: confirm,
          common: common,
        );
      case SetupStep.voiceLanguage:
        Future<void> pick(Locale locale) async {
          await _settings.update((s) => s.copyWith(locale: locale));
          final l = _l;
          await _bus.say(
            l.setupLanguageChosen(
              locale == AppLocales.english ? l.langEnglish : l.langTagalog,
            ),
            protect: true,
          );
        }
        return _choice(
          title: title,
          prompt: (l) => '${l.setupLanguageQuestion} ${l.setupLanguageHow}',
          current: true,
          options: [
            _Option(
              id: '$_screenId.fil',
              label: (l) => l.langTagalog,
              synonyms: const ['tagalog', 'filipino', 'pilipino'],
              onFocus: (bus) => _sampleVoice(AppLocales.filipino, bus),
              choose: () => pick(AppLocales.filipino),
            ),
            _Option(
              id: '$_screenId.en',
              label: (l) => l.langEnglishBoth,
              synonyms: const ['ingles', 'english'],
              onFocus: (bus) => _sampleVoice(AppLocales.english, bus),
              choose: () => pick(AppLocales.english),
            ),
          ],
          skip: skip,
          common: common,
        );
      case SetupStep.speed:
        return _adjust(
          title: title,
          prompt: (l) =>
              '${l.setupSpeedQuestion} ${l.setupSpeedHow} '
              '${l.setupSpeedValue(ReadingRate.label(_s.readingRate))}',
          up: () => _change(
            (s) => s.copyWith(readingRate: s.readingRate + ReadingRate.step),
            (l, s) =>
                '${l.setupSpeedValue(ReadingRate.label(s.readingRate))} '
                '${l.setupSpeedSample}',
            useRate: true,
          ),
          down: () => _change(
            (s) => s.copyWith(readingRate: s.readingRate - ReadingRate.step),
            (l, s) =>
                '${l.setupSpeedValue(ReadingRate.label(s.readingRate))} '
                '${l.setupSpeedSample}',
            useRate: true,
          ),
          vertical: true,
          skip: skip,
          confirm: confirm,
          common: common,
        );
      case SetupStep.pitch:
        return _adjust(
          title: title,
          prompt: (l) =>
              '${l.setupPitchQuestion} ${l.setupPitchHow} '
              '${l.setupPitchValue(ReadingRate.label(_s.pitch))}',
          up: () => _change(
            (s) => s.copyWith(pitch: s.pitch + ReadingRate.step),
            (l, s) =>
                '${l.setupPitchValue(ReadingRate.label(s.pitch))} '
                '${l.setupPitchSample}',
          ),
          down: () => _change(
            (s) => s.copyWith(pitch: s.pitch - ReadingRate.step),
            (l, s) =>
                '${l.setupPitchValue(ReadingRate.label(s.pitch))} '
                '${l.setupPitchSample}',
          ),
          upWords: const ['taasan', 'mas mataas', 'higher'],
          downWords: const ['babaan', 'mas mababa', 'lower'],
          vertical: true,
          skip: skip,
          confirm: confirm,
          common: common,
        );
      case SetupStep.theme:
        return _adjust(
          title: title,
          prompt: (l) =>
              '${l.setupThemeQuestion} ${l.setupCycleHow} '
              '${l.setupThemeValue(themeName(_s.themeId, l))}',
          up: () => _cycleTheme(1),
          down: () => _cycleTheme(-1),
          vertical: false,
          skip: skip,
          confirm: confirm,
          common: common,
        );
      case SetupStep.vibration:
        return _choice(
          title: title,
          prompt: (l) => '${l.setupVibrationQuestion} ${l.setupChoiceHow}',
          current: true,
          answers: true,
          options: [
            _Option(
              id: '$_screenId.yes',
              label: (l) => l.answerYes,
              synonyms: const ['oo', 'opo', 'yes', 'on'],
              // Preview: turn it on and buzz.
              onFocus: (_) async {
                await _settings.update((s) => s.copyWith(haptics: true));
                await ref.read(hapticsProvider).confirm();
              },
              choose: () async {
                await _settings.update((s) => s.copyWith(haptics: true));
                await ref.read(hapticsProvider).confirm();
              },
            ),
            _Option(
              id: '$_screenId.no',
              label: (l) => l.answerNo,
              synonyms: const ['hindi', 'no', 'off', 'huwag'],
              onFocus: (_) =>
                  _settings.update((s) => s.copyWith(haptics: false)),
              choose: () => _settings.update((s) => s.copyWith(haptics: false)),
            ),
          ],
          skip: skip,
          common: common,
        );
      case SetupStep.autoRead:
        return _choice(
          title: title,
          prompt: (l) => '${l.setupAutoReadQuestion} ${l.setupChoiceHow}',
          current: true,
          answers: true,
          options: [
            _Option(
              id: '$_screenId.yes',
              label: (l) => l.answerYes,
              synonyms: const ['oo', 'opo', 'yes', 'on'],
              choose: () => _settings.update((s) => s.copyWith(autoRead: true)),
            ),
            _Option(
              id: '$_screenId.no',
              label: (l) => l.answerNo,
              synonyms: const ['hindi', 'no', 'off', 'huwag'],
              choose: () =>
                  _settings.update((s) => s.copyWith(autoRead: false)),
            ),
          ],
          skip: skip,
          common: common,
        );
      case SetupStep.summary:
        return _summary(title, common);
    }
  }

  /// A step answered by picking one option.
  ScreenRegistration _choice({
    required L10nText title,
    required L10nText prompt,
    required List<_Option> options,
    required A11yAction skip,
    required Map<NavIntent, BusHandler> common,
    required bool current,
    bool answers = false,
    bool autoListen = false,
  }) {
    Future<void> choose(_Option o) async {
      final step = _flow?.step;
      await o.choose();
      // The sight question moves on by itself.
      if (step != SetupStep.seesText && mounted) await _confirm();
    }

    Future<void> move(CommandBus bus, int d) async {
      await bus.moveFocus(d);
      final id = ref.read(focusControllerProvider);
      final o = options.where((o) => o.id == id).firstOrNull;
      if (o?.onFocus != null) await o!.onFocus!(bus);
    }

    return ScreenRegistration(
      id: _screenId,
      title: title,
      prompt: prompt,
      autoListen: autoListen,
      listOptions: !answers,
      includeModeHint: false,
      help: (l) => '${l.helpSetupChoice} ${l.helpSetupCommon}',
      actions: [
        for (final o in options)
          A11yAction(
            id: o.id,
            label: o.label,
            voiceSynonyms: o.synonyms,
            confirmation: (_) => '',
            onActivate: (_) => choose(o),
          ),
        skip,
      ],
      intentHandlers: {
        ...common,
        NavIntent.next: (bus) => move(bus, 1),
        NavIntent.previous: (bus) => move(bus, -1),
        NavIntent.activate: (bus) {
          final id = ref.read(focusControllerProvider);
          final o = options.where((o) => o.id == id).firstOrNull;
          if (o != null) return bus.activate(o.id);
          // Nothing picked: keep the current value, if there is one.
          if (current) return _confirm();
          return bus.activateFocused();
        },
      },
    );
  }

  /// A step answered by stepping a value (size, color, speed, tone, theme).
  ScreenRegistration _adjust({
    required L10nText title,
    required L10nText prompt,
    required Future<void> Function() up,
    required Future<void> Function() down,
    required bool vertical,
    required A11yAction skip,
    required A11yAction confirm,
    required Map<NavIntent, BusHandler> common,
    List<String> upWords = const [],
    List<String> downWords = const [],
  }) {
    return ScreenRegistration(
      id: _screenId,
      title: title,
      prompt: prompt,
      listOptions: false,
      includeModeHint: false,
      help: (l) =>
          '${vertical ? l.helpSetupVertical : l.helpSetupHorizontal} '
          '${l.helpSetupCommon}',
      actions: [
        confirm,
        skip,
        if (upWords.isNotEmpty)
          A11yAction(
            id: '$_screenId.up',
            label: (_) => upWords.first,
            voiceSynonyms: upWords,
            focusable: false,
            confirmation: (_) => '',
            onActivate: (_) => up(),
          ),
        if (downWords.isNotEmpty)
          A11yAction(
            id: '$_screenId.down',
            label: (_) => downWords.first,
            voiceSynonyms: downWords,
            focusable: false,
            confirmation: (_) => '',
            onActivate: (_) => down(),
          ),
      ],
      intentHandlers: {
        ...common,
        if (vertical) ...{
          NavIntent.faster: (_) => up(),
          NavIntent.slower: (_) => down(),
        } else ...{
          NavIntent.next: (_) => up(),
          NavIntent.previous: (_) => down(),
        },
        NavIntent.activate: (_) => _confirm(),
      },
    );
  }

  /// Step 10: the choices read back as a list; confirm, or jump back to a
  /// step by voice ("bumalik sa bilis") or by swiping + double-tap.
  ScreenRegistration _summary(
    L10nText title,
    Map<NavIntent, BusHandler> common,
  ) {
    final flow = _flow!;
    final items = flow.summaryItems;
    String id(SetupStep s) => '$_screenId.${s.name}';

    return ScreenRegistration(
      id: _screenId,
      title: title,
      prompt: (l) => l.setupSummaryPrompt(
        [for (final s in items) summaryLine(s, _s, l)].join('. '),
      ),
      listOptions: false,
      includeModeHint: false,
      help: (l) => l.helpSetupSummary,
      onUtterance: (text, bus) async {
        final target = matchStepJump(text, items);
        if (target == null) return false;
        unawaited(ref.read(hapticsProvider).confirm());
        await _go(flow.jumpTo(target));
        return true;
      },
      actions: [
        for (final s in items)
          A11yAction(
            id: id(s),
            label: (l) => summaryLine(s, _s, l),
            voiceSynonyms: stepKeywords[s] ?? const [],
            confirmation: (_) => '',
            onActivate: (_) => _go(flow.jumpTo(s)),
          ),
        A11yAction(
          id: '$_screenId.confirm',
          label: (l) => l.actionFinishSetup,
          voiceSynonyms: const [
            'oo',
            'opo',
            'tama',
            'sige',
            'okay',
            'ok',
            'yes',
            'tapos na',
            'tapusin',
          ],
          focusable: false,
          confirmation: (_) => '',
          onActivate: _finish,
        ),
      ],
      intentHandlers: {
        ...common,
        NavIntent.activate: (bus) {
          final focused = ref.read(focusControllerProvider);
          if (focused != null && focused.startsWith('$_screenId.')) {
            return bus.activate(focused);
          }
          return _finish(bus);
        },
      },
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null) return const Scaffold();
    // Rebuild on every settings change: the previews are live.
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);

    return AccessibleScreen(
      registration: _registration,
      dependencies: [flow.index, flow.fromSummary, flow.seesText],
      child: flow.step == SetupStep.navMode
          ? _NavModeView(screenId: _screenId)
          : _StepView(
              screenId: _screenId,
              flow: flow,
              settings: settings,
              l10n: l10n,
            ),
    );
  }
}

/// Step 1, laid out like the "how do they want to use" mockup: the Welcome
/// heading, the question, Pa-boses / Pa-galaw. The whole screen takes
/// gestures.
class _NavModeView extends ConsumerWidget {
  const _NavModeView({required this.screenId});

  final String screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    return Scaffold(
      body: GestureSurface(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.pagePadding,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 3),
                      Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${l10n.welcomeTitleLine1}\n'),
                              TextSpan(
                                text: l10n.appName,
                                style: TextStyle(
                                  color: context.palette.primary,
                                ),
                              ),
                            ],
                          ),
                          style: textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.welcomeSubtitle, style: textTheme.titleMedium),
                      const Spacer(flex: 2),
                      const SizedBox(height: 24),
                      LiveSpeakingZone(
                        screenId: screenId,
                        fallback: l10n.welcomePrompt,
                      ),
                      const SizedBox(height: 24),
                      const Spacer(flex: 2),
                      PillButton(
                        label: l10n.navModeVoice,
                        focused: focused == '$screenId.voice',
                        onPressed: () => bus.activate('$screenId.voice'),
                      ),
                      const SizedBox(height: AppDimens.buttonGap),
                      PillButton(
                        label: l10n.navModeGestures,
                        variant: PillVariant.secondary,
                        focused: focused == '$screenId.gestures',
                        onPressed: () => bus.activate('$screenId.gestures'),
                      ),
                      const Spacer(flex: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Steps 2–10: eye logo, preview (text steps), progress, Speaking Zone,
/// options or the current value, and the Gesture Pad.
class _StepView extends ConsumerWidget {
  const _StepView({
    required this.screenId,
    required this.flow,
    required this.settings,
    required this.l10n,
  });

  final String screenId;
  final SetupFlow flow;
  final AppSettings settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = flow.step;
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final preview =
        step == SetupStep.textSize ||
        step == SetupStep.textColor ||
        step == SetupStep.theme;

    Widget pill(String id, String label, {bool primary = false}) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.buttonGap),
      child: PillButton(
        label: label,
        variant: primary ? PillVariant.primary : PillVariant.secondary,
        focused: focused == id,
        onPressed: () => bus.activate(id),
      ),
    );

    final List<Widget> controls = switch (step) {
      SetupStep.seesText || SetupStep.vibration || SetupStep.autoRead => [
        pill('$screenId.yes', l10n.answerYes, primary: true),
        pill('$screenId.no', l10n.answerNo),
      ],
      SetupStep.voiceLanguage => [
        pill('$screenId.fil', l10n.langTagalog, primary: true),
        pill('$screenId.en', l10n.langEnglishBoth),
      ],
      // The list scrolls inside its own box (below); Finish stays visible.
      SetupStep.summary => [
        pill('$screenId.confirm', l10n.actionFinishSetup, primary: true),
      ],
      // As in the customization mockups: logo, preview box, Speaking Zone,
      // Gesture Pad. The value is spoken and shown in the subtitle; confirm
      // by double-tap or "okay" (TalkBack: tap the preview).
      _ when preview => const <Widget>[],
      _ => [
        Semantics(
          liveRegion: true,
          child: Text(
            stepValue(step, settings, l10n),
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        pill('$screenId.confirm', l10n.actionOkay, primary: true),
      ],
    };

    final below = <Widget>[
      Text(
        l10n.setupProgress(flow.number, flow.total),
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      LiveSpeakingZone(screenId: screenId, fallback: stepQuestion(step, l10n)),
      const SizedBox(height: 18),
      ...controls,
    ];

    return GesturePadLayout(
      padHint: switch (step) {
        SetupStep.textSize ||
        SetupStep.speed ||
        SetupStep.pitch => l10n.helpSetupVertical,
        SetupStep.textColor || SetupStep.theme => l10n.helpSetupHorizontal,
        SetupStep.summary => l10n.helpSetupSummary,
        _ => l10n.helpSetupChoice,
      },
      content: preview
          // The preview box keeps its size; bigger text scrolls inside it,
          // so the rest of the screen never moves (mockup customization_2).
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EyeLogo(),
                const SizedBox(height: 12),
                Expanded(
                  child: _PreviewBox(
                    label:
                        '${l10n.setupPreviewLabel}. '
                        '${stepValue(step, settings, l10n)}',
                    onConfirm: () => bus.activate('$screenId.confirm'),
                  ),
                ),
                const SizedBox(height: 12),
                ...below,
              ],
            )
          : step == SetupStep.summary
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EyeLogo(),
                const SizedBox(height: 12),
                ...below.take(below.length - controls.length),
                Expanded(
                  child: BoxedList(
                    items: [
                      for (final s in flow.summaryItems)
                        BoxedListItem(
                          '$screenId.${s.name}',
                          summaryLine(s, settings, l10n),
                        ),
                    ],
                    focused: focused,
                    onTap: bus.activate,
                  ),
                ),
                const SizedBox(height: 12),
                ...controls,
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EyeLogo(),
                  const SizedBox(height: 12),
                  ...below,
                ],
              ),
            ),
    );
  }
}

/// The sample paragraph in a fixed box (text size, color and theme steps).
/// The text is shown at exactly the chosen size and scrolls inside the box.
class _PreviewBox extends StatefulWidget {
  const _PreviewBox({required this.label, required this.onConfirm});

  final String label;

  /// TalkBack's double-tap on the preview confirms the step.
  final VoidCallback onConfirm;

  @override
  State<_PreviewBox> createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<_PreviewBox> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      onTap: widget.onConfirm,
      child: BorderedPanel(
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.all(14),
            child: Text(
              AppLocalizations.of(context).setupSample,
              textAlign: TextAlign.center,
              style: AppTheme.documentText(context),
              textScaler: AppTheme.documentTextScaler,
            ),
          ),
        ),
      ),
    );
  }
}
