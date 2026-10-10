import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/voice/understanding.dart';

void main() {
  group('clean: everyday phrasing → command words', () {
    final cases = {
      'Pwede bang ulitin mo po': 'ulitin',
      'pakibasa nga': 'basahin',
      'Paki-ulit lang': 'ulitin',
      'pakihinto po': 'itigil',
      'gusto kong bumalik': 'bumalik',
      'Can you go back please': 'go back',
      'I want to open the library': 'open the library',
      'pakibilisan naman': 'bilisan',
      'tumigil ka muna': 'itigil ka',
    };
    cases.forEach((said, expected) {
      test('"$said" → "$expected"', () {
        expect(Understanding.clean(said), expected);
      });
    });

    test('never cleans everything away', () {
      expect(Understanding.clean('po'), 'po');
      expect(Understanding.clean('please'), 'please');
    });
  });

  group('questions', () {
    final cases = {
      'Nasaan ako?': Question.whereAmI,
      'nasan na ako ngayon': Question.whereAmI,
      'Where am I': Question.whereAmI,
      'ano ang pwede kong gawin dito': Question.whatCanIDo,
      'what can I say': Question.whatCanIDo,
      'Anong oras na po?': Question.time,
      'what time is it': Question.time,
      'anong petsa ngayon': Question.date,
      'paano gamitin ang app': Question.tutorial,
      'teach me': Question.tutorial,
    };
    cases.forEach((said, expected) {
      test('"$said" → ${expected.name}', () {
        expect(Understanding.question(said), expected);
      });
    });

    test('commands are not questions', () {
      for (final said in ['susunod', 'bumalik', 'basahin', 'mag-upload']) {
        expect(Understanding.question(said), isNull, reason: said);
      }
    });

    final docCases = {
      'magkano ang babayaran': Question.total,
      'how much': Question.total,
      'kailan ang due': Question.due,
      'kailan mapapaso': Question.expiry,
      'paano inumin': Question.dosage,
      'ibuod mo nga': Question.summary,
      'summarize': Question.summary,
      'ano ito': Question.docType,
      'ilan pa': Question.progress,
    };
    docCases.forEach((said, expected) {
      test('document: "$said" → ${expected.name}', () {
        expect(Understanding.documentQuestion(said), expected);
      });
    });
  });

  group('documents by name', () {
    test('verb, article and title (original words kept)', () {
      final c = Understanding.titleCommand('Basahin ang Liham kay Nanay')!;
      expect(c.verb, TitleVerb.read);
      expect(c.title, 'Liham kay Nanay');
      expect(c.last, isFalse);
    });

    test('polite and Taglish forms', () {
      expect(
        Understanding.titleCommand('pakibasa nga yung resibo po')?.title,
        'resibo',
      );
      expect(
        Understanding.titleCommand('pakibukas ang Florante')?.verb,
        TitleVerb.open,
      );
      expect(
        Understanding.titleCommand('open my Meralco bill')?.title,
        'Meralco bill',
      );
      expect(
        Understanding.titleCommand('ituloy ang Liham')?.verb,
        TitleVerb.resume,
      );
    });

    test('"the last one" means the most recent', () {
      expect(Understanding.titleCommand('ituloy ang pagbasa')!.last, isTrue);
      expect(Understanding.titleCommand('buksan ang huli')!.last, isTrue);
      expect(Understanding.titleCommand('continue the last one')!.last, isTrue);
    });

    test('a verb alone is not a title command', () {
      expect(Understanding.titleCommand('basahin'), isNull);
      expect(Understanding.titleCommand('basahin mo po'), isNull);
      expect(Understanding.titleCommand('susunod'), isNull);
    });
  });
}
