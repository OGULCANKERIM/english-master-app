import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ana_menu.dart';

// ==========================================
// AÇILIŞ KAPISI (KENDİ İKONUNLA SİNEMATİK PORTAL GEÇİŞİ)
// ==========================================
class AcilisKapisiEkrani extends StatefulWidget {
  const AcilisKapisiEkrani({super.key});

  @override
  State<AcilisKapisiEkrani> createState() => _AcilisKapisiEkraniState();
}

class _AcilisKapisiEkraniState extends State<AcilisKapisiEkrani> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon süresi (1.2 saniyede şık bir geçiş)
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    // Logon yavaşça başlayıp hızla ekranı kaplayacak şekilde büyüyecek
    _scaleAnimation = Tween<double>(begin: 1.0, end: 20.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInExpo)
    );

    // Büyürken ekran yavaşça şeffaflaşıp altındaki menüyü gösterecek
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    _sinematikGecisiBaslat();
  }

  Future<void> _sinematikGecisiBaslat() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    // Giriş zorunlu değil: uygulama her zaman ana menüye açılır.
    // Hesap isteyen ekranlar (My Tutor, My Profile) kendi giriş ekranını gösterir.
    const Widget gidilecekEkran = AnaMenuEkrani();

    if (mounted) {
      _controller.forward().then((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => gidilecekEkran,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          )
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E), // Ana menü ile aynı derin siyah/mor arka plan
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // NEON PARLAYAN KÜRE VE SENİN ÖZEL İKONUN
                    Container(
                      padding: const EdgeInsets.all(20), // İkonun etrafındaki nefes alma boşluğu
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 10)]
                      ),
                      // YENİ: Senin assets klasöründeki ikonun!
                      child: Image.asset(
                        'assets/icon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.language_rounded, color: Colors.white, size: 90),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // YAKINLAŞIRKEN ANINDA SİLİNEN METİN
                    Opacity(
                      opacity: _controller.value > 0.2 ? 0.0 : 1.0 - (_controller.value * 5),
                      child: Text(
                        "ENGLISH MASTER",
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 4)
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}