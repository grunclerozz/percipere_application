// Spelling a name back letter by letter, reading a spelled name, and the
// yes/no after "J-U-A-N, tama ba?".

import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/auth/name_spelling.dart';

void main() {
  test('spell: letters joined by dashes, words apart by a pause', () {
    expect(NameSpelling.spell('Juan'), 'J-U-A-N');
    expect(NameSpelling.spell('  juan   carlos '), 'J-U-A-N, C-A-R-L-O-S');
    expect(NameSpelling.spell('Dela Cruz'), 'D-E-L-A, C-R-U-Z');
    expect(NameSpelling.spell(''), '');
  });

  test('a spelled name is joined and capitalized', () {
    expect(NameSpelling.parseSpelled('j u a n'), 'Juan');
    expect(NameSpelling.parseSpelled('J. U. A. N.'), 'Juan');
    expect(NameSpelling.parseSpelled('j-u-a-n'), 'Juan');
    expect(NameSpelling.parseSpelled('jey yu ey en'), 'Juan');
    expect(
      NameSpelling.parseSpelled('j u a n space c r u z'),
      'Juan Cruz',
    );
    expect(NameSpelling.parseSpelled('enye a'), 'Ña');
  });

  test('ordinary names and single words are not "spelled"', () {
    expect(NameSpelling.parseSpelled('Juan'), isNull);
    expect(NameSpelling.parseSpelled('Juan Carlos'), isNull);
    expect(NameSpelling.parseSpelled('si Juan'), isNull);
    expect(NameSpelling.parseSpelled('a'), isNull, reason: 'one letter');
    expect(NameSpelling.parseSpelled(''), isNull);
  });

  test('yes: tama, oo, opo, yes, with filler', () {
    for (final said in ['tama', 'Tama po', 'oo', 'opo', 'yes', 'correct',
      'oo tama na', 'okay', 'Tama!']) {
      expect(NameSpelling.answer(said), SpellAnswer.yes, reason: said);
    }
  });

  test('no: mali, hindi, no (a no wins over a yes)', () {
    for (final said in ['mali', 'Mali po', 'hindi', 'hindi po', 'no',
      'wrong', 'hindi tama', 'mali ulit']) {
      expect(NameSpelling.answer(said), SpellAnswer.no, reason: said);
    }
  });

  test('anything else is neither (a new name, a command)', () {
    for (final said in ['Pedro', 'j u a n', 'tapos na', 'tama ang pangalan ko',
      '', '   ']) {
      expect(NameSpelling.answer(said), SpellAnswer.none, reason: said);
    }
  });
}
