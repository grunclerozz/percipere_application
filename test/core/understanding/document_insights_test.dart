import 'package:flutter_test/flutter_test.dart';
import 'package:percipere_app/core/understanding/document_insights.dart';

void main() {
  test('receipt: store name and total (not the subtotal)', () {
    const text = '''
Tindahan ni Aling Rosa
Official Receipt No. 00123
Bigas 5kg 1 x 250.00
Asukal 1kg 1 x 85.50
Subtotal 335.50
VAT 12% 40.26
TOTAL ₱375.76
Cash 500.00
Change 124.24
Salamat po!''';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.receipt);
    expect(d.total, '375.76');
    expect(d.from, 'Tindahan ni Aling Rosa');
    expect(d.hasKeyFacts, isTrue);
  });

  test('bill: amount due and due date', () {
    const text = '''
MERALCO
Statement of Account
Account Number 1234-5678-90
Billing Period Sep 1 - Sep 30, 2026
Total Amount Due
PHP 1,245.50
Due Date: Oct 15, 2026
Please pay on or before the due date to avoid disconnection.''';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.bill);
    expect(d.total, '1,245.50');
    expect(d.dueDate, 'Oct 15, 2026');
  });

  test('bill in Filipino', () {
    const text = '''
Bataan Water District
Kabuuang babayaran: P 512.00
Petsa ng pagbabayad: 20 Oktubre 2026
Bayaran bago ang due date upang hindi maputulan ng tubig.''';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.bill);
    expect(d.total, '512.00');
    expect(d.dueDate, '20 Oktubre 2026');
  });

  test('medicine: dosage and expiry', () {
    const text = '''
Paracetamol 500mg
20 tablets
Dosage: Take 1 tablet every 6 hours as needed for fever.
Do not exceed 8 tablets a day.
Keep out of reach of children.
EXP: 03/2028''';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.medicine);
    expect(d.dosage, contains('Take 1 tablet every 6 hours'));
    expect(d.expiry, isNotNull);
  });

  test('letter: who it is for', () {
    const text = '''
Mahal na Nanay,
Kumusta na po kayo diyan sa Bataan? Mabuti naman po kami dito.
Uuwi po ako sa Disyembre para sa Pasko.
Nagmamahal,
Juan''';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.letter);
    expect(d.from, 'Nanay');
    expect(d.hasKeyFacts, isFalse);
  });

  test('form', () {
    const text = '''
Application Form
Pangalan: ____________
Tirahan: ____________
Petsa ng kapanganakan: ________
Lagda: ________''';
    expect(DocumentAnalyzer.analyze(text).type, DocType.form);
  });

  test('ordinary text is "other" (no guessing from one word)', () {
    const text =
        'Ang mga bata ay naglalaro sa labas. Masaya sila. '
        'Ang total na saya ay hindi mabibilang.';
    final d = DocumentAnalyzer.analyze(text);
    expect(d.type, DocType.other);
    expect(d.total, isNull);
  });

  test('summary keeps the most informative sentences in order', () {
    const text =
        'Ang barangay ay magkakaroon ng libreng bakuna sa Sabado. '
        'Ang bakuna ay para sa mga bata at matatanda. '
        'Magdala ng ID at ng vaccination card. '
        'Maraming salamat sa inyong pakikiisa sa barangay. '
        'Ang panahon ay maganda ngayong linggo. '
        'Ang bakuna ay gagawin sa barangay hall mula alas-otso.';
    final summary = DocumentAnalyzer.summarize(text);
    expect(summary, hasLength(3));
    expect(summary.join(' '), contains('bakuna'));
    // In reading order.
    final positions = [for (final s in summary) text.indexOf(s)];
    expect(positions, orderedEquals([...positions]..sort()));
  });

  test('empty text', () {
    expect(DocumentAnalyzer.analyze('').type, DocType.other);
    expect(DocumentAnalyzer.summarize(''), isEmpty);
  });
}
