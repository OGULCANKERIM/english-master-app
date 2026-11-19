import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/screens/kelime_modulu.dart';

void main() {
  test('alanlar kırpılır, seviye büyük, tür küçük harfe çevrilir', () {
    final sonuc = kelimeleriDuzenle([
      {'ing': ' Answer ', 'tr': ' Cevap', 'type': ' N ', 'lvl': ' a1 ', 'sentence': ' The answer is correct. '},
    ]);
    expect(sonuc, [
      {'ing': 'Answer', 'tr': 'Cevap', 'type': 'n', 'lvl': 'A1', 'sentence': 'The answer is correct.'},
    ]);
  });

  test('eksik hücreler boş metin olur, "null" yazısı çıkmaz', () {
    final sonuc = kelimeleriDuzenle([
      {'ing': 'Apple', 'tr': 'Elma'},
      {'ing': 'Run', 'tr': 'Koşmak', 'sentence': null, 'type': null, 'lvl': null},
    ]);
    expect(sonuc.length, 2);
    for (final kelime in sonuc) {
      expect(kelime['sentence'], '');
      expect(kelime['type'], '');
      expect(kelime['lvl'], '');
    }
  });

  test('İngilizcesi ya da Türkçesi olmayan ve bozuk satırlar atılır', () {
    final sonuc = kelimeleriDuzenle([
      {'ing': '', 'tr': 'Boş'},
      {'ing': 'Only', 'tr': '  '},
      {'tr': 'Yok'},
      'satır değil',
      null,
      42,
      {'ing': 'Ok', 'tr': 'Tamam', 'lvl': 'B2'},
    ]);
    expect(sonuc.length, 1);
    expect(sonuc.single['ing'], 'Ok');
  });

  test('sayı olarak gelen hücre metne çevrilir', () {
    final sonuc = kelimeleriDuzenle([
      {'ing': 7, 'tr': 'Yedi'},
    ]);
    expect(sonuc.single['ing'], '7');
  });
}
