import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/ocr/ocr_service.dart';

/// A live camera with text analysis on preview frames. Abstract so the
/// camera screen can be tested without a camera.
abstract interface class CameraSession {
  /// Opens the back camera and starts analysing frames; [onFrame] gets a
  /// summary of each analysed frame (a few per second).
  Future<void> start(void Function(FrameStats stats) onFrame);

  /// The live preview.
  Widget preview();

  /// Stops analysis and takes a full-resolution photo; returns its path.
  Future<String> takePicture();

  /// Releases the camera.
  Future<void> dispose();
}

/// [CameraSession] on the device camera, with ML Kit on NV21 frames.
class DeviceCameraSession implements CameraSession {
  /// Time between analysed frames.
  static const Duration analysisInterval = Duration(milliseconds: 650);

  CameraController? _controller;
  final TextRecognizer _recognizer = TextRecognizer();
  bool _busy = false;
  bool _disposed = false;
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> start(void Function(FrameStats stats) onFrame) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw CameraException('none', 'No camera');
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = _controller = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    try {
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
    } on Object {
      // Not all devices support these; defaults are fine.
    }
    await controller.startImageStream((image) {
      final now = DateTime.now();
      if (_busy ||
          _disposed ||
          now.difference(_lastAnalysis) < analysisInterval) {
        return;
      }
      _busy = true;
      _lastAnalysis = now;
      unawaited(
        _analyse(image, back.sensorOrientation)
            .then((stats) {
              if (!_disposed) onFrame(stats);
            })
            .catchError((Object e) => debugPrint('Frame analysis failed: $e'))
            .whenComplete(() => _busy = false),
      );
    });
  }

  Future<FrameStats> _analyse(CameraImage image, int sensorOrientation) async {
    final bytes = toNv21(image);
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final input = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
    final result = await _recognizer.processImage(input);
    final sideways =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final upright = sideways
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
    return toFrameStats(
      result,
      upright,
      meanLuma(bytes, image.width * image.height),
    );
  }

  @override
  Widget preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.expand();
    return CameraPreview(c);
  }

  @override
  Future<String> takePicture() async {
    final c = _controller!;
    if (c.value.isStreamingImages) await c.stopImageStream();
    unawaited(HapticFeedback.heavyImpact());
    final file = await c.takePicture();
    return file.path;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.dispose();
    }
    await _recognizer.close();
  }
}

/// Packs a camera frame as NV21 (Y plane, then interleaved V/U), whether the
/// plugin delivered one NV21 plane or three YUV_420_888 planes. Rows are
/// copied without their stride padding.
Uint8List toNv21(CameraImage image) {
  final w = image.width;
  final h = image.height;
  if (image.planes.length == 1) {
    final plane = image.planes.first;
    if (plane.bytesPerRow == w) return plane.bytes;
    return _unpad(plane.bytes, plane.bytesPerRow, w, h + h ~/ 2);
  }
  final out = Uint8List(w * h + 2 * (w ~/ 2) * (h ~/ 2));
  final y = image.planes[0];
  out.setRange(0, w * h, _unpad(y.bytes, y.bytesPerRow, w, h));
  final u = image.planes[1];
  final v = image.planes[2];
  final uvPixelStride = u.bytesPerPixel ?? 1;
  var o = w * h;
  for (var row = 0; row < h ~/ 2; row++) {
    for (var col = 0; col < w ~/ 2; col++) {
      final i = row * u.bytesPerRow + col * uvPixelStride;
      out[o++] = v.bytes[i];
      out[o++] = u.bytes[i];
    }
  }
  return out;
}

Uint8List _unpad(Uint8List src, int stride, int width, int rows) {
  final out = Uint8List(width * rows);
  for (var r = 0; r < rows; r++) {
    final start = r * stride;
    if (start + width > src.length) break;
    out.setRange(r * width, (r + 1) * width, src, start);
  }
  return out;
}

/// Average of a sample of the first [ySize] bytes (the luma plane).
double meanLuma(Uint8List nv21, int ySize) {
  final n = ySize < nv21.length ? ySize : nv21.length;
  if (n == 0) return 0;
  var sum = 0;
  var count = 0;
  for (var i = 0; i < n; i += 97) {
    sum += nv21[i];
    count++;
  }
  return sum / count;
}

/// Creates camera sessions (a new one each time the camera screen opens or
/// resumes).
final cameraSessionFactoryProvider = Provider<CameraSession Function()>(
  (ref) => DeviceCameraSession.new,
);
