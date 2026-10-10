import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';

/// How to reach the ElevenLabs voice agent ("Percy").
@immutable
class AssistantConfig {
  /// Creates a configuration.
  const AssistantConfig({
    required this.agentId,
    required this.voiceId,
    this.tokenUrl = '',
    this.appKey = '',
    this.useOverrides = false,
  });

  /// From the build (`--dart-define`), see [Env].
  static const AssistantConfig fromEnvironment = AssistantConfig(
    agentId: Env.elevenLabsAgentId,
    voiceId: Env.elevenLabsVoiceId,
    tokenUrl: Env.elevenLabsTokenUrl,
    appKey: Env.elevenLabsAppKey,
    useOverrides: Env.elevenLabsUseOverrides,
  );

  /// Agent id (`agent_…`); empty when not set up.
  final String agentId;

  /// Voice the agent speaks with.
  final String voiceId;

  /// Token service for a private agent; empty for a public agent.
  final String tokenUrl;

  /// Shared secret sent to the token service, if it has one.
  final String appKey;

  /// Whether to send the language, first message and voice per call (the
  /// agent must allow these overrides).
  final bool useOverrides;

  /// Whether the assistant can be used at all.
  bool get isSetUp => agentId.trim().isNotEmpty;

  /// Whether conversations need a token from [tokenUrl].
  bool get isPrivate => tokenUrl.trim().isNotEmpty;
}

/// The assistant's configuration; overridden in tests.
final assistantConfigProvider = Provider<AssistantConfig>(
  (ref) => AssistantConfig.fromEnvironment,
);

/// Gets a conversation token for a private agent (token_server.py).
typedef TokenFetcher = Future<String> Function(AssistantConfig config);

/// The app's token fetcher; overridden in tests.
final assistantTokenFetcherProvider = Provider<TokenFetcher>(
  (ref) => (config) async {
    final response =
        await Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        ).get<Map<String, dynamic>>(
          config.tokenUrl,
          options: Options(
            headers: {
              if (config.appKey.isNotEmpty) 'X-Percipere-Key': config.appKey,
            },
          ),
        );
    final token = response.data?['token'];
    if (token is! String || token.isEmpty) {
      throw StateError('the token service sent no token');
    }
    return token;
  },
);
