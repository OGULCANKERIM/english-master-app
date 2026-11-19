import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Cihazda saklanan bir konuşma: ekranda görünen balonlar ve Claude'a gönderilen geçmiş.
class KayitliSohbet {
  const KayitliSohbet({required this.sistem, required this.mesajlar, required this.gecmis});

  /// Sohbetin başladığı andaki sistem metni (karakter, seviye ve konu). Eski sohbet
  /// açıldığında aynı karakterle devam edebilmek için saklanır.
  final String sistem;

  /// Ekrandaki balonlar: {"gonderen", "metin", ...}.
  final List<Map<String, String>> mesajlar;

  /// Claude geçmişi: {"role": "user" | "assistant", "content": "..."}.
  final List<Map<String, dynamic>> gecmis;

  Map<String, dynamic> toJson() => {'sistem': sistem, 'mesajlar': mesajlar, 'gecmis': gecmis};

  /// Bozuk ya da eksik kayıt için null döner.
  static KayitliSohbet? fromJson(dynamic veri) {
    if (veri is! Map || veri['mesajlar'] is! List || veri['gecmis'] is! List) return null;
    try {
      final mesajlar = (veri['mesajlar'] as List)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())))
          .where((m) => (m['metin'] ?? '').isNotEmpty)
          .toList();
      final gecmis = (veri['gecmis'] as List)
          .whereType<Map>()
          .where((m) => (m['role'] == 'user' || m['role'] == 'assistant') && m['content'] is String)
          .map((m) => <String, dynamic>{'role': m['role'], 'content': m['content']})
          .toList();
      if (mesajlar.isEmpty || !gecmisGecerli(gecmis)) return null;
      return KayitliSohbet(sistem: (veri['sistem'] ?? '').toString(), mesajlar: mesajlar, gecmis: gecmis);
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
