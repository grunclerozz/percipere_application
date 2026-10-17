import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/startup_config.dart';
import '../../core/accessibility/announcer.dart';
import '../../core/accessibility/earcon.dart';
import '../../core/startup/startup_tasks.dart';
import '../../core/tts/speech_language.dart';
import '../../core/voice/voice_readiness.dart';
import '../../core/widgets/page_padding.dart';
import '../../l10n/app_localizations.dart';
import '../offline_voice/offline_voice_setup_screen.dart';

/// Whether a [StartupStep] is done.
enum StepStatus {
  /// Still loading.
  loading,

  /// Ready.
  ready,

  /// Failed (the app goes on without it).
  failed,
}

/// The loading screen of every cold start (after the first-launch model
/// download, when that is needed): says "Pakihintay po, inihahanda ang
/// Percipere." and prepares the voice, the recognizers, Percy and ML Kit
/// before the first screen ([StartupStep]). Nothing listens or speaks other
/// prompts meanwhile ([VoiceBusy.startup]). When all is ready it says
/// "Handa na po" with a tone and opens [next]. After
/// [StartupConfig.timeout] it goes on with what is ready, says once "May
/// ilang bahagi pa pong naglo-load," and the rest loads in the background
/// ([VoiceBusy.loading]: voice works, its failures don't count).
///
/// Not a command screen: there is nothing to choose, so it registers no
/// actions and the gesture area is not shown.
class StartupScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [next] is the first real screen.
  const StartupScreen({super.key, required this.next});

  /// Where to go once loading is done.
  final OfflineVoiceNext next;

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  final Map<StartupStep, StepStatus> _status = {
    for (final s in StartupStep.values) s: StepStatus.loading,
  };
  bool _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  /// Longest wait for one of this screen's own sentences (a voice that
  /// never reports the end must not keep the app on this screen).
  static const Duration _speechCap = Duration(seconds: 10);

  Future<void> _run() async {
    final readiness = ref.read(voiceReadinessProvider.notifier);
    try {
      await _load(readiness);
    } on Object catch (e, stack) {
      // Never stuck here: go on to the first screen whatever happened.
      debugPrint('[STARTUP] loading screen failed: $e\n$stack');
    }
    if (!mounted || _left) return;
    _left = true;
    readiness.end(VoiceBusy.startup);
    GoRouter.of(context).go(widget.next.location, extra: widget.next.extra);
  }

  Future<void> _load(VoiceReadinessNotifier readiness) async {
    final watch = Stopwatch()..start();
    // After the first-launch download the screen begins the startup phase
    // itself (the download screen had to listen).
    if (!ref.read(voiceReadinessProvider).starting) {
      readiness.begin(VoiceBusy.startup);
    }
    final announcer = ref.read(announcerProvider.notifier);
    final l = ref.read(speechLanguageProvider).strings;
    final saidWait = announcer.say(l.startupWait, interrupt: false);

    final tasks = ref.read(startupTasksProvider);
    final took = <StartupStep, int>{};
    Future<void> run(StartupStep step) async {
      final stepWatch = Stopwatch()..start();
      var status = StepStatus.ready;
      try {
        await (tasks[step] ?? () async {})();
      } on Object catch (e) {
        debugPrint('[STARTUP] ${step.name} failed: $e');
        status = StepStatus.failed;
      }
      took[step] = stepWatch.elapsedMilliseconds;
      if (mounted) setState(() => _status[step] = status);
    }

    final all = Future.wait([for (final s in StartupStep.values) run(s)]);
    final finished = await all
        .then((_) => true)
        .timeout(StartupConfig.timeout, onTimeout: () => false);
    if (!mounted) return;
    final elapsed = watch.elapsed;
    debugPrint(
      '[STARTUP] ${finished ? 'ready' : 'timed out'} after '
      '${elapsed.inMilliseconds}ms on the loading screen '
      '(${launchClock.elapsedMilliseconds}ms since launch); steps: '
      '${[for (final s in StartupStep.values) '${s.name} ${took[s] == null ? 'still loading' : '${took[s]}ms'}'].join(', ')}',
    );
    ref.read(startupReportProvider.notifier).set(launchClock.elapsed);

    if (!finished) {
      // The rest loads in the background; voice works meanwhile.
      readiness.begin(VoiceBusy.loading);
      unawaited(
        all.whenComplete(() {
          debugPrint(
            '[STARTUP] background loading done '
            '(${launchClock.elapsedMilliseconds}ms since launch)',
          );
          readiness.end(VoiceBusy.loading);
        }),
      );
    }
    await saidWait.timeout(_speechCap, onTimeout: () {});
    if (!mounted) return;
    final now = ref.read(speechLanguageProvider).strings;
    if (finished) {
      await announcer
          .say(now.startupReady, interrupt: false)
          .timeout(_speechCap, onTimeout: () {});
      if (!mounted) return;
      unawaited(ref.read(earconProvider).heard());
    } else {
      await announcer
          .say(now.startupStillLoading, interrupt: false)
          .timeout(_speechCap, onTimeout: () {});
    }
    await Future<void>.delayed(StartupConfig.afterReady);
  }

  String _stepName(AppLocalizations l, StartupStep step) => switch (step) {
    StartupStep.settings => l.startupStepSettings,
    StartupStep.voice => l.startupStepVoice,
    StartupStep.recognizer => l.startupStepRecognizer,
    StartupStep.percy => l.startupStepPercy,
    StartupStep.mlkit => l.startupStepOcr,
  };

  String _statusName(AppLocalizations l, StepStatus status) => switch (status) {
    StepStatus.loading => l.startupStepLoading,
    StepStatus.ready => l.startupStepReady,
    StepStatus.failed => l.startupStepFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final done = _status.values.where((s) => s != StepStatus.loading).length;
    final total = _status.length;
    final progress = l.startupProgress('$done', '$total');
    return Scaffold(
      body: SafeArea(
        child: PagePadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(l.startupTitle, style: textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              Text(l.startupWait, style: textTheme.bodyLarge),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                label: '${l.startupTitle}: $progress',
                value: '${(done * 100 / total).round()}%',
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(progress, style: textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              for (final step in StartupStep.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l.startupStepLine(
                      _stepName(l, step),
                      _statusName(l, _status[step]!),
                    ),
                    style: textTheme.bodyLarge,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
