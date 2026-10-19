import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_dio.dart';
import '../network/connectivity.dart';
import '../network/server_address.dart';

/// Whether the server can describe pictures right now: the phone is online
/// and `GET {base}/api/v1/health` says `"vision_enabled": true` (a missing
/// field counts as false). The health answer is remembered for [cacheFor], so
/// a describe does not wait for it every time.
class VisionAvailability {
  /// Creates the check for the web app at [baseUrl]. [clock] is for tests.
  VisionAvailability({
    required this.baseUrl,
    required this.dio,
    required this.isOnline,
    this.cacheFor = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The dashboard folder, without `/api/v1`.
  final String baseUrl;

  /// The HTTP client.
  final Dio dio;

  /// Whether the phone is online.
  final Future<bool> Function() isOnline;

  final DateTime Function() _clock;

  /// How long a health answer is reused.
  final Duration cacheFor;

  bool _enabled = false;
  DateTime? _checkedAt;

  /// Whether online descriptions can be asked for now.
  Future<bool> check() async {
    try {
      if (!await isOnline()) return false;
    } on Object catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
    final at = _checkedAt;
    if (at != null && _clock().difference(at) < cacheFor) return _enabled;
    _enabled = await _askServer();
    _checkedAt = _clock();
    return _enabled;
  }

  Future<bool> _askServer() async {
    try {
      final response = await dio.get<Object?>(
        '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/health',
        options: Options(validateStatus: (_) => true),
      );
      if (response.statusCode != 200) return false;
      var body = response.data;
      if (body is String) body = jsonDecode(body);
      return body is Map && body['vision_enabled'] == true;
    } on Object catch (e) {
      debugPrint('[DESCRIBE] health check failed: $e');
      return false;
    }
  }
}

/// The app's check for online descriptions.
final visionAvailabilityProvider = Provider<VisionAvailability>(
  (ref) => VisionAvailability(
    baseUrl: ref.watch(serverAddressProvider),
    dio: apiDio(
      connect: const Duration(seconds: 4),
      send: const Duration(seconds: 4),
      receive: const Duration(seconds: 4),
    ),
    isOnline: ref.watch(isOnlineProvider),
  ),
);
