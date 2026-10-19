import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/discovery_config.dart';
import '../../config/env.dart';
import 'api_dio.dart';

/// What the scan needs to know about the tablet's network. Abstract so tests
/// can use a fake one.
abstract interface class LocalNetwork {
  /// Whether the tablet is on Wi-Fi (not mobile data only).
  Future<bool> onWifi();

  /// The tablet's own private IPv4 addresses.
  Future<List<String>> ownAddresses();
}

/// The real network: connectivity_plus and the phone's interfaces.
class DeviceNetwork implements LocalNetwork {
  /// Creates the reader.
  const DeviceNetwork();

  @override
  Future<bool> onWifi() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.wifi);
    } on Object catch (e) {
      debugPrint('[DISCOVERY] wifi check failed: $e');
      return false;
    }
  }

  @override
  Future<List<String>> ownAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (Env.isPrivateHost(a.address) && !a.isLoopback) a.address,
      ];
    } on Object catch (e) {
      debugPrint('[DISCOVERY] interfaces failed: $e');
      return const [];
    }
  }
}

/// Whether the dashboard answers at a base URL (`GET {baseUrl}/api/v1/health`
/// returns `{"status": "ok"}`).
typedef ServerProbe = Future<bool> Function(String baseUrl);

/// The real probe: a short plain HTTP request.
ServerProbe httpProbe({
  Duration timeout = DiscoveryConfig.probeTimeout,
  Dio? dio,
}) {
  final client =
      dio ??
      apiDio(
        connect: timeout,
        send: timeout,
        receive: timeout,
        reportUnreachable: false,
      );
  return (baseUrl) async {
    try {
      final response = await client.get<Object?>(
        '$baseUrl/api/v1/health',
        options: Options(validateStatus: (_) => true, followRedirects: false),
      );
      final body = response.data;
      return response.statusCode == 200 &&
          body is Map &&
          body['status'] == 'ok';
    } on Object {
      return false;
    }
  };
}

/// What [ServerDiscovery.locate] did.
@immutable
class DiscoveryResult {
  /// Creates a result.
  const DiscoveryResult(this.address, {required this.scanned});

  /// The address that answered, or null.
  final String? address;

  /// Whether a subnet scan was needed.
  final bool scanned;
}

/// Finds the dashboard: the saved address first, then the one the app was
/// built with, then (on Wi-Fi only) every address of the tablet's subnet on
/// ports 80 and 8888. Short timeouts, a limited number of requests at once
/// and a time budget keep it from freezing the tablet.
class ServerDiscovery {
  /// Creates the finder. All the knobs are for tests.
  ServerDiscovery({
    required this.probe,
    required this.network,
    this.parallel = DiscoveryConfig.parallel,
    this.budget = DiscoveryConfig.budget,
    this.ports = DiscoveryConfig.ports,
    this.folder = DiscoveryConfig.folder,
  });

  /// Asks one address.
  final ServerProbe probe;

  /// The tablet's network.
  final LocalNetwork network;

  /// Requests in flight at once.
  final int parallel;

  /// Time for the whole scan.
  final Duration budget;

  /// Ports tried per address.
  final List<int> ports;

  /// Dashboard folder on the PC.
  final String folder;

  /// Looks for the server. [saved] and [built] are tried in that order;
  /// [onScanStart] runs just before a scan begins.
  Future<DiscoveryResult> locate({
    String? saved,
    required String built,
    void Function()? onScanStart,
  }) async {
    final known = <String>[?saved, built];
    for (final address in known.toSet()) {
      if (await probe(address)) {
        return DiscoveryResult(address, scanned: false);
      }
    }
    if (!await network.onWifi()) {
      return const DiscoveryResult(null, scanned: false);
    }
    onScanStart?.call();
    return DiscoveryResult(await scan(), scanned: true);
  }

  /// Every candidate address of the subnet(s) the tablet is on.
  Future<List<String>> candidates() async {
    final own = await network.ownAddresses();
    final prefixes = {
      for (final a in own) a.substring(0, a.lastIndexOf('.') + 1),
    };
    return [
      for (final port in ports)
        for (final prefix in prefixes)
          for (
            var host = DiscoveryConfig.firstHost;
            host <= DiscoveryConfig.lastHost;
            host++
          )
            if (!own.contains('$prefix$host'))
              'http://$prefix$host${port == 80 ? '' : ':$port'}$folder',
    ];
  }

  /// Probes the subnet and returns the first address that answers, or null
  /// when none does within [budget].
  Future<String?> scan() async {
    final urls = await candidates();
    if (urls.isEmpty) return null;
    final found = Completer<String?>();
    var next = 0;
    Future<void> worker() async {
      while (!found.isCompleted && next < urls.length) {
        final url = urls[next++];
        if (await probe(url) && !found.isCompleted) found.complete(url);
      }
    }

    unawaited(
      Future.wait([for (var i = 0; i < parallel; i++) worker()]).then((_) {
        if (!found.isCompleted) found.complete(null);
      }),
    );
    return found.future.timeout(budget, onTimeout: () => null);
  }
}
