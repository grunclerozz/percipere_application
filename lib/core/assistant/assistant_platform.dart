import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something that happened in the voice-assistant conversation.
@immutable
sealed class AssistantEvent {
  const AssistantEvent();

  /// Parses an event from the Android bridge (`AssistantBridge.kt`); null for
  /// unknown events.
  static AssistantEvent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    String text(String key) => map[key]?.toString() ?? '';
    return switch (map['type']) {
      'connected' => const AssistantConnected(),
      'status' => AssistantStatusChanged(text('value')),
      'mode' => AssistantModeChanged(speaking: text('value') == 'speaking'),
      'toolCall' => AssistantToolCall(
        id: text('id'),
        name: text('name'),
        parameters: switch (map['parameters']) {
          final Map<Object?, Object?> p => {
            for (final e in p.entries) e.key.toString(): e.value,
          },
          _ => const {},
        },
      ),
      'user' => AssistantHeard(text('text')),
      'agent' => AssistantSaid(text('text')),
      'disconnected' => AssistantDisconnected(text('reason')),
      'error' => AssistantFailed(text('message')),
      _ => null,
    };
  }
}

/// The conversation is connected.
final class AssistantConnected extends AssistantEvent {
  /// Creates the event.
  const AssistantConnected();
}

/// The SDK's connection status changed (`connecting`, `connected`, …).
final class AssistantStatusChanged extends AssistantEvent {
  /// Creates the event.
  const AssistantStatusChanged(this.status);

  /// The new status, lower case.
  final String status;
}

/// The agent started or stopped talking.
final class AssistantModeChanged extends AssistantEvent {
  /// Creates the event.
  const AssistantModeChanged({required this.speaking});

  /// True while the agent talks; false while it listens.
  final bool speaking;
}

/// The agent wants the app to do something (a client tool).
final class AssistantToolCall extends AssistantEvent {
  /// Creates the event.
  const AssistantToolCall({
    required this.id,
    required this.name,
    required this.parameters,
  });

  /// Tool call id, to send the result back.
  final String id;

  /// Tool name (see `assistant/agent_config/tools.json`).
  final String name;

  /// Arguments chosen by the agent.
  final Map<String, Object?> parameters;
}

/// What the user said (final transcript of a turn).
final class AssistantHeard extends AssistantEvent {
  /// Creates the event.
  const AssistantHeard(this.text);

  /// The words.
  final String text;
}

/// What the agent said (one turn).
final class AssistantSaid extends AssistantEvent {
  /// Creates the event.
  const AssistantSaid(this.text);

  /// The words.
  final String text;
}

/// The conversation ended (`agent`, `user` or `error`).
final class AssistantDisconnected extends AssistantEvent {
  /// Creates the event.
  const AssistantDisconnected(this.reason);

  /// Why.
  final String reason;
}

/// The service reported an error.
final class AssistantFailed extends AssistantEvent {
  /// Creates the event.
  const AssistantFailed(this.message);

  /// Details for the log.
  final String message;
}

/// What a conversation starts with.
@immutable
class AssistantStartOptions {
  /// Creates the options. Exactly one of [agentId] or [conversationToken].
  const AssistantStartOptions({
    this.agentId,
    this.conversationToken,
    this.language,
    this.firstMessage,
    this.voiceId,
    this.userId,
    this.dynamicVariables = const {},
  });

  /// Public agent id.
  final String? agentId;

  /// Token for a private agent (from the token service).
  final String? conversationToken;

  /// Agent language code (`tl` for Filipino, `en`); null: the agent's own.
  final String? language;

  /// What the agent says first; null: the agent's own.
  final String? firstMessage;

  /// Voice to speak with; null: the agent's own.
  final String? voiceId;

  /// Account id, for the conversation history in the dashboard.
  final String? userId;

  /// Values for `{{…}}` in the agent's instructions.
  final Map<String, String> dynamicVariables;

  /// For the method channel.
  Map<String, Object?> toMap() => {
    'agentId': agentId,
    'conversationToken': conversationToken,
    'language': language,
    'firstMessage': firstMessage,
    'voiceId': voiceId,
    'userId': userId,
    'dynamicVariables': dynamicVariables,
  };
}

/// The ElevenLabs conversation on the phone. Abstract so tests can script it.
abstract interface class AssistantPlatform {
  /// Events of the current conversation.
  Stream<AssistantEvent> get events;

  /// Starts a conversation; throws if it can't.
  Future<void> start(AssistantStartOptions options);

  /// Ends the conversation.
  Future<void> end();

  /// Answers tool call [id] with [result].
  Future<bool> sendToolResult(String id, String result, {bool isError});

  /// Tells the agent something without asking it to reply.
  Future<void> sendContext(String text);
}

/// [AssistantPlatform] over the Android bridge (`AssistantBridge.kt`).
class MethodChannelAssistantPlatform implements AssistantPlatform {
  /// Creates the platform.
  MethodChannelAssistantPlatform();

  static const MethodChannel _methods = MethodChannel(
    'ph.bataan.percipere/assistant',
  );
  static const EventChannel _events = EventChannel(
    'ph.bataan.percipere/assistant_events',
  );

  late final Stream<AssistantEvent> _stream = _events
      .receiveBroadcastStream()
      .map(AssistantEvent.fromMap)
      .where((e) => e != null)
      .cast<AssistantEvent>()
      .asBroadcastStream();

  @override
  Stream<AssistantEvent> get events => _stream;

  @override
  Future<void> start(AssistantStartOptions options) =>
      _methods.invokeMethod<void>('start', options.toMap());

  @override
  Future<void> end() => _methods.invokeMethod<void>('end');

  @override
  Future<bool> sendToolResult(
    String id,
    String result, {
    bool isError = false,
  }) async =>
      await _methods.invokeMethod<bool>('toolResult', {
        'id': id,
        'result': result,
        'isError': isError,
      }) ??
      false;

  @override
  Future<void> sendContext(String text) =>
      _methods.invokeMethod<void>('context', {'text': text});
}

/// The app's assistant platform.
final assistantPlatformProvider = Provider<AssistantPlatform>(
  (ref) => MethodChannelAssistantPlatform(),
);
