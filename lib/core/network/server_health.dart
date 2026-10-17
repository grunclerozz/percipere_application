import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'connectivity.dart';
import 'server_address.dart';

/// What "Test connection" found.
enum ServerHealthStatus {
  /// The server answered `GET /api/v1/health` with `status: ok`.
  ok,

  /// No server address is set.
  notConfigured,

  /// The tablet has no network at all.
  noNetwork,

  /// The address does not lead to the dashboard (host not found, or the
  /// server answered with something that is not the Percipere API).
  wrongAddress,

  /// The tablet is online but cannot reach that machine (not on the same
  /// Wi-Fi or hotspot, or a firewall).
  unreachable,

  /// The machine answered but the web server is off, or the dashboard
  /// reported an error (for example the database is down).
  serverDown,

  /// Plain `http://` to a host this build does not allow.
  httpBlocked,

  /// The server did not answer in time.
  timeout,
}

/// The result of one health check.
@immutable
class ServerHealth {
  /// Creates a result.
  const ServerHealth(this.status, {this.serverTime, this.detail});

  /// What was found.
  final ServerHealthStatus status;

  /// The server's clock from the reply, if it sent one.
  final String? serverTime;

  /// Technical detail for logs.
  final String? detail;

  /// Whether the server is ready.
  bool get ok => status == ServerHealthStatus.ok;
}

/// Calls `GET {address}/api/v1/health` and says what happened.
class ServerHealthChecker {
  /// Creates a checker. [dio] and [isOnline] are for tests.
  ServerHealthChecker({Dio? dio, Future<bool> Function()? isOnline})
    : _dio =
          dio ??
          apiDio(
            connect: const Duration(seconds: 6),
            receive: const Duration(seconds: 8),
            send: const Duration(seconds: 8),
          ),
      _isOnline = isOnline ?? (() async => true);

  final Dio _dio;
  final Future<bool> Function() _isOnline;

  /// Checks the server at [address] (the dashboard folder, without
  /// `/api/v1`). Without `mod_rewrite` the dashboard is reachable as
  /// `/api/v1/index.php/health`; that form is tried when the first one is
  /// not found.
  Future<ServerHealth> check(String address) async {
    if (!hasServer(address)) {
      return const ServerHealth(ServerHealthStatus.notConfigured);
    }
    final root = address.replaceAll(RegExp(r'/+$'), '');
    var result = await _get('$root/api/v1/health');
    if (result.status == ServerHealthStatus.wrongAddress) {
      final second = await _get('$root/api/v1/index.php/health');
      if (second.ok) result = second;
    }
    debugPrint(
      '[CONNECTION] $address → ${result.status.name} '
      '(${result.detail ?? ''})',
    );
    return result;
  }

  Future<ServerHealth> _get(String url) async {
    try {
      final response = await _dio.get<Object?>(
        url,
        options: Options(validateStatus: (_) => true),
      );
      final code = response.statusCode ?? 0;
      final body = response.data;
      if (code >= 500) {
        return ServerHealth(
          ServerHealthStatus.serverDown,
          detail: 'HTTP $code',
        );
      }
      if (code == 200 && body is Map && body['status'] == 'ok') {
        final time = body['time'];
        return ServerHealth(
          ServerHealthStatus.ok,
          serverTime: time is String ? time : null,
        );
      }
      return ServerHealth(
        ServerHealthStatus.wrongAddress,
        detail: 'HTTP $code',
      );
    } on DioException catch (e) {
      return _fromError(e);
    } on Object catch (e) {
      return ServerHealth(ServerHealthStatus.wrongAddress, detail: '$e');
    }
  }

  Future<ServerHealth> _fromError(DioException e) async {
    final detail = '${e.type.name}: ${e.error ?? e.message}';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ServerHealth(
          await _isOnline()
              ? ServerHealthStatus.timeout
              : ServerHealthStatus.noNetwork,
          detail: detail,
        );
      case DioExceptionType.connectionError:
        if (e.error == 'cleartext_not_allowed') {
          return ServerHealth(ServerHealthStatus.httpBlocked, detail: detail);
        }
        if (!await _isOnline()) {
          return ServerHealth(ServerHealthStatus.noNetwork, detail: detail);
        }
        final text = '${e.error}'.toLowerCase();
        if (text.contains('refused')) {
          return ServerHealth(ServerHealthStatus.serverDown, detail: detail);
        }
        if (e.error is SocketException &&
            (text.contains('lookup') || text.contains('resolve'))) {
          return ServerHealth(ServerHealthStatus.wrongAddress, detail: detail);
        }
        return ServerHealth(ServerHealthStatus.unreachable, detail: detail);
      case DioExceptionType.badCertificate:
        return ServerHealth(ServerHealthStatus.wrongAddress, detail: detail);
      case DioExceptionType.badResponse:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ServerHealth(ServerHealthStatus.unreachable, detail: detail);
    }
  }
}

/// The app's health checker.
final serverHealthCheckerProvider = Provider<ServerHealthChecker>(
  (ref) => ServerHealthChecker(isOnline: ref.watch(isOnlineProvider)),
);
