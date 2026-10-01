import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/widgets/document_box.dart';
import 'package:percipere_app/core/widgets/pill_button.dart';
import 'package:percipere_app/core/widgets/speaking_zone.dart';
import 'package:percipere_app/core/widgets/waveform.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('PillButton', () {
    testWidgets('is at least 56dp tall, tappable and labelled', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        Scaffold(
          body: Center(
            child: PillButton(label: 'Mag-upload', onPressed: () => taps++),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(56),
      );
      await tester.tap(find.byType(PillButton));
      expect(taps, 1);

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mag-upload')),
        matchesSemantics(
          label: 'Mag-upload',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('meets Android tap-target and label guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        Scaffold(
          body: Center(
            child: PillButton(label: 'Pa-boses', onPressed: () {}),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Waveform', () {
    testWidgets('animates only while active', (tester) async {
      await pumpThemed(tester, const Scaffold(body: Waveform()));
      expect(tester.hasRunningAnimations, isFalse);

      await pumpThemed(tester, const Scaffold(body: Waveform(active: true)));
      expect(tester.hasRunningAnimations, isTrue);

      await pumpThemed(tester, const Scaffold(body: Waveform()));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stays still when system animations are disabled', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Waveform(active: true)),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('SpeakingZone shows subtitle and the heard line', (tester) async {
    await pumpThemed(
      tester,
      const Scaffold(
        body: SpeakingZone(subtitle: 'Paano?', heard: 'camera'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paano?'), findsOneWidget);
    expect(find.text('Narinig: “camera”'), findsOneWidget);
  });

  group('DocumentBox', () {
    testWidgets('shows the loading state', (tester) async {
      await pumpThemed(
        tester,
        const Scaffold(body: DocumentBox(text: null, isLoading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Binabasa ang dokumento…'), findsOneWidget);
    });

    testWidgets('shows an always-visible scrollbar for long text', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Scaffold(
          body: SizedBox(
            height: 200,
            child: DocumentBox(text: List.filled(80, 'Pangungusap.').join(' ')),
          ),
        ),
      );
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.thumbVisibility, isTrue);
    });

    testWidgets('shows the empty state and the caption strip', (tester) async {
      await pumpThemed(
        tester,
        const Scaffold(
          body: DocumentBox(text: '  ', caption: 'Bilis: 1.2x'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Walang tekstong mababasa.'), findsOneWidget);
      expect(find.text('Bilis: 1.2x'), findsOneWidget);
    });

    testWidgets('highlights the current sentence', (tester) async {
      await pumpThemed(
        tester,
        const Scaffold(
          body: DocumentBox(
            text: 'Una. Ikalawa.',
            highlight: TextRange(start: 5, end: 13),
          ),
        ),
      );
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(DocumentBox),
          matching: find.byType(RichText),
        ),
      );
      final spans = <InlineSpan>[];
      rich.text.visitChildren((span) {
        spans.add(span);
        return true;
      });
      final highlighted = spans.whereType<TextSpan>().firstWhere(
        (s) => s.style?.backgroundColor != null,
      );
      expect(highlighted.text, 'Ikalawa.');
      expect(highlighted.style!.decoration, TextDecoration.underline);
    });
  });
}
