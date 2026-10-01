import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/features/setup/setup_flow.dart';
import 'package:percipere_app/features/setup/setup_labels.dart';

void main() {
  SetupFlow full() => SetupFlow.start(guest: false, mode: SetupMode.firstRun);

  test('full setup: 10 numbered steps; the sight question shares number 2', () {
    final f = full();
    expect(f.plan, SetupStep.values);
    expect(f.total, 10);
    expect(f.step, SetupStep.navMode);
    expect(f.number, 1);
    final sees = f.next();
    expect(sees.step, SetupStep.seesText);
    expect(sees.number, 2);
    final size = sees.answerSeesText(true);
    expect(size.step, SetupStep.textSize);
    expect(size.number, 2);
    expect(size.next().number, 3);
  });

  test('"cannot see text" skips Steps 2–3, both ways', () {
    final noSight = full().next().answerSeesText(false);
    expect(noSight.step, SetupStep.voiceLanguage);
    expect(noSight.number, 4);
    // Back from Step 4 skips the hidden steps too.
    expect(noSight.back()!.step, SetupStep.seesText);
    expect(noSight.summaryItems, isNot(contains(SetupStep.textSize)));
  });

  test('back keeps going one step; null on the first step', () {
    final f = full().next().answerSeesText(true).next(); // textColor
    expect(f.step, SetupStep.textColor);
    expect(f.back()!.step, SetupStep.textSize);
    expect(full().back(), isNull);
  });

  test('guests: Steps 1, 4, 5 and the summary', () {
    final g = SetupFlow.start(guest: true, mode: SetupMode.firstRun);
    expect(g.plan, [
      SetupStep.navMode,
      SetupStep.voiceLanguage,
      SetupStep.speed,
      SetupStep.summary,
    ]);
    expect(g.total, 4);
    expect(g.next().number, 2);
  });

  test('a guest who registers is asked only the steps not done yet', () {
    final f = SetupFlow.start(
      guest: false,
      mode: SetupMode.firstRun,
      done: {SetupStep.navMode, SetupStep.voiceLanguage, SetupStep.speed},
    );
    expect(f.plan, [
      SetupStep.seesText,
      SetupStep.textSize,
      SetupStep.textColor,
      SetupStep.pitch,
      SetupStep.theme,
      SetupStep.vibration,
      SetupStep.autoRead,
      SetupStep.summary,
    ]);
    expect(f.total, 7);
    expect(f.number, 1);
  });

  test('guests get the full setup from "Ulitin ang setup"', () {
    final f = SetupFlow.start(guest: true, mode: SetupMode.redo);
    expect(f.plan, SetupStep.values);
    expect(f.total, 10);
  });

  test('"Ulitin ang setup" asks everything again', () {
    final f = SetupFlow.start(
      guest: false,
      mode: SetupMode.redo,
      done: SetupStep.values.toSet(),
    );
    expect(f.plan, SetupStep.values);
  });

  test('resume at the saved step (with the saved sight answer)', () {
    final f = SetupFlow.start(
      guest: false,
      mode: SetupMode.firstRun,
      resumeAt: SetupStep.pitch,
      seesText: false,
    );
    expect(f.step, SetupStep.pitch);
    expect(f.back()!.step, SetupStep.speed);
    expect(f.hidden(SetupStep.textColor), isTrue);
  });

  test('from the summary: jump to a step, confirm returns to the summary', () {
    var f = full();
    while (f.step != SetupStep.summary) {
      f = f.step == SetupStep.seesText ? f.answerSeesText(true) : f.next();
    }
    final speed = f.jumpTo(SetupStep.speed);
    expect(speed.step, SetupStep.speed);
    expect(speed.fromSummary, isTrue);
    expect(speed.next().step, SetupStep.summary);
    expect(speed.back()!.step, SetupStep.summary);
  });

  test(
    'from the summary, a skipped text step asks the sight question first',
    () {
      var f = full();
      while (f.step != SetupStep.summary) {
        f = f.step == SetupStep.seesText ? f.answerSeesText(false) : f.next();
      }
      final sees = f.jumpTo(SetupStep.textSize);
      expect(sees.step, SetupStep.seesText);
      final size = sees.answerSeesText(true);
      expect(size.step, SetupStep.textSize);
      expect(size.next().step, SetupStep.summary);
    },
  );

  test('"bumalik sa bilis" names a step', () {
    final items = full().summaryItems;
    expect(matchStepJump('bumalik sa bilis', items), SetupStep.speed);
    expect(matchStepJump('palitan ang kulay', items), SetupStep.textColor);
    expect(matchStepJump('go back to theme', items), SetupStep.theme);
    expect(matchStepJump('bumalik sa nakaraang page', items), isNull);
    expect(matchStepJump('bilis', items), isNull, reason: 'needs the prefix');
  });
}
