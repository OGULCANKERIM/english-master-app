import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _temaAnahtari = 'app_theme_index';

// Seçili temanın sıra numarası (0-4). Değişince bütün uygulama yeniden boyanır.
final ValueNotifier<int> appThemeNotifier = ValueNotifier(0);

class AppThemes {
  static final List<ThemeData> themes = [
    // 0: Modern Light (Clean, Crisp, Minimalist)
    ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF6366F1), // Elegant Indigo
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Ultra light slate
      cardColor: Colors.white,
      shadowColor: Colors.black12,
      textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFF1E293B), displayColor: const Color(0xFF0F172A)),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1), brightness: Brightness.light).copyWith(secondary: const Color(0xFFF43F5E)),
    ),
    // 1: OLED Dark (Pitch Black, Hacker Vibe, High Contrast)
    ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF00E676), // Neon Green
      scaffoldBackgroundColor: const Color(0xFF020202), // Pitch Black
      cardColor: const Color(0xFF101010), // Very dark grey
      shadowColor: Colors.black87,
      textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFFF8FAFC), displayColor: Colors.white),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00E676), brightness: Brightness.dark).copyWith(secondary: const Color(0xFF00B0FF)),
    ),
    // 2: Velvet Violet (Luxurious Deep Purple & Magenta)
    ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFFE91E63), // Pink/Magenta
      scaffoldBackgroundColor: const Color(0xFF150525), // Velvet Deep Violet
      cardColor: const Color(0xFF2A1045), // Slightly lighter violet
      shadowColor: Colors.black87,
      textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFFFCE7F3), displayColor: Colors.white),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63), brightness: Brightness.dark).copyWith(secondary: const Color(0xFFFFB300)),
    ),
    // 3: Forest Green (Earthy, Calm, Natural Light)
    ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2E7D32), // Deep Green
      scaffoldBackgroundColor: const Color(0xFFF1F8E9), // Very light green
      cardColor: Colors.white,
      shadowColor: Colors.black12,
      textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFF1B5E20), displayColor: const Color(0xFF003300)),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.light).copyWith(secondary: const Color(0xFFFF8F00)),
    ),
    // 4: Sunset Crimson (Warm, Energetic Dark)
    ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFFFF3D00), // Fiery Orange/Red
      scaffoldBackgroundColor: const Color(0xFF1E0B0B), // Very dark crimson
      cardColor: const Color(0xFF2B1111), // Slightly lighter crimson
      shadowColor: Colors.black87,
      textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFFFFE0B2), displayColor: Colors.white),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF3D00), brightness: Brightness.dark).copyWith(secondary: const Color(0xFFFFD600)),
    )
  ];
}

/// Temaların ayarlar ekranında görünen adları ([AppThemes.themes] ile aynı sırada).
const List<String> temaAdlari = ['Modern Light', 'OLED Dark', 'Velvet Violet', 'Forest Green', 'Sunset Crimson'];

/// Cihazda kayıtlı temayı yükler; kayıt yoksa ya da geçersizse ilk tema seçilir.
Future<void> temaYukle() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final kayit = prefs.getInt(_temaAnahtari) ?? 0;
    appThemeNotifier.value = (kayit >= 0 && kayit < AppThemes.themes.length) ? kayit : 0;
  } catch (e) {
    debugPrint("Tema yüklenemedi: $e");
    appThemeNotifier.value = 0;
  }
}

/// Temayı değiştirir ve cihaza kaydeder. Geçersiz numara yok sayılır.
Future<void> temaKaydet(int index) async {
  if (index < 0 || index >= AppThemes.themes.length) return;
  appThemeNotifier.value = index;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_temaAnahtari, index);
  } catch (e) {
    debugPrint("Tema kaydedilemedi: $e");
  }
}
