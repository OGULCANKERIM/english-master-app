import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/claude_servisi.dart';
import '../core/seviye.dart';

/// "Nova": bulunulan ekrana göre kısa, motive edici tavsiye veren yapay zekâ koçu.
class AiCoachSystem {
  /// Ekran adına göre Nova'ya verilen durum açıklaması.
  static String _ekranBaglami(String ekran, Map<String, dynamic> veri) {
    switch (ekran) {
      case "AnaMenu":
        return "Uygulamanın ana menüsünde geziyor. Uygulamayı yeni açmış olabilir, ne yapacağına karar verecek.";
      case "KelimeModulu":
        final String tur = (veri["currentType"] ?? "Unknown").toString();
        final int ogrenilen = veri["learnedCount"] is int ? veri["learnedCount"] as int : 0;
        return "Kelime öğrenme bölümünde. Şu an '$tur' (İsim/Fiil/Sıfat vb.) türünde kelimeleri ezberliyor. Bu oturumda $ogrenilen kelime Vault'a gönderilmiş (master edilmiş).";
      case "TestEkrani":
        return "Seçtiği İngilizce seviyesine göre kelime testine giriyor (Quiz).";
      case "SpeakingView":
        return "Konuşma (Speaking) stüdyosunda, AI karakterleriyle konuşma başlattı ya da başlatacak. Cesaretlendirilmeye ihtiyacı var.";
      case "ProfileScreen":
        return "Profil ayarlarını, temasını ve isim değişikliği yapabileceği sayfayı inceliyor.";
      case "Eşleştirme":
        return "Kelime eşleştirme oyununda (Word Match). İngilizce kelimeleri Türkçe anlamlarıyla eşleştirip hafızasını sınıyor.";
      case "ReadingView":
        return "Okuma (Reading) bölümünde. Seviyesine göre üretilen metni cümle cümle sesli okuyup telaffuz puanı alıyor.";
      default:
        return "Uygulamada İngilizce çalışıyor.";
    }
  }

  /// Nova'nın kişiliğini ve öğrencinin o anki durumunu anlatan sistem metni.
  static String novaIstemi({required String ekran, required String ad, required String seviye, Map<String, dynamic>? veri}) {
    final String screenContext = _ekranBaglami(ekran, veri ?? const {});
    return """
Sen İngilizce öğretmeni "Nova"sın. Ancak son teknoloji, zeki, espirili, modern ve aşırı motive edici bir yapay zeka koçusun.
Öğrencinin Adı: $ad
Öğrencinin Mevcut Seviyesi: $seviye
Şu an ne yapıyor?: $screenContext

GÖREV: Kullanıcıya bu EKRANDA olduğu duruma göre anlık tavsiye veren 2-3 cümlelik, heyecanlı ve zeki bir İngilizce mesaj ver.
KURALLAR:
1) Dil çok doğal bir İngilizce olsun fakat aralara rastgele, aşırı motive edici anlık TÜRKÇE kelimeler ("Harikasın!", "Aslan parçası", "Helal!", "Hadi canım", "Aynen böyle!") sıkıştır. İki dili birleştir!
2) Standart, sıkıcı "İngilizce çalışmak iyidir" kalıplarına girme. Espri yap, meydan oku veya durumu havalı bir şekilde yorumla. $ad ismini bol kullan.
3) Tamamen kendi üretimin olsun, Markdown (# veya *) kullanma. Yalnızca senin sesinden çıkacak mesaj olsun.
""";
  }

  static String _kullaniciAdi() {
    try {
      if (Firebase.apps.isEmpty) return "Friend";
      final ad = FirebaseAuth.instance.currentUser?.displayName?.trim();
      return (ad == null || ad.isEmpty) ? "Friend" : ad;
    } catch (_) {
      return "Friend";
    }
  }

  /// Ekrana özel canlı tavsiye. Hiçbir durumda hata atmaz; sorun olursa yedek bir cümle döner.
  static Future<String> getLiveAdviceForScreen(String screenName, {dynamic data, ClaudeServisi? servis}) async {
    final ClaudeServisi claude = servis ?? ClaudeServisi.varsayilan;
    final String userName = _kullaniciAdi();
    if (!claude.anahtarVar) return ClaudeServisi.anahtarYokMesaji;

    try {
      final String seviye = await mevcutSeviye();
      final Map<String, dynamic>? veri = data is Map ? Map<String, dynamic>.from(data) : null;
      return await claude.sor(
        sistem: novaIstemi(ekran: screenName, ad: userName, seviye: seviye, veri: veri),
        istem: "Give me your live advice for this moment.",
        maxTokens: 400,
      );
    } on ClaudeHatasi catch (e) {
      debugPrint("Nova yanıt veremedi: ${e.kullaniciMesaji}");
      // Bağlantı sorunu geçicidir; anahtar/model gibi kalıcı sorunlar ise açıkça söylenir.
      if (!e.baglantiSorunu) return e.kullaniciMesaji;
      return "I'm having a little cloud connection issue right now, but keep pushing forward, $userName! Harikasın!";
    } catch (e) {
      debugPrint("Nova hatası: $e");
      return "Sometimes the cloud is dark, but your progress is bright. Stay focused! Aynen devam!";
    }
  }

  static void showCoachDialog(BuildContext context, String screenName, {dynamic data}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cache the initial text for the modal loading state
    
    final Future<String> tavsiye = getLiveAdviceForScreen(screenName, data: data);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.cyanAccent.withValues(alpha: isDark ? 0.15 : 0.05), blurRadius: 40, spreadRadius: 10)
            ]
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 6, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 30),
              
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.cyanAccent.shade400, width: 3),
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.5), blurRadius: 30)]
                ),
                // Nova'nın yüzü uygulamanın içinde çizilir; internetten resim indirilmez.
                child: const Center(child: NovaOrbWidget(size: 56)),
              ),
              const SizedBox(height: 20),
              
              Text("NOVA", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 5)),
              Text("Live AI Coach", style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5))),
              const SizedBox(height: 30),
              
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 140),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: isDark ? 0.05 : 0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2))
                ),
                child: FutureBuilder<String>(
                  future: tavsiye,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 35, height: 35,
                              child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 3),
                            ),
                            const SizedBox(height: 20),
                            Text("Nova is analyzing your aura...", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
                          ],
                        ),
                      );
                    } else if (snapshot.hasData) {
                      return _TypingTextWidget(text: snapshot.data!, textStyle: GoogleFonts.lora(fontSize: 18, color: theme.textTheme.bodyLarge?.color, height: 1.5, fontStyle: FontStyle.italic));
                    } else {
                      return Text("Nova logic loop failed.", style: GoogleFonts.lora(fontSize: 18, color: Colors.redAccent, height: 1.5, fontStyle: FontStyle.italic));
                    }
                  },
                ),
              ),
              const SizedBox(height: 30),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text("Got it, Coach!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
          ),
        );
      }
    );
  }

  static Widget globalCoachButton(BuildContext context, String screenName, {dynamic data}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: FloatingActionButton(
        heroTag: "NovaFab_$screenName",
        onPressed: () => showCoachDialog(context, screenName, data: data),
        backgroundColor: Theme.of(context).cardColor,
        shape: const CircleBorder(),
        child: const NovaOrbWidget(size: 30),
      ),
    );
  }
}

class _TypingTextWidget extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  const _TypingTextWidget({required this.text, required this.textStyle});

  @override
  State<_TypingTextWidget> createState() => _TypingTextWidgetState();
}

class _TypingTextWidgetState extends State<_TypingTextWidget> {
  String _displayedText = "";
  late Timer _timer;
  int _currentIndex = 0;
  // Karakterler (rune) tek tek yazılır; emoji gibi çift kod birimli harfler bölünmez.
  late final List<int> _harfler = widget.text.runes.toList();

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentIndex < _harfler.length) {
        setState(() {
          _displayedText += String.fromCharCode(_harfler[_currentIndex]);
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text("$_displayedText|", style: widget.textStyle);
  }
}

// ==========================================
// YENİ: NEFES ALAN ENERJİ KÜRESİ (PULSING NOVA ORB)
// ==========================================
class NovaOrbWidget extends StatefulWidget {
  final double size;
  const NovaOrbWidget({super.key, this.size = 50});

  @override
  State<NovaOrbWidget> createState() => _NovaOrbWidgetState();
}

class _NovaOrbWidgetState extends State<NovaOrbWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5 * _pulse.value), width: 1.5),
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF000000), // Singularity (Absolute Black)
                  Color(0xFF050014), // Deep Space Blue/Purple
                  Colors.deepPurpleAccent, // Event horizon
                  Colors.cyanAccent, // Light bending at the edge
                ],
                stops: [0.4, 0.75, 0.95, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.8 * _pulse.value), 
                  blurRadius: 25 * _pulse.value, 
                  spreadRadius: 2 * _pulse.value
                ),
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.4 * _pulse.value), 
                  blurRadius: 40 * _pulse.value, 
                  spreadRadius: 8 * _pulse.value
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
