import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/algorithms/wer.dart';
import 'package:percipere_app/core/db/daos/wer_dao.dart';

import '../../helpers/fakes.dart';

void main() {
  group('wordErrorRate', () {
    test('identical sentences have no errors', () {
      final r = wordErrorRate(
        'basahin mo ang talata',
        'Basahin mo ang talata.',
      );
      expect((r.substitutions, r.deletions, r.insertions), (0, 0, 0));
      expect(r.referenceWords, 4);
      expect(r.wer, 0);
    });

    test('one substitution', () {
      final r = wordErrorRate('the cat sat down', 'the cat sit down');
      expect((r.substitutions, r.deletions, r.insertions), (1, 0, 0));
      expect(r.wer, 0.25);
    });

    test('one deletion', () {
      final r = wordErrorRate('open the settings now', 'open settings now');
      expect((r.substitutions, r.deletions, r.insertions), (0, 1, 0));
      expect(r.wer, 0.25);
    });

    test('one insertion', () {
      final r = wordErrorRate('susunod na talata', 'susunod na na talata');
      expect((r.substitutions, r.deletions, r.insertions), (0, 0, 1));
      expect(r.wer, closeTo(1 / 3, 1e-9));
    });

    test('substitution and deletion together', () {
      final r = wordErrorRate('one two three four', 'one three five');
      expect((r.substitutions, r.deletions, r.insertions), (1, 1, 0));
      expect(r.wer, 0.5);
    });

    test('(S + D + I) / N: the error count is the minimum edit distance', () {
      // Several alignments tie at 3 edits; the total never changes.
      final r = wordErrorRate('a b c d e', 'a x c e f');
      expect(r.errors, 3);
      expect(r.referenceWords, 5);
      expect(r.wer, 0.6);
    });

    test('nothing recognized: every word is a deletion, WER is 1', () {
      final r = wordErrorRate('itigil mo na', '');
      expect((r.substitutions, r.deletions, r.insertions), (0, 3, 0));
      expect(r.wer, 1);
    });

    test('WER can pass 1 when there are many insertions', () {
      final r = wordErrorRate('oo', 'oo oo oo');
      expect(r.insertions, 2);
      expect(r.wer, 2);
    });

    test('empty reference', () {
      expect(wordErrorRate('', '').wer, 0);
      expect(wordErrorRate('', 'hello').wer, 1);
    });

    test('case, punctuation and diacritics are ignored', () {
      final r = wordErrorRate('Ano ang nasa larawan?', 'ano ang NASA, larawan');
      expect(r.errors, 0);
    });
  });

  group('WerDao', () {
    WerRecord record(String ref, String hyp) => WerRecord(
      sessionId: 's1',
      locale: 'fil-PH',
      onDevice: true,
      reference: ref,
      hypothesis: hyp,
      result: wordErrorRate(ref, hyp),
      at: DateTime(2026, 10, 17, 9),
    );

    test('saves results and reads them back', () async {
      final db = await openTestDatabase();
      final dao = WerDao(db.db);
      await dao.insert(record('a b c d', 'a b x d'));
      await dao.insert(record('open settings', 'open'));
      final all = await dao.all();
      expect(all, hasLength(2));
      expect(all.first.reference, 'a b c d');
      expect(all.first.result.substitutions, 1);
      expect(all.first.onDevice, isTrue);
      expect(all.last.result.deletions, 1);
      await dao.clear();
      expect(await dao.all(), isEmpty);
    });

    test('CSV has a header, one row per sentence and a pooled total', () {
      final csv = WerDao.toCsv([
        record('a b c d', 'a b x d'),
        record('say "hi", ok', 'say hi ok'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('session,locale,on_device,reference'));
      expect(lines, hasLength(4));
      expect(lines[2], contains('"say ""hi"", ok"'));
      // 1 error / 4 words + 0 errors / 3 words... the second row is
      // "say hi ok" vs "say hi ok" after normalizing: 1 error in 7 words.
      expect(lines.last, startsWith('TOTAL,'));
      expect(lines.last, contains('0.1429'));
    });
  });
}
