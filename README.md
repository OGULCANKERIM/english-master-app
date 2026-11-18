# English Master

Flutter ile yazılmış İngilizce öğrenme uygulaması.

- **Vocabulary List** – seviye / harf / kelime türüne göre filtrelenen kelime kartları, sesli okuma ve quiz
- **Reels Mode** – dikey kaydırmalı kısa video kesitleri
- **Favorite Videos** – beğenilen videolar (cihazda kalıcı saklanır)
- **Speaking Practice** – Gemini destekli sesli İngilizce konuşma pratiği

## Çalıştırma

Gemini API anahtarı koda yazılmaz, derleme sırasında verilir:

```
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=ANAHTARINIZ
```

İsteğe bağlı: `--dart-define=GEMINI_MODEL=gemini-3.8-flash` ile model değiştirilebilir.

## Otomatik derleme (GitHub Actions)

`main` dalına her push'ta APK derlenir ve Firebase App Distribution'a yüklenir.
Gerekli repo secret'ları: `GEMINI_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_TOKEN`.
