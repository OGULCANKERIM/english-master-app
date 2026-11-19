import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Öğrencinin seçebileceği seviyeler.
const List<String> seviyeler = ['A1', 'A2', 'B1', 'B2', 'C1'];

/// Eğitmenin müsait gün olarak işaretleyebileceği günler.
const List<String> haftaGunleri = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const String rolOgrenci = 'ogrenci';
const String rolEgitmen = 'egitmen';

/// Kullanıcıya gösterilecek Türkçe mesajı taşıyan hata.
class HesapHatasi implements Exception {
  const HesapHatasi(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}

/// Firestore'daki `users/{uid}` belgesi.
class Kullanici {
  const Kullanici({
    required this.uid,
    required this.ad,
    required this.rol,
    required this.seviye,
    required this.hedef,
    required this.egitmenId,
    required this.tanitim,
    required this.uzmanliklar,
    required this.diller,
    required this.musaitGunler,
  });

  factory Kullanici.belgeden(String uid, Map<String, dynamic> veri) {
    final egitmenId = _metin(veri['egitmenId']);
    return Kullanici(
      uid: uid,
      ad: _metin(veri['ad']),
      rol: veri['rol'] == rolEgitmen ? rolEgitmen : rolOgrenci,
      seviye: seviyeler.contains(veri['seviye']) ? veri['seviye'] as String : seviyeler.first,
      hedef: _metin(veri['hedef']),
      egitmenId: egitmenId.isEmpty ? null : egitmenId,
      tanitim: _metin(veri['tanitim']),
      uzmanliklar: _liste(veri['uzmanliklar']),
      diller: _metin(veri['diller']),
      musaitGunler: _liste(veri['musaitGunler']),
    );
  }

  final String uid;
  final String ad;
  final String rol;
  final String seviye;
  final String hedef;
  final String? egitmenId;
  final String tanitim;
  final List<String> uzmanliklar;
  final String diller;
  final List<String> musaitGunler;

  bool get egitmenMi => rol == rolEgitmen;

  /// Ad boşsa gösterilecek yedek metinle birlikte ad.
  String get gorunenAd => ad.isEmpty ? 'İsimsiz' : ad;

  /// Avatar yerine gösterilen baş harf.
  String get basHarf => ad.isEmpty ? '?' : ad.substring(0, 1).toUpperCase();

  static String _metin(Object? deger) => deger is String ? deger.trim() : '';

  static List<String> _liste(Object? deger) {
    if (deger is! List) return const [];
    return [
      for (final oge in deger)
        if (oge is String && oge.trim().isNotEmpty) oge.trim(),
    ];
  }
}

/// Firebase Auth + Firestore işlemleri. Firebase başlatılamadıysa (ör. web)
/// [hazir] false döner; ekranlar bu durumda "bu platformda yok" gösterir.
class HesapServisi {
  HesapServisi._();

  static const Duration _yazmaSuresi = Duration(seconds: 15);

  static String? _bekleyenAd;
  static Future<void>? _garantiIsi;
  static String? _garantiUid;

  static bool get hazir => Firebase.apps.isNotEmpty;

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static String? get uid => hazir ? _auth.currentUser?.uid : null;

  static String? get eposta => hazir ? _auth.currentUser?.email : null;

  static void _hazirOlmali() {
    if (!hazir) {
      throw const HesapHatasi('Hesap özellikleri bu platformda kullanılamıyor.');
    }
  }

  static String _gerekliUid() {
    _hazirOlmali();
    final id = _auth.currentUser?.uid;
    if (id == null) throw const HesapHatasi('Önce giriş yapmalısın.');
    return id;
  }

  // ---------------------------------------------------------------- Oturum

  /// Giriş yapan kullanıcının uid'sini, çıkışta null yayınlar.
  static Stream<String?> oturumuIzle() {
    if (!hazir) return Stream<String?>.value(null);
    return _auth.authStateChanges().map((kullanici) => kullanici?.uid);
  }

  static Future<void> kayitOl({
    required String ad,
    required String eposta,
    required String sifre,
  }) async {
    _hazirOlmali();
    final temizAd = ad.trim();
    _bekleyenAd = temizAd;
    final UserCredential sonuc;
    try {
      sonuc = await _auth.createUserWithEmailAndPassword(email: eposta.trim(), password: sifre);
    } catch (_) {
      _bekleyenAd = null;
      rethrow;
    }
    try {
      await sonuc.user?.updateDisplayName(temizAd);
    } catch (_) {
      // Görünen ad yalnızca yedek; asıl ad Firestore belgesinde durur.
    }
    try {
      await profiliGarantile();
    } catch (_) {
      // Veritabanı henüz açılmamış olabilir. Hesap oluştu; profil belgesi
      // kullanıcı hesap ekranlarına girdiğinde yeniden denenir.
    }
  }

  static Future<void> girisYap({required String eposta, required String sifre}) async {
    _hazirOlmali();
    await _auth.signInWithEmailAndPassword(email: eposta.trim(), password: sifre);
  }

  static Future<void> sifreSifirla(String eposta) async {
    _hazirOlmali();
    await _auth.sendPasswordResetEmail(email: eposta.trim());
  }

  static Future<void> cikisYap() async {
    _hazirOlmali();
    _bekleyenAd = null;
    await _auth.signOut();
  }

  // ---------------------------------------------------------------- Kendi profilim

  /// `users/{uid}` belgesi yoksa öğrenci rolüyle oluşturur. Var olan belgeye
  /// dokunmaz. Aynı anda birden çok çağrı tek işleme bağlanır.
  static Future<void> profiliGarantile() {
    final id = _gerekliUid();
    final suren = _garantiIsi;
    if (suren != null && _garantiUid == id) return suren;
    _garantiUid = id;
    final Future<void> yeni = _profilOlustur(id).whenComplete(() => _garantiIsi = null);
    _garantiIsi = yeni;
    return yeni;
  }

  static Future<void> _profilOlustur(String id) {
    final belge = _users.doc(id);
    final ad = _bekleyenAd ?? _auth.currentUser?.displayName?.trim() ?? '';
    // Transaction çevrimdışıyken çalışmaz; böylece önbellekteki "belge yok"
    // bilgisine güvenip var olan bir profilin üzerine yazılmaz.
    return FirebaseFirestore.instance.runTransaction<void>((islem) async {
      final mevcut = await islem.get(belge);
      if (mevcut.exists) return;
      islem.set(belge, <String, Object?>{
        'ad': ad,
        'rol': rolOgrenci,
        'seviye': seviyeler.first,
        'hedef': '',
        'tanitim': '',
        'uzmanliklar': <String>[],
        'diller': '',
        'musaitGunler': <String>[],
        'olusturma': FieldValue.serverTimestamp(),
      });
    }).timeout(_yazmaSuresi);
  }

  /// Girişli kullanıcının profili; belge henüz yoksa null yayınlar.
  static Stream<Kullanici?> profilimiIzle() {
    final id = _gerekliUid();
    return _users.doc(id).snapshots().map(_belgeyiCevir);
  }

  static Future<void> ogrenciProfiliniGuncelle({
    required String ad,
    required String seviye,
    required String hedef,
  }) {
    return _guncelle(<String, Object?>{
      'ad': ad.trim(),
      'seviye': seviyeler.contains(seviye) ? seviye : seviyeler.first,
      'hedef': hedef.trim(),
    });
  }

  static Future<void> egitmenProfiliniGuncelle({
    required String ad,
    required String tanitim,
    required List<String> uzmanliklar,
    required String diller,
    required List<String> musaitGunler,
  }) {
    return _guncelle(<String, Object?>{
      'ad': ad.trim(),
      'tanitim': tanitim.trim(),
      'uzmanliklar': uzmanliklar,
      'diller': diller.trim(),
      'musaitGunler': [
        for (final gun in haftaGunleri)
          if (musaitGunler.contains(gun)) gun,
      ],
    });
  }

  static Future<void> egitmenSec(String egitmenId) {
    return _guncelle(<String, Object?>{'egitmenId': egitmenId});
  }

  static Future<void> egitmeniBirak() {
    return _guncelle(<String, Object?>{'egitmenId': FieldValue.delete()});
  }

  /// Kendi belgesini günceller. `rol` (ve `olusturma`) hiçbir koşulda gönderilmez;
  /// rol yalnızca Firebase konsolundan değişir.
  static Future<void> _guncelle(Map<String, Object?> veri) {
    final id = _gerekliUid();
    final temiz = Map<String, Object?>.of(veri)
      ..remove('rol')
      ..remove('olusturma');
    return _users.doc(id).update(temiz).timeout(_yazmaSuresi);
  }

  // ---------------------------------------------------------------- Diğer kullanıcılar

  /// Tüm eğitmenler, ada göre sıralı. Sorgu kurallarla eşleşir: `rol == egitmen`.
  static Stream<List<Kullanici>> egitmenleriIzle() {
    _gerekliUid();
    return _users.where('rol', isEqualTo: rolEgitmen).snapshots().map(_listeyiCevir);
  }

  /// Giriş yapan eğitmeni seçmiş öğrenciler. Sorgu kurallarla eşleşir:
  /// `egitmenId == kendi uid'si`.
  static Stream<List<Kullanici>> ogrencilerimiIzle() {
    final id = _gerekliUid();
    return _users.where('egitmenId', isEqualTo: id).snapshots().map(_listeyiCevir);
  }

  /// Tek bir kullanıcı (ör. seçili eğitmen); belge yoksa null yayınlar.
  static Stream<Kullanici?> kullaniciyiIzle(String kullaniciId) {
    _gerekliUid();
    return _users.doc(kullaniciId).snapshots().map(_belgeyiCevir);
  }

  static Kullanici? _belgeyiCevir(DocumentSnapshot<Map<String, dynamic>> belge) {
    final veri = belge.data();
    return veri == null ? null : Kullanici.belgeden(belge.id, veri);
  }

  static List<Kullanici> _listeyiCevir(QuerySnapshot<Map<String, dynamic>> sonuc) {
    final liste = [
      for (final belge in sonuc.docs) Kullanici.belgeden(belge.id, belge.data()),
    ];
    liste.sort((a, b) => a.ad.toLowerCase().compareTo(b.ad.toLowerCase()));
    return liste;
  }

  // ---------------------------------------------------------------- Hata mesajları

  /// Firebase hata kodlarını kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String hataMesaji(Object hata) {
    if (hata is HesapHatasi) return hata.mesaj;
    if (hata is TimeoutException) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.';
    }
    if (hata is FirebaseException) {
      switch (hata.code) {
        case 'invalid-email':
          return 'E-posta adresi geçerli değil.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'E-posta veya şifre hatalı.';
        case 'email-already-in-use':
          return 'Bu e-posta ile zaten bir hesap var. Giriş yapmayı dene.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter kullan.';
        case 'operation-not-allowed':
          return 'E-posta ile giriş henüz açılmamış. Uygulama sahibine haber ver.';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';
        case 'network-request-failed':
        case 'unavailable':
        case 'deadline-exceeded':
          return 'İnternet bağlantısı yok gibi görünüyor. Bağlantını kontrol edip tekrar dene.';
        case 'requires-recent-login':
          return 'Bu işlem için yeniden giriş yapman gerekiyor.';
        case 'permission-denied':
          return 'Bu işlem için iznin yok.';
        case 'not-found':
          return 'Kayıt bulunamadı. Veritabanı henüz hazır olmayabilir.';
      }
    }
    return 'Bir şeyler ters gitti. Lütfen tekrar dene.';
  }
}
