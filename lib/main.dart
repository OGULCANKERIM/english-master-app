import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/globals.dart';
import 'core/temalar.dart';
import 'screens/acilis_ekrani.dart';

// ==========================================
// ANA GİRİŞ NOKTASI
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Başlatılamadı: $e");
  }

  await favorileriYukle();
  await temaYukle();

  runApp(const IngilizceUygulamam());
}

class IngilizceUygulamam extends StatelessWidget {
  const IngilizceUygulamam({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema değişince bütün uygulama yeniden boyanır.
    return ValueListenableBuilder<int>(
      valueListenable: appThemeNotifier,
      builder: (context, themeIndex, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'English Master',
          theme: AppThemes.themes[themeIndex.clamp(0, AppThemes.themes.length - 1)],
          home: const AcilisKapisiEkrani(),
        );
      },
    );
  }
}
