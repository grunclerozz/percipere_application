import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/env.dart';
import 'issue_report.dart';

/// What the web app answered for a report.
@immutable
class IssueReceipt {
  /// Creates a receipt.
  const IssueReceipt({required this.serverId, required this.status});

  /// The web app's id (`feedback_id`).
  final String serverId;

  /// Its status there (`open`, …).
  final String status;
}

/// Why a report wasn't sent.
class IssueSendException implements Exception {
  /// Creates the exception.
  const IssueSendException(this.reason, {required this.refused});

  /// For logs only (never the report's text).
  final String reason;

  /// The web app rejected the report itself: retrying won't help. Otherwise
  /// (no connection, server error, too many reports) it is tried again later.
  final bool refused;

  @override
  String toString() => 'IssueSendException($reason, refused: $refused)';
}

/// Sends a report to the web app (the dashboard's `POST /api/v1/reports`).
abstract interface class IssueReportApi {
  /// Sends [report]; [token] links it to the signed-in account. Sending the
  /// same ticket twice stores it once. Throws [IssueSendException].
  Future<IssueReceipt> send(IssueReport report, {String? token});
}

/// [IssueReportApi] over HTTP (dio).
class HttpIssueReportApi implements IssueReportApi {
  /// Creates the client for the web app at [baseUrl].
  HttpIssueReportApi(String baseUrl, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
            ),
          ) {
    _dio.options
      ..baseUrl = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/'
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  @override
  Future<IssueReceipt> send(IssueReport report, {String? token}) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        'reports',
        data: report.toJson(),
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (e) {
      throw IssueSendException(e.type.name, refused: false);
    }
    final status = response.statusCode ?? 0;
    final data = response.data;
    // 201 new, 200 the same ticket again (nothing stored twice): both are done.
    if (status >= 200 && status < 300 && data is Map && data['id'] != null) {
      return IssueReceipt(
        serverId: '${data['id']}',
        status: (data['status'] as String?) ?? 'open',
      );
    }
    final error = data is Map ? data['error'] : null;
    final code = error is Map ? '${error['code']}' : 'HTTP $status';
    // 4xx other than 429: the report itself was refused.
    throw IssueSendException(
      code,
      refused: status >= 400 && status < 500 && status != 429,
    );
  }
}

/// The web app's report endpoint, or null when no web app is configured
/// (then reports stay "Naghihintay ipadala" on the phone).
final issueReportApiProvider = Provider<IssueReportApi?>(
  (ref) => Env.apiBaseUrl == Env.noServer
      ? null
      : HttpIssueReportApi(Env.apiBaseUrl),
);

/// App version, Android version and phone model (attached to reports).
Future<IssueDetails> readIssueDetails() async {
  var appVersion = '';
  var os = 'Android';
  var model = '';
  try {
    final info = await PackageInfo.fromPlatform();
    appVersion = '${info.version}+${info.buildNumber}';
  } on Object catch (e) {
    debugPrint('Package info failed: $e');
  }
  try {
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      os = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      model = '${a.manufacturer} ${a.model}';
    }
  } on Object catch (e) {
    debugPrint('Device info failed: $e');
  }
  String cut(String s, int max) => s.length > max ? s.substring(0, max) : s;
  return IssueDetails(
    appVersion: cut(appVersion, 20),
    osVersion: cut(os, 40),
    deviceModel: cut(model, 100),
  );
}

/// How the app and phone details are read (tests override it).
final issueDetailsProvider = Provider<Future<IssueDetails> Function()>(
  (ref) => readIssueDetails,
);
