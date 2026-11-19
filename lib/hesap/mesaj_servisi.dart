import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'hesap_servisi.dart';

const int mesajUzunlukSiniri = 1000;

/// `sohbetler/{ogrenciId}_{egitmenId}` belgesi.
class Sohbet {
  const Sohbet({
    required this.ogrenciId,
    required this.egitmenId,
    required this.sonMesaj,
    required this.okunmamisOgrenci,
    required this.okunmamisEgitmen,
  });

  factory Sohbet.belgeden(Map<String, dynamic> veri) {
    return Sohbet(
      ogrenciId: veri['ogrenciId'] is String ? veri['ogrenciId'] as String : '',
      egitmenId: veri['egitmenId'] is String ? veri['egitmenId'] as String : '',
      sonMesaj: veri['sonMesaj'] is String ? veri['sonMesaj'] as String : '',
      okunmamisOgrenci: _sayi(veri['okunmamisOgrenci']),
      okunmamisEgitmen: _sayi(veri['okunmamisEgitmen']),
    );
  }

  final String ogrenciId;
  final String egitmenId;
  final String sonMesaj;
  final int okunmamisOgrenci;
  final int okunmamisEgitmen;

  /// [uid] için okunmamış mesaj sayısı.
  int okunmamis(String? uid) {
    if (uid == ogrenciId) return okunmamisOgrenci;
    if (uid == egitmenId) return okunmamisEgitmen;
    return 0;
  }

  static int _sayi(Object? deger) => deger is num && deger > 0 ? deger.toInt() : 0;
}

class Mesaj {
  const Mesaj({
    required this.id,
    required this.gonderen,
    required this.metin,
    required this.zaman,
    required this.bekliyor,
  });

  final String id;
  final String gonderen;
  final String metin;
  final DateTime? zaman;

  /// Henüz sunucuya ulaşmadı (ör. çevrimdışı gönderildi).
  final bool bekliyor;
}

/// Öğrenci ile seçtiği eğitmen arasındaki birebir mesajlaşma.
class MesajServisi {
  MesajServisi._();

  static CollectionReference<Map<String, dynamic>> get _sohbetler =>
      FirebaseFirestore.instance.collection('sohbetler');

  static DocumentReference<Map<String, dynamic>> _sohbet(String ogrenciId, String egitmenId) =>
      _sohbetler.doc('${ogrenciId}_$egitmenId');

  static String _gerekliUid() {
    final id = HesapServisi.uid;
    if (id == null) throw const HesapHatasi('Önce giriş yapmalısın.');
    return id;
  }

  /// Tek sohbet; henüz mesaj yazılmadıysa null yayınlar.
  static Stream<Sohbet?> sohbetiIzle(String ogrenciId, String egitmenId) {
    _gerekliUid();
    return _sohbet(ogrenciId, egitmenId).snapshots().map((belge) {
      final veri = belge.data();
      return veri == null ? null : Sohbet.belgeden(veri);
    });
  }

  /// Giriş yapan eğitmenin tüm sohbetleri. Kurallarla eşleşir: `egitmenId == uid`.
  static Stream<List<Sohbet>> egitmenSohbetleriniIzle() {
    final id = _gerekliUid();
    return _sohbetler.where('egitmenId', isEqualTo: id).snapshots().map(
          (sonuc) => [for (final belge in sonuc.docs) Sohbet.belgeden(belge.data())],
        );
  }

  /// Son 100 mesaj, en yenisi başta.
  static Stream<List<Mesaj>> mesajlariIzle(String ogrenciId, String egitmenId) {
    _gerekliUid();
    return _sohbet(ogrenciId, egitmenId)
        .collection('mesajlar')
        .orderBy('zaman', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true)
        .map((sonuc) {
      return [
        for (final belge in sonuc.docs)
          () {
            final veri = belge.data();
            final zaman = veri['zaman'];
            return Mesaj(
              id: belge.id,
              gonderen: veri['gonderen'] is String ? veri['gonderen'] as String : '',
              metin: veri['metin'] is String ? veri['metin'] as String : '',
              zaman: zaman is Timestamp ? zaman.toDate() : null,
              bekliyor: belge.metadata.hasPendingWrites,
            );
          }(),
      ];
    });
  }

  /// Mesajı ekler ve sohbet belgesini (son mesaj, karşı tarafın okunmamış sayacı)
  /// tek toplu yazımla günceller. Çevrimdışıyken sıraya girer; dönen Future
  /// sunucu onaylayınca tamamlanır.
  static Future<void> gonder({
    required String ogrenciId,
    required String egitmenId,
    required String metin,
  }) {
    final ben = _gerekliUid();
    final temiz = metin.trim();
    if (temiz.isEmpty) return Future<void>.value();
    if (temiz.length > mesajUzunlukSiniri) {
      throw const HesapHatasi('Mesaj en fazla $mesajUzunlukSiniri karakter olabilir.');
    }
    final sohbet = _sohbet(ogrenciId, egitmenId);
    final karsiSayac = ben == ogrenciId ? 'okunmamisEgitmen' : 'okunmamisOgrenci';
    final toplu = FirebaseFirestore.instance.batch()
      ..set(sohbet.collection('mesajlar').doc(), <String, Object?>{
        'gonderen': ben,
        'metin': temiz,
        'zaman': FieldValue.serverTimestamp(),
      })
      ..set(
        sohbet,
        <String, Object?>{
          'ogrenciId': ogrenciId,
          'egitmenId': egitmenId,
          'sonMesaj': temiz.length > 100 ? temiz.substring(0, 100) : temiz,
          'sonGonderen': ben,
          'sonZaman': FieldValue.serverTimestamp(),
          karsiSayac: FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    return toplu.commit();
  }

  /// Giriş yapan tarafın okunmamış sayacını sıfırlar.
  static Future<void> okunduIsaretle(String ogrenciId, String egitmenId) {
    final ben = _gerekliUid();
    final sayac = ben == ogrenciId ? 'okunmamisOgrenci' : 'okunmamisEgitmen';
    return _sohbet(ogrenciId, egitmenId).update(<String, Object?>{sayac: 0});
  }

  /// Ana menü için: giriş yapan kullanıcının toplam okunmamış mesaj sayısı.
  /// Giriş yoksa, Firebase yoksa veya hata olursa 0 yayınlar.
  static Stream<int> okunmamisSayisiniIzle() {
    if (!HesapServisi.hazir) return Stream<int>.value(0);
    return _degistir<String?, int>(HesapServisi.oturumuIzle(), (uid) {
      if (uid == null) return Stream<int>.value(0);
      return _degistir<Kullanici?, int>(HesapServisi.profilimiIzle(), (ben) {
        if (ben == null) return Stream<int>.value(0);
        if (ben.egitmenMi) {
          // Yalnızca hâlâ öğrencim olanların sohbetleri sayılır.
          return _birlestir<List<Kullanici>, List<Sohbet>, int>(
            HesapServisi.ogrencilerimiIzle(),
            egitmenSohbetleriniIzle(),
            (ogrenciler, sohbetler) => egitmenOkunmamisi(ogrenciler, sohbetler).values.fold(0, (a, b) => a + b),
          );
        }
        final egitmenId = ben.egitmenId;
        if (egitmenId == null) return Stream<int>.value(0);
        return sohbetiIzle(ben.uid, egitmenId).map((sohbet) => sohbet?.okunmamisOgrenci ?? 0);
      });
    });
  }

  /// Öğrenci uid'si -> eğitmenin o öğrenciden okunmamış mesaj sayısı.
  static Map<String, int> egitmenOkunmamisi(List<Kullanici> ogrenciler, List<Sohbet> sohbetler) {
    final kimlikler = {for (final ogrenci in ogrenciler) ogrenci.uid};
    return {
      for (final sohbet in sohbetler)
        if (kimlikler.contains(sohbet.ogrenciId) && sohbet.okunmamisEgitmen > 0)
          sohbet.ogrenciId: sohbet.okunmamisEgitmen,
    };
  }
}

/// [kaynak] her değer verdiğinde [sec] ile yeni bir akışa geçer (öncekini bırakır).
/// Hatalar yutulur ve 0 benzeri bir varsayılan yerine sessiz kalınır.
Stream<R> _degistir<T, R>(Stream<T> kaynak, Stream<R> Function(T deger) sec) {
  late final StreamController<R> denetleyici;
  StreamSubscription<T>? dis;
  StreamSubscription<R>? ic;
  denetleyici = StreamController<R>(
    onListen: () {
      dis = kaynak.listen(
        (deger) {
          unawaited(ic?.cancel());
          try {
            ic = sec(deger).listen(denetleyici.add, onError: (Object _) {});
          } catch (_) {
            ic = null;
          }
        },
        onError: (Object _) {},
      );
    },
    onCancel: () async {
      await ic?.cancel();
      await dis?.cancel();
    },
  );
  return denetleyici.stream;
}

/// İki akışın son değerlerini birleştirir (ikisi de en az bir değer verdikten sonra).
Stream<R> _birlestir<A, B, R>(Stream<A> a, Stream<B> b, R Function(A a, B b) birlestir) {
  late final StreamController<R> denetleyici;
  StreamSubscription<A>? aboneA;
  StreamSubscription<B>? aboneB;
  A? sonA;
  B? sonB;
  var varA = false;
  var varB = false;
  void yayinla() {
    if (varA && varB) denetleyici.add(birlestir(sonA as A, sonB as B));
  }

  denetleyici = StreamController<R>(
    onListen: () {
      aboneA = a.listen((deger) {
        sonA = deger;
        varA = true;
        yayinla();
      }, onError: denetleyici.addError);
      aboneB = b.listen((deger) {
        sonB = deger;
        varB = true;
        yayinla();
      }, onError: denetleyici.addError);
    },
    onCancel: () async {
      await aboneA?.cancel();
      await aboneB?.cancel();
    },
  );
  return denetleyici.stream;
}
