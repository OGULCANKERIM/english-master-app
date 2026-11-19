import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hesap/hesap_servisi.dart';

const String varsayilanSeviye = 'A2';
const String _seviyeAnahtari = 'userLevel';

/// Giriş yapılmışsa Firestore profilindeki seviyeyi okur; yapılmamışsa null döner.
Future<String?> _profildenSeviye() async {
  if (HesapServisi.uid == null) return null;
  final profil = await HesapServisi.profilimiIzle().first.timeout(const Duration(seconds: 5));
  return profil?.seviye;
}

/// Öğrencinin seviyesi: önce profil (giriş yapılmışsa), sonra cihazdaki kayıt, o da yoksa A2.
Future<String> mevcutSeviye({Future<String?> Function()? profilSeviyesi}) async {
  try {
    final profil = await (profilSeviyesi ?? _profildenSeviye)();
    if (profil != null && seviyeler.contains(profil)) return profil;
  } catch (e) {
    debugPrint("Profil seviyesi okunamadı: $e");
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    final yerel = prefs.getString(_seviyeAnahtari);
    if (yerel != null && seviyeler.contains(yerel)) return yerel;
  } catch (e) {
    debugPrint("Yerel seviye okunamadı: $e");
  }
  return varsayilanSeviye;
}

/// Seviyeyi cihaza yazar (profil kaydedilince çağrılır; girişsiz kullanımda da geçerli olur).
Future<void> yerelSeviyeyiKaydet(String seviye) async {
  if (!seviyeler.contains(seviye)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seviyeAnahtari, seviye);
  } catch (e) {
    debugPrint("Seviye kaydedilemedi: $e");
  }
}
