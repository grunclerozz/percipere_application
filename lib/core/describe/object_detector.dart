import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Which part of the picture an object is in.
enum ObjectSide {
  /// The left third.
  left,

  /// The middle third.
  middle,

  /// The right third.
  right,
}

/// One object ML Kit found in a picture.
@immutable
class FoundObject {
  /// Creates an object at horizontal position [centerX] (0 = left edge,
  /// 1 = right edge).
  const FoundObject(this.centerX, {this.category});

  /// Horizontal center, 0..1.
  final double centerX;

  /// ML Kit's coarse category ("Food", "Home good", …), when it gave one.
  final String? category;

  /// The third of the picture it is in.
  ObjectSide get side => centerX < 1 / 3
      ? ObjectSide.left
      : centerX > 2 / 3
      ? ObjectSide.right
      : ObjectSide.middle;
}

/// On-device object detection. Abstract so tests can script what is "seen".
abstract interface class ObjectDetectorService {
  /// The objects in the image at [path], left to right.
  Future<List<FoundObject>> detect(String path);

  /// Frees native resources.
  Future<void> close();
}

/// [ObjectDetectorService] on ML Kit's bundled object detector (works
/// offline, sends nothing anywhere).
class MlKitObjectDetectorService implements ObjectDetectorService {
  final ObjectDetector _detector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  @override
  Future<List<FoundObject>> detect(String path) async {
    final found = await _detector.processImage(InputImage.fromFilePath(path));
    if (found.isEmpty) return const [];
    final size = await _imageSize(path);
    // ML Kit turns the picture upright by its EXIF tag; the size read from the
    // file may be the sideways one. A box beyond the width means it is.
    var width = size.width;
    final farthest = found
        .map((o) => o.boundingBox.right)
        .reduce((a, b) => a > b ? a : b);
    if (farthest > width) width = size.height;
    if (width <= 0) return const [];
    return [
      for (final o in found)
        FoundObject(
          (o.boundingBox.center.dx / width).clamp(0.0, 1.0),
          category: o.labels.isEmpty
              ? null
              : (o.labels.toList()
                      ..sort((a, b) => b.confidence.compareTo(a.confidence)))
                    .first
                    .text,
        ),
    ]..sort((a, b) => a.centerX.compareTo(b.centerX));
  }

  Future<ui.Size> _imageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await File(path).readAsBytes(),
    );
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = ui.Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      descriptor.dispose();
      return size;
    } finally {
      buffer.dispose();
    }
  }

  @override
  Future<void> close() => _detector.close();
}

/// The app's object detector.
final objectDetectorProvider = Provider<ObjectDetectorService>((ref) {
  final service = MlKitObjectDetectorService();
  ref.onDispose(service.close);
  return service;
});
