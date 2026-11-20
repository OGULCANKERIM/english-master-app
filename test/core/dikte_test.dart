import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/core/dikte.dart';

void main() {
  group('DikteMetni', () {
    test('parçaları tek metinde toplar ve ilk harfi büyütür', () {
      final d = DikteMetni()..basla('');
      d.parcaGuncelle('i think');
      d.parcaGuncelle('i think movies are');
      expect(d.metin, 'I think movies are');
      expect(d.parcayiBitir(), isTrue);
      d.parcaGuncelle('really fun');
      expect(d.metin, 'I think movies are really fun');
    });

    test('kutuda duran metnin sonuna ekler', () {
      final d = DikteMetni()..basla('Hello there. ');
      d.parcaGuncelle('how are you');
      expect(d.metin, 'Hello there. how are you');
    });

    test('boş parça sessizlik sayılır ve metni bozmaz', () {
      final d = DikteMetni()..basla('');
      d.parcaGuncelle('good morning');
      expect(d.parcayiBitir(), isTrue);
      expect(d.parcayiBitir(), isFalse);
      expect(d.metin, 'Good morning');
    });

    test('yeniden başlayınca eski parça kalmaz', () {
      final d = DikteMetni()..basla('');
      d.parcaGuncelle('old words');
      d.basla('');
      expect(d.metin, '');
    });
  });

  test('konusmaHatasiMesaji önemli hataları açıklar, önemsizleri gizler', () {
    expect(konusmaHatasiMesaji('error_no_match'), contains('duyamadım'));
    expect(konusmaHatasiMesaji('error_permission'), contains('izni'));
    expect(konusmaHatasiMesaji('error_network'), contains('internet'));
    expect(konusmaHatasiMesaji('error_client'), isNull);
    expect(konusmaHatasiMesaji('error_busy'), isNull);
    expect(sessizlikHatasiMi('error_speech_timeout'), isTrue);
    expect(sessizlikHatasiMi('error_network'), isFalse);
  });

  test('ingilizceYerelSec önce en_US, sonra başka bir İngilizce seçer', () {
    expect(ingilizceYerelSec(['tr_TR', 'en_GB', 'en_US']), 'en_US');
    expect(ingilizceYerelSec(['tr-TR', 'en-AU', 'en-GB']), 'en-GB');
    expect(ingilizceYerelSec(['tr_TR', 'en_IN']), 'en_IN');
    expect(ingilizceYerelSec(['tr_TR']), isNull);
    expect(ingilizceYerelSec([]), isNull);
  });

  test('sesDuzeyiOrani 0..1 aralığında kalır', () {
    expect(sesDuzeyiOrani(-50), 0);
    expect(sesDuzeyiOrani(50), 1);
    expect(sesDuzeyiOrani(4), closeTo(0.5, 0.001));
  });
}
