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

/// The HTTP client the app's web-app clients use: timeouts and the
/// [CleartextGuard].
Dio apiDio({
  Duration connect = const Duration(seconds: 10),
  Duration receive = const Duration(seconds: 20),
  Duration send = const Duration(seconds: 20),
}) => Dio(
  BaseOptions(
    connectTimeout: connect,
    receiveTimeout: receive,
    sendTimeout: send,
  ),
)..interceptors.add(CleartextGuard());
