import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../describe/image_labeler.dart';
import '../ocr/ocr_service.dart';
import '../offline_voice/offline_engines.dart';
import '../percy/percy_controller.dart';
import '../settings/settings_controller.dart';
import '../tts/tts_service.dart';
import '../voice/voice_controller.dart';

/// What the startup loading screen prepares before the first screen.
enum StartupStep {
  /// Settings and the database (opened by `bootstrap()`).
  settings,

  /// The speech engine and its voice (the app's own offline voices load).
  voice,

  /// The offline command recognizer (loaded and warmed up with one silent
  /// decode) and Android's recognizer (set up); then the room's noise is
  /// measured for a second.
  recognizer,

  /// Percy's intent model.
  percy,

  /// ML Kit text recognition (OCR) and image labeling, each run once on a
  /// tiny blank picture so their models are loaded.
  mlkit,
}

/// One step's work. Throwing counts as done (the app goes on without it;
/// the failure is logged).
typedef StartupTask = Future<void> Function();

/// The startup work, by step. Overridden in tests.
final startupTasksProvider = Provider<Map<StartupStep, StartupTask>>(
  (ref) => {
    StartupStep.settings: () async => ref.read(settingsProvider),
    StartupStep.voice: () async {
      final engines = ref.read(offlineEnginesProvider);
      await engines.voicesLoaded;
      // The voices known now (the app's own may have just loaded).
      await ref.read(voiceStatusProvider.notifier).refresh();
    },
    StartupStep.recognizer: () async {
      await ref.read(offlineEnginesProvider).loaded;
      final voice = ref.read(voiceControllerProvider.notifier);
      await voice.warmUp();
      // The room's noise, measured once while the loading screen is quiet:
      // the speech threshold for the first commands.
      await voice.calibrateNoise();
    },
    StartupStep.percy: () async => ref.read(percyBrainProvider.future),
    StartupStep.mlkit: () => warmUpMlKit(
      ref.read(ocrServiceProvider),
      ref.read(imageLabelerProvider),
    ),
  },
);

/// Runs OCR and image labeling once on a tiny blank picture, so ML Kit
/// creates its recognizers and loads its models now and not on the first
/// photo (where it happens on Android's main thread, next to the voice).
Future<void> warmUpMlKit(OcrService ocr, ImageLabelerService labeler) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(dir.path, 'warmup_${DateTime.now().microsecondsSinceEpoch}.png'),
  );
  try {
    final blank = img.Image(width: 64, height: 64)
      ..clear(img.ColorRgb8(255, 255, 255));
    await file.writeAsBytes(img.encodePng(blank), flush: true);
    await Future.wait([
      ocr.recognizeFile(file.path).then<void>((_) {}),
      labeler.label(file.path).then<void>((_) {}),
    ]);
  } on Object catch (e) {
    debugPrint('[STARTUP] ML Kit warm-up failed: $e');
    rethrow;
  } finally {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Temporary folder: cleaned by the system anyway.
    }
  }
}

/// How long the last cold start took on the loading screen, for the
/// developer voice-state overlay. Null until the loading screen is done.
class StartupReport extends Notifier<Duration?> {
  @override
  Duration? build() => null;

  /// Records the load time.
  void set(Duration took) => state = took;
}

/// The last cold start's load time.
final startupReportProvider = NotifierProvider<StartupReport, Duration?>(
  StartupReport.new,
);

/// Started in `main()`: time since the app process began running Dart.
final Stopwatch launchClock = Stopwatch();
