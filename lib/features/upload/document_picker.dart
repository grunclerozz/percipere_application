import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/extraction/document_extractor.dart';

/// Outcome of asking the user for a file.
@immutable
sealed class PickResult {
  const PickResult();
}

/// A supported file was chosen.
final class Picked extends PickResult {
  /// Creates the result.
  const Picked(this.file);

  /// The chosen document.
  final DocumentFile file;
}

/// The picker was closed without a choice.
final class PickCancelled extends PickResult {
  /// Creates the result.
  const PickCancelled();
}

/// A file of an unsupported type was chosen.
final class PickUnsupported extends PickResult {
  /// Creates the result.
  const PickUnsupported();
}

/// A file was chosen but could not be read or copied (or the picker itself
/// failed). Not the same as cancelling.
final class PickFailed extends PickResult {
  /// Creates the result; [error] is for the logs.
  const PickFailed(this.error);

  /// What went wrong.
  final Object error;
}

/// Logs a capture/upload problem with its stack trace (`adb logcat -s
/// flutter | findstr CAPTURE`).
void logCapture(String what, Object error, [StackTrace? stack]) {
  debugPrint('[CAPTURE] $what: $error');
  if (stack != null) debugPrint('[CAPTURE] $stack');
}

/// System pickers. Abstract so tests can script choices.
abstract interface class DocumentPicker {
  /// Opens the Storage Access Framework picker for JPG/PNG/PDF/DOCX.
  Future<PickResult> pickDocument();

  /// Opens the picker for JPG/PNG images only (Maglarawan).
  Future<PickResult> pickImage();

  /// Fallback when the in-app camera fails: the phone's own camera app.
  Future<PickResult> takePhotoWithSystemCamera();
}

/// [DocumentPicker] via `file_picker` (no broad storage permission needed)
/// and `image_picker`.
class SystemDocumentPicker implements DocumentPicker {
  /// Creates the picker. [tempDir] is where copies of picked files go
  /// (replaced in tests).
  const SystemDocumentPicker({this.tempDir = getTemporaryDirectory});

  /// The app's temporary directory.
  final Future<Directory> Function() tempDir;

  @override
  Future<PickResult> pickDocument() =>
      _pick(const ['jpg', 'jpeg', 'png', 'pdf', 'docx'], accept: (_) => true);

  @override
  Future<PickResult> pickImage() => _pick(const [
    'jpg',
    'jpeg',
    'png',
  ], accept: (kind) => kind == DocumentKind.image);

  Future<PickResult> _pick(
    List<String> extensions, {
    required bool Function(DocumentKind kind) accept,
  }) async {
    final PlatformFile? file;
    try {
      // One file only: with multiple selection allowed, a file Android
      // fails to copy is silently left out and the result is an empty
      // list, which looks exactly like "cancelled". Single selection
      // reports that failure as an error instead.
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } on Object catch (e, stack) {
      logCapture('the file picker failed', e, stack);
      return PickFailed(e);
    }
    if (file == null) {
      debugPrint('[CAPTURE] picker closed without a file (cancelled)');
      return const PickCancelled();
    }
    // The kind comes from the name: a content:// address has no extension.
    final kind = DocumentKind.forPath(file.name);
    debugPrint(
      '[CAPTURE] picked "${file.name}" kind=${kind?.name} '
      'path=${file.path} uri=${file.uri.scheme} size=${file.lengthSync()}',
    );
    if (kind == null || !accept(kind)) return const PickUnsupported();
    try {
      return Picked(DocumentFile(path: await localCopyOf(file), kind: kind));
    } on Object catch (e, stack) {
      logCapture('the picked file could not be read', e, stack);
      return PickFailed(e);
    }
  }

  /// A readable local path for [file]: its own path when that file is
  /// really there and not empty, otherwise a private copy of its bytes
  /// (Android may hand back only a content:// address). Throws if neither
  /// works (e.g. the cached copy is missing or empty), so a chosen file is
  /// never treated as "nothing chosen".
  @visibleForTesting
  Future<String> localCopyOf(PlatformFile file) async {
    final path = file.path;
    if (path != null) {
      final onDisk = File(path);
      if (await onDisk.exists() && await onDisk.length() > 0) return path;
      debugPrint('[CAPTURE] picked path is missing or empty: $path');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw FileSystemException('the chosen file is empty', file.name);
    }
    final dir = Directory(p.join((await tempDir()).path, 'picked'));
    await dir.create(recursive: true);
    final copy = File(
      p.join(
        dir.path,
        '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.name)}',
      ),
    );
    await copy.writeAsBytes(bytes, flush: true);
    debugPrint('[CAPTURE] read the chosen file by its bytes: ${copy.path}');
    return copy.path;
  }

  @override
  Future<PickResult> takePhotoWithSystemCamera() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo == null) return const PickCancelled();
      return Picked(
        DocumentFile(
          path: photo.path,
          kind: DocumentKind.image,
          fromCamera: true,
        ),
      );
    } on Object catch (e, stack) {
      logCapture('the phone camera app failed', e, stack);
      return PickFailed(e);
    }
  }
}

/// The app's document picker.
final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => const SystemDocumentPicker(),
);
