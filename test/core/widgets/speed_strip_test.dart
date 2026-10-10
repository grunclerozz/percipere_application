// The speed strip at the right edge of the Gesture Pad: slide up/down for
// reading speed in 0.25x steps (0.5x–2.0x), a tick per step, the final
// value spoken once, saved; adjustable for TalkBack; separate from the
// pad's own swipes.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/db/daos/preferences_dao.dart';
import 'package:percipere_app/core/gestures/gesture_surface.dart';
import 'package:percipere_app/core/settings/settings_controller.dart';
import 'package:percipere_app/core/widgets/gesture_pad.dart';
import 'package:percipere_app/core/widgets/speed_strip.dart';
import 'package:percipere_app/features/home/home_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/library_ui.dart';
import '../../helpers/pump_app.dart';

Future<TestEnv> _start(WidgetTester tester) async {
  final env = await libraryEnv(tester);
  await pumpApp(tester, env);
  expect(find.byType(HomeScreen), findsOneWidget);
  await tester.settleReal();
  return env;
}

extension on WidgetTester {
  double get rate =>
      ProviderScope.containerOf(element(find.byType(SpeedStrip)))
          .read(settingsProvider)
          .readingRate;

  /// Slides a finger along the strip by [dy] in small moves.
  Future<void> slideStrip(double dy) async {
    final start = getCenter(find.byType(SpeedStrip));
    final g = await startGesture(start);
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await pump(const Duration(milliseconds: 16));
      await g.moveTo(start + Offset(0, dy * i / steps));
    }
    await g.up();
    await settleReal();
  }
}

void main() {
  testWidgets('right edge of the Gesture Pad, full height, at least 48 dp', (
    tester,
  ) async {
    await _start(tester);
    final strip = tester.getRect(find.byType(SpeedStrip));
    final pad = tester.getRect(find.byType(GesturePad));
    expect(strip.width, greaterThanOrEqualTo(48));
    expect(strip.width, closeTo(88, 1));
    expect(strip.right, closeTo(pad.right, 2));
    expect(strip.height, closeTo(pad.height, 3));
    expect(find.text('Bilis'), findsOneWidget);
    expect(find.text('2.0x'), findsOneWidget);
    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('slide up: faster in 0.25 steps, a tick each, the final value '
      'spoken once and saved', (tester) async {
    final env = await _start(tester);
    final before = env.tts.spoken.length;
    final ticks = env.haptics.events.where((e) => e == 'tick').length;
    await tester.slideStrip(-80); // 2 steps of 36 dp
    expect(tester.rate, 1.5);
    expect(find.text('1.5x'), findsOneWidget);
    expect(
      env.haptics.events.where((e) => e == 'tick').length,
      greaterThanOrEqualTo(ticks + 2),
    );
    expect(env.tts.spoken.sublist(before), ['Bilis 1.5']);
    expect(env.tts.rates.last, 1.5, reason: 'said at the new speed');
    final saved = await tester.runAsync(
      () =>
          PreferencesDao(env.database.db)
              .get(PrefKeys.readingRate, userId: env.account?.id ?? 'device'),
    );
    expect(saved, 1.5);

    await tester.slideStrip(80);
    expect(tester.rate, 1.0, reason: 'slide down: slower');
  });

  testWidgets('clamped at 2.0x and 0.5x with an error buzz', (tester) async {
    final env = await _start(tester);
    await tester.slideStrip(-400);
    expect(tester.rate, 2.0);
    expect(env.haptics.events, contains('error'));
    expect(env.tts.spoken.last, 'Bilis 2.0');
    await tester.slideStrip(400);
    await tester.slideStrip(200);
    expect(tester.rate, 0.5);
  });

  testWidgets('swipes on the pad never change the speed, and the strip '
      'never counts as a pad swipe', (tester) async {
    final env = await _start(tester);
    final surface = tester.getRect(
      find.descendant(
        of: find.byType(GesturePad),
        matching: find.byType(GestureSurface),
      ),
    );
    expect(
      surface.right,
      lessThanOrEqualTo(tester.getRect(find.byType(SpeedStrip)).left + 1),
    );
    await tester.flingFrom(surface.center, const Offset(0, -200), 1000);
    await tester.settleReal();
    await tester.flingFrom(surface.center, const Offset(0, 200), 1000);
    await tester.settleReal();
    expect(tester.rate, 1.0);

    final before = env.tts.spoken.length;
    await tester.slideStrip(-80);
    expect(
      env.tts.spoken.sublist(before),
      everyElement(startsWith('Bilis')),
      reason: 'no focus move or other command',
    );
  });

  testWidgets('TalkBack: an adjustable "Bilis, 1.0 na beses" with Bilisan / '
      'Bagalan actions', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await _start(tester);
    final node = tester.getSemantics(find.byType(SpeedStrip));
    final data = node.getSemanticsData();
    expect(data.label, 'Bilis, 1.0 na beses');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.customSemanticsActionIds, hasLength(2));
    final labels = [
      for (final id in data.customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, containsAll(['Bilisan', 'Bagalan']));

    tester.semantics.decrease(find.semantics.byLabel('Bilis, 1.0 na beses'));
    await tester.settleReal();
    expect(tester.rate, 0.75);
    expect(env.tts.spoken.last, 'Bilis 0.75');
    expect(
      tester.getSemantics(find.byType(SpeedStrip)).label,
      'Bilis, 0.75 na beses',
    );
    handle.dispose();
  });
}
