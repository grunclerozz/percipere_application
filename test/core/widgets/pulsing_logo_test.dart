// The loading screen's pulsing logo: it breathes while active, and stays
// still when inactive or when the system asks for no animations.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/config/constants.dart';
import 'package:percipere_app/core/widgets/pulsing_logo.dart';

Widget _app({bool active = true}) => MaterialApp(
  home: Scaffold(body: PulsingLogo(active: active)),
);

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(PulsingLogo),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('pulses while active: the opacity rises and falls again', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final start = _opacity(tester);
    await tester.pump(AppDurations.logoPulse);
    final peak = _opacity(tester);
    expect(peak, greaterThan(start), reason: 'one breath in: at its fullest');
    await tester.pump(AppDurations.logoPulse);
    expect(_opacity(tester), lessThan(peak), reason: 'and out again');
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('stays still when not active', (tester) async {
    await tester.pumpWidget(_app(active: false));
    final start = _opacity(tester);
    await tester.pump(AppDurations.logoPulse);
    expect(_opacity(tester), start);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('stops when it becomes inactive (loading done)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(AppDurations.logoPulse * 0.3);
    await tester.pumpWidget(_app(active: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('"remove animations" keeps it still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app());
    final start = _opacity(tester);
    await tester.pump(AppDurations.logoPulse * 0.5);
    expect(_opacity(tester), start);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    expect(
      tester.getSemantics(find.byType(PulsingLogo)).label,
      isEmpty,
    );
    handle.dispose();
  });
}
