import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Haftanın günleri; sıra `DateTime.weekday` ile aynıdır (Pazartesi = 1).
const List<String> randevuGunleri = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

const List<String> randevuSeviyeleri = ['A1', 'A2', 'B1', 'B2', 'C1'];

/// Eğitmenin kendi eklediği öğrenci ve onun haftalık speaking randevusu.
/// Kayıtlar eğitmenin cihazında saklanır; öğrencinin uygulamada hesabı olması gerekmez.
@immutable
class OgrenciKaydi {
  const OgrenciKaydi({
    required this.id,
    required this.ad,
    required this.seviye,
    required this.gun,
    required this.saat,
    required this.dakika,
    this.konu = '',
  });

  final String id;
  final String ad;
  final String seviye;

  /// Randevu günü: 1 (Pazartesi) – 7 (Pazar).
  final int gun;
  final int saat;
  final int dakika;

  /// O derste konuşulacak konu ya da not (isteğe bağlı).
  final String konu;

  String get gunAdi => randevuGunleri[gun - 1];
  String get saatMetni => '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}';
  String get basHarf => ad.isEmpty ? '?' : ad.substring(0, 1).toUpperCase();

  /// [simdi]'den sonraki ilk randevu zamanı (şu an süren dakika da sayılır).
  DateTime sonrakiZaman(DateTime simdi) {
    final bugun = DateTime(simdi.year, simdi.month, simdi.day, saat, dakika);
    int fark = (gun - simdi.weekday) % 7;
    if (fark == 0 && bugun.isBefore(DateTime(simdi.year, simdi.month, simdi.day, simdi.hour, simdi.minute))) fark = 7;
    // Gün eklemek yaz/kış saati geçişinde saati kaydırmasın diye tarih yeniden kurulur.
    return DateTime(simdi.year, simdi.month, simdi.day + fark, saat, dakika);
  }

  /// "Bugün 19:00", "Yarın 19:00" ya da "Salı 19:00 · 3 gün sonra".
  String neZaman(DateTime simdi) {
    final zaman = sonrakiZaman(simdi);
    // UTC tarihleriyle hesaplanır; yaz/kış saati geçişi gün sayısını bozmaz.
    final int gunFarki =
        DateTime.utc(zaman.year, zaman.month, zaman.day).difference(DateTime.utc(simdi.year, simdi.month, simdi.day)).inDays;
    if (gunFarki <= 0) return 'Bugün $saatMetni';
    if (gunFarki == 1) return 'Yarın $saatMetni';
    return '$gunAdi $saatMetni · $gunFarki gün sonra';
  }

  OgrenciKaydi kopya({String? ad, String? seviye, int? gun, int? saat, int? dakika, String? konu}) => OgrenciKaydi(
        id: id,
        ad: ad ?? this.ad,
        seviye: seviye ?? this.seviye,
        gun: gun ?? this.gun,
        saat: saat ?? this.saat,
        dakika: dakika ?? this.dakika,
        konu: konu ?? this.konu,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'ad': ad, 'seviye': seviye, 'gun': gun, 'saat': saat, 'dakika': dakika, 'konu': konu};

  /// Bozuk ya da eksik kayıtta null döner.
  static OgrenciKaydi? fromJson(Object? veri) {
    if (veri is! Map) return null;
    final String ad = (veri['ad'] ?? '').toString().trim();
    final String id = (veri['id'] ?? '').toString();
    final gun = veri['gun'], saat = veri['saat'], dakika = veri['dakika'];
    if (ad.isEmpty || id.isEmpty || gun is! int || saat is! int || dakika is! int) return null;
    if (gun < 1 || gun > 7 || saat < 0 || saat > 23 || dakika < 0 || dakika > 59) return null;
    final String seviye = (veri['seviye'] ?? '').toString();
    return OgrenciKaydi(
      id: id,
      ad: ad,
      seviye: randevuSeviyeleri.contains(seviye) ? seviye : randevuSeviyeleri.first,
      gun: gun,
      saat: saat,
      dakika: dakika,
      konu: (veri['konu'] ?? '').toString().trim(),
    );
  }
}

/// İlk açılışta eklenen iki öğrenci; eğitmen bunları düzenleyebilir ya da silebilir.
List<OgrenciKaydi> ornekOgrenciler() => const [
      OgrenciKaydi(id: 'ornek-1', ad: 'Elif Kaya', seviye: 'B1', gun: 2, saat: 19, dakika: 0, konu: 'Travel & Culture'),
      OgrenciKaydi(id: 'ornek-2', ad: 'Can Demir', seviye: 'A2', gun: 4, saat: 20, dakika: 30, konu: 'Small Talk'),
    ];

/// Öğrencileri en yakın randevudan en uzağa sıralar.
List<OgrenciKaydi> randevuyaGoreSirala(Iterable<OgrenciKaydi> ogrenciler, DateTime simdi) {
  final liste = ogrenciler.toList();
  liste.sort((a, b) {
    final int z = a.sonrakiZaman(simdi).compareTo(b.sonrakiZaman(simdi));
    return z != 0 ? z : a.ad.toLowerCase().compareTo(b.ad.toLowerCase());
  });
  return liste;
}

List<OgrenciKaydi> ogrencileriCoz(String? kayit) {
  if (kayit == null || kayit.isEmpty) return [];
  try {
    final cozulen = jsonDecode(kayit);
    if (cozulen is! List) return [];
    return [
      for (final oge in cozulen)
        if (OgrenciKaydi.fromJson(oge) case final OgrenciKaydi kayit) kayit,
    ];
  } catch (e) {
    debugPrint("Öğrenci kayıtları çözülemedi: $e");
    return [];
  }
}

String ogrencileriKodla(Iterable<OgrenciKaydi> ogrenciler) => jsonEncode([for (final o in ogrenciler) o.toJson()]);

/// Eğitmenin öğrenci kayıtlarını cihazda saklar (her eğitmen hesabı için ayrı).
class RandevuDeposu {
  RandevuDeposu(this.egitmenId);

  final String egitmenId;

  String get _anahtar => 'egitmen_ogrencileri_$egitmenId';

  /// Kayıtlı öğrenciler; hiç kayıt yapılmamışsa iki örnek öğrenci eklenir.
  Future<List<OgrenciKaydi>> yukle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? kayit = prefs.getString(_anahtar);
    if (kayit == null) {
      final ornekler = ornekOgrenciler();
      await prefs.setString(_anahtar, ogrencileriKodla(ornekler));
      return ornekler;
    }
    return ogrencileriCoz(kayit);
  }

  Future<void> kaydet(Iterable<OgrenciKaydi> ogrenciler) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_anahtar, ogrencileriKodla(ogrenciler));
  }
}
