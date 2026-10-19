import 'dart:io' show Platform;

import 'package:dio/dio.dart';

import '../../config/env.dart';

/// Refuses plain `http://` to any host the build did not allow (Android
/// only; `Env.allowsCleartext`). Android's network security config says the
/// same for its own network stack, but Dart's HTTP client ignores that, so
/// the app checks it itself: a mistyped or hostile address can never carry
/// accounts or reports over plain HTTP.
class CleartextGuard extends Interceptor {
  /// Creates the guard. [enforce] and [allows] are for tests.
  CleartextGuard({bool? enforce, bool Function(String host)? allows})
    : _enforce = enforce ?? Platform.isAndroid,
      _allows = allows ?? Env.allowsCleartext;

  final bool _enforce;
  final bool Function(String host) _allows;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (_enforce && uri.scheme == 'http' && !_allows(uri.host)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'cleartext_not_allowed',
          message: 'Plain HTTP to ${uri.host} is not allowed in this build.',
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// Called when a request to the web app could not reach it (no connection,
/// timeout). Set by the server connection (`serverConnectionProvider`) to look
/// for the server again; null in tests. Gets the address that failed.
void Function(Uri failed)? serverUnreachableHook;

/// Tells [serverUnreachableHook] when a request fails before any answer.
class UnreachableReporter extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    const unreachable = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    // A request refused by our own guard says nothing about the server.
    if (unreachable.contains(err.type) &&
        err.error != 'cleartext_not_allowed') {
      try {
        serverUnreachableHook?.call(err.requestOptions.uri);
      } on Object {
        // Looking for the server must never hide the request's own error.
      }
    }
    handler.next(err);
  }
}

/// The HTTP client the app's web-app clients use: timeouts, the
/// [CleartextGuard] and (unless [reportUnreachable] is false) the
/// [UnreachableReporter].
Dio apiDio({
  Duration connect = const Duration(seconds: 10),
  Duration receive = const Duration(seconds: 20),
  Duration send = const Duration(seconds: 20),
  bool reportUnreachable = true,
}) =>
    Dio(
        BaseOptions(
          connectTimeout: connect,
          receiveTimeout: receive,
          sendTimeout: send,
        ),
      )
      ..interceptors.addAll([
        CleartextGuard(),
        if (reportUnreachable) UnreachableReporter(),
      ]);
