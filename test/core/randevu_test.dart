import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeni_english/core/randevu.dart';

void main() {
  // 2026-11-20 bir Cuma günüdür (weekday == 5).
  final cuma = DateTime(2026, 11, 20, 10, 0);

  OgrenciKaydi kayit({int gun = 2, int saat = 19, int dakika = 0, String ad = 'Elif'}) =>
      OgrenciKaydi(id: 'x-$ad', ad: ad, seviye: 'B1', gun: gun, saat: saat, dakika: dakika);

  group('sonrakiZaman', () {
    test('test tarihi gerçekten Cuma', () => expect(cuma.weekday, DateTime.friday));

    test('haftanın ileriki günü', () {
      expect(kayit(gun: 7).sonrakiZaman(cuma), DateTime(2026, 11, 22, 19, 0));
    });

    test('geçmiş gün gelecek haftaya düşer', () {
      expect(kayit(gun: 2).sonrakiZaman(cuma), DateTime(2026, 11, 24, 19, 0));
    });

    test('bugün ve saati gelmemişse bugün', () {
      expect(kayit(gun: 5, saat: 19).sonrakiZaman(cuma), DateTime(2026, 11, 20, 19, 0));
    });

    test('bugün ama saati geçmişse gelecek hafta', () {
      expect(kayit(gun: 5, saat: 9).sonrakiZaman(cuma), DateTime(2026, 11, 27, 9, 0));
    });

    test('tam o dakikada hâlâ bugün sayılır', () {
      expect(kayit(gun: 5, saat: 10, dakika: 0).sonrakiZaman(DateTime(2026, 11, 20, 10, 0, 45)), DateTime(2026, 11, 20, 10, 0));
    });
  });

  test('neZaman bugün, yarın ve ileriki günü anlatır', () {
    expect(kayit(gun: 5, saat: 19).neZaman(cuma), 'Bugün 19:00');
    expect(kayit(gun: 6, saat: 8, dakika: 5).neZaman(cuma), 'Yarın 08:05');
    expect(kayit(gun: 2).neZaman(cuma), 'Salı 19:00 · 4 gün sonra');
  });

  test('randevuyaGoreSirala en yakın randevuyu başa alır', () {
    final sirali = randevuyaGoreSirala([kayit(gun: 2, ad: 'Sali'), kayit(gun: 6, ad: 'Cumartesi'), kayit(gun: 5, saat: 9, ad: 'Gecen')], cuma);
    expect(sirali.map((o) => o.ad), ['Cumartesi', 'Sali', 'Gecen']);
  });

  group('kayıt', () {
    test('kodlanıp geri çözülür', () {
      final cozulen = ogrencileriCoz(ogrencileriKodla(ornekOgrenciler()));
      expect(cozulen.length, 2);
      expect(cozulen.first.ad, 'Elif Kaya');
      expect(cozulen.first.gunAdi, 'Salı');
      expect(cozulen.last.saatMetni, '20:30');
    });

    test('bozuk kayıtlar atlanır, çökme olmaz', () {
      expect(ogrencileriCoz('bozuk'), isEmpty);
      expect(ogrencileriCoz('{"a":1}'), isEmpty);
      final cozulen = ogrencileriCoz(
          '[{"id":"1","ad":"Ali","seviye":"Z9","gun":3,"saat":18,"dakika":0},{"id":"2","ad":"","gun":3,"saat":18,"dakika":0},{"id":"3","ad":"Veli","gun":9,"saat":18,"dakika":0},7]');
      expect(cozulen.length, 1);
      expect(cozulen.single.seviye, 'A1');
    });

    test('örnek iki öğrencinin randevuları farklı günlerde', () {
      final ornek = ornekOgrenciler();
      expect(ornek.length, 2);
      expect(ornek[0].gun, isNot(ornek[1].gun));
    });
  });

  group('RandevuDeposu', () {
    test('ilk açılışta iki örnek öğrenci ekler, sonra kaydedileni döndürür', () async {
      SharedPreferences.setMockInitialValues({});
      final depo = RandevuDeposu('egitmen1');
      expect((await depo.yukle()).length, 2);
      await depo.kaydet([kayit(ad: 'Tek')]);
      expect((await depo.yukle()).single.ad, 'Tek');
      // Hepsi silinirse örnekler geri gelmez.
      await depo.kaydet([]);
      expect(await depo.yukle(), isEmpty);
      // Başka eğitmenin kayıtları ayrıdır.
      expect((await RandevuDeposu('egitmen2').yukle()).length, 2);
    });
  });
}
