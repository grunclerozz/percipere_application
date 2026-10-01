import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/tts/language_detector.dart';

void main() {
  test('Filipino', () {
    final g = detectLanguage(
      'Ang Bataan ay isang lalawigan sa rehiyon ng Gitnang Luzon. '
      'Kilala ito sa kasaysayan nito.',
    );
    expect(g.language, DocLanguage.filipino);
    expect(g.mixed, isFalse);
  });

  test('English', () {
    final g = detectLanguage(
      'Please bring this form to the barangay hall. The office is open from '
      'Monday to Friday, and you should arrive early.',
    );
    expect(g.language, DocLanguage.english);
  });

  test('Taglish leans Filipino (a Filipino voice handles English words)', () {
    final g = detectLanguage(
      'Please pumunta kayo sa barangay hall para sa meeting. Ang schedule ay '
      'on Monday, at dalhin ninyo ang inyong ID for verification.',
    );
    expect(g.language, DocLanguage.filipino);
    expect(g.mixed, isTrue);
  });

  test('no function words: falls back', () {
    expect(
      detectLanguage('Bigas 250.00 Asukal 80.00').language,
      DocLanguage.filipino,
    );
    expect(
      detectLanguage('12345', fallback: DocLanguage.english).language,
      DocLanguage.english,
    );
  });

  test('"may" counts for neither language', () {
    final g = detectLanguage('may may may');
    expect(g.filipinoHits + g.englishHits, 0);
  });
}
