import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../accessibility/announcer.dart';
import '../accessibility/command_bus.dart';
import '../accessibility/haptics.dart';
import '../auth/session.dart';
import '../db/daos/preferences_dao.dart';
import '../network/connectivity.dart';
import '../platform/permissions.dart';
import '../tts/speech_language.dart';
import 'assistant_config.dart';
import 'assistant_platform.dart';
import 'assistant_tools.dart';

/// Where the voice assistant ("Percy") is.
enum AssistantStatus {
  /// No conversation.
  off,

  /// Connecting to ElevenLabs.
  connecting,

  /// Connected; Percy is listening.
  listening,

  /// Connected; Percy is talking.
  speaking,
}

/// The voice assistant's state.
@immutable
class AssistantState {
  /// Creates a state.
  const AssistantState({
    this.status = AssistantStatus.off,
    this.heard,
    this.said,
  });

  /// Where the conversation is.
  final AssistantStatus status;

  /// What the user said last.
  final String? heard;

  /// What Percy said last.
  final String? said;

  /// Whether a conversation is starting or running.
  bool get active => status != AssistantStatus.off;

  /// Returns a copy with the given fields replaced.
  AssistantState copyWith({
    AssistantStatus? status,
    String? heard,
    String? said,
  }) => AssistantState(
    status: status ?? this.status,
    heard: heard ?? this.heard,
    said: said ?? this.said,
  );
}

/// Runs conversations with the ElevenLabs voice agent ("Percy").
///
/// - Started by two-finger swipe left or saying "Percy" (`NavIntent.assistant`);
///   ended by Percy (`end_call`), by saying goodbye, or by any gesture or tap.
/// - Online only, with a spoken privacy consent the first time (per user).
///   Without an agent id, internet or consent the app's own voice commands
///   simply keep working.
/// - While a conversation runs, the app's own listening is off and its own
///   prompts are shown but not spoken (the [Announcer] checks
///   [assistantActiveProvider]), so the two voices never overlap.
/// - Percy's client tools are answered by [AssistantTools] through the
///   command bus. Tools that hand over to the app's own voice (open, read,
///   scan, upload) run once the conversation has ended ([handOver]).
class AssistantController extends Notifier<AssistantState> {
  StreamSubscription<AssistantEvent>? _events;
  FutureOr<void> Function()? _afterEnd;
  Timer? _connectWatchdog;
  Timer? _endWatchdog;
  Timer? _handoverTimer;
  bool _failed = false;
  int _toolsRunning = 0;

  /// How long to wait for a connection before giving up.
  static const Duration connectTimeout = Duration(seconds: 20);

  /// After a hand-over, Percy should end the call; if it doesn't, the app
  /// ends it after this long.
  static const Duration handoverTimeout = Duration(seconds: 8);

  /// Pref key (per user) for the assistant's privacy consent.
  static const String consentKey = 'assistant.consent';

  @override
  AssistantState build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _cancelTimers();
    });
    return const AssistantState();
  }

  AssistantPlatform get _platform => ref.read(assistantPlatformProvider);
  CommandBus get _bus => ref.read(commandBusProvider);
  AppLocalizations get _l => ref.read(speechLanguageProvider).strings;
  Haptics get _haptics => ref.read(hapticsProvider);

  /// Whether one of Percy's tools is running right now (its commands must
  /// not end the conversation the way a user's gesture does).
  bool get runningTool => _toolsRunning > 0;

  /// Starts a conversation, or ends the running one.
  Future<void> toggle() => state.active ? stop() : start();

  /// Starts a conversation (checks set-up, internet and consent first).
  Future<void> start() async {
    if (state.active) return;
    final config = ref.read(assistantConfigProvider);
    if (!config.isSetUp) {
      unawaited(_haptics.error());
      return _bus.say(_l.assistantNotSetUp);
    }
    var online = true;
    try {
      online = await ref.read(isOnlineProvider)();
    } on Object catch (e) {
      debugPrint('[ASSISTANT] connectivity check failed: $e');
    }
    if (!ref.mounted) return;
    if (!online) {
      unawaited(_haptics.error());
      return _bus.say(_l.assistantOffline);
    }
    if (await _hasConsent()) return _connect(config);
    if (!ref.mounted) return;
    await _bus.offer(_l.assistantConsentAsk, () async {
      await _saveConsent();
      await _connect(config);
    }, onDecline: () => _bus.say(_l.assistantConsentDeclined));
  }

  /// Ends the conversation.
  Future<void> stop() async {
    if (!state.active) return;
    _endWatchdog?.cancel();
    // If the platform never reports the end, finish anyway.
    _endWatchdog = Timer(const Duration(seconds: 3), _finish);
    try {
      await _platform.end();
    } on Object catch (e) {
      debugPrint('[ASSISTANT] ending failed: $e');
      _finish();
    }
  }

  /// Runs [action] once the conversation has ended (the app's own voice
  /// takes over), and ends it soon if Percy doesn't.
  void handOver(FutureOr<void> Function() action) {
    _afterEnd = action;
    _handoverTimer?.cancel();
    _handoverTimer = Timer(handoverTimeout, () => unawaited(stop()));
  }

  String get _consentScope =>
      ref.read(currentAccountProvider)?.id ?? PreferencesDao.deviceScope;

  Future<bool> _hasConsent() async {
    try {
      return await ref
              .read(userPrefsProvider)
              .get(consentKey, userId: _consentScope) ==
          true;
    } on Object catch (e) {
      debugPrint('[ASSISTANT] reading consent failed: $e');
      return false;
    }
  }

  Future<void> _saveConsent() async {
    try {
      await ref
          .read(userPrefsProvider)
          .set(consentKey, true, userId: _consentScope);
    } on Object catch (e) {
      debugPrint('[ASSISTANT] saving consent failed: $e');
    }
  }

  Future<void> _connect(AssistantConfig config) async {
    if (state.active || !ref.mounted) return;
    final permissions = ref.read(permissionServiceProvider);
    var mic = await permissions.status(AppPermission.microphone);
    if (mic != PermissionAccess.granted) {
      mic = await permissions.request(AppPermission.microphone);
    }
    if (!ref.mounted) return;
    if (mic != PermissionAccess.granted) {
      unawaited(_haptics.error());
      return _bus.say(_l.assistantMicNeeded);
    }
    String? token;
    if (config.isPrivate) {
      try {
        token = await ref.read(assistantTokenFetcherProvider)(config);
      } on Object catch (e) {
        debugPrint('[ASSISTANT] no conversation token: $e');
        if (!ref.mounted) return;
        unawaited(_haptics.error());
        return _bus.say(_l.assistantFailed);
      }
    }
    if (!ref.mounted) return;
    unawaited(_haptics.confirm());
    // (The app's own listening stops by itself once the state below turns
    // active: the voice controller listens to [assistantActiveProvider].)
    await _bus.say(_l.assistantConnecting, protect: true);
    if (!ref.mounted || state.active) return;

    _failed = false;
    _afterEnd = null;
    state = const AssistantState(status: AssistantStatus.connecting);
    _events ??= _platform.events.listen(
      _onEvent,
      onError: (Object e) {
        debugPrint('[ASSISTANT] event error: $e');
        _failed = true;
        _finish();
      },
    );
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(connectTimeout, () {
      if (state.status == AssistantStatus.connecting) {
        debugPrint(
          '[ASSISTANT] no connection after ${connectTimeout.inSeconds}s',
        );
        _failed = true;
        unawaited(stop());
      }
    });
    final filipino =
        ref.read(speechLanguageProvider).locale == AppLocales.filipino;
    final account = ref.read(currentAccountProvider);
    final name = account == null || account.isGuest
        ? _l.assistantGuestName
        : account.firstName;
    try {
      await _platform.start(
        AssistantStartOptions(
          agentId: token == null ? config.agentId : null,
          conversationToken: token,
          // Only if the agent allows overrides; otherwise its dashboard
          // settings are used (sending them anyway ends the call at once).
          language: config.useOverrides ? (filipino ? 'tl' : 'en') : null,
          firstMessage: config.useOverrides ? _l.assistantFirstMessage : null,
          voiceId: config.useOverrides ? config.voiceId : null,
          userId: account?.id,
          dynamicVariables: {
            'user_name': name,
            'app_language': filipino ? 'fil' : 'en',
          },
        ),
      );
      debugPrint(
        '[ASSISTANT] started (${token == null ? 'public' : 'private'} agent)',
      );
    } on Object catch (e) {
      debugPrint('[ASSISTANT] start failed: $e');
      _failed = true;
      _finish();
    }
  }

  void _onEvent(AssistantEvent event) {
    if (!ref.mounted) return;
    if (!state.active) {
      if (event is AssistantToolCall) {
        unawaited(
          _platform.sendToolResult(
            event.id,
            'The conversation is over.',
            isError: true,
          ),
        );
      }
      return;
    }
    switch (event) {
      case AssistantConnected():
        _connected();
      case AssistantStatusChanged(:final status):
        if (status == 'connected') _connected();
        if (status == 'error') _failed = true;
        if (status == 'disconnected' || status == 'error') _finish();
      case AssistantModeChanged(:final speaking):
        _connectWatchdog?.cancel();
        state = state.copyWith(
          status: speaking
              ? AssistantStatus.speaking
              : AssistantStatus.listening,
        );
      case AssistantHeard(:final text):
        state = state.copyWith(heard: text);
        ref.read(announcerProvider.notifier).showSubtitle('“$text”');
      case AssistantSaid(:final text):
        state = state.copyWith(said: text);
        ref.read(announcerProvider.notifier).showSubtitle(text);
      case AssistantToolCall():
        unawaited(_runTool(event));
      case AssistantDisconnected(:final reason):
        debugPrint('[ASSISTANT] ended by $reason');
        if (reason == 'error') _failed = true;
        _finish();
      case AssistantFailed(:final message):
        debugPrint('[ASSISTANT] error: $message');
        _failed = true;
        _finish();
    }
  }

  void _connected() {
    _connectWatchdog?.cancel();
    if (state.status == AssistantStatus.connecting) {
      state = state.copyWith(status: AssistantStatus.listening);
    }
  }

  Future<void> _runTool(AssistantToolCall call) async {
    debugPrint('[ASSISTANT] tool ${call.name} ${call.parameters}');
    _toolsRunning++;
    String result;
    var isError = false;
    try {
      result = await AssistantTools(ref, this).run(call.name, call.parameters);
    } on AssistantToolError catch (e) {
      result = e.message;
      isError = true;
    } on Object catch (e) {
      debugPrint('[ASSISTANT] tool ${call.name} crashed: $e');
      result = 'The app could not do that.';
      isError = true;
    } finally {
      _toolsRunning--;
    }
    try {
      await _platform.sendToolResult(call.id, result, isError: isError);
    } on Object catch (e) {
      debugPrint('[ASSISTANT] sending the tool result failed: $e');
    }
  }

  void _cancelTimers() {
    _connectWatchdog?.cancel();
    _endWatchdog?.cancel();
    _handoverTimer?.cancel();
  }

  /// The conversation is over: give the app its voice back, then run what
  /// was handed over (or say it ended).
  void _finish() {
    if (!ref.mounted || !state.active) return;
    _cancelTimers();
    state = const AssistantState();
    final after = _afterEnd;
    _afterEnd = null;
    final failed = _failed;
    // A moment for the call to release the audio.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        if (!ref.mounted) return;
        try {
          if (after != null) {
            await after();
          } else {
            await _bus.say(failed ? _l.assistantFailed : _l.assistantEnded);
          }
        } on Object catch (e) {
          debugPrint('[ASSISTANT] after the conversation: $e');
        }
      }),
    );
  }
}

/// The voice assistant.
final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantState>(
      AssistantController.new,
    );

/// Whether a conversation with Percy is starting or running.
final assistantActiveProvider = Provider<bool>(
  (ref) => ref.watch(assistantControllerProvider.select((s) => s.active)),
);
