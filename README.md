# English Master

Flutter ile yazılmış İngilizce öğrenme uygulaması.

- **Word Vault** – seviye / harf / kelime türüne göre filtrelenen, kaydırmalı ve resimli kelime kartları, sesli okuma ve quiz
- **Cinematic Mode** – dikey kaydırmalı kısa video kesitleri
- **Favorite Reels** – beğenilen videolar (cihazda kalıcı saklanır)
- **Voice Studio** – Claude destekli sesli konuşma pratiği: 5 karakter, konu kütüphanesi, mesaj çevirisi, ipuçları ve kayıtlı sohbetler
- **Reading Lounge** – seviyeye göre üretilen metni cümle cümle sesli okuma ve telaffuz puanı
- **Word Match** – İngilizce–Türkçe kelime eşleştirme oyunu
- **Nova** – her ekranda duruma göre kısa tavsiye veren yapay zekâ koçu
- **Temalar ve ayarlar** – 5 tema, sesli okuma perdesi ve hızı (giriş gerektirmez)
- **My Tutor / My Profile** – e-posta ve şifreyle hesap, öğrenci ve eğitmen profilleri, eğitmen seçme

## Hesaplar ve eğitmenler

Kelime kartları, quiz, reels, favoriler, konuşma, okuma, eşleştirme ve ayarlar girişsiz kullanılır. "My Tutor" ve
"My Profile" kartları giriş ister (Firebase Authentication + Firestore, yalnızca Android).

- **Öğrenci:** ad, seviye (A1–C1) ve öğrenme hedefi girer; listeden bir eğitmen seçer, istediği
  zaman değiştirir veya bırakır.
- **Eğitmen:** tanıtım yazısı, uzmanlık alanları, konuştuğu diller ve müsait günlerini girer;
  panelinde kendisini seçen öğrencileri görür.
- **Mesajlaşma:** öğrenci seçtiği eğitmenle, eğitmen de her öğrencisiyle birebir yazışır (yalnızca
  metin). Okunmamış mesaj ana menüde "My Tutor" kartında kırmızı noktayla görünür. Uygulama
  kapalıyken telefona bildirim gelmez. Öğrenci eğitmeni bırakırsa sohbet kapanır.
- Herkes öğrenci olarak kayıt olur. Kimin eğitmen olacağına uygulama sahibi karar verir (4. adım).

Profilde ad, seviye, hedef ve şifre değiştirilebilir. Profildeki seviye konuşma, okuma ve Nova
tarafından kullanılır; giriş yapılmamışsa seviye A2 kabul edilir.

Kod `lib/hesap/` altındadır; güvenlik kuralları `firestore.rules` dosyasındadır.

## Kod düzeni

```
lib/
  main.dart      başlatma ve tema
  core/          Claude servisi, derleme ayarları, temalar, seviye, kalıcılık, güncelleme kontrolü
  services/      Nova koçu
  screens/       açılış, ana menü, ayarlar ve öğrenme modülleri
  hesap/         giriş, profil, eğitmenler, mesajlaşma
test/            birim testleri (`flutter test`)
```

Bütün yapay zekâ çağrıları `lib/core/claude_servisi.dart` üzerinden geçer.

### Firebase konsolunda bir kez yapılacaklar

[Firebase konsolu](https://console.firebase.google.com) → `english-master-devops` projesi:

1. **Girişi aç:** Build → Authentication → Sign-in method → Email/Password → Enable → Save.
2. **Veritabanını oluştur:** Build → Firestore Database → Create database → konum seç →
   "Start in production mode" → Create.
3. **Kuralları yükle:** Firestore Database → Rules sekmesi → kutudaki her şeyi sil,
   `firestore.rules` dosyasının içeriğini yapıştır → Publish.
   (Alternatif: `firebase.cmd deploy --only firestore:rules --project english-master-devops`)
4. **Birini eğitmen yap:** kişi önce uygulamadan kayıt olur ve bir kez "My Profile"ı açar.
   Sonra Firestore Database → Data → `users` → o kişinin belgesi → `rol` alanını `ogrenci`
   yerine `egitmen` yap → Update. Hangi belgenin kime ait olduğu `ad` alanından anlaşılır
   (belge kimliği, Authentication → Users listesindeki "User UID" ile aynıdır).

## Çalıştırma

API anahtarları koda yazılmaz, derleme sırasında verilir:

```
flutter pub get
flutter run --dart-define=ANTHROPIC_API_KEY=ANAHTARINIZ --dart-define=PIXABAY_API_KEY=PIXABAY_ANAHTARINIZ
```

`PIXABAY_API_KEY` isteğe bağlıdır (kelime kartlarındaki resimler için, pixabay.com/api/docs
adresinden ücretsiz alınır). Verilmezse kartlar resimsiz gösterilir. `ANTHROPIC_API_KEY` verilmezse
konuşma, okuma ve Nova "anahtar tanımlı değil" uyarısı gösterir; diğer modüller çalışır.

İsteğe bağlı: `--dart-define=CLAUDE_MODEL=claude-opus-5-5` ile model değiştirilebilir (varsayılan `claude-haiku-5-5`).

## Otomatik derleme (GitHub Actions)

`main` dalına her push'ta önce `flutter analyze` ve `flutter test` çalışır, sonra APK derlenir ve
Firebase App Distribution'a yüklenir.
Gerekli repo secret'ları: `ANTHROPIC_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_TOKEN`.
İsteğe bağlı: `PIXABAY_API_KEY`.

## Yeni sürüm çıkarırken

1. `pubspec.yaml` içindeki `version` ile `lib/core/ayarlar.dart` içindeki `uygulamaSurumu` aynı
   sürüme yükseltilir.
2. APK testerlara ulaştıktan sonra Firebase konsolu → Remote Config → `current_version` değeri yeni
   sürüm numarası yapılır. Eski sürümü kullananlara güncelleme penceresi çıkar; uzak sürüm
   uygulamadakinden yeni değilse pencere çıkmaz.
