import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Longest side of an image sent to the server.
const int uploadMaxSide = 1280;

/// Longest side of a history thumbnail.
const int thumbnailMaxSide = 320;

/// Decodes [bytes], turns it upright, shrinks it so its longest side is at
/// most [maxSide] (never enlarges) and encodes it as JPEG. Pure; run it off
/// the UI isolate. Null if [bytes] isn't an image.
Uint8List? resizeToJpeg(Uint8List bytes, int maxSide, {int quality = 85}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    // Truncated or foreign data: some decoders throw instead of returning null.
    return null;
  }
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

/// Image work for Maglarawan. Abstract so tests need no files or isolates.
abstract interface class ImagePrep {
  /// The image at [path], shrunk and compressed for upload; null if
  /// unreadable.
  Future<Uint8List?> forUpload(String path);

  /// Saves a small thumbnail of the image at [path] for Reading History and
  /// returns its file path; null if unreadable.
  Future<String?> saveThumbnail(String path);
}

/// [ImagePrep] that works in a background isolate.
class IsolateImagePrep implements ImagePrep {
  /// Creates the service.
  const IsolateImagePrep();

  @override
  Future<Uint8List?> forUpload(String path) async {
    final bytes = await File(path).readAsBytes();
    return Isolate.run(() => resizeToJpeg(bytes, uploadMaxSide));
  }

  @override
  Future<String?> saveThumbnail(String path) async {
    final bytes = await File(path).readAsBytes();
    final jpeg = await Isolate.run(
      () => resizeToJpeg(bytes, thumbnailMaxSide, quality: 75),
    );
    if (jpeg == null) return null;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'thumbnails'));
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, 'thumb_${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await file.writeAsBytes(jpeg);
    return file.path;
  }
}

/// The app's image preparation.
final imagePrepProvider = Provider<ImagePrep>(
  (ref) => const IsolateImagePrep(),
);

/// Removes a history thumbnail; a missing file or path is fine.
Future<void> deleteThumbnail(String? path) async {
  if (path == null) return;
  try {
    await File(path).delete();
  } on Object {
    // Already gone.
  }
}
