# English Master

Flutter ile yazılmış İngilizce öğrenme uygulaması.

- **Vocabulary List** – seviye / harf / kelime türüne göre filtrelenen kelime kartları, sesli okuma ve quiz
- **Reels Mode** – dikey kaydırmalı kısa video kesitleri
- **Favorite Videos** – beğenilen videolar (cihazda kalıcı saklanır)
- **Speaking Practice** – Claude destekli sesli İngilizce konuşma pratiği
- **My Tutor / My Profile** – e-posta ve şifreyle hesap, öğrenci ve eğitmen profilleri, eğitmen seçme

## Hesaplar ve eğitmenler

Kelime listesi, quiz, reels, favoriler ve konuşma pratiği girişsiz kullanılır. "My Tutor" ve
"My Profile" kartları giriş ister (Firebase Authentication + Firestore, yalnızca Android).

- **Öğrenci:** ad, seviye (A1–C1) ve öğrenme hedefi girer; listeden bir eğitmen seçer, istediği
  zaman değiştirir veya bırakır.
- **Eğitmen:** tanıtım yazısı, uzmanlık alanları, konuştuğu diller ve müsait günlerini girer;
  panelinde kendisini seçen öğrencileri görür.
- **Mesajlaşma:** öğrenci seçtiği eğitmenle, eğitmen de her öğrencisiyle birebir yazışır (yalnızca
  metin). Okunmamış mesaj ana menüde "My Tutor" kartında kırmızı noktayla görünür. Uygulama
  kapalıyken telefona bildirim gelmez. Öğrenci eğitmeni bırakırsa sohbet kapanır.
- Herkes öğrenci olarak kayıt olur. Kimin eğitmen olacağına uygulama sahibi karar verir (4. adım).

Kod `lib/hesap/` altındadır; güvenlik kuralları `firestore.rules` dosyasındadır.

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

Claude (Anthropic) API anahtarı koda yazılmaz, derleme sırasında verilir:

```
flutter pub get
flutter run --dart-define=ANTHROPIC_API_KEY=ANAHTARINIZ
```

İsteğe bağlı: `--dart-define=CLAUDE_MODEL=claude-opus-5-5` ile model değiştirilebilir (varsayılan `claude-haiku-5-5`).

## Otomatik derleme (GitHub Actions)

`main` dalına her push'ta APK derlenir ve Firebase App Distribution'a yüklenir.
Gerekli repo secret'ları: `ANTHROPIC_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_TOKEN`.
