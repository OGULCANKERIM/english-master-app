import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/globals.dart';
import '../core/temalar.dart';

// ==========================================
// AYARLAR (tema ve ses) — giriş gerektirmez
// ==========================================
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  final FlutterTts _flutterTts = FlutterTts();
  double _perde = varsayilanTtsPerde;
  double _hiz = varsayilanTtsHiz;
  bool _yuklendi = false;

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final ayar = await ttsAyarlariniOku();
    if (!mounted) return;
    setState(() {
      _perde = ayar.perde;
      _hiz = ayar.hiz;
      _yuklendi = true;
    });
  }

  Future<void> _sesiKaydetVeDene() async {
    try {
      await ttsAyarlariniKaydet(perde: _perde, hiz: _hiz);
      await _flutterTts.stop();
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(_perde);
      await _flutterTts.setSpeechRate(_hiz);
      await _flutterTts.speak("This is how I will sound.");
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text("Voice settings saved.")));
      }
    } catch (e) {
      debugPrint("Ses ayarı kaydedilemedi: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice settings could not be saved.")));
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color yazi = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.poppins(color: yazi, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: yazi),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          _baslik("Theme", yazi),
          ValueListenableBuilder<int>(
            valueListenable: appThemeNotifier,
            builder: (context, secili, _) => Column(
              children: [
                for (int i = 0; i < AppThemes.themes.length; i++)
                  _temaSatiri(i, secili == i, theme, yazi),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _baslik("AI Voice", yazi),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
            child: !_yuklendi
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Used when words and reading texts are read aloud. Speaking characters keep their own voices.",
                          style: GoogleFonts.poppins(color: yazi.withValues(alpha: 0.6), fontSize: 12)),
                      const SizedBox(height: 12),
                      Text("Voice Pitch", style: GoogleFonts.poppins(color: yazi, fontWeight: FontWeight.w500)),
                      Slider(
                        value: _perde,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: _perde.toStringAsFixed(1),
                        activeColor: theme.primaryColor,
                        onChanged: (deger) => setState(() => _perde = deger),
                      ),
                      Text("Speaking Speed", style: GoogleFonts.poppins(color: yazi, fontWeight: FontWeight.w500)),
                      Slider(
                        value: _hiz,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: _hiz.toStringAsFixed(1),
                        activeColor: theme.primaryColor,
                        onChanged: (deger) => setState(() => _hiz = deger),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sesiKaydetVeDene,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text("Save & Listen", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _baslik(String metin, Color yazi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(metin, style: GoogleFonts.poppins(color: yazi.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _temaSatiri(int index, bool secili, ThemeData theme, Color yazi) {
    final ThemeData tema = AppThemes.themes[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => temaKaydet(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: secili ? theme.primaryColor : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                // Temanın zemin ve vurgu renklerini gösteren küçük önizleme.
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tema.scaffoldBackgroundColor,
                    border: Border.all(color: tema.primaryColor, width: 4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(temaAdlari[index], style: GoogleFonts.poppins(color: yazi, fontSize: 15, fontWeight: FontWeight.w600))),
                if (secili) Icon(Icons.check_circle_rounded, color: theme.primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
