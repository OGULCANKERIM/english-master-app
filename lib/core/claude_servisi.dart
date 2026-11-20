import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ayarlar.dart';

/// Claude'dan yanıt alınamadığında atılır. [kullaniciMesaji] ekranda gösterilecek metindir.
class ClaudeHatasi implements Exception {
  const ClaudeHatasi(this.kullaniciMesaji, {this.baglantiSorunu = false});

  final String kullaniciMesaji;

  /// Geçici bir sorun mu (internet yok, zaman aşımı, servis meşgul)? Yeniden denemek işe yarayabilir.
  final bool baglantiSorunu;

  @override
  String toString() => 'ClaudeHatasi: $kullaniciMesaji';
}

/// Claude'un bir yanıtı.
class ClaudeYaniti {
  const ClaudeYaniti({required this.metin, required this.icerik});

  /// Yanıttaki metin bloklarının birleşimi.
  final String metin;

  /// Ham içerik blokları; sohbet geçmişine `assistant` mesajı olarak eklenir.
  final List<dynamic> icerik;
}

/// Uygulamadaki bütün yapay zekâ çağrılarının geçtiği tek nokta.
class ClaudeServisi {
  ClaudeServisi({http.Client? istemci, this.anahtar = claudeApiKey, this.model = claudeModel})
      : _istemci = istemci ?? http.Client();

  static final ClaudeServisi varsayilan = ClaudeServisi();

  static const String anahtarYokMesaji =
      "⚠️ Yapay zekâ bu sürümde bağlı değil: uygulama Claude anahtarı olmadan derlenmiş. "
      "GitHub > Settings > Secrets and variables > Actions altına ANTHROPIC_API_KEY ekleyip yeniden derleyin.";

  final http.Client _istemci;
  final String anahtar;
  final String model;

  bool get anahtarVar => anahtar.isNotEmpty;

  // Haiku sunucu tarafı yedek modeli desteklemez.
  bool get _yedekDestekli => claudeYedekDestekli && model != 'claude-haiku-5-5';

  /// Sohbet geçmişini ([mesajlar]) gönderir, Claude'un yanıtını döndürür.
  /// Her başarısızlıkta [ClaudeHatasi] atar.
  Future<ClaudeYaniti> gonder({
    required String sistem,
    required List<Map<String, dynamic>> mesajlar,
    int maxTokens = 4096,
  }) async {
    if (!anahtarVar) throw const ClaudeHatasi(anahtarYokMesaji);

    final http.Response response;
    try {
      response = await _istemci
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': anahtar,
              'anthropic-version': '2026-10-21',
              // Model güvenlik nedeniyle yanıt vermezse istek sunucuda yedek modelle yeniden denenir.
              if (_yedekDestekli) 'anthropic-beta': 'server-side-fallback-2026-07-01',
              // Tarayıcıdan (web sürümü) doğrudan çağrı için gerekli.
              if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': maxTokens,
              'system': sistem,
              // Kısa yanıtlar için düşük efor yeterli ve daha hızlı.
              'output_config': {'effort': 'low'},
              if (_yedekDestekli) 'fallbacks': 'default',
              'messages': mesajlar,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ClaudeHatasi("Error: The answer took too long. Please try again.", baglantiSorunu: true);
    } catch (e) {
      debugPrint("Claude bağlantı hatası: $e");
      throw const ClaudeHatasi("Error: Connection problem. Please check your internet.", baglantiSorunu: true);
    }

    dynamic govde;
    try {
      govde = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      govde = null;
    }

    if (response.statusCode != 200) {
      final String apiMesaji =
          (govde is Map && govde['error'] is Map) ? (govde['error']['message'] ?? '').toString() : '';
      debugPrint("Claude API hatası ${response.statusCode}: $apiMesaji");
      final String aciklama = switch (response.statusCode) {
        401 => "API key is invalid",
        403 => "API key is not allowed to use this model",
        404 => "Model '$model' is not available",
        429 => "Too many requests, try again in a moment",
        529 => "The AI service is busy, try again in a moment",
        _ => apiMesaji.isNotEmpty ? apiMesaji : "Server error (${response.statusCode})",
      };
      // 429, 529 ve 5xx geçicidir; 401/403/404 gibi hatalar yeniden denemekle düzelmez.
      final int kod = response.statusCode;
      throw ClaudeHatasi("Error: $aciklama.", baglantiSorunu: kod == 429 || kod >= 500);
    }

    if (govde is Map && govde['stop_reason'] == 'refusal') {
      throw const ClaudeHatasi("Sorry, I can't answer that. Let's talk about something else.");
    }

    final List<dynamic> icerik =
        (govde is Map && govde['content'] is List) ? govde['content'] as List<dynamic> : const [];
    final String metin = icerik
        .where((b) => b is Map && b['type'] == 'text')
        .map((b) => (b['text'] ?? '').toString())
        .join(' ')
        .trim();
    if (metin.isEmpty) {
      throw const ClaudeHatasi("I'm listening, but I couldn't form a sentence.");
    }
    return ClaudeYaniti(metin: metin, icerik: icerik);
  }

  /// Tek seferlik bir istek gönderir, yanıtın metnini döndürür.
  Future<String> sor({required String sistem, required String istem, int maxTokens = 4096}) async {
    final yanit = await gonder(
      sistem: sistem,
      mesajlar: [
        {'role': 'user', 'content': istem}
      ],
      maxTokens: maxTokens,
    );
    return yanit.metin;
  }

  /// Tek seferlik bir istek gönderir ve yanıttaki ilk JSON nesnesini çözer.
  /// Yanıt ```json bloğu içinde ya da düz metnin arasında gelse de çalışır.
  Future<Map<String, dynamic>> jsonIste({required String sistem, required String istem}) async {
    final metin = await sor(sistem: sistem, istem: istem);
    final bas = metin.indexOf('{');
    final son = metin.lastIndexOf('}');
    if (bas >= 0 && son > bas) {
      try {
        final cozulen = jsonDecode(metin.substring(bas, son + 1));
        if (cozulen is Map) return Map<String, dynamic>.from(cozulen);
      } catch (_) {
        // aşağıda hata olarak bildirilir
      }
    }
    debugPrint("Claude JSON yanıtı çözülemedi: $metin");
    throw const ClaudeHatasi("Error: The AI gave an unexpected answer. Please try again.");
  }
}
