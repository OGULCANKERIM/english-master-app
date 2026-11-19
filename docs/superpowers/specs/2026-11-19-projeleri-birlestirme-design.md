# yeni_english ile english-master-app'i birleştirme — tasarım

Tarih: 2026-11-19

## Amaç ve neden

Elde aynı uygulamanın iki kolu var:

- **english-master-app** (`B:\english master\english-master-app`): GitHub'daki güncel kol
  (`OGULCANKERIM/english-master-app`, `main`). Claude ile konuşma pratiği, isteğe bağlı giriş,
  öğrenci/eğitmen profilleri, eğitmen seçme ve mesajlaşma, CI ile APK dağıtımı. Kodun çoğu tek
  bir `lib/main.dart` dosyasında (~67 KB), hesap kodu `lib/hesap/` altında.
- **yeni_english** (`B:\yeni_english`): 21 Şubat 2026'da (`5f67710`) ayrılmış eski kol. Üstünde
  **commit edilmemiş** büyük bir çalışma var: kod `lib/screens/`, `lib/services/`, `lib/core/`
  altında ekranlara bölünmüş; Reading Lounge, Word Match, 5 tema, AI koç "Nova", resimli kelime
  kartları, gelişmiş reels, kayıtlı konuşma sohbetleri, profil fotoğrafı/isim/şifre/ses ayarları.

Kullanıcı tek bir uygulama istiyor: **iki tarafın bütün özellikleri bir arada**. Çakışan yerlerde
kararı bana bıraktı. Seçilen yol (A): english-master-app temel alınır, yeni_english'in dosya
düzeni ve özellikleri onun üzerine taşınır.

## Hedefler

1. english-master-app reposunda, `lib/screens/` + `lib/core/` + `lib/services/` + `lib/hesap/`
   düzeninde tek bir uygulama.
2. İki taraftaki her kullanıcı özelliği çalışır durumda (aşağıdaki modül tablosu).
3. Bütün yapay zekâ çağrıları tek bir Claude servisinden geçer; hiçbir anahtar kodda yok.
4. Mevcut CI (push'ta APK derleme + Firebase App Distribution) bozulmadan çalışmaya devam eder.
5. `flutter analyze` hatasız, APK derlenir.

## Hedef dışı

- Deepgram ile ses tanıma (ayrı ücretli anahtar ister; `speech_to_text` kalır). Sonra eklenebilir.
- Gerçek push bildirimi, gerçek hesap silme (yeni_english'te ikisi de çalışmayan taslak).
- iOS/web/masaüstüne özel iş. Hedef platform Android (mevcut durumla aynı).
- Yeni özellik eklemek. Bu iş birleştirmedir.

## Başarısızlık sayılacak durumlar (anti-hedefler)

- Herhangi bir API anahtarının koda, `.env`'e veya uygulama paketine girmesi.
- english-master-app'te bugün çalışan bir şeyin (giriş, eğitmen seçme, mesajlaşma, okunmamış
  mesaj noktası, favorilerin kalıcılığı, güncelleme kontrolü) bozulması.
- Uygulamanın girişsiz açılamaz hale gelmesi (bugün kelime, reels, konuşma girişsiz kullanılıyor).
- yeni_english'teki commit edilmemiş çalışmanın kaybolması.

## Kısıtlar

- Firebase projesi iki tarafta da aynı: `english-master-devops`, paket adı
  `com.example.yeni_english`. Firestore şeması ve `firestore.rules` english-master-app'teki gibi
  kalır.
- Claude çağrısı bugünkü gibi yapılır: `ANTHROPIC_API_KEY` ve `CLAUDE_MODEL` (varsayılan
  `claude-haiku-5-5`) `--dart-define` ile verilir; mevcut başlıklar (`anthropic-version`, yedek
  model `anthropic-beta`, web için doğrudan erişim başlığı) korunur.
- Paket sürümleri english-master-app'teki `^` kısıtlarıyla kalır; yeni_english'teki sabitlenmiş
  sürümler (`video_player: 2.8.1` vb.) alınmaz.
- Proje dili: tanımlayıcılar ve yorumlar Türkçe (mevcut stil), arayüz metinleri İngilizce.

## Yaklaşımlar

| | Yol | Artısı | Eksisi |
|---|---|---|---|
| **A (seçildi)** | english-master-app temel; önce `main.dart` ekranlara bölünür, sonra yeni_english modülleri taşınır | Git geçmişi, CI, Claude ve hesap sistemi korunur; sonuç düzenli | En çok iş |
| C | Dosya düzenine dokunmadan yeni modülleri english-master-app'e eklemek | Hızlı | `main.dart` daha da büyür, sonraki her iş zorlaşır |
| B | yeni_english'i temel alıp english-master-app'in son 10 commit'ini taşımak | yeni_english düzeni hazır | Hesap/mesajlaşma ve CI baştan taşınır, geçmiş kopar |

Kullanıcı A'yı seçti.

## Tasarım

### 0. Güvenlik önlemleri (önce)

- `B:\yeni_english` olduğu gibi `B:\yeni_english_yedek_2026-11-19` klasörüne kopyalanır
  (`build/`, `.dart_tool/` hariç). Orijinal klasöre dokunulmaz.
- yeni_english'teki dosyalar okunurken hiçbir anahtar yeni koda geçmez. Bilinen anahtarlar:
  birkaç Gemini anahtarı (`speaking_modulu.dart`, `reading_modulu.dart`, `ai_coach_system.dart`),
  Pixabay anahtarı (`kelime_modulu.dart`), Deepgram ayarı, `.env` dosyası. `.env` artık asset
  olarak paketlenmez, `flutter_dotenv` kaldırılır.
- İş `birlestirme` adlı yeni bir dalda yapılır; `main`'e kullanıcı onayıyla birleştirilir.

### 1. Dosya düzeni

```
lib/
  main.dart                 başlatma (Firebase, favoriler, tema), MaterialApp, temalar
  core/
    ayarlar.dart            dart-define sabitleri (Claude anahtarı/model, Pixabay anahtarı, sürüm)
    claude_servisi.dart     tek Claude çağrı noktası (bugünkü main.dart çağrısından çıkarılır)
    globals.dart            favoriler + kalıcılık, ortak yardımcılar (_jsonListeCoz, _alan)
    temalar.dart            yeni_english'in 5 teması + appThemeNotifier
  services/
    ai_coach_system.dart    Nova koçu, Claude servisine çevrilmiş
  screens/
    acilis_ekrani.dart      açılış animasyonu; girişe zorlamaz, ana menüye geçer
    ana_menu.dart           yeni_english tasarımı + My Tutor / My Profile kartları
    kelime_modulu.dart      kelime listesi + Test
    reels_modulu.dart       reels + favoriler
    speaking_modulu.dart    konuşma pratiği
    reading_modulu.dart     Reading Lounge
    eslestirme_modulu.dart  Word Match
  hesap/                    english-master-app'teki gibi kalır (giriş, profil, eğitmen, sohbet)
```

### 2. Modüller: hangisi nereden

| Modül | Kaynak | Not |
|---|---|---|
| Açılış ekranı | yeni_english | Girişe zorlama kaldırılır |
| Ana menü | yeni_english tasarımı | english-master-app'in My Tutor (okunmamış noktası dahil) ve My Profile kartları ile güncelleme kontrolü eklenir |
| Temalar | yeni_english | 5 tema, seçim `SharedPreferences`'ta; `hesap/` ekranları tema renklerini kullanacak şekilde uyarlanır |
| Kelime listesi + Test | yeni_english | Pixabay resmi `PIXABAY_API_KEY` ile; anahtar yoksa resimsiz kart, hata yok |
| Reels + Favoriler | yeni_english | Favorilerin cihazda kalıcılığı english-master-app'teki gibi korunur |
| Konuşma pratiği | yeni_english ekranı (benim kararım) | Bütün özellikleri kalır: 5 AI karakteri, konu/kategori vitrini, mesaj çevirisi, ipuçları, sohbet içinde seviye değiştirme, sohbet geçmişi çekmecesi, kayıtlı sohbetler, ses seçimi. Gemini çağrıları Claude servisine çevrilir, Deepgram yerine `speech_to_text` kullanılır. english-master-app'teki küçük ekran kaldırılır |
| Reading Lounge | yeni_english | Metin üretme ve telaffuz değerlendirmesi Claude'a çevrilir |
| Word Match | yeni_english | Yapay zekâ kullanıyorsa Claude'a çevrilir |
| AI koç Nova | yeni_english | Claude'a çevrilir; seviye bilgisi giriş yapılmışsa profil seviyesinden, yoksa yereldeki değerden |
| Giriş / kayıt | english-master-app (`hesap/giris_ekrani.dart`) | yeni_english'in `login_ekrani.dart` dosyası alınmaz |
| Profil | english-master-app (`hesap/profil_ekrani.dart`) | Eklenir: tema seçimi, isim değiştirme, şifre değiştirme, AI ses ayarları (perde/hız). Fotoğraf yok (bkz. 3) |
| Eğitmen seçme, mesajlaşma | english-master-app | Değişmez |

yeni_english'teki çalışmayan taslaklar alınmaz: bildirim açma/kapama düğmesi ve "hesabı sil".

### 3. Profil fotoğrafı

**Kullanıcı kararı: bu işte yapılmaz.** Storage'ın açık olup olmadığı bilinmiyor ve proje
bucket'ı (`english-master-devops.firebasestorage.app`) ücretli Blaze planı isteyen türden.
Profilde baş harf avatarı gösterilir. `firebase_storage`, `image_picker` ve resim okuma izinleri
eklenmez. Sonradan Storage açılırsa ayrı bir iş olarak eklenebilir.

### 3b. Öğrenci seviyesi (benim kararım)

`core/` altında tek bir seviye yardımcısı olur. Giriş yapılmışsa Firestore profilindeki `seviye`
(A1–C1) okunur. Yapılmamışsa yereldeki `userLevel` değeri okunur, varsayılan A2'dir. Profilde
seviye kaydedilince `userLevel` de güncellenir. Nova, Reading ve Konuşma bu yardımcıyı kullanır.
Modül içinde seviye değiştirmek yalnızca o oturum için geçerlidir, profile geri yazılmaz. Kelime
modülündeki A1–C2 filtresi bir kelime listesi filtresidir, öğrenci seviyesinden ayrıdır ve aynen
kalır. `hesap/` kodunda yapılacak tek değişiklik, profil kaydedilirken `userLevel`'in de
yazılmasıdır.

### 3c. Android ve sürüm (benim kararım)

- yeni_english'in `AndroidManifest.xml` dosyasından yalnızca özelliklerin ihtiyaç duyduğu
  parçalar alınır: `RecognitionService` sorgusu (Android 11 ve sonrasında `speech_to_text` için),
  `ACCESS_NETWORK_STATE`.
  - `settings.gradle.kts`, gradle wrapper ve `google-services.json` english-master-app'teki
    gibi kalır.
  - Uygulama simgesi de english-master-app'teki gibi kalır.
- Sürüm `1.1.0+2`'ye çıkarılır (`pubspec.yaml` ve `uygulamaSurumu`). Kullanıcı test edip
  `main`'e aldıktan sonra Remote Config'teki sürüm değerini günceller; böylece test edenlere
  güncelleme bildirimi gider.
- yeni_english'in kayıtlı sohbetleri için veri taşıma yapılmaz. O sürüm hiç dağıtılmadı.

### 4. Claude servisi

`core/claude_servisi.dart` tek bir fonksiyon sunar: sistem metni + mesaj listesi alır, yanıt
metnini döner; anahtar yoksa veya hata olursa anlaşılır bir hata verir (bugünkü "API anahtarı
tanımlı değil" davranışı korunur). Konuşma pratiği, Reading, Word Match ve Nova bunu kullanır.
Gemini çağrılarındaki istemler (prompt) aynen korunur, sadece çağrı biçimi değişir. Telaffuz
puanı gibi yapılandırılmış yanıt bekleyen yerlerde JSON istenir ve güvenli ayrıştırılır.

### 5. Paketler

Eklenen paket yok.
Alınmaz: `google_generative_ai`, `flutter_dotenv`, `web_socket_channel`, `record`.
Kalan bütün paketler english-master-app'teki sürüm kısıtlarıyla kalır.

### 6. CI ve belgeler

- `flutter_build.yml` derleme satırına `--dart-define=PIXABAY_API_KEY=${{ secrets.PIXABAY_API_KEY }}`
  eklenir. Kullanıcı GitHub'da `PIXABAY_API_KEY` secret'ını ekler (yoksa resimsiz çalışır).
- `README.md` yeni modüller ve `PIXABAY_API_KEY` ile güncellenir.

### 7. Doğrulama

- `flutter analyze` hatasız.
- `flutter build apk --release` başarılı.
- Elle gezinti: girişsiz açılış → her modül açılıyor; Claude anahtarıyla konuşma, Reading, Nova
  yanıt veriyor; tema değişimi her ekranda görünüyor; giriş → profil, eğitmen seçme, mesajlaşma,
  okunmamış noktası çalışıyor; favoriler uygulama kapanıp açılınca duruyor.
- Kodda anahtar araması (`AIza`, `ghp_`, Pixabay anahtarı) boş döner.

## Kullanıcının yapması gerekenler (kod dışı)

- GitHub token'ını iptal edip yenilemek (yeni_english'in git ayarında düz metin duruyor).
- yeni_english'teki Gemini ve Pixabay anahtarlarını iptal etmek; git geçmişinde de eski Gemini
  anahtarı izleri var.
- Pixabay için yeni anahtar alıp GitHub secret olarak eklemek.

## Uygulayıcıya bırakılanlar

- Ekranları bölerken sınıfların hangi dosyaya düştüğünün ayrıntısı, ortak yardımcıların yeri.
- `hesap/` ekranlarının temalara uyarlanma derecesi (en azından açık temalarda okunur olmalı).
- İş sırası ve commit bölümleri (plan aşamasında).
