# Aşama 1: Hesaplar ve Profiller — Tasarım

Tarih: 2026-11-19. Kullanıcı tasarımı sohbette onayladı ("devam").

## Amaç

English Master'a eğitmen–öğrenci sistemi ekleniyor. Bu, beş aşamalı işin ilki:

1. **Hesaplar ve profiller (bu belge)**
2. Mesajlaşma (öğrenci ↔ seçtiği eğitmen, bildirim)
3. Haftalık ödevler ve görevler (eğitmen verir, öğrenci tamamlar)
4. Sesli görüşme (Agora / ZEGOCLOUD / LiveKit arasından seçilecek)
5. Ekstralar (rezervasyon, yorum, yapay zekâ ders özeti, ödeme)

Eğitmenleri uygulama sahibi seçer; pazar yeri değil. Başvuru, onay akışı ve ödeme yok.

## Yaklaşımlar

- **Firebase Auth + Firestore (seçildi):** Firebase projede zaten kurulu (`firebase_core`,
  `android/app/google-services.json`, proje `english-master-devops`). En az kurulum.
- Supabase / kendi sunucu: sıfırdan kurulum, bu ölçekte kazancı yok.

## Kapsam

**Giriş**
- E-posta + şifre ile kayıt, giriş, şifre sıfırlama, çıkış.
- Google ile giriş **şimdilik yok** (benim kararım): release APK her CI çalışmasında farklı bir
  debug anahtarıyla imzalanıyor (`android/app/build.gradle.kts`, `signingConfigs.debug`), bu
  yüzden SHA-1 sabit değil ve Google girişi çalışmaz. Sabit bir imza anahtarı eklenince yapılır.
- Kelime listesi, quiz, reels, favoriler girişsiz açık kalır. Eğitmen/profil alanı giriş ister.

**Öğrenci profili:** ad, seviye (A1–C1), öğrenme hedefi, seçtiği eğitmen.

**Eğitmen profili:** ad, tanıtım yazısı, uzmanlık alanları, konuştuğu diller, müsait günler.

**Fotoğraf yükleme şimdilik yok** (benim kararım): Firebase Storage ücretli plan istiyor.
Avatar olarak adın baş harfi gösterilir.

**Eğitmen listesi ve seçme:** öğrenci listeyi görür, profile bakar, "Bu eğitmeni seç" der.
Aynı anda tek eğitmen; istediği zaman değiştirir veya bırakır.

**Eğitmen ekleme:** kişi normal kayıt olur; uygulama sahibi Firebase konsolunda
`users/{uid}.rol` alanını `egitmen` yapar. Uygulama içinden rol değiştirilemez.

**Eğitmen paneli:** kendi profilini düzenler, kendisini seçen öğrencileri listeler.

**Ana menü:** iki yeni kart — "My Tutor" (role göre: öğrencide eğitmenim/eğitmen listesi,
eğitmende panel) ve "My Profile".

## Kapsam dışı

Mesajlaşma, ödev, sesli görüşme, ödeme, puan/yorum, fotoğraf yükleme, Google girişi,
uygulama içi yönetici ekranı.

## Veri modeli (Firestore)

`users/{uid}`:

| Alan | Tür | Not |
|---|---|---|
| `ad` | string | |
| `rol` | string | `ogrenci` (varsayılan) veya `egitmen`; yalnızca konsoldan değişir |
| `seviye` | string | A1..C1 (öğrenci) |
| `hedef` | string | (öğrenci) |
| `egitmenId` | string? | seçilen eğitmenin uid'si |
| `tanitim` | string | (eğitmen) |
| `uzmanliklar` | string[] | (eğitmen) |
| `diller` | string | (eğitmen) serbest metin |
| `musaitGunler` | string[] | (eğitmen) |
| `olusturma` | timestamp | |

E-posta belgede tutulmaz (eğitmen profilleri tüm girişli kullanıcılara açık).

## Güvenlik kuralları (`firestore.rules`)

- Okuma: giriş yapmış kullanıcı kendi belgesini, `rol == 'egitmen'` olan belgeleri ve
  `egitmenId == kendi uid'si` olan (yani kendi öğrencisi) belgeleri okuyabilir.
- Oluşturma: yalnızca kendi belgesi ve `rol == 'ogrenci'` ile.
- Güncelleme: yalnızca kendi belgesi ve `rol` değişmeden.
- Silme: yok.

Sorgular kurallarla eşleşmeli: eğitmen listesi `where rol == egitmen`, öğrencilerim
`where egitmenId == uid`.

## Kod yapısı

`lib/main.dart` tek dosya ve ~1200 satır; yeni kod oraya eklenmez:

- `lib/hesap/hesap_servisi.dart` — `Kullanici` modeli, Auth + Firestore işlemleri, hata mesajları
- `lib/hesap/giris_ekrani.dart` — giriş / kayıt / şifre sıfırlama
- `lib/hesap/profil_ekrani.dart` — role göre profil düzenleme, çıkış
- `lib/hesap/egitmen_ekranlari.dart` — eğitmen listesi, eğitmen profili, "eğitmenim", eğitmen paneli
- `lib/main.dart` — yalnızca iki menü kartı ve import

Görsel dil mevcut ekranlarla aynı: koyu mor gradyan (`0xFF0f0c29 → 0xFF302b63 → 0xFF24243e`),
yarı saydam beyaz kartlar, Poppins.

## Kısıtlar

- `Firebase.initializeApp()` seçeneksiz çağrılıyor; yalnızca Android'de çalışır. Web'de
  `Firebase.apps` boş kalır; hesap ekranları bu durumda çökmeyip "bu platformda yok" demeli.
- Signup sırasında Firestore yazımı başarısız olabilir (veritabanı henüz açılmamışsa);
  girişli ama profil belgesi olmayan kullanıcı için belge sonradan oluşturulmalı.
- API anahtarı, token, şifre hiçbir yere yazılmaz.

## Uygulama sahibinin yapacakları (Firebase konsolu)

1. Authentication → Sign-in method → Email/Password'ü aç.
2. Firestore Database → veritabanı oluştur (production mode).
3. `firestore.rules` içeriğini Rules sekmesine yapıştır (veya `firebase.cmd deploy --only firestore:rules`).
4. Bir eğitmen eklemek için: o kişinin `users/{uid}` belgesinde `rol` → `egitmen`.

## Doğrulama

- `flutter analyze` temiz.
- `flutter build web` ve Android release derlemesi geçer (yerelde Android için JDK 17 gerekir;
  CI `.github/workflows/flutter_build.yml` Flutter 3.47.7 + Java 17 kullanır).
- Gerçek cihazda giriş/kayıt denemesi kullanıcıya kalır (yerelde bağlı cihaz yetkisiz).
