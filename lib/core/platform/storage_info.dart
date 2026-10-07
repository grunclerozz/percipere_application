import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Free space on the phone, to warn before a big download.
abstract interface class StorageInfo {
  /// Free bytes in the app's storage, or null when unknown.
  Future<int?> freeBytes();
}

/// [StorageInfo] via a small Android channel (`StatFs`).
class DeviceStorageInfo implements StorageInfo {
  /// Creates the device implementation.
  const DeviceStorageInfo();

  static const MethodChannel _channel = MethodChannel(
    'ph.bataan.percipere/storage',
  );

  @override
  Future<int?> freeBytes() async {
    try {
      return await _channel.invokeMethod<int>('freeBytes');
    } on Object {
      return null; // Unknown: don't block the download.
    }
  }
}

/// Free-space source; overridden in tests.
final storageInfoProvider = Provider<StorageInfo>(
  (ref) => const DeviceStorageInfo(),
);
