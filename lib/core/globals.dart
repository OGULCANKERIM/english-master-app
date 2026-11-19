import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// GLOBAL HAFIZA (cihazda kalıcı olarak saklanır)
// ==========================================
const String _favoriAnahtari = "favori_sahneler";
List<Map<String, dynamic>> globalFavoriSahneler = [];

/// Konuşma ekranında seçilen TTS sesi (oturum boyunca).
Map<dynamic, dynamic>? globalSeciliSes;

Future<void> favorileriYukle() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final kayit = prefs.getString(_favoriAnahtari);
    if (kayit == null) return;
    final cozulen = json.decode(kayit);
    if (cozulen is! List) return;
    globalFavoriSahneler = cozulen.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    debugPrint("Favoriler yüklenemedi: $e");
  }
}

Future<void> favorileriKaydet() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoriAnahtari, json.encode(globalFavoriSahneler));
  } catch (e) {
    debugPrint("Favoriler kaydedilemedi: $e");
  }
}

/// Sunucudan gelen JSON listesini her zaman UTF-8 olarak çözer (Türkçe karakterler bozulmasın).
List<dynamic> jsonListeCoz(http.Response response) {
  final veri = json.decode(utf8.decode(response.bodyBytes));
  return veri is List ? veri : <dynamic>[];
}

/// Tablodaki bir hücreyi güvenli şekilde metne çevirir (boş/eksik hücre çökme yapmaz).
String alan(dynamic satir, String anahtar) {
  if (satir is! Map) return "";
  return (satir[anahtar] ?? "").toString().trim();
}

// ==========================================
// SES AYARLARI (profil ekranından değiştirilir)
// ==========================================
const String _perdeAnahtari = 'tts_perde';
const String _hizAnahtari = 'tts_hiz';
const double varsayilanTtsPerde = 1.0;
const double varsayilanTtsHiz = 0.5;

/// Kayıtlı ses perdesi (0.5–2.0) ve konuşma hızı (0.1–1.0).
Future<({double perde, double hiz})> ttsAyarlariniOku() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return (
      perde: (prefs.getDouble(_perdeAnahtari) ?? varsayilanTtsPerde).clamp(0.5, 2.0).toDouble(),
      hiz: (prefs.getDouble(_hizAnahtari) ?? varsayilanTtsHiz).clamp(0.1, 1.0).toDouble(),
    );
  } catch (e) {
    debugPrint("Ses ayarları okunamadı: $e");
    return (perde: varsayilanTtsPerde, hiz: varsayilanTtsHiz);
  }
}

Future<void> ttsAyarlariniKaydet({required double perde, required double hiz}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_perdeAnahtari, perde.clamp(0.5, 2.0).toDouble());
  await prefs.setDouble(_hizAnahtari, hiz.clamp(0.1, 1.0).toDouble());
}

// ==========================================
// SAYFA GEÇİŞLERİ
// ==========================================
Route<T> _gecis<T>(Widget sayfa, Offset baslangic) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => sayfa,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: baslangic, end: Offset.zero).chain(CurveTween(curve: Curves.easeInOutQuart));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 500),
  );
}

/// Sağdan kayarak açılan sayfa.
Route<T> kayarakGecis<T>(Widget sayfa) => _gecis<T>(sayfa, const Offset(1.0, 0.0));

/// Alttan kayarak açılan sayfa.
Route<T> alttanKayarakGecis<T>(Widget sayfa) => _gecis<T>(sayfa, const Offset(0.0, 1.0));
