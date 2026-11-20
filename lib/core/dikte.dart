/// Sesle yazdırma (dikte) yardımcıları.
///
/// Telefonun konuşma tanıması kısa bir sessizlikte dinlemeyi kendiliğinden bitirir.
/// Kullanıcı düşünürken sözü kesilmesin diye dinleme parça parça yeniden başlatılır;
/// [DikteMetni] bu parçaları tek bir metinde toplar.
library;

/// İki metin parçasını tek boşlukla birleştirir, ilk harfi büyütür.
String dikteBirlestir(String onceki, String yeni) {
  final a = onceki.trim();
  final b = yeni.trim();
  final String tum = a.isEmpty ? b : (b.isEmpty ? a : '$a $b');
  if (tum.isEmpty) return tum;
  return tum[0].toUpperCase() + tum.substring(1);
}

class DikteMetni {
  String _onceki = '';
  String _parca = '';

  /// Şu ana kadar yazılanların tamamı (bitmiş parçalar + süren parça).
  String get metin => dikteBirlestir(_onceki, _parca);

  /// Dinleme başlarken çağrılır; [mevcut] yazı kutusunda zaten duran metindir.
  void basla(String mevcut) {
    _onceki = mevcut.trim();
    _parca = '';
  }

  /// Süren parçanın o ana kadar tanınan hâli (her seferinde parçanın tamamı gelir).
  void parcaGuncelle(String taninan) => _parca = taninan.trim();

  /// Süren parçayı bitirir. Parçada söz varsa true döner (dinlemeye devam edilebilir);
  /// boşsa false döner (kullanıcı susmuş demektir).
  bool parcayiBitir() {
    final bool dolu = _parca.isNotEmpty;
    _onceki = metin;
    _parca = '';
    return dolu;
  }
}

/// Konuşma tanıma hata kodunu kullanıcıya gösterilecek mesaja çevirir.
/// Önemsiz (kendiliğinden geçen) hatalarda null döner.
String? konusmaHatasiMesaji(String kod) {
  switch (kod) {
    case 'error_no_match':
    case 'error_speech_timeout':
      return "Seni duyamadım. Mikrofona biraz daha yakın konuşup tekrar dene.";
    case 'error_permission':
    case 'error_insufficient_permissions':
      return "Mikrofon izni yok. Telefon Ayarları > Uygulamalar > English Master > İzinler bölümünden mikrofona izin ver.";
    case 'error_network':
    case 'error_network_timeout':
    case 'error_server':
    case 'error_server_disconnected':
      return "Konuşma tanıma için internet bağlantısı gerekli. Bağlantını kontrol et.";
    case 'error_audio_error':
    case 'error_audio':
      return "Mikrofon açılamadı. Başka bir uygulama mikrofonu kullanıyor olabilir.";
    case 'error_language_not_supported':
    case 'error_language_unavailable':
      return "Telefonunda İngilizce konuşma tanıma yüklü değil. Google uygulamasının ses ayarlarından İngilizce (US) dilini indir.";
    default:
      // error_client, error_busy vb. dinleme durdurulurken oluşur; kullanıcıya gösterilmez.
      return null;
  }
}

/// Bir dinleme parçasının "sessizlik" yüzünden bittiğini gösteren hata kodları.
bool sessizlikHatasiMi(String kod) => kod == 'error_no_match' || kod == 'error_speech_timeout';

/// Cihazdaki konuşma tanıma dillerinden en uygun İngilizceyi seçer; yoksa null (cihaz varsayılanı).
String? ingilizceYerelSec(Iterable<String> yerelKimlikler) {
  String duz(String k) => k.replaceAll('-', '_').toLowerCase();
  final liste = yerelKimlikler.toList();
  for (final tercih in const ['en_us', 'en_gb']) {
    for (final k in liste) {
      if (duz(k) == tercih) return k;
    }
  }
  for (final k in liste) {
    if (duz(k).startsWith('en')) return k;
  }
  return null;
}

/// Mikrofon ses düzeyini (Android'de yaklaşık -2..10 dB) 0..1 aralığına çeker.
double sesDuzeyiOrani(double duzey) => ((duzey + 2) / 12).clamp(0.0, 1.0).toDouble();
