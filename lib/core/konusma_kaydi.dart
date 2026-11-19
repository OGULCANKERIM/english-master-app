import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Cihazda saklanan bir konuşma: ekranda görünen balonlar ve Claude'a gönderilen geçmiş.
class KayitliSohbet {
  const KayitliSohbet({
    required this.sistem,
    required this.mesajlar,
    required this.gecmis,
    this.konu = '',
    this.mod = '',
    this.seviye = '',
  });

  /// Sohbetin konusu, karakteri (`aiMode` anahtarı) ve seviyesi. Eski sohbet açıldığında
  /// ekran aynı ayarlara döner. Eski kayıtlarda boş olabilir.
  final String konu;
  final String mod;
  final String seviye;

  /// Sohbetin başladığı andaki sistem metni (karakter, seviye ve konu).
  final String sistem;

  /// Ekrandaki balonlar: {"gonderen", "metin", ...}.
  final List<Map<String, String>> mesajlar;

  /// Claude geçmişi: {"role": "user" | "assistant", "content": "..."}.
  /// Her zaman "user" ile başlar, roller sırayla gider ve "assistant" ile biter.
  final List<Map<String, dynamic>> gecmis;

  Map<String, dynamic> toJson() => {
        'konu': konu,
        'mod': mod,
        'seviye': seviye,
        'sistem': sistem,
        'mesajlar': mesajlar,
        'gecmis': gecmis,
      };

  /// Bozuk ya da eksik kayıt için null döner.
  static KayitliSohbet? fromJson(dynamic veri) {
    if (veri is! Map || veri['mesajlar'] is! List || veri['gecmis'] is! List) return null;
    try {
      final gecmis = (veri['gecmis'] as List)
          .whereType<Map>()
          .where((m) => (m['role'] == 'user' || m['role'] == 'assistant') && m['content'] is String)
          .map((m) => <String, dynamic>{'role': m['role'], 'content': m['content']})
          .toList();
      // Hiçbir giriş atılmamış olmalı; atıldıysa rol sırası bozulmuş olabilir.
      if (gecmis.length != (veri['gecmis'] as List).length) return null;
      final hazir = kaydaHazirla(
        konu: (veri['konu'] ?? '').toString(),
        mod: (veri['mod'] ?? '').toString(),
        seviye: (veri['seviye'] ?? '').toString(),
        sistem: (veri['sistem'] ?? '').toString(),
        gecmis: gecmis,
      );
      if (hazir == null) return null;

      // Balonlar geçmişle birebir örtüşüyorsa saklanan hâli kullanılır (çeviriler korunur).
      final mesajlar = (veri['mesajlar'] as List)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())))
          .toList();
      if (mesajlar.length != hazir.mesajlar.length) return hazir;
      for (var i = 0; i < mesajlar.length; i++) {
        if (mesajlar[i]['metin'] != hazir.mesajlar[i]['metin']) return hazir;
      }
      return KayitliSohbet(
        konu: hazir.konu,
        mod: hazir.mod,
        seviye: hazir.seviye,
        sistem: hazir.sistem,
        mesajlar: mesajlar,
        gecmis: hazir.gecmis,
      );
    } catch (e) {
      debugPrint("Kayıtlı sohbet okunamadı: $e");
      return null;
    }
  }
}

/// Claude geçmişi "user" ile başlamalı ve roller sırayla gitmeli; yoksa API isteği reddeder.
bool gecmisGecerli(List<Map<String, dynamic>> gecmis) {
  if (gecmis.isEmpty || gecmis.first['role'] != 'user') return false;
  for (var i = 1; i < gecmis.length; i++) {
    if (gecmis[i]['role'] == gecmis[i - 1]['role']) return false;
  }
  return true;
}

/// Açık sohbeti saklanacak hâle getirir:
/// - Yanıtı gelmemiş son kullanıcı mesajı atılır (yoksa sohbet yeniden açıldığında art arda
///   iki "user" mesajı oluşur ve Claude isteği reddeder).
/// - Balonlar geçmişten kurulur; hata ve uyarı balonları saklanmaz.
/// Kullanıcı en az bir yanıt almadıysa ya da geçmiş geçersizse null döner (saklanacak şey yok).
KayitliSohbet? kaydaHazirla({
  required String konu,
  required String mod,
  required String seviye,
  required String sistem,
  required List<Map<String, dynamic>> gecmis,
}) {
  final temiz = gecmis.map((m) => <String, dynamic>{'role': m['role'], 'content': (m['content'] ?? '').toString()}).toList();
  if (temiz.isNotEmpty && temiz.last['role'] == 'user') temiz.removeLast();
  // İlk iki giriş açılıştır (gizli "başla" mesajı + karşılama); gerçek bir konuşma en az 4 giriştir.
  if (temiz.length < 4 || !gecmisGecerli(temiz)) return null;
  return KayitliSohbet(
    konu: konu,
    mod: mod,
    seviye: seviye,
    sistem: sistem,
    // İlk "user" girişi ekranda gösterilmeyen başlatma mesajıdır.
    mesajlar: [
      for (final m in temiz.skip(1))
        {'gonderen': m['role'] == 'assistant' ? 'AI' : 'Sen', 'metin': m['content'] as String, 'ceviriGoster': 'false'},
    ],
    gecmis: temiz,
  );
}

/// Cihazdaki kaydı çözer. Kayıt yoksa ya da bozuksa boş liste döner; tek tek bozuk
/// sohbetler atlanır, sağlam olanlar korunur.
List<KayitliSohbet> kayitliSohbetleriCoz(String? ham) {
  if (ham == null || ham.isEmpty) return [];
  try {
    final cozulen = json.decode(ham);
    if (cozulen is! List) return [];
    return cozulen.map(KayitliSohbet.fromJson).whereType<KayitliSohbet>().toList();
  } catch (e) {
    debugPrint("Kayıtlı sohbetler okunamadı: $e");
    return [];
  }
}

/// En yeni [enFazla] sohbeti saklanacak metne çevirir (cihaz hafızası şişmesin).
String kayitliSohbetleriKodla(List<KayitliSohbet> sohbetler, {int enFazla = 30}) {
  final secilen = sohbetler.length > enFazla ? sohbetler.sublist(sohbetler.length - enFazla) : sohbetler;
  return json.encode(secilen.map((s) => s.toJson()).toList());
}
