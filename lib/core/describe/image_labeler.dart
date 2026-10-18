import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// One thing ML Kit thinks is in the picture.
@immutable
class LabelResult {
  /// Creates a label result ([count] is how many were seen, when the source
  /// can count; ML Kit's image labeling can't, so it stays 1).
  const LabelResult(this.label, this.confidence, {this.count = 1});

  /// English label, as the model names it ("Plate").
  final String label;

  /// Model confidence, 0..1.
  final double confidence;

  /// How many of it are in the picture (1 when unknown).
  final int count;
}

/// On-device image labeling. Abstract so tests can script what is "seen".
abstract interface class ImageLabelerService {
  /// Labels the (color) image at [path], most confident first.
  Future<List<LabelResult>> label(String path);

  /// Frees native resources.
  Future<void> close();
}

/// [ImageLabelerService] on ML Kit's bundled base model (works offline).
class MlKitImageLabelerService implements ImageLabelerService {
  // Everything above 0.5 is returned; the app applies its own, stricter cut.
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  @override
  Future<List<LabelResult>> label(String path) async {
    final labels = await _labeler.processImage(InputImage.fromFilePath(path));
    final results = [for (final l in labels) LabelResult(l.label, l.confidence)]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  @override
  Future<void> close() => _labeler.close();
}

/// The app's image labeler.
final imageLabelerProvider = Provider<ImageLabelerService>((ref) {
  final service = MlKitImageLabelerService();
  ref.onDispose(service.close);
  return service;
});
