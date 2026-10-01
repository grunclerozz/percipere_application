import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/ocr/ocr_service.dart';
import 'package:percipere_app/features/camera/camera_guidance.dart';

import '../../helpers/fakes.dart';

void main() {
  group('Guidance.of', () {
    test('classifies frames', () {
      expect(Guidance.of(Frames.dark), Guidance.tooDark);
      expect(Guidance.of(Frames.empty), Guidance.noText);
      expect(Guidance.of(Frames.far), Guidance.moveCloser);
      expect(Guidance.of(Frames.good), Guidance.ready);
      expect(
        Guidance.of(
          const FrameStats(
            lineCount: 20,
            textAreaFraction: 0.8,
            touchesEdge: true,
            meanLuma: 120,
          ),
        ),
        Guidance.moveBack,
      );
    });
  });

  group('GuidanceTracker', () {
    final t0 = DateTime(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('speaks a hint only once it holds for two frames', () {
      final tracker = GuidanceTracker();
      expect(tracker.update(Guidance.noText, at(0)).speak, isNull);
      final step = tracker.update(Guidance.noText, at(650));
      expect(step.speak, Guidance.noText);
    });

    test('flicker between hints stays quiet', () {
      final tracker = GuidanceTracker();
      for (var i = 0; i < 6; i++) {
        final g = i.isEven ? Guidance.moveCloser : Guidance.ready;
        expect(tracker.update(g, at(i * 650)).speak, isNull);
      }
    });

    test('waits the minimum gap between different hints', () {
      final tracker = GuidanceTracker();
      tracker
        ..update(Guidance.noText, at(0))
        ..markSpoken(tracker.update(Guidance.noText, at(650)).speak!, at(650));
      tracker.update(Guidance.moveCloser, at(1300));
      expect(tracker.update(Guidance.moveCloser, at(1950)).speak, isNull);
      expect(
        tracker.update(Guidance.moveCloser, at(3200)).speak,
        Guidance.moveCloser,
      );
    });

    test('repeats a problem after a while, but not "ready"', () {
      final tracker = GuidanceTracker()
        ..update(Guidance.noText, at(0))
        ..markSpoken(Guidance.noText, at(650));
      expect(tracker.update(Guidance.noText, at(3000)).speak, isNull);
      expect(tracker.update(Guidance.noText, at(7000)).speak, Guidance.noText);

      final ready = GuidanceTracker()
        ..update(Guidance.ready, at(0))
        ..markSpoken(Guidance.ready, at(650));
      expect(ready.update(Guidance.ready, at(9000)).speak, isNull);
    });

    test('auto-capture after four ready frames in a row', () {
      final tracker = GuidanceTracker();
      final steps = [
        for (var i = 0; i < 4; i++) tracker.update(Guidance.ready, at(i * 650)),
      ];
      expect(steps.map((s) => s.autoCapture), [false, false, false, true]);
      expect(
        tracker.update(Guidance.moveCloser, at(3000)).autoCapture,
        isFalse,
      );
    });
  });
}
