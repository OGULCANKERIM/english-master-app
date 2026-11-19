# English Master

Flutter ile yazılmış İngilizce öğrenme uygulaması.

- **Vocabulary List** – seviye / harf / kelime türüne göre filtrelenen kelime kartları, sesli okuma ve quiz
- **Reels Mode** – dikey kaydırmalı kısa video kesitleri
- **Favorite Videos** – beğenilen videolar (cihazda kalıcı saklanır)
- **Speaking Practice** – Claude destekli sesli İngilizce konuşma pratiği

## Çalıştırma

Claude (Anthropic) API anahtarı koda yazılmaz, derleme sırasında verilir:

```
flutter pub get
flutter run --dart-define=ANTHROPIC_API_KEY=ANAHTARINIZ
```

İsteğe bağlı: `--dart-define=CLAUDE_MODEL=claude-haiku-5-5` ile model değiştirilebilir (varsayılan `claude-opus-5-5`).

## Otomatik derleme (GitHub Actions)

`main` dalına her push'ta APK derlenir ve Firebase App Distribution'a yüklenir.
Gerekli repo secret'ları: `ANTHROPIC_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_TOKEN`.
