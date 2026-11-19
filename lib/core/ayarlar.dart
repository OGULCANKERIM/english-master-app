// ==========================================
// DERLEME ZAMANI AYARLARI
// ==========================================
// API anahtarları ASLA koda yazılmaz. Derlerken şu şekilde verilir:
//   flutter run --dart-define=ANTHROPIC_API_KEY=xxxx --dart-define=PIXABAY_API_KEY=yyyy
const String claudeApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const String claudeModel = String.fromEnvironment('CLAUDE_MODEL', defaultValue: 'claude-haiku-5-5');
// Haiku sunucu tarafı yedek modeli (fallbacks) desteklemez; diğer modellerde açılır.
const bool claudeYedekDestekli = !bool.fromEnvironment('CLAUDE_YEDEK_KAPALI') && claudeModel != 'claude-haiku-5-5';

// Kelime kartlarındaki resimler için (isteğe bağlı). Boşsa kartlar resimsiz gösterilir.
const String pixabayApiKey = String.fromEnvironment('PIXABAY_API_KEY');

// pubspec.yaml içindeki "version" ile aynı tutulmalı (güncelleme kontrolü bunu kullanır).
const String uygulamaSurumu = "1.1.0";
