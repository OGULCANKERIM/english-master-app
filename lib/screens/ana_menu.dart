import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/globals.dart';
import '../core/guncelleme.dart';
import '../core/temalar.dart';
import '../hesap/egitmen_ekranlari.dart';
import '../hesap/hesap_servisi.dart';
import '../hesap/profil_ekrani.dart';
import '../hesap/sohbet_ekrani.dart';
import '../services/ai_coach_system.dart';
import 'ayarlar_ekrani.dart';
import 'eslestirme_modulu.dart';
import 'kelime_modulu.dart';
import 'reading_modulu.dart';
import 'reels_modulu.dart';
import 'speaking_modulu.dart';

// ==========================================
// ANA MENÜ (PREMIUM BENTO BOX / STAGGERED GRID TASARIMI)
// ==========================================
class AnaMenuEkrani extends StatefulWidget {
  const AnaMenuEkrani({super.key});

  @override
  State<AnaMenuEkrani> createState() => _AnaMenuEkraniState();
}

class _AnaMenuEkraniState extends State<AnaMenuEkrani> {
  @override
  void initState() {
    super.initState();
    // Yeni sürüm varsa (Remote Config) bir kez haber verilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) guncellemeKontrolEt(context);
    });
  }

  void _temaDegistir() {
    temaKaydet((appThemeNotifier.value + 1) % AppThemes.themes.length);
  }

  List<List<Color>> _getGradients(int themeIndex) {
    if (themeIndex == 0) { // Light / Indigo
      return [
        [const Color(0xFF6366F1), const Color(0xFFA855F7)], // Cinematic
        [const Color(0xFF06B6D4), const Color(0xFF10B981)], // Word Vault
        [const Color(0xFF3B82F6), const Color(0xFF60A5FA)], // Voice
        [const Color(0xFFF43F5E), const Color(0xFFFB923C)], // Reading
        [const Color(0xFFFACC15), const Color(0xFFF97316)], // Word Match
      ];
    } else if (themeIndex == 1) { // OLED Hacker / Neon
      return [
        [const Color(0xFF00E676), const Color(0xFF1DE9B6)], // Cinematic
        [const Color(0xFF651FFF), const Color(0xFF8D24AA)], // Word Vault
        [const Color(0xFFFF3D00), const Color(0xFFFF9100)], // Voice
        [const Color(0xFF2979FF), const Color(0xFF00B0FF)], // Reading
        [const Color(0xFFFFEA00), const Color(0xFFFF9100)], // Word Match
      ];
    } else if (themeIndex == 2) { // Velvet Violet / Soft Warm
      return [
        [const Color(0xFFE91E63), const Color(0xFFFF8A80)], // Cinematic
        [const Color(0xFFFFB300), const Color(0xFFFFD54F)], // Word Vault
        [const Color(0xFF673AB7), const Color(0xFF9575CD)], // Voice
        [const Color(0xFFD32F2F), const Color(0xFFEF5350)], // Reading
        [const Color(0xFFEC407A), const Color(0xFFF48FB1)], // Word Match
      ];
    } else if (themeIndex == 3) { // Forest Green
      return [
        [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        [const Color(0xFF00796B), const Color(0xFF26A69A)],
        [const Color(0xFF558B2F), const Color(0xFF9CCC65)],
        [const Color(0xFFFF8F00), const Color(0xFFFFCA28)],
        [const Color(0xFF4E342E), const Color(0xFF8D6E63)],
      ];
    } else { // Sunset Crimson
      return [
        [const Color(0xFFFF3D00), const Color(0xFFFF8A65)],
        [const Color(0xFFD84315), const Color(0xFFFF7043)],
        [const Color(0xFFC2185B), const Color(0xFFF06292)],
        [const Color(0xFFE65100), const Color(0xFFFFB74D)],
        [const Color(0xFF5D4037), const Color(0xFF8D6E63)],
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradients = _getGradients(appThemeNotifier.value);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "AnaMenu"),
      body: Stack(
        children: [
          // Subtly inject a glowing orb gradient at the top right for depth
          if (isDark)
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(color: theme.primaryColor.withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 60)
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                       child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ENGLISH MASTER",
                            style: GoogleFonts.poppins(color: theme.colorScheme.secondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2.5)
                          ),
                        ],
                       ),
                      ),
                      Row(
                        children: [
                          // TEMA DEĞİŞTİRME BUTONU
                          GestureDetector(
                            onTap: () => Navigator.push(context, kayarakGecis(const AyarlarEkrani())),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 5))
                                ],
                              ),
                              child: Icon(Icons.settings_rounded, color: theme.primaryColor, size: 24),
                            ),
                          ),
                          GestureDetector(
                            onTap: _temaDegistir,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.05),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Icon(Icons.palette_rounded, color: theme.primaryColor, size: 24),
                            ),
                          ),
                          // PROFİL BUTONU
                          GestureDetector(
                            onTap: () => Navigator.push(context, kayarakGecis(const ProfilEkrani())),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4), width: 2),
                                boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.2), blurRadius: 15)],
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                child: Icon(Icons.person_rounded, color: theme.primaryColor, size: 26),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Karşılama kendi satırında: düğmeler adı sıkıştırmasın.
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 8),
                  child: _KarsilamaYazisi(stil: GoogleFonts.playfairDisplay(color: theme.textTheme.bodyLarge!.color, fontSize: 28, fontWeight: FontWeight.bold)),
                ),

                // 2. BENTO BOX STAGGERED GRID
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your Learning Modules",
                          style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                        ),
                        const SizedBox(height: 15),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT COLUMN
                            Expanded(
                              child: Column(
                                children: [
                                  // Cinematic Mode (Tall & Dominant)
                                  _buildBentoCard(
                                    context,
                                    title: "Cinematic\nMode",
                                    subtitle: "Learn with movie snippets",
                                    icon: Icons.movie_filter_rounded,
                                    height: 260,
                                    gradientColors: gradients[0],
                                    route: const FilmKesitleriEkrani(),
                                    isPrimary: true,
                                  ),
                                  const SizedBox(height: 15),
                                  // Word Vault (Short)
                                  _buildBentoCard(
                                    context,
                                    title: "Word\nVault",
                                    subtitle: "Expand vocabulary",
                                    icon: Icons.diamond_rounded,
                                    height: 180,
                                    gradientColors: gradients[1],
                                    route: const SeviyeliKelimeEkrani(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 15),

                            // RIGHT COLUMN
                            Expanded(
                              child: Column(
                                children: [
                                  // Voice Studio (Medium)
                                  _buildBentoCard(
                                    context,
                                    title: "Voice\nStudio",
                                    subtitle: "Perfect your accent",
                                    icon: Icons.mic_rounded,
                                    height: 190,
                                    gradientColors: gradients[2],
                                    route: const KonusmaPratigiEkrani(),
                                  ),
                                  const SizedBox(height: 15),
                                  // Reading Lounge (Tall)
                                  _buildBentoCard(
                                    context,
                                    title: "Reading\nLounge",
                                    subtitle: "Articles & stories",
                                    icon: Icons.auto_stories_rounded,
                                    height: 250,
                                    gradientColors: gradients[3],
                                    route: const OkumaPratigiEkrani(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),
                        // Word Match (Full Width)
                        _buildBentoCard(
                          context,
                          title: "Word\nMatch",
                          subtitle: "Play & Memorize",
                          icon: Icons.extension_rounded,
                          height: 175,
                          gradientColors: gradients[4],
                          route: const EslestirmeModulu(),
                          isPrimary: false,
                        ),

                        const SizedBox(height: 15),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildBentoCard(
                                context,
                                title: "Favorite\nReels",
                                subtitle: "Your saved scenes",
                                icon: Icons.favorite_rounded,
                                height: 170,
                                gradientColors: gradients[3],
                                route: const FavorilerEkrani(),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              // Hesap gerektirir: giriş yapılmamışsa bu ekran giriş ekranını gösterir.
                              child: Stack(
                                children: [
                                  _buildBentoCard(
                                    context,
                                    title: "My\nTutor",
                                    subtitle: "Chat with your tutor",
                                    icon: Icons.school_rounded,
                                    height: 170,
                                    gradientColors: gradients[2],
                                    route: const EgitmenimEkrani(),
                                  ),
                                  // Okunmamış mesaj varsa kırmızı nokta.
                                  const Positioned(top: 18, right: 18, child: OkunmamisNoktasi()),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildBentoCard(
                          context,
                          title: "My\nProfile",
                          subtitle: "Account, level & goals",
                          icon: Icons.person_rounded,
                          height: 150,
                          gradientColors: gradients[1],
                          route: const ProfilEkrani(),
                        ),

                        const SizedBox(height: 90),
                      ],
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

  // BENTO CARD BUILDER
  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required double height,
    required List<Color> gradientColors,
    required Widget route,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, kayarakGecis(route)),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            children: [
              // Oversized Background Icon (Bleeding Effect)
              Positioned(
                right: -30,
                bottom: -30,
                child: Transform.rotate(
                  angle: -0.2, // Hafif yan yatırılmış
                  child: Icon(
                    icon,
                    size: isPrimary ? 170 : 130,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),

              // Top-left Glow for highly glossy 3D feel
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 20)
                    ],
                  ),
                ),
              ),

              // Content Padding
              Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Section (Icon + Badge)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text("PRO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),

                    // Bottom Section (Texts)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dar ekranlarda başlık kelime ortasından bölünmesin; sığmazsa küçülür.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: isPrimary ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// "Welcome, ad" yazısı: giriş yapılmışsa profildeki ad, yapılmamışsa "Guest".
class _KarsilamaYazisi extends StatefulWidget {
  const _KarsilamaYazisi({required this.stil});

  final TextStyle stil;

  @override
  State<_KarsilamaYazisi> createState() => _KarsilamaYazisiState();
}

class _KarsilamaYazisiState extends State<_KarsilamaYazisi> {
  // Akışlar bir kez kurulur; menü her yeniden çizildiğinde (ör. tema değişince)
  // Firestore'a yeniden abone olunmaz.
  late final Stream<String?> _oturum = HesapServisi.oturumuIzle();
  String? _profilUid;
  Stream<Kullanici?>? _profil;

  Stream<Kullanici?>? _profilAkisi(String uid) {
    if (_profilUid != uid) {
      _profilUid = uid;
      try {
        _profil = HesapServisi.profilimiIzle();
      } catch (e) {
        // Tam bu anda çıkış yapıldıysa profil akışı kurulamaz; "Friend" gösterilir.
        debugPrint("Profil akışı kurulamadı: $e");
        _profil = null;
        _profilUid = null;
      }
    }
    return _profil;
  }

  Widget _yazi(String ad) => Text("Welcome, $ad", style: widget.stil, maxLines: 1, overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _oturum,
      builder: (context, oturum) {
        final String? uid = oturum.data;
        if (uid == null) {
          _profilUid = null;
          _profil = null;
          return _yazi("Guest");
        }
        return StreamBuilder<Kullanici?>(
          // uid değişince (başka hesapla giriş) akış yeniden kurulur.
          key: ValueKey(uid),
          stream: _profilAkisi(uid),
          builder: (context, profil) {
            final String ad = profil.data?.ad.trim() ?? "";
            return _yazi(ad.isEmpty ? "Friend" : ad.split(" ").first);
          },
        );
      },
    );
  }
}
