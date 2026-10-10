import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// A file as Android's picker hands it back: a local cached copy ([path]),
/// or only a `content://` address whose bytes must be read through the
/// plugin ([bytes]).
final class FakePickedFile extends PlatformFile {
  /// Creates a picked file.
  FakePickedFile({required this.name, String? path, this.bytes})
    : uri = path != null
          ? Uri.file(path)
          : Uri.parse('content://com.android.providers.downloads/1/$name');

  @override
  final String name;

  @override
  final Uri uri;

  /// What reading the content address yields (null: reading fails).
  final Uint8List? bytes;

  @override
  XFile get xFile => XFile(uri.toString(), name: name);

  @override
  int? lengthSync() => bytes?.length;

  @override
  Future<int?> length() async => bytes?.length;

  /// Like the Android plugin: a file with a path is read from that path
  /// (so a missing cached copy fails); only a content:// address is read
  /// through the content resolver ([bytes]).
  @override
  Future<Uint8List> readAsBytes() async {
    final local = path;
    if (local != null) return File(local).readAsBytes();
    final b = bytes;
    if (b == null) throw const FileSystemException('permission denied');
    return b;
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromFuture(readAsBytes());
}

/// The file_picker plugin, scripted: returns [next] (null = the user
/// closed the picker), or throws [error].
class FakeFilePickerPlatform extends FilePickerPlatform {
  /// What the next pick returns.
  PlatformFile? next;

  /// Thrown by the next pick instead, if set.
  Object? error;

  /// Whether the app asked for a single file.
  bool askedForOne = false;

  /// Extensions the app allowed.
  List<String>? allowed;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    askedForOne = true;
    allowed = allowedExtensions;
    final e = error;
    if (e != null) throw e;
    return next;
  }
}
