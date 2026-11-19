import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ayarlar.dart';
import '../core/globals.dart';
import '../services/ai_coach_system.dart';

/// Tablodan gelen satırları uygulamanın kullandığı düzgün biçime çevirir:
/// bütün alanlar kırpılmış metin olur (eksik hücre = boş metin), seviye büyük harfe
/// ("a1" -> "A1"), tür küçük harfe çevrilir. İngilizcesi ya da Türkçesi olmayan satırlar atılır.
List<Map<String, String>> kelimeleriDuzenle(List<dynamic> satirlar) {
  final List<Map<String, String>> sonuc = [];
  for (final satir in satirlar) {
    if (satir is! Map) continue;
    final String ing = alan(satir, "ing");
    final String tr = alan(satir, "tr");
    if (ing.isEmpty || tr.isEmpty) continue;
    sonuc.add({
      "ing": ing,
      "tr": tr,
      "type": alan(satir, "type").toLowerCase(),
      "lvl": alan(satir, "lvl").toUpperCase(),
      "sentence": alan(satir, "sentence"),
    });
  }
  return sonuc;
}

/// Kelime için Pixabay'den bir çizim adresi getirir. Anahtar yoksa, sonuç yoksa ya da
/// herhangi bir hata olursa null döner; kart o zaman resimsiz gösterilir.
Future<String?> kelimeResmiGetir(String kelime, {http.Client? istemci, String anahtar = pixabayApiKey}) async {
  if (anahtar.isEmpty || kelime.trim().isEmpty) return null;
  try {
    final url = Uri.https('pixabay.com', '/api/', {
      'key': anahtar,
      'q': kelime.trim(),
      'image_type': 'illustration',
      'per_page': '3',
      'safesearch': 'true',
    });
    final response = await (istemci?.get(url) ?? http.get(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final data = json.decode(utf8.decode(response.bodyBytes));
    if (data is! Map || data["hits"] is! List || (data["hits"] as List).isEmpty) return null;
    final ilk = (data["hits"] as List).first;
    final adres = ilk is Map ? ilk["webformatURL"] : null;
    return adres is String && adres.isNotEmpty ? adres : null;
  } catch (e) {
    debugPrint("Pixabay hatası: $e");
    return null;
  }
}

// ==========================================
// 3D FLIP & ASCEND COLOR-CODED LEARNING
// ==========================================
class SeviyeliKelimeEkrani extends StatefulWidget {
  const SeviyeliKelimeEkrani({super.key});

  @override
  State<SeviyeliKelimeEkrani> createState() => _SeviyeliKelimeEkraniState();
}

class _SeviyeliKelimeEkraniState extends State<SeviyeliKelimeEkrani> {
  FlutterTts flutterTts = FlutterTts();
  List<dynamic> tumKelimeler = [];

  List<dynamic> kelimeDestesi = [];
  List<dynamic> ogrenilenKelimeler = [];
  Key _aktifKey = UniqueKey();

  Map<String, String?> kelimeResimleri = {};

  Future<void> _resmiHazirla(String kelime) async {
    if (kelime.isEmpty || kelimeResimleri.containsKey(kelime)) return;
    kelimeResimleri[kelime] = "loading";
    final String? imageUrl = await kelimeResmiGetir(kelime);
    if (!mounted) return;
    setState(() { kelimeResimleri[kelime] = imageUrl ?? "not_found"; });
    if (imageUrl != null) {
      // Resim açılamazsa kart kendi yedek simgesini gösterir; burada hata bastırılır.
      precacheImage(NetworkImage(imageUrl), context, onError: (_, _) {});
    }
  }

  bool isLoading = true;
  String hataMesaji = "";

  String seciliSeviye = "A1";
  String seciliTur = "All";
  String seciliHarf = "All";

  bool anlamigoster = false;

  String? sonOkunanMetin;
  bool okumaYapiliyor = false;
  bool siradakiOkumaYavas = false;
  double _ttsHiz = varsayilanTtsHiz;

  final List<String> seviyeListesi = ["A1", "A2", "B1", "B2", "C1", "C2"];
  final Map<String, Color> seviyeRenkleri = {"A1": Colors.green, "A2": Colors.teal, "B1": Colors.blue, "B2": Colors.indigo, "C1": Colors.purple, "C2": Colors.red};
  final List<String> alfabeListesi = ["All"] + List.generate(26, (index) => String.fromCharCode(index + 65));

  final Map<String, String> turEtiketleri = {
    "All": "All Types", "n": "Noun (İsim)", "v": "Verb (Fiil)", "adj": "Adjective (Sıfat)",
    "adv": "Adverb (Zarf)", "prep": "Preposition (Edat)", "pron": "Pronoun (Zamir)",
    "conj": "Conjunction (Bağlaç)", "det": "Determiner (Belirteç)", "excl": "Exclamation (Ünlem)",
    "int": "Interrogative (Soru)", "poss": "Possessive (Sahiplik)", "dis": "Discourse Marker",
  };

  final Map<String, Color> turRenkleri = {
    "All": Colors.orangeAccent, "n": Colors.blueAccent, "v": Colors.greenAccent, "adj": Colors.pinkAccent,
    "adv": Colors.deepPurpleAccent, "prep": Colors.tealAccent, "pron": Colors.indigo, "conj": Colors.brown,
    "det": Colors.blueGrey, "excl": Colors.redAccent, "int": Colors.amberAccent, "poss": Colors.cyanAccent, "dis": Colors.limeAccent,
  };

  // Dinamik Ekran Renk Kodlaması
  Color get aktifAuraRengi {
    if (kelimeDestesi.isEmpty) return Theme.of(context).primaryColor;
    String type = alan(kelimeDestesi[0], "type").toLowerCase();
    return turRenkleri[type] ?? Theme.of(context).primaryColor;
  }

  @override
  void initState() {
    super.initState();
    kelimeleriGetir();
    ayarlariYap();
  }

  Future<void> ayarlariYap() async {
    try {
      final ayar = await ttsAyarlariniOku();
      _ttsHiz = ayar.hiz;
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.setPitch(ayar.perde);
      await flutterTts.setSpeechRate(_ttsHiz);
    } catch (e) {
      debugPrint("TTS ayar hatası: $e");
    }

    try {
      var rawVoices = await flutterTts.getVoices;
      if (rawVoices != null) {
        List<dynamic> sesler = rawVoices;
        Map<dynamic, dynamic>? secilecekSes;

        for (var ses in sesler) {
          if (ses["locale"] == null) continue;
          String loc = ses["locale"].toString().toLowerCase();
          String name = ses["name"].toString().toLowerCase();

          bool isMale = name.contains("male") || name.contains("daniel") || name.contains("arthur") || name.contains("iom") || name.contains("tpm") || name.contains("rjs") || name.contains("bruce");

          if ((loc.contains("en-gb") || loc.contains("en-au") || loc.contains("en-ie")) && isMale) {
            secilecekSes = ses;
            break;
          }
        }
        if (secilecekSes != null) {
          await flutterTts.setVoice({"name": secilecekSes["name"], "locale": secilecekSes["locale"]});
        } else {
          await flutterTts.setLanguage("en-GB");
        }
      }
    } catch (e) {
      try { await flutterTts.setLanguage("en-GB"); } catch (_) {}
    }
  }

  Future<void> metniOku(String metin) async {
    if (okumaYapiliyor || !mounted) return;
    setState(() => okumaYapiliyor = true);
    try {
      if (sonOkunanMetin != metin) { sonOkunanMetin = metin; siradakiOkumaYavas = false; }
      if (siradakiOkumaYavas) { await flutterTts.setSpeechRate(_ttsHiz * 0.45); await flutterTts.speak(metin); siradakiOkumaYavas = false; }
      else { await flutterTts.setSpeechRate(_ttsHiz); await flutterTts.speak(metin); siradakiOkumaYavas = true; }
    } catch (e) { debugPrint("Okuma hatası: $e"); }
    if (mounted) setState(() => okumaYapiliyor = false);
  }

  Future<void> kelimeleriGetir() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/WORD');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode == 200) {
        tumKelimeler = kelimeleriDuzenle(jsonListeCoz(response));
        _desteyiHazirla();
        setState(() { isLoading = false; hataMesaji = ""; });
      } else { setState(() { hataMesaji = "Server Error: ${response.statusCode}"; isLoading = false; }); }
    } catch (e) {
      debugPrint("Kelimeler alınamadı: $e");
      if (mounted) setState(() { hataMesaji = "Connection problem. Please check your internet and try again."; isLoading = false; });
    }
  }

  void _desteyiHazirla() {
    List<dynamic> filtrelenmis = tumKelimeler.where((k) {
      String gelenSeviye = alan(k, "lvl"); bool seviyeUyuyor = gelenSeviye == seciliSeviye;
      String kelime = alan(k, "ing"); bool harfUyuyor = seciliHarf == "All" || kelime.toUpperCase().startsWith(seciliHarf);
      String gelenTur = alan(k, "type").toLowerCase(); bool turUyuyor = seciliTur == "All" ? true : (gelenTur == seciliTur || gelenTur.startsWith(seciliTur));
      return seviyeUyuyor && turUyuyor && harfUyuyor;
    }).toList();

    List<String> siralama = ["n", "v", "adj", "adv", "prep", "conj", "pron", "det", "excl", "int", "poss", "dis"];
    Map<String, List<dynamic>> gruplar = {};
    for (var type in siralama) { gruplar[type] = []; }

    for(var k in filtrelenmis) {
       String t = alan(k, "type").toLowerCase();
       if(gruplar.containsKey(t)) {
         gruplar[t]!.add(k);
       } else if (t.isNotEmpty && siralama.contains(t.split(" ")[0])) {
         gruplar[t.split(" ")[0]]!.add(k);
       } else {
         gruplar["n"]!.add(k);
       }
    }

    List<dynamic> siraliDeste = [];
    for(var type in siralama) {
       if(gruplar[type]!.isNotEmpty) {
          gruplar[type]!.shuffle();
          siraliDeste.addAll(gruplar[type]!);
       }
    }

    setState(() {
      kelimeDestesi = siraliDeste;
      ogrenilenKelimeler.clear();
      anlamigoster = false;
      _aktifKey = UniqueKey();
    });

    if (mounted) {
      for (int i = 0; i < min(3, kelimeDestesi.length); i++) {
        _resmiHazirla(alan(kelimeDestesi[i], "ing"));
      }
    }
  }

  void _kartKaydirildi(DismissDirection direction) {
    if (kelimeDestesi.isEmpty) return;
    final kelime = kelimeDestesi.removeAt(0);

    if (direction == DismissDirection.up) {
      ogrenilenKelimeler.add(kelime);
    } else if (direction == DismissDirection.down) {
      kelimeDestesi.add(kelime);
    }

    setState(() {
      anlamigoster = false;
      _aktifKey = UniqueKey();
    });

    if (kelimeDestesi.length > 2) {
      _resmiHazirla(alan(kelimeDestesi[2], "ing"));
    }
  }

  // YENİ: Oturum İstatistikleri (Kelimeler nereye gidiyor?)
  void _istatistikleriGoster() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(35))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 15, bottom: 20), height: 5, width: 60, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(10))),
              Text("Deck Statistics", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 10),

              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: theme.primaryColor, unselectedLabelColor: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5), indicatorColor: theme.primaryColor,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        tabs: [
                          Tab(text: "Vault (${ogrenilenKelimeler.length})", icon: const Icon(Icons.check_circle_rounded)),
                          Tab(text: "Remaining (${kelimeDestesi.length})", icon: const Icon(Icons.loop_rounded)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // ÖĞRENİLENLER LİSTESİ (Vault)
                            ogrenilenKelimeler.isEmpty
                              ? Center(child: Text("You haven't mastered any words yet.\nSwipe UP to ascend them here!", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5))))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(15), itemCount: ogrenilenKelimeler.length,
                                  itemBuilder: (context, index) {
                                    final k = ogrenilenKelimeler[index];
                                    return ListTile(
                                      leading: const Icon(Icons.rocket_launch_rounded, color: Colors.amberAccent),
                                      title: Text(alan(k, "ing"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      subtitle: Text(alan(k, "tr")),
                                      trailing: IconButton(icon: const Icon(Icons.volume_up_rounded), onPressed: () => metniOku(alan(k, "ing"))),
                                    );
                                  },
                                ),
                            // KALANLAR LİSTESİ (Remaining)
                            kelimeDestesi.isEmpty
                              ? Center(child: Text("Deck is empty!\nCongratulations!", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5))))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(15), itemCount: kelimeDestesi.length,
                                  itemBuilder: (context, index) {
                                    final k = kelimeDestesi[index];
                                    return ListTile(
                                      leading: Icon(Icons.access_time_filled_rounded, color: theme.primaryColor.withValues(alpha: 0.5)),
                                      title: Text(alan(k, "ing"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                      subtitle: const Text("Waiting in cycle..."),
                                    );
                                  },
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Route _alttanKayarakGecis(Widget gidilecekSayfa) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => gidilecekSayfa,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(position: animation.drive(Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutQuart))), child: child);
      }, transitionDuration: const Duration(milliseconds: 600),
    );
  }

  void _pencereAc({required String baslik, required List<String> liste, required String seciliDeger, required Function(String) onSecim, Map<String, Color>? renkler}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(baslik, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: theme.primaryColor), textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
                children: liste.map((String item) {
                  String label = item; if (baslik.contains("Type") && turEtiketleri.containsKey(item)) label = turEtiketleri[item]!.split(" ")[0];
                  bool isSelected = seciliDeger == item;
                  return ChoiceChip(
                    label: Text(label),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 13),
                    selected: isSelected, selectedColor: isSelected ? theme.primaryColor : theme.cardColor, backgroundColor: theme.cardColor,
                    side: BorderSide(color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.2)),
                    onSelected: (bool selected) { onSecim(item); Navigator.of(context).pop(); }, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(child: Text("Close", style: TextStyle(color: theme.textTheme.bodyLarge?.color)), onPressed: () => Navigator.of(context).pop())],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(theme),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        title: Text("Word Vault", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
        actions: [
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded, size: 28), color: theme.textTheme.bodyLarge?.color, onPressed: () => Scaffold.of(ctx).openDrawer())),
          IconButton(
            icon: const Icon(Icons.data_exploration_rounded, size: 28),
            color: aktifAuraRengi,
            onPressed: () => _istatistikleriGoster(), // STATS BUTTON
            tooltip: "View Deck Statistics",
          ),
          const SizedBox(width: 5),
        ],
      ),
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "KelimeModulu", data: {"currentType": seciliTur, "learnedCount": ogrenilenKelimeler.length}),
      body: Stack(
        children: [
          if (isDark)
            Positioned(
              top: -100, right: -50,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 700), width: 350, height: 350,
                decoration: BoxDecoration(shape: BoxShape.circle, color: aktifAuraRengi.withValues(alpha: 0.12), boxShadow: [BoxShadow(color: aktifAuraRengi.withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 60)]),
              ),
            ),

          SafeArea(
            child: isLoading
              ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
              : hataMesaji.isNotEmpty
                  ? Center(child: Text(hataMesaji, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 18), textAlign: TextAlign.center))
                  : Column(
                      children: [
                        _buildIlerlemeEkrani(theme),
                        Expanded(
                          child: Center(
                            child: kelimeDestesi.isEmpty
                                ? _buildTebriklerEkrani(theme)
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (kelimeDestesi.length > 2) _buildAnimatedBackgroundCard(kelimeDestesi[2], 2, theme, isDark),
                                      if (kelimeDestesi.length > 1) _buildAnimatedBackgroundCard(kelimeDestesi[1], 1, theme, isDark),

                                      Dismissible(
                                        key: _aktifKey,
                                        direction: DismissDirection.vertical,
                                        movementDuration: const Duration(milliseconds: 200), // Daha hızlı ekrandan çıkma
                                        dismissThresholds: const {
                                          DismissDirection.up: 0.22, // %22 kaydırmada kabul et (Daha hassas)
                                          DismissDirection.down: 0.22,
                                        },
                                        resizeDuration: null,
                                        onDismissed: (direction) => _kartKaydirildi(direction),
                                        background: _buildVerticalPortal(false, theme),
                                        secondaryBackground: _buildVerticalPortal(true, theme),
                                        child: _buildFrontCardAnimated(kelimeDestesi[0], theme, isDark),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (kelimeDestesi.isNotEmpty)
                          _buildBottomControls(theme, isDark),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildIlerlemeEkrani(ThemeData theme) {
    int total = ogrenilenKelimeler.length + kelimeDestesi.length;
    double progress = total == 0 ? 0 : (ogrenilenKelimeler.length / total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mastery Progress", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 500),
                style: TextStyle(color: aktifAuraRengi, fontSize: 13, fontWeight: FontWeight.bold),
                child: Text("${ogrenilenKelimeler.length} / $total Learned"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: aktifAuraRengi.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(aktifAuraRengi)),
          )
        ],
      ),
    );
  }

  Widget _buildVerticalPortal(bool isUp, ThemeData theme) {
    Color glowColor = isUp ? aktifAuraRengi : Colors.redAccent.shade700;
    IconData portalIcon = isUp ? Icons.check_circle_rounded : Icons.all_inclusive_rounded;
    String portalText = isUp ? "ASCEND TO VAULT\n(Knew it)" : "RETURN TO CYCLE\n(Review later)";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(40),
        border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 3),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10)]
      ),
      alignment: isUp ? Alignment.bottomCenter : Alignment.topCenter,
      padding: const EdgeInsets.all(50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(portalIcon, color: glowColor, size: 70), const SizedBox(height: 15),
          Text(portalText, style: GoogleFonts.poppins(color: glowColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2), textAlign: TextAlign.center)
        ],
      ),
    );
  }

  Widget _buildTebriklerEkrani(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.emoji_events_rounded, size: 120, color: Colors.amber.shade400), const SizedBox(height: 20),
        Text("Amazing!", style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)), const SizedBox(height: 10),
        Text("You mastered $seciliSeviye level words for this session.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6))), const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () { _desteyiHazirla(); }, icon: const Icon(Icons.refresh_rounded), label: const Text("Study Again", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))
        )
      ],
    );
  }

  Widget _buildAnimatedBackgroundCard(dynamic kelimeVerisi, int index, ThemeData theme, bool isDark) {
    double targetScale = index == 1 ? 0.92 : 0.85;
    double startScale = index == 1 ? 0.85 : 0.78;
    double targetOffset = index == 1 ? 20.0 : 40.0;
    double startOffset = index == 1 ? 40.0 : 60.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey("bg_${index}_${kelimeVerisi['ing']}"),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, startOffset + (targetOffset - startOffset) * val),
          child: Transform.scale(
            scale: startScale + (targetScale - startScale) * val,
            child: child,
          ),
        );
      },
      child: _buildStaticDepthCard(kelimeVerisi, theme, isDark),
    );
  }

  Widget _buildFrontCardAnimated(dynamic kelimeVerisi, ThemeData theme, bool isDark) {
    return TweenAnimationBuilder<double>(
      key: ValueKey("front_${kelimeVerisi['ing']}"),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack, // Öne gelirken hafif bir yaylanma (bounce) efekti
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, 20.0 * (1 - val)),
          child: Transform.scale(
            scale: 0.92 + (0.08 * val),
            child: child,
          ),
        );
      },
      child: _build3DFlipCard(kelimeVerisi, theme, isDark),
    );
  }

  Widget _build3DFlipCard(dynamic kelimeVerisi, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => anlamigoster = !anlamigoster);
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: anlamigoster ? 1 : 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, double val, child) {
          bool isBack = val >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(val * pi),
            child: isBack
                ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(pi), child: _buildCardBack(kelimeVerisi, theme, isDark))
                : _buildCardFront(kelimeVerisi, theme, isDark),
          );
        },
      ),
    );
  }

  Widget _buildStaticDepthCard(dynamic kelimeVerisi, ThemeData theme, bool isDark) {
    Color staticTurRengi = turRenkleri[alan(kelimeVerisi, "type")] ?? theme.primaryColor;
    return Container(
      height: 480, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(40),
        border: Border.all(color: staticTurRengi.withValues(alpha: 0.1), width: 1.5)
      ),
    );
  }

  Widget _buildCardFront(dynamic kelimeVerisi, ThemeData theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 480, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: theme.cardColor, borderRadius: BorderRadius.circular(40),
        border: Border.all(color: aktifAuraRengi.withValues(alpha: isDark ? 0.4 : 0.2), width: 2.5),
        boxShadow: [BoxShadow(color: aktifAuraRengi.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 40, offset: const Offset(0, 15))]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: aktifAuraRengi.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: aktifAuraRengi.withValues(alpha: 0.5))),
              child: Text(turEtiketleri[alan(kelimeVerisi, "type")]?.split("(")[0] ?? (alan(kelimeVerisi, "type").isEmpty ? "?" : alan(kelimeVerisi, "type")), style: TextStyle(color: aktifAuraRengi, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5))
            )
          ),
          const Spacer(),
          Text(alan(kelimeVerisi, "ing"), style: GoogleFonts.poppins(fontSize: 50, fontWeight: FontWeight.w800, color: theme.textTheme.bodyLarge?.color), textAlign: TextAlign.center),
          const SizedBox(height: 15),
          IconButton(icon: Icon(Icons.volume_up_rounded, size: 45, color: aktifAuraRengi), onPressed: () { metniOku(alan(kelimeVerisi, "ing")); }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(color: aktifAuraRengi.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
            child: Text("Tap card to flip", style: TextStyle(color: aktifAuraRengi.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  Widget _buildCardBack(dynamic kelimeVerisi, ThemeData theme, bool isDark) {
    String kelime = alan(kelimeVerisi, "ing");
    String? resimUrl = kelimeResimleri[kelime];

    Widget resimWidget;
    if (resimUrl == null || resimUrl == "loading") {
      resimWidget = Center(child: CircularProgressIndicator(color: aktifAuraRengi, strokeWidth: 2));
    } else if (resimUrl == "not_found") {
      resimWidget = Icon(Icons.lightbulb_rounded, color: aktifAuraRengi, size: 50);
    } else {
      resimWidget = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          resimUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.image_not_supported_rounded, size: 40, color: aktifAuraRengi.withValues(alpha: 0.5)),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 480, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: aktifAuraRengi.withValues(alpha: isDark ? 0.12 : 0.05), borderRadius: BorderRadius.circular(40),
        border: Border.all(color: aktifAuraRengi.withValues(alpha: 0.5), width: 2.5),
        boxShadow: [BoxShadow(color: aktifAuraRengi.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 5)]
      ),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: resimUrl == "not_found" ? null : BoxDecoration(color: aktifAuraRengi.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
              child: resimWidget,
            )
          ),
          const SizedBox(height: 15),
          Text(alan(kelimeVerisi, "tr"), style: TextStyle(fontSize: 28, color: aktifAuraRengi, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 15),
          if (alan(kelimeVerisi, "sentence").isNotEmpty) Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: aktifAuraRengi.withValues(alpha: 0.2))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text("\"${alan(kelimeVerisi, "sentence")}\"", textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 16, fontStyle: FontStyle.italic, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.9)))),
                IconButton(icon: Icon(Icons.volume_down_rounded, size: 24, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)), onPressed: () => metniOku(alan(kelimeVerisi, "sentence")))
              ]
            ),
          ),
          const SizedBox(height: 15),
          Text("Swipe UP to Ascend\nSwipe DOWN to Drop", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold, height: 1.3))
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25, left: 30, right: 30, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => _kartKaydirildi(DismissDirection.down),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor, shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2.5),
                boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))]
              ),
              child: const Icon(Icons.all_inclusive_rounded, color: Colors.redAccent, size: 36),
            ),
          ),

           GestureDetector(
            onTap: () => _kartKaydirildi(DismissDirection.up),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor, shape: BoxShape.circle,
                border: Border.all(color: aktifAuraRengi.withValues(alpha: 0.6), width: 2.5),
                boxShadow: [BoxShadow(color: aktifAuraRengi.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]
              ),
              child: Icon(Icons.check_circle_rounded, color: aktifAuraRengi, size: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      backgroundColor: theme.cardColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.primaryColor, theme.colorScheme.secondary])),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.style_rounded, size: 60, color: Colors.white), const SizedBox(height: 10), Text("Word Vault", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))])
          ),
          ListTile(
            leading: Icon(Icons.quiz_rounded, color: theme.colorScheme.secondary, size: 28),
            title: Text("Vocabulary Test", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); if (tumKelimeler.isNotEmpty) { Navigator.push(context, _alttanKayarakGecis(TestEkrani(tumKelimeler: tumKelimeler))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bekleyin!"))); } }
          ),
          ListTile(
            leading: Icon(Icons.data_exploration_rounded, color: Colors.amberAccent, size: 28),
            title: Text("Mastery Stats", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _istatistikleriGoster(); } // YENİ: DRAWER İSTATİSTİK BUTONU
          ),
          ListTile(
            leading: Icon(Icons.refresh, color: theme.primaryColor, size: 28),
            title: Text("Refresh Cards", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); setState(() { isLoading = true; hataMesaji = ""; }); kelimeleriGetir(); }
          ),
          Divider(thickness: 1, color: theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("FILTERS", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
           _buildFilterTile(theme, "Level", Icons.bar_chart_rounded, seciliSeviye, seviyeListesi, seviyeRenkleri, (val) { setState(() { seciliSeviye = val; }); _desteyiHazirla(); }),
          _buildFilterTile(theme, "Letter", Icons.sort_by_alpha_rounded, seciliHarf == "All" ? "A-Z" : seciliHarf, alfabeListesi, null, (val) { setState(() { seciliHarf = val; }); _desteyiHazirla(); }, isLetter: true),
          _buildFilterTile(theme, "Word Type", Icons.category_rounded, turEtiketleri[seciliTur]?.split(" ")[0] ?? "Type", turEtiketleri.keys.toList(), turRenkleri, (val) { setState(() { seciliTur = val; }); _desteyiHazirla(); }),
        ],
      ),
    );
  }

  Widget _buildFilterTile(ThemeData theme, String title, IconData icon, String currentVal, List<String> list, Map<String, Color>? colors, Function(String) onSelect, {bool isLetter = false}) {
    Color badgeColor = theme.primaryColor;
    if (colors != null && colors.containsKey(currentVal)) { badgeColor = colors[currentVal]!; } else if (isLetter) { badgeColor = theme.colorScheme.secondary; }

    return ListTile(
      leading: Icon(icon, color: badgeColor),
      title: Text(title, style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)), child: Text(currentVal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      onTap: () { _pencereAc(baslik: "Select $title", liste: list, seciliDeger: isLetter ? (currentVal == "A-Z" ? "All" : currentVal) : currentVal, renkler: colors, onSecim: onSelect); }
    );
  }
}

// ==========================================
// TEST / QUIZ EKRANI
// ==========================================
class TestEkrani extends StatefulWidget {
  final List<dynamic> tumKelimeler;
  const TestEkrani({super.key, required this.tumKelimeler});

  @override
  State<TestEkrani> createState() => _TestEkraniState();
}

class _TestEkraniState extends State<TestEkrani> {
  final List<String> seviyeListesi = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String seciliSeviye = "A1";
  bool testDevamEdiyor = false;
  List<dynamic> testKelimeleri = [];

  int soruIndex = 0; int puan = 0; dynamic dogruKelime; List<String> secenekler = []; bool cevapSecildi = false; String secilenCevap = "";

  void testiBaslat() {
    testKelimeleri = widget.tumKelimeler.where((k) => alan(k, "lvl") == seciliSeviye && alan(k, "ing").isNotEmpty && alan(k, "tr").isNotEmpty).toList();
    if (testKelimeleri.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeterli kelime yok!"))); return; }
    testKelimeleri.shuffle(); setState(() { testDevamEdiyor = true; soruIndex = 0; puan = 0; }); yeniSoruHazirla();
  }

  void yeniSoruHazirla() {
    if (soruIndex >= 10 || soruIndex >= testKelimeleri.length) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) {
          return AlertDialog(backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("Test Finished! 🎉", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
            content: Text("Your Score: $puan / ${min(10, testKelimeleri.length)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary), textAlign: TextAlign.center),
            actions: [ TextButton(child: Text("Close", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16)), onPressed: () { Navigator.of(ctx).pop(); setState(() => testDevamEdiyor = false); }) ]
          );
        }); return;
    }
    cevapSecildi = false; secilenCevap = ""; dogruKelime = testKelimeleri[soruIndex];
    List<String> havuz = widget.tumKelimeler.where((k) => alan(k, "tr").isNotEmpty && alan(k, "tr") != alan(dogruKelime, "tr")).map((k) => alan(k, "tr")).toSet().toList();
    havuz.shuffle(); secenekler = [alan(dogruKelime, "tr")]; secenekler.addAll(havuz.take(3)); secenekler.shuffle(); setState(() {});
  }

  void cevapKontrol(String cevap) {
    if (cevapSecildi) return; setState(() { cevapSecildi = true; secilenCevap = cevap; if (cevap == alan(dogruKelime, "tr")) puan++; });
    Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) { setState(() { soruIndex++; }); yeniSoruHazirla(); } });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text("Vocabulary Test", style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color)),
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "TestEkrani"),
      body: Stack(children: [if (isDark) Positioned(top: -100, right: -50, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.secondary.withValues(alpha: 0.12), boxShadow: [BoxShadow(color: theme.colorScheme.secondary.withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 60)]))), SafeArea(child: !testDevamEdiyor ? _testGirisEkrani(theme, isDark) : _soruEkrani(theme, isDark))])
    );
  }

  Widget _testGirisEkrani(ThemeData theme, bool isDark) {
    return Center(child: Padding(padding: const EdgeInsets.all(25.0), child: Container(decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(32), border: Border.all(color: theme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.05)), boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))]), padding: const EdgeInsets.all(35.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.school_rounded, size: 70, color: theme.primaryColor)),const SizedBox(height: 25), Text("Select Level for Quiz", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)), const SizedBox(height: 25), Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: seciliSeviye, isExpanded: true, dropdownColor: theme.cardColor, icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor), style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.w600), items: seviyeListesi.map((String value) { return DropdownMenuItem<String>(value: value, child: Text("Level $value")); }).toList(), onChanged: (yeniDeger) { setState(() { seciliSeviye = yeniDeger!; }); }))), const SizedBox(height: 35), SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 5), onPressed: testiBaslat, child: const Text("START TEST", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5))))]))));
  }

  Widget _soruEkrani(ThemeData theme, bool isDark) {
    return Padding(padding: const EdgeInsets.all(25.0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Question: ${soruIndex + 1} / ${min(10, testKelimeleri.length)}", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600)), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3))), child: Text("Score: $puan", style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)))]), const SizedBox(height: 30), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(32), border: Border.all(color: theme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.05)), boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(children: [Text("What does this mean?", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.w500)), const SizedBox(height: 15), Text(dogruKelime["ing"], style: GoogleFonts.poppins(fontSize: 42, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color), textAlign: TextAlign.center)])), const SizedBox(height: 40), Expanded(child: ListView.builder(physics: const BouncingScrollPhysics(), itemCount: secenekler.length, itemBuilder: (context, index) {String secenek = secenekler[index]; Color butonRengi = theme.cardColor; Color yaziRengi = theme.textTheme.bodyLarge!.color!; BorderSide sinir = BorderSide(color: theme.primaryColor.withValues(alpha: 0.2)); if (cevapSecildi) { if (secenek == dogruKelime["tr"]) { butonRengi = Colors.green.shade600; yaziRengi = Colors.white; sinir = BorderSide.none;} else if (secenek == secilenCevap) { butonRengi = Colors.red.shade600; yaziRengi = Colors.white; sinir = BorderSide.none;} else { butonRengi = theme.cardColor.withValues(alpha: 0.5); yaziRengi = theme.textTheme.bodyLarge!.color!.withValues(alpha: 0.3);} } return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: SizedBox(height: 65, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: butonRengi, foregroundColor: yaziRengi, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: cevapSecildi ? 0 : 2, side: sinir), onPressed: () => cevapKontrol(secenek), child: Text(secenek, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center)))); }))]));
  }
}