import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

/// System pickers. Abstract so tests can script choices.
abstract interface class DocumentPicker {
  /// Opens the Storage Access Framework picker for JPG/PNG/PDF/DOCX.
  Future<PickResult> pickDocument();

  /// Fallback when the in-app camera fails: the phone's own camera app.
  Future<PickResult> takePhotoWithSystemCamera();
}

/// [DocumentPicker] via `file_picker` (no broad storage permission needed)
/// and `image_picker`.
class SystemDocumentPicker implements DocumentPicker {
  /// Creates the picker.
  const SystemDocumentPicker();

  @override
  Future<PickResult> pickDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
    );
    if (files.isEmpty) return const PickCancelled();
    final path = files.first.path;
    if (path == null) return const PickCancelled();
    final kind = DocumentKind.forPath(path);
    if (kind == null) return const PickUnsupported();
    return Picked(DocumentFile(path: path, kind: kind));
  }

  @override
  Future<PickResult> takePhotoWithSystemCamera() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null) return const PickCancelled();
    return Picked(
      DocumentFile(
        path: photo.path,
        kind: DocumentKind.image,
        fromCamera: true,
      ),
    );
  }
}

/// The app's document picker.
final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => const SystemDocumentPicker(),
);
