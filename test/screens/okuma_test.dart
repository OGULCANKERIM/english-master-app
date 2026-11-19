import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/screens/reading_modulu.dart';

void main() {
  group('okumaDegerlendirmesiniCoz', () {
    test('normal yanıt', () {
      final sonuc = okumaDegerlendirmesiniCoz({'skor': 85, 'geribildirim': ' Good '});
      expect(sonuc.skor, 85);
      expect(sonuc.geribildirim, 'Good');
    });
    test('metin olarak gelen puan', () {
      final sonuc = okumaDegerlendirmesiniCoz({'skor': '70'});
      expect(sonuc.skor, 70);
      expect(sonuc.geribildirim, '');
    });
    test('ondalıklı puan yuvarlanır', () {
      expect(okumaDegerlendirmesiniCoz({'skor': 79.6}).skor, 80);
    });
    test('aralık dışı puan 0-100 arasına çekilir', () {
      expect(okumaDegerlendirmesiniCoz({'skor': 140}).skor, 100);
      expect(okumaDegerlendirmesiniCoz({'skor': -5}).skor, 0);
    });
    test('eksik ya da anlamsız alanlar çökmez', () {
      expect(okumaDegerlendirmesiniCoz({}).skor, 0);
      expect(okumaDegerlendirmesiniCoz({}).geribildirim, '');
      expect(okumaDegerlendirmesiniCoz({'skor': 'abc', 'geribildirim': null}).skor, 0);
      expect(okumaDegerlendirmesiniCoz({'skor': null, 'geribildirim': 12}).geribildirim, '12');
    });
  });

  group('cumlelereBol', () {
    test('noktalama ile böler', () {
      expect(cumlelereBol('Hi there. How are you? Fine!'), ['Hi there.', 'How are you?', 'Fine!']);
    });
    test('noktalama yoksa tek cümle', () {
      expect(cumlelereBol('  no punctuation here  '), ['no punctuation here']);
    });
    test('boş metin boş liste', () {
      expect(cumlelereBol('   '), isEmpty);
    });
  });
}
