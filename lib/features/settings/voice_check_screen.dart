import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ids.dart';
import '../../app/locale_provider.dart';
import '../../config/env.dart';
import '../../core/accessibility/accessible_screen.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/accessibility/focus_controller.dart';
import '../../core/accessibility/screen_registration.dart';
import '../../core/network/connectivity.dart';
import '../../core/offline_voice/hybrid_tts_service.dart';
import '../../core/offline_voice/model_catalog.dart';
import '../../core/offline_voice/offline_voice_setup.dart';
import '../../core/percy/percy_controller.dart';
import '../../core/platform/permissions.dart';
import '../../core/platform/system_settings.dart';
import '../../core/tts/speech_language.dart';
import '../../core/tts/tts_service.dart';
import '../../core/voice/command_matcher.dart';
import '../../core/voice/speech_input.dart';
import '../../core/voice/voice_controller.dart';
import '../../core/widgets/boxed_list.dart';
import '../../l10n/app_localizations.dart';
import '../auth/form_scaffold.dart';

/// What the Voice check found, in display order.
@immutable
class VoiceCheckFacts {
  /// Creates the facts.
  const VoiceCheckFacts({
    required this.info,
    required this.plan,
    required this.preferredLocale,
    required this.online,
    required this.micGranted,
    required this.tts,
    required this.voices,
    this.offline = const OfflineVoiceState(
      status: OfflineVoiceStatus.unavailable,
    ),
  });

  /// Recognition on this phone (null: the recognizer isn't set up, e.g.
  /// no microphone permission yet).
  final RecognizerInfo? info;

  /// How the next listening session would recognize speech.
  final ListenPlan plan;

  /// The app language's recognizer locale.
  final String? preferredLocale;

  /// The phone has a network.
  final bool online;

  /// The microphone is allowed.
  final bool micGranted;

  /// The voice that speaks the app's prompts.
  final TtsReport tts;

  /// Which TTS languages work offline.
  final VoiceStatus voices;

  /// The app's own offline voices and command recognizer.
  final OfflineVoiceState offline;

  /// The status of the app's own offline models, as said.
  static String offlineStatus(AppLocalizations l, OfflineVoiceState s) {
    switch (s.status) {
      case OfflineVoiceStatus.downloading || OfflineVoiceStatus.checking:
        return l.voiceCheckModelsDownloading('${s.percent}');
      case OfflineVoiceStatus.waitingForInternet:
        return l.voiceCheckModelsWaiting;
      case OfflineVoiceStatus.lowStorage:
        return l.voiceCheckModelsLowStorage;
      case OfflineVoiceStatus.failed:
        return l.voiceCheckModelsFailed;
      case OfflineVoiceStatus.ready ||
          OfflineVoiceStatus.idle ||
          OfflineVoiceStatus.unavailable:
        if (s.complete) {
          return l.voiceCheckModelsInstalled(
            [
              for (final n in OfflineModelCatalog.names)
                s.installed[n]!.version,
            ].join(', '),
          );
        }
        return s.installed.isEmpty
            ? l.voiceCheckModelsMissing
            : l.voiceCheckModelsPartial;
    }
  }

  /// One spoken sentence per fact.
  List<String> lines(AppLocalizations l, {required bool details}) {
    String yesNo(bool? v) => v == null
        ? l.voiceCheckUnknown
        : v
        ? l.voiceCheckYes
        : l.voiceCheckNo;
    final i = info;
    final offlineKnown = i != null && i.installed != null;
    return [
      l.voiceCheckOfflineModels(offlineStatus(l, offline)),
      l.voiceCheckRecognizer(_serviceName(i?.service, l)),
      l.voiceCheckLanguage(plan.localeId ?? preferredLocale ?? '–'),
      l.voiceCheckOfflineFilipino(
        yesNo(offlineKnown ? i.filipinoOffline : null),
      ),
      l.voiceCheckOfflineEnglish(
        yesNo(offlineKnown ? i.englishOffline != null : null),
      ),
      l.voiceCheckMode(
        plan.isNone
            ? l.voiceCheckModeNone
            : plan.offline
            ? l.voiceCheckModeOffline
            : plan.englishFallback
            ? l.voiceCheckModeEnglish
            : plan.onDevice
            ? l.voiceCheckModeOnDevice
            : l.voiceCheckModeOnline,
      ),
      l.voiceCheckInternet(yesNo(online)),
      l.voiceCheckMic(yesNo(micGranted)),
      l.voiceCheckTtsEngine(_engineName(tts.engine, l)),
      l.voiceCheckTtsVoice(
        tts.voiceName ?? l.voiceCheckUnknown,
        tts.local == null
            ? l.voiceCheckUnknown
            : tts.local!
            ? l.voiceCheckVoiceLocal
            : l.voiceCheckVoiceNetwork,
      ),
      if (!voices.filipinoReady) l.voiceCheckFilipinoVoiceMissing,
      if (details && i != null) ...[
        'SDK ${i.sdk}; service ${i.service ?? '–'}; '
            'on-device ${i.onDevice}',
        'Installed: ${i.installed ?? '–'}; pending: ${i.pending}',
        if (i.error != null) 'Error: ${i.error}',
      ],
    ];
  }

  static String _serviceName(String? package, AppLocalizations l) {
    if (package == null) return l.voiceCheckUnknown;
    if (package.contains('google')) return 'Google';
    if (package.contains('samsung')) return 'Samsung';
    return package;
  }

  static String _engineName(String? package, AppLocalizations l) {
    if (package == null) return l.voiceCheckUnknown;
    if (package == HybridTtsService.bundledEngine) return l.voiceCheckOfflineVoice;
    if (package.contains('google')) return 'Google';
    if (package.contains('samsung')) return 'Samsung';
    return package;
  }
}

/// The result of the five-second test.
@immutable
class VoiceCheckTest {
  /// Creates a result.
  const VoiceCheckTest({
    required this.heard,
    required this.command,
    required this.intent,
    required this.intentConfidence,
    required this.confidence,
    required this.responseMs,
  });

  /// What was heard.
  final String heard;

  /// The command it would run, or null.
  final String? command;

  /// Percy's intent for it, or null.
  final String? intent;

  /// Percy's confidence, 0..1.
  final double intentConfidence;

  /// The recognizer's confidence, 0..1; −1 when it doesn't say.
  final double confidence;

  /// From the end of speech to the command being known.
  final int responseMs;

  /// The spoken result.
  String line(AppLocalizations l) => l.voiceCheckTestResult(
    heard,
    command ?? l.voiceCheckNone,
    intent ?? l.voiceCheckNone,
    '${(intentConfidence * 100).round()}',
    confidence < 0 ? l.voiceCheckUnknown : '${(confidence * 100).round()}%',
    '$responseMs',
  );
}

/// "Pagsusuri ng boses" (Voice check), Settings: shows and speaks how
/// listening and the app's voice work on this tablet (recognizer, language,
/// offline yes/no, voice installed or online, microphone) and runs a
/// five-second test ("Sabihin: buksan ang Aklatan") that shows what was
/// heard, the command and Percy intent, the confidence and the response
/// time. A developer build (`PERCIPERE_DEV`) also lists the raw details.
class VoiceCheckScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const VoiceCheckScreen({super.key});

  @override
  ConsumerState<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends ConsumerState<VoiceCheckScreen> {
  VoiceCheckFacts? _facts;
  VoiceCheckTest? _test;
  bool _testing = false;

  static const String _test0 = '${Ids.voiceCheck}.test';
  static const String _readAgain = '${Ids.voiceCheck}.readAgain';
  static const String _download = '${Ids.voiceCheck}.download';
  static const String _voiceInput = '${Ids.voiceCheck}.voiceInput';
  static const String _ttsSettings = '${Ids.voiceCheck}.tts';
  static const String _redownload = '${Ids.voiceCheck}.redownload';
  static const String _deleteModels = '${Ids.voiceCheck}.deleteModels';

  @override
  void initState() {
    super.initState();
    unawaited(_gather());
  }

  Future<VoiceCheckFacts> _read() async {
    final voice = ref.read(voiceControllerProvider.notifier);
    final mic = await ref
        .read(permissionServiceProvider)
        .status(AppPermission.microphone);
    final micGranted = mic == PermissionAccess.granted;
    RecognizerInfo? info;
    if (micGranted) {
      await voice.warmUp();
      info = await voice.refreshRecognizerInfo();
    }
    var online = voice.online;
    try {
      online = await ref.read(isOnlineProvider)();
    } on Object catch (e) {
      debugPrint('[VOICE CHECK] network check failed: $e');
    }
    final tag = ref.read(speechLanguageProvider).ttsTag;
    final tts = await ref.read(ttsServiceProvider).report(tag);
    return VoiceCheckFacts(
      info: info,
      plan: voice.nextPlan,
      preferredLocale: voice.preferredLocale,
      online: online,
      micGranted: micGranted,
      tts: tts,
      voices: ref.read(voiceStatusProvider),
      offline: ref.read(offlineVoiceProvider),
    );
  }

  Future<void> _gather() async {
    try {
      final facts = await _read();
      if (mounted) setState(() => _facts = facts);
    } on Object catch (e) {
      debugPrint('[VOICE CHECK] failed: $e');
      if (mounted) {
        setState(
          () => _facts = VoiceCheckFacts(
            info: null,
            plan: ListenPlan.none,
            preferredLocale: null,
            online: false,
            micGranted: false,
            tts: const TtsReport(),
            voices: ref.read(voiceStatusProvider),
            offline: ref.read(offlineVoiceProvider),
          ),
        );
      }
    }
  }

  /// Offline language that could be downloaded here (Android 13+, an
  /// on-device recognizer, the app's language missing), or null.
  String? _downloadable(VoiceCheckFacts facts) {
    final info = facts.info;
    if (info == null || info.sdk < 33 || !info.onDevice) return null;
    if (info.installed == null) return null;
    final filipino = (facts.preferredLocale ?? 'fil').toLowerCase().startsWith(
      RegExp('fil|tl'),
    );
    if (filipino && !info.filipinoOffline) {
      final supported = RecognizerInfo(
        onDevice: true,
        installed: info.supported,
      );
      if (supported.filipinoOffline) return 'fil-PH';
    }
    if (info.englishOffline == null) return 'en-US';
    return null;
  }

  Future<void> _runTest(CommandBus bus) async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _test = null;
    });
    try {
      final l = bus.strings;
      await bus.say(l.voiceCheckTestSay);
      if (!mounted) return;
      final probe = await ref.read(voiceControllerProvider.notifier).probe();
      if (!mounted) return;
      if (probe == null) {
        await bus.say(l.voiceCheckTestNothing);
        return;
      }
      final match = bus.matchOnly(probe.text);
      String? command;
      if (match is Matched) {
        command = _targetName(match.target);
      } else if (match is Ambiguous) {
        command = '${_targetName(match.target)}?';
      }
      String? intent;
      var intentConfidence = 0.0;
      try {
        final brain = await ref.read(percyBrainProvider.future);
        final prediction = brain.model.predict(probe.text);
        intent = prediction.top.label;
        intentConfidence = prediction.top.probability;
      } on Object catch (e) {
        debugPrint('[VOICE CHECK] Percy model unavailable: $e');
      }
      final known = DateTime.now();
      final from = probe.endOfSpeech ?? probe.decided;
      final result = VoiceCheckTest(
        heard: probe.text,
        command: command,
        intent: intent,
        intentConfidence: intentConfidence,
        confidence: probe.confidence,
        responseMs: known.difference(from).inMilliseconds,
      );
      debugPrint(
        '[VOICE CHECK] "${probe.text}" via ${probe.via} plan='
        '${probe.plan.localeId}/${probe.plan.onDevice ? 'device' : 'online'} '
        'command=$command intent=$intent '
        'response=${result.responseMs}ms alternates=${probe.alternates}',
      );
      if (!mounted) return;
      setState(() => _test = result);
      await bus.say(result.line(l));
    } on Object catch (e) {
      debugPrint('[VOICE CHECK] test failed: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  static String _targetName(CommandTarget target) => switch (target) {
    ActionTarget(:final actionId) => actionId,
    ValueTarget(:final value) => value is Enum ? value.name : '$value',
  };

  Future<void> _downloadOffline(CommandBus bus, String language) async {
    final started = await ref
        .read(voiceControllerProvider.notifier)
        .downloadOffline(language);
    final l = bus.strings;
    await bus.say(
      started ? l.voiceCheckDownloadStarted : l.voiceCheckDownloadFailed,
    );
  }

  String _languageName(String tag, AppLocalizations l) =>
      tag.startsWith('fil') ? l.languageFilipino : l.languageEnglish;

  ScreenRegistration _registration(WidgetRef ref) {
    final facts = _facts!;
    final details = Env.devTools;
    final download = _downloadable(facts);
    final test = _test;
    final lineCount = facts
        .lines(lookupAppLocalizations(AppLocales.filipino), details: details)
        .length;
    return ScreenRegistration(
      id: Ids.voiceCheck,
      title: (l) => l.screenVoiceCheck,
      prompt: (l) =>
          '${l.voiceCheckIntro} ${facts.lines(l, details: false).join(' ')}',
      help: (l) => l.helpChooseList,
      actions: [
        A11yAction(
          id: _test0,
          label: (l) => l.voiceCheckTest,
          voiceSynonyms: const ['subukan', 'test'],
          confirmation: (l) => '',
          onActivate: _runTest,
        ),
        if (test != null)
          A11yAction(
            id: '${Ids.voiceCheck}.result',
            label: test.line,
            confirmation: (l) => '',
            onActivate: (bus) => bus.say(test.line(bus.strings)),
          ),
        A11yAction(
          id: _readAgain,
          label: (l) => l.voiceCheckReadAgain,
          voiceSynonyms: const ['basahin ulit', 'read again'],
          confirmation: (l) => '',
          onActivate: (bus) async {
            await _gather();
            if (!mounted) return;
            final l = bus.strings;
            await bus.say(_facts!.lines(l, details: false).join(' '));
          },
        ),
        for (var index = 0; index < lineCount; index++)
          A11yAction(
            id: '${Ids.voiceCheck}.line$index',
            label: (l) => facts.lines(l, details: details)[index],
            confirmation: (l) => '',
            onActivate: (bus) =>
                bus.say(facts.lines(bus.strings, details: details)[index]),
          ),
        if (download != null)
          A11yAction(
            id: _download,
            label: (l) => l.voiceCheckDownload(_languageName(download, l)),
            onActivate: (bus) => _downloadOffline(bus, download),
          ),
        if (facts.offline.status != OfflineVoiceStatus.unavailable) ...[
          A11yAction(
            id: _redownload,
            label: (l) => l.voiceCheckRedownload,
            voiceSynonyms: const ['i-download ulit', 'download again'],
            confirmation: (l) => l.voiceCheckRedownloadStarted,
            onActivate: (bus) async {
              unawaited(ref.read(offlineVoiceProvider.notifier).redownload());
              await Future<void>.delayed(const Duration(milliseconds: 300));
              await _gather();
            },
          ),
          if (facts.offline.installed.isNotEmpty)
            A11yAction(
              id: _deleteModels,
              label: (l) => l.voiceCheckDeleteModels,
              voiceSynonyms: const ['burahin', 'delete'],
              confirmation: (l) => '',
              onActivate: (bus) => bus.offer(
                bus.strings.voiceCheckDeleteConfirm,
                () async {
                  await ref.read(offlineVoiceProvider.notifier).deleteAll();
                  await bus.say(bus.strings.voiceCheckModelsDeleted);
                  await _gather();
                },
              ),
            ),
        ],
        A11yAction(
          id: _voiceInput,
          label: (l) => l.voiceCheckVoiceInput,
          onActivate: (bus) =>
              ref.read(systemSettingsProvider).openVoiceInputSettings(),
        ),
        A11yAction(
          id: _ttsSettings,
          label: (l) => l.voiceCheckTtsSettings,
          onActivate: (bus) =>
              ref.read(systemSettingsProvider).openTtsSettings(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = ref.watch(focusControllerProvider);
    final bus = ref.read(commandBusProvider);
    final facts = _facts;
    // Announced once the facts are read (quick), so the first words are
    // right.
    if (facts == null) return const Scaffold();
    final registration = _registration(ref);
    return AccessibleScreen(
      registration: _registration,
      dependencies: [facts, _test],
      child: FormScaffold(
        screenId: Ids.voiceCheck,
        title: l10n.screenVoiceCheck,
        subtitle: l10n.voiceCheckIntro,
        padHint: l10n.helpChooseList,
        fill: true,
        child: BoxedList(
          items: [
            for (final a in registration.actions)
              BoxedListItem(a.id, a.label(l10n)),
          ],
          focused: focused,
          onTap: bus.activate,
        ),
      ),
    );
  }
}
