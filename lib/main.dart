import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- YENİ EKLENEN YAPAY ZEKA VE SES PAKETLERİ ---
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';

// ==========================================
// DERLEME ZAMANI AYARLARI
// ==========================================
// API anahtarı ASLA koda yazılmaz. Derlerken şu şekilde verilir:
//   flutter run --dart-define=GEMINI_API_KEY=xxxx
const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String geminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');

// pubspec.yaml içindeki "version" ile aynı tutulmalı (güncelleme kontrolü bunu kullanır).
const String uygulamaSurumu = "1.0.0";

// ==========================================
// GLOBAL HAFIZA (cihazda kalıcı olarak saklanır)
// ==========================================
const String _favoriAnahtari = "favori_sahneler";
List<Map<String, dynamic>> globalFavoriSahneler = [];

Future<void> favorileriYukle() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final kayit = prefs.getString(_favoriAnahtari);
    if (kayit == null) return;
    globalFavoriSahneler = (json.decode(kayit) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
List<dynamic> _jsonListeCoz(http.Response response) {
  final veri = json.decode(utf8.decode(response.bodyBytes));
  return veri is List ? veri : <dynamic>[];
}

/// Tablodaki bir hücreyi güvenli şekilde metne çevirir (boş/eksik hücre çökme yapmaz).
String _alan(dynamic satir, String anahtar) {
  if (satir is! Map) return "";
  return (satir[anahtar] ?? "").toString().trim();
}

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

  runApp(const IngilizceUygulamam());
}

class IngilizceUygulamam extends StatelessWidget {
  const IngilizceUygulamam({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'English Master',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const AnaMenuEkrani(), 
    );
  }
}

// ==========================================
// ANA MENÜ (DASHBOARD) EKRANI
// ==========================================
class AnaMenuEkrani extends StatelessWidget {
  const AnaMenuEkrani({super.key});

  Route _kayarakGecis(Widget sayfa) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => sayfa,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); 
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome Back,", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 16)),
                        Text("English Master", style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text("What would you like to do?", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2, 
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.9,
                    children: [
                      _menuKarti(
                        baslik: "Vocabulary\nList",
                        ikon: Icons.menu_book_rounded,
                        renk: Colors.blueAccent,
                        onTap: () => Navigator.push(context, _kayarakGecis(const SeviyeliKelimeEkrani())),
                      ),
                      _menuKarti(
                        baslik: "Reels\nMode",
                        ikon: Icons.play_circle_fill_rounded,
                        renk: Colors.pinkAccent,
                        onTap: () => Navigator.push(context, _kayarakGecis(const FilmKesitleriEkrani())),
                      ),
                      _menuKarti(
                        baslik: "Favorite\nVideos",
                        ikon: Icons.favorite_rounded,
                        renk: Colors.redAccent,
                        onTap: () => Navigator.push(context, _kayarakGecis(const FavorilerEkrani())),
                      ),
                      // YEPYENİ YAPAY ZEKA BUTONUMUZ
                      _menuKarti(
                        baslik: "Speaking\nPractice",
                        ikon: Icons.mic_rounded,
                        renk: Colors.greenAccent,
                        onTap: () => Navigator.push(context, _kayarakGecis(const KonusmaPratigiEkrani())),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuKarti({required String baslik, required IconData ikon, required Color renk, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(ikon, size: 40, color: renk),
            ),
            const SizedBox(height: 15),
            Text(baslik, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// KELİME LİSTESİ EKRANI
// ==========================================
class SeviyeliKelimeEkrani extends StatefulWidget {
  const SeviyeliKelimeEkrani({super.key});

  @override
  State<SeviyeliKelimeEkrani> createState() => _SeviyeliKelimeEkraniState();
}

class _SeviyeliKelimeEkraniState extends State<SeviyeliKelimeEkrani> {
  FlutterTts flutterTts = FlutterTts(); 
  List<dynamic> tumKelimeler = []; 
  bool isLoading = true; 
  String hataMesaji = ""; 

  String seciliSeviye = "A1";
  String seciliTur = "All";
  String seciliHarf = "All"; 

  int index = 0; 
  bool anlamigoster = false; 
  
  String? sonOkunanMetin;
  bool okumaYapiliyor = false;
  bool siradakiOkumaYavas = false;

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
    "All": Colors.orange, "n": Colors.blue, "v": Colors.green, "adj": Colors.pink,
    "adv": Colors.purple, "prep": Colors.teal, "pron": Colors.indigo, "conj": Colors.brown,
    "det": Colors.grey, "excl": Colors.red, "int": Colors.amber, "poss": Colors.cyan, "dis": Colors.lime,
  };

  @override
  void initState() {
    super.initState();
    kelimeleriGetir(); 
    ayarlariYap(); 
    _checkForUpdate(); 
  }

  Route _alttanKayarakGecis(Widget gidilecekSayfa) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => gidilecekSayfa,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); 
        const end = Offset.zero;
        const curve = Curves.easeOutQuart; 
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 600), 
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 15),
      ));
      await remoteConfig.fetchAndActivate();
      
      String newVersion = remoteConfig.getString('current_version').trim();

      if (mounted && newVersion.isNotEmpty && newVersion != uygulamaSurumu) {
        _showUpdateDialog();
      }
    } catch (e) {
      debugPrint("Güncelleme Hatası: $e");
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("🚀 Yeni Sürüm Hazır!"),
        content: const Text("English Master'ı en iyi deneyimle kullanmak için lütfen güncelleyin."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("SONRA")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () async { 
              final Uri url = Uri.parse('https://appdistribution.firebase.google.com/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("GÜNCELLE"),
          ),
        ],
      ),
    );
  }

  Future<void> ayarlariYap() async {
    try { await flutterTts.setLanguage("en-US"); await flutterTts.setPitch(1.0); await flutterTts.awaitSpeakCompletion(true); }
    catch (e) { debugPrint("TTS ayar hatası: $e"); }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> metniOku(String metin) async {
    if (okumaYapiliyor || metin.isEmpty) return;
    setState(() => okumaYapiliyor = true);
    try {
      if (sonOkunanMetin != metin) { sonOkunanMetin = metin; siradakiOkumaYavas = false; }
      if (siradakiOkumaYavas) { await flutterTts.setSpeechRate(0.2); await flutterTts.speak(metin); siradakiOkumaYavas = false; }
      else { await flutterTts.setSpeechRate(0.5); await flutterTts.speak(metin); siradakiOkumaYavas = true; }
    } catch (e) { debugPrint("Error: $e"); }
    if (mounted) setState(() => okumaYapiliyor = false);
  }

  Future<void> kelimeleriGetir() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/WORD');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) { final liste = _jsonListeCoz(response); setState(() { tumKelimeler = liste; index = 0; anlamigoster = false; isLoading = false; }); }
      else { setState(() { hataMesaji = "Server Error: ${response.statusCode}"; isLoading = false; }); }
    } catch (e) {
      debugPrint("Kelime listesi hatası: $e");
      if (mounted) setState(() { hataMesaji = "Connection Error.\nPlease check your internet and tap Refresh Words."; isLoading = false; });
    }
  }

  void _pencereAc({required String baslik, required List<String> liste, required String seciliDeger, required Function(String) onSecim, Map<String, Color>? renkler}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(baslik, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
                children: liste.map((String item) {
                  Color chipColor = Colors.grey[300]!;
                  if (renkler != null && renkler.containsKey(item)) { chipColor = renkler[item]!; } else if (seciliDeger == item) { chipColor = Colors.deepPurple; }
                  String label = item; if (baslik.contains("Type") && turEtiketleri.containsKey(item)) label = turEtiketleri[item]!.split(" ")[0]; 
                  return ChoiceChip(
                    label: Text(label), labelStyle: TextStyle(color: seciliDeger == item ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                    selected: seciliDeger == item, selectedColor: chipColor, backgroundColor: Colors.white, side: BorderSide(color: chipColor.withValues(alpha: 0.5)),
                    onSelected: (bool selected) { onSecim(item); Navigator.of(context).pop(); }, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(child: const Text("Close"), onPressed: () => Navigator.of(context).pop())],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filtrelenmisKelimeler = tumKelimeler.where((k) {
      String gelenSeviye = _alan(k, "lvl").toUpperCase(); bool seviyeUyuyor = gelenSeviye == seciliSeviye;
      String kelime = _alan(k, "ing"); bool harfUyuyor = seciliHarf == "All" || kelime.toUpperCase().startsWith(seciliHarf);
      String gelenTur = _alan(k, "type").toLowerCase(); bool turUyuyor = seciliTur == "All" ? true : (gelenTur == seciliTur || gelenTur.startsWith(seciliTur));
      return kelime.isNotEmpty && seviyeUyuyor && turUyuyor && harfUyuyor;
    }).toList();

    // Liste yenilenince/filtre değişince index liste dışına taşmasın.
    if (index >= filtrelenmisKelimeler.length) index = 0;
    final dynamic aktifKelime = filtrelenmisKelimeler.isEmpty ? null : filtrelenmisKelimeler[index];
    final String aktifIng = _alan(aktifKelime, "ing");
    final String aktifTr = _alan(aktifKelime, "tr");
    final String aktifCumle = _alan(aktifKelime, "sentence");
    final String aktifTur = _alan(aktifKelime, "type").toLowerCase();

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.menu_book_rounded, size: 60, color: Colors.white), const SizedBox(height: 10), Text("English Master", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))])),
            ListTile(leading: const Icon(Icons.quiz_rounded, color: Colors.orangeAccent, size: 28), title: Text("Vocabulary Test", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); if (tumKelimeler.isNotEmpty) { Navigator.push(context, _alttanKayarakGecis(TestEkrani(tumKelimeler: tumKelimeler))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen kelimelerin yüklenmesini bekleyin!"))); } }),
            ListTile(leading: const Icon(Icons.refresh, color: Colors.blue, size: 28), title: Text("Refresh Words", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); setState(() { isLoading = true; hataMesaji = ""; }); kelimeleriGetir(); }),
            Divider(thickness: 1, color: Colors.grey[300]),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("FILTERS", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            ListTile(leading: Icon(Icons.bar_chart_rounded, color: seviyeRenkleri[seciliSeviye] ?? Colors.deepPurple), title: Text("Level", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: seviyeRenkleri[seciliSeviye], borderRadius: BorderRadius.circular(12)), child: Text(seciliSeviye, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Level", liste: seviyeListesi, seciliDeger: seciliSeviye, renkler: seviyeRenkleri, onSecim: (val) => setState(() { seciliSeviye = val; index = 0; anlamigoster = false; })); }),
            ListTile(leading: const Icon(Icons.sort_by_alpha_rounded, color: Colors.orangeAccent), title: Text("Letter", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)), child: Text(seciliHarf == "All" ? "A-Z" : seciliHarf, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Letter", liste: alfabeListesi, seciliDeger: seciliHarf, onSecim: (val) => setState(() { seciliHarf = val; index = 0; anlamigoster = false; })); }),
            ListTile(leading: Icon(Icons.category_rounded, color: turRenkleri[seciliTur] ?? Colors.deepPurple), title: Text("Word Type", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: turRenkleri[seciliTur], borderRadius: BorderRadius.circular(12)), child: Text(turEtiketleri[seciliTur]?.split(" ")[0] ?? "Type", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Word Type", liste: turEtiketleri.keys.toList(), seciliDeger: seciliTur, renkler: turRenkleri, onSecim: (val) => setState(() { seciliTur = val; index = 0; anlamigoster = false; })); }),
          ],
        ),
      ),
      appBar: AppBar(title: Text("Vocabulary List", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        width: double.infinity, height: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])),
        child: SafeArea(
          child: isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) 
              : hataMesaji.isNotEmpty ? Center(child: Text(hataMesaji, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center))
                  : Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: filtrelenmisKelimeler.isEmpty ? Padding(padding: const EdgeInsets.all(20.0), child: Text("No words found for:\nLevel: $seciliSeviye\nLetter: $seciliHarf\nType: ${turEtiketleri[seciliTur]}", style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center))
                                : Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Card(
                                      elevation: 12, shadowColor: Colors.black45, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                      child: Container(
                                        width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Align(alignment: Alignment.topRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (turRenkleri[aktifTur] ?? Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: (turRenkleri[aktifTur] ?? Colors.grey))), child: Text(turEtiketleri[aktifTur]?.split("(")[0] ?? (aktifTur.isEmpty ? "?" : aktifTur), style: TextStyle(color: turRenkleri[aktifTur] ?? Colors.black, fontWeight: FontWeight.bold, fontSize: 12)))),
                                              const SizedBox(height: 40),
                                              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [Flexible(child: Text(aktifIng, style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center)), const SizedBox(width: 10), IconButton(icon: Icon(Icons.volume_up_rounded, size: 36, color: okumaYapiliyor ? Colors.grey : Colors.deepPurple), onPressed: () => metniOku(aktifIng))]),
                                              const SizedBox(height: 40),
                                              
                                              GestureDetector(
                                                onTap: () { setState(() { anlamigoster = !anlamigoster; }); }, 
                                                child: AnimatedCrossFade(
                                                  firstChild: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
                                                    child: Column(
                                                      children: [
                                                        Icon(Icons.touch_app_rounded, color: Colors.grey[300], size: 40),
                                                        const SizedBox(height: 10),
                                                        Text("Tap to reveal meaning", style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500)),
                                                      ],
                                                    ),
                                                  ),
                                                  secondChild: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(20),
                                                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green[200]!)),
                                                    child: Column(
                                                      children: [
                                                        Text(aktifTr, style: TextStyle(fontSize: 24, color: Colors.green[800], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                        const SizedBox(height: 15),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Flexible(child: Text("\"$aktifCumle\"", textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey[800]))),
                                                            const SizedBox(width: 8),
                                                            IconButton(icon: Icon(Icons.volume_up_rounded, size: 28, color: Colors.deepPurple[400]), onPressed: () => metniOku(aktifCumle))
                                                          ]
                                                        )
                                                      ]
                                                    )
                                                  ),
                                                  crossFadeState: anlamigoster ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                                  duration: const Duration(milliseconds: 400), 
                                                  sizeCurve: Curves.easeOutBack, 
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30, left: 10, right: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(onPressed: () { setState(() { if (index > 0) { index--; anlamigoster = false; } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Start of list!"))); } }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Icon(Icons.arrow_back)),
                              ElevatedButton.icon(onPressed: () { setState(() { anlamigoster = !anlamigoster; }); }, icon: Icon(anlamigoster ? Icons.visibility_off : Icons.visibility), label: Text(anlamigoster ? "Hide" : "Show"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
                              ElevatedButton(onPressed: () { setState(() { if (index < filtrelenmisKelimeler.length - 1) { index++; anlamigoster = false; } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End of list!"))); } }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Icon(Icons.arrow_forward)),
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

// ==========================================
// TEST / QUIZ EKRANI (Vocabulary Test)
// ==========================================
class TestEkrani extends StatefulWidget {
  final List<dynamic> tumKelimeler;
  const TestEkrani({super.key, required this.tumKelimeler});
  @override
  State<TestEkrani> createState() => _TestEkraniState();
}

class _TestEkraniState extends State<TestEkrani> {
  final List<String> seviyeListesi = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String seciliSeviye = "A1"; bool testDevamEdiyor = false; List<dynamic> testKelimeleri = [];
  int soruIndex = 0; int puan = 0; dynamic dogruKelime; List<String> secenekler = []; bool cevapSecildi = false; String secilenCevap = "";

  int get toplamSoru => min(10, testKelimeleri.length);
  String get dogruCevap => _alan(dogruKelime, "tr");

  void testiBaslat() {
    testKelimeleri = widget.tumKelimeler.where((k) => _alan(k, "lvl").toUpperCase() == seciliSeviye && _alan(k, "ing").isNotEmpty && _alan(k, "tr").isNotEmpty).toList();
    if (testKelimeleri.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu seviyede yeterli kelime yok!"))); return; }
    testKelimeleri.shuffle(); setState(() { testDevamEdiyor = true; soruIndex = 0; puan = 0; }); yeniSoruHazirla();
  }

  void testiBitir() {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Text("Test Finished! 🎉", textAlign: TextAlign.center), content: Text("Your Score: $puan / $toplamSoru", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center), actions: [ TextButton(child: const Text("Close"), onPressed: () { Navigator.of(ctx).pop(); if (mounted) setState(() => testDevamEdiyor = false); }) ]));
  }

  void yeniSoruHazirla() {
    cevapSecildi = false; secilenCevap = ""; dogruKelime = testKelimeleri[soruIndex];
    List<String> havuz = widget.tumKelimeler.map((k) => _alan(k, "tr")).where((tr) => tr.isNotEmpty && tr != dogruCevap).toSet().toList();
    havuz.shuffle(); secenekler = [dogruCevap, ...havuz.take(3)]; secenekler.shuffle(); setState(() {});
  }

  void cevapKontrol(String cevap) {
    if (cevapSecildi) return; setState(() { cevapSecildi = true; secilenCevap = cevap; if (cevap == dogruCevap) puan++; });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      // Son sorudan sonra "Question 11 / 10" görünmesin: önce bitiş kontrolü.
      if (soruIndex + 1 >= toplamSoru) { testiBitir(); } else { soruIndex++; yeniSoruHazirla(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text("Vocabulary Test", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(width: double.infinity, height: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFFC466B), Color(0xFF3F5EFB)])), child: SafeArea(child: !testDevamEdiyor ? _testGirisEkrani() : _soruEkrani())),
    );
  }

  Widget _testGirisEkrani() { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.school_rounded, size: 80, color: Colors.deepPurple), const SizedBox(height: 20), Text("Select Level for Quiz", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20), DropdownButton<String>(value: seciliSeviye, isExpanded: true, items: seviyeListesi.map((String value) { return DropdownMenuItem<String>(value: value, child: Center(child: Text("Level $value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))); }).toList(), onChanged: (yeniDeger) { setState(() { seciliSeviye = yeniDeger!; }); }), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: testiBaslat, child: const Text("START TEST", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5))))]))))); }
  Widget _soruEkrani() { return Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Question: ${soruIndex + 1} / $toplamSoru", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text("Score: $puan", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))]), const SizedBox(height: 40), Card(elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), child: Column(children: [Text("What does this mean?", style: TextStyle(color: Colors.grey[600], fontSize: 16)), const SizedBox(height: 10), Text(_alan(dogruKelime, "ing"), style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center)]))), const SizedBox(height: 40), Expanded(child: ListView.builder(itemCount: secenekler.length, itemBuilder: (context, index) {String secenek = secenekler[index]; Color butonRengi = Colors.white; Color yaziRengi = Colors.black87; if (cevapSecildi) { if (secenek == dogruCevap) { butonRengi = Colors.green; yaziRengi = Colors.white; } else if (secenek == secilenCevap) { butonRengi = Colors.red; yaziRengi = Colors.white; } else { butonRengi = Colors.grey[300]!; } } return Padding(padding: const EdgeInsets.only(bottom: 15.0), child: SizedBox(height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: butonRengi, foregroundColor: yaziRengi, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: cevapSecildi ? 0 : 5), onPressed: () => cevapKontrol(secenek), child: Text(secenek, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center)))); }))])); }
}

// ==========================================
// FAVORİ VİDEOLAR EKRANI
// ==========================================
class FavorilerEkrani extends StatefulWidget {
  const FavorilerEkrani({super.key});

  @override
  State<FavorilerEkrani> createState() => _FavorilerEkraniState();
}

class _FavorilerEkraniState extends State<FavorilerEkrani> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Favorite Videos", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF6A11CB), iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        width: double.infinity, height: double.infinity, decoration: BoxDecoration(color: Colors.grey[100]),
        child: globalFavoriSahneler.isEmpty 
          ? Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.heart_broken_rounded, size: 80, color: Colors.grey[400]), const SizedBox(height: 20), Text("No favorites yet.", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[600])), const SizedBox(height: 10), Text("Watch videos and tap the heart icon to save them here!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[500]))]))) 
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10), itemCount: globalFavoriSahneler.length,
              itemBuilder: (context, index) {
                final sahne = globalFavoriSahneler[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.movie_creation_rounded, color: Colors.pinkAccent)),
                    title: Text(sahne["kaynak"] ?? "Reels Video ${index + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)), 
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28), onPressed: () { 
                      setState(() => globalFavoriSahneler.removeAt(index));
                      favorileriKaydet();
                    }),
                    // Videodan dönünce liste yenilensin (izlerken favoriden çıkarılmış olabilir).
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani(ozelListe: List.of(globalFavoriSahneler), baslangicIndex: index)));
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }
            ),
      ),
    );
  }
}

// ==========================================
// TIKTOK / REELS TARZI VİDEO EKRANI
// ==========================================
class FilmKesitleriEkrani extends StatefulWidget {
  final List<dynamic>? ozelListe;
  final int baslangicIndex;

  const FilmKesitleriEkrani({super.key, this.ozelListe, this.baslangicIndex = 0});

  @override
  State<FilmKesitleriEkrani> createState() => _FilmKesitleriEkraniState();
}

class _FilmKesitleriEkraniState extends State<FilmKesitleriEkrani> {
  List<dynamic> _sahneler = [];
  int _suankiIndex = 0;
  PageController? _pageController;
  bool _isLoading = true;
  String _hataMesaji = "";

  @override
  void initState() {
    super.initState();
    if (widget.ozelListe != null) {
      _sahneler = widget.ozelListe!;
      _suankiIndex = widget.baslangicIndex;
      _pageController = PageController(initialPage: _suankiIndex);
      _isLoading = false;
    } else {
      _suankiIndex = 0;
      _pageController = PageController(initialPage: 0);
      _videolariGetir();
    }
  }

  Future<void> _videolariGetir() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/VIDEO');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        // Video adresi boş olan satırlar oynatıcıyı çökertmesin.
        final List<dynamic> gelenVeri = _jsonListeCoz(response).where((s) => _alan(s, "videoUrl").isNotEmpty).toList();
        gelenVeri.shuffle();
        setState(() { _sahneler = gelenVeri; _isLoading = false; });
      } else {
        setState(() { _hataMesaji = "Sunucu Hatası: ${response.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      debugPrint("Video listesi hatası: $e");
      if (mounted) setState(() { _hataMesaji = "Bağlantı Hatası: İnternetinizi kontrol edin."; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));
    if (_hataMesaji.isNotEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)), body: Center(child: Text(_hataMesaji, style: const TextStyle(color: Colors.white))));
    if (_hataMesaji.isEmpty && _sahneler.isEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)), body: const Center(child: Text("Excel tablonda henüz video yok.", style: TextStyle(color: Colors.white))));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white, size: 30)),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _sahneler.length,
        onPageChanged: (index) { setState(() { _suankiIndex = index; }); },
        itemBuilder: (context, index) {
          final sahne = _sahneler[index];
          final isFavori = globalFavoriSahneler.any((f) => f["videoUrl"] == sahne["videoUrl"]);

          return ReelsVideoOgesi(
            sahne: sahne,
            isFocused: _suankiIndex == index,
            isFavori: isFavori,
            onFavoriToggle: () {
              setState(() {
                if (isFavori) { globalFavoriSahneler.removeWhere((f) => f["videoUrl"] == sahne["videoUrl"]); }
                else { globalFavoriSahneler.add(Map<String, dynamic>.from(sahne as Map)); }
              });
              favorileriKaydet();
            },
          );
        },
      ),
    );
  }
}

class ReelsVideoOgesi extends StatefulWidget {
  final dynamic sahne;
  final bool isFocused; 
  final bool isFavori;
  final VoidCallback onFavoriToggle;

  const ReelsVideoOgesi({super.key, required this.sahne, required this.isFocused, required this.isFavori, required this.onFavoriToggle});

  @override
  State<ReelsVideoOgesi> createState() => _ReelsVideoOgesiState();
}

class _ReelsVideoOgesiState extends State<ReelsVideoOgesi> {
  VideoPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _sesAcik = true;
  bool _videoHatasi = false;

  @override
  void initState() {
    super.initState();
    final adres = Uri.tryParse(_alan(widget.sahne, "videoUrl"));
    if (adres == null || !adres.hasScheme) { _videoHatasi = true; return; }
    final controller = VideoPlayerController.networkUrl(adres);
    _controller = controller;
    controller.initialize().then((_) {
      // Video yüklenirken sayfadan çıkıldıysa dispose edilmiş state'e dokunma.
      if (!mounted) return;
      setState(() { _isPlayerReady = true; });
      controller.setVolume(_sesAcik ? 1.0 : 0.0);
      controller.setLooping(true);
      if (widget.isFocused) { controller.play(); }
    }).catchError((Object e) {
      debugPrint("Video yüklenemedi: $e");
      if (mounted) setState(() { _videoHatasi = true; });
    });
  }

  @override
  void didUpdateWidget(ReelsVideoOgesi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      _controller?.play(); 
      _controller?.setVolume(_sesAcik ? 1.0 : 0.0); 
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _controller?.pause(); _controller?.seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _sesiDegistir() {
    setState(() {
      _sesAcik = !_sesAcik;
      _controller?.setVolume(_sesAcik ? 1.0 : 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _isPlayerReady
            ? GestureDetector(
                onTap: () { setState(() { if (_controller!.value.isPlaying) { _controller!.pause(); } else { _controller!.play(); } }); }, 
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain, 
                    child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)),
                  ),
                ),
              )
            : _videoHatasi
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline_rounded, color: Colors.white54, size: 60), SizedBox(height: 10), Text("Bu video yüklenemedi.\nKaydırarak devam edin.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))]))
                : const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),

        IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomRight, end: Alignment.center, colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent])))),

        Positioned(
          right: 15, bottom: 40,
          child: Column(
            children: [
              GestureDetector(
                onTap: _sesiDegistir,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Icon(_sesAcik ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: widget.onFavoriToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Icon(widget.isFavori ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: widget.isFavori ? Colors.redAccent : Colors.white, size: 36),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// YAPAY ZEKA DESTEKLİ KONUŞMA PRATİĞİ EKRANI (GÜNCELLENDİ)
// ==========================================
class KonusmaPratigiEkrani extends StatefulWidget {
  const KonusmaPratigiEkrani({super.key});

  @override
  State<KonusmaPratigiEkrani> createState() => _KonusmaPratigiEkraniState();
}

class _KonusmaPratigiEkraniState extends State<KonusmaPratigiEkrani> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechHazir = false;
  bool _isListening = false;
  String _kullaniciMetni = "";

  final List<Map<String, String>> _mesajlar = [];
  final ScrollController _scrollController = ScrollController();
  bool _aiDusunuyor = false;

  ChatSession? _chat;

  // Ses çeşitliliği için listeler
  List<Map<dynamic, dynamic>> _ingilizceSesler = [];

  static const String _karsilama = "Hello! I am your English teacher. How are you doing today?";

  @override
  void initState() {
    super.initState();
    _yapayZekayiBaslat();
    _sesAyarlariniYap().then((_) { if (mounted) _sesliOku(_karsilama); });
  }

  @override
  void dispose() {
    // Ekrandan çıkınca öğretmen konuşmaya ve mikrofon dinlemeye devam etmesin.
    _speechToText.cancel();
    _flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sesAyarlariniYap() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0); // Doğal ton
      await _flutterTts.setSpeechRate(0.5); // TAM GÜNLÜK KONUŞMA HIZI (Sabit)

      // Cihazda yüklü olan İngilizce sesleri bul (en-US, en-GB, en-AU vb.)
      final dynamic sesler = await _flutterTts.getVoices;
      final List<Map<dynamic, dynamic>> filtrelenmis = [];
      if (sesler is List) {
        for (final ses in sesler) {
          if (ses is Map && (ses["locale"] ?? "").toString().toLowerCase().startsWith("en")) {
            filtrelenmis.add(ses);
          }
        }
      }
      if (mounted) setState(() { _ingilizceSesler = filtrelenmis; });
    } catch (e) {
      debugPrint("TTS ayar hatası: $e");
    }
  }

  // Sağ üstteki menüden ses değiştirildiğinde çalışır
  Future<void> _sesiDegistir(Map<dynamic, dynamic> yeniSes) async {
    try {
      await _flutterTts.setVoice({"name": yeniSes["name"].toString(), "locale": yeniSes["locale"].toString()});
      // Her değiştirdiğinde hızı tekrar sabitliyoruz ki bozulmasın
      await _flutterTts.setSpeechRate(0.5);
      await _sesliOku("Hi! I am your new teacher.");
    } catch (e) {
      debugPrint("Ses değiştirilemedi: $e");
    }
  }

  void _yapayZekayiBaslat() {
    _mesajlar.add({"gonderen": "AI", "metin": _karsilama});

    if (geminiApiKey.isEmpty) {
      _mesajlar.add({"gonderen": "AI", "metin": "⚠️ Gemini API anahtarı tanımlı değil. Uygulamayı --dart-define=GEMINI_API_KEY=... ile derleyin."});
      return;
    }

    final model = GenerativeModel(
      model: geminiModel,
      apiKey: geminiApiKey,
      systemInstruction: Content.system("Sen arkadaş canlısı ve cesaretlendirici bir İngilizce öğretmenisin. Karşındaki kişi A2 seviyesinde İngilizce pratik yapmak istiyor. Onunla sadece İngilizce konuş. Yanıtların çok kısa, günlük hayattan ve anlaşılır olsun (en fazla 2-3 cümle). Eğer İngilizce gramer hatası yaparsa, çok nazikçe doğrusunu söyleyip sohbete devam et."),
    );
    _chat = model.startChat();
  }

  void _mesajEkle(String gonderen, String metin) {
    if (!mounted) return;
    setState(() {
      _mesajlar.add({"gonderen": gonderen, "metin": metin});
    });
    // Yeni mesaj gelince sohbeti en alta kaydır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // Mikrofona Dokunma (Toggle) Mantığı
  Future<void> _mikrofonuTetikle() async {
    if (_aiDusunuyor) return;
    if (_isListening) {
      await _dinlemeyiBitir(); // Zaten dinliyorsa durdur ve gönder
      return;
    }

    try {
      // Motor sadece bir kez kurulur; her dokunuşta yeniden kurmak çift tetiklemeye yol açıyordu.
      if (!_speechHazir) {
        _speechHazir = await _speechToText.initialize(
          onStatus: (status) {
            // Kullanıcı susarsa otomatik olarak gönder
            if (status == 'done' || status == 'notListening') _dinlemeyiBitir();
          },
          onError: (hata) {
            debugPrint('Konuşma tanıma hatası: $hata');
            if (mounted) setState(() => _isListening = false);
          },
        );
      }
      if (!mounted) return;

      if (!_speechHazir) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mikrofon izni alınamadı veya konuşma tanıma desteklenmiyor.")));
        return;
      }

      // Öğretmen konuşurken dinlemeye başlarsak mikrofon öğretmenin sesini yazar.
      await _flutterTts.stop();
      if (!mounted) return;
      setState(() {
        _isListening = true;
        _kullaniciMetni = "";
      });
      await _speechToText.listen(
        onResult: (result) {
          if (mounted && _isListening) setState(() { _kullaniciMetni = result.recognizedWords; });
        },
        localeId: "en_US",
      );
    } catch (e) {
      debugPrint("Mikrofon başlatılamadı: $e");
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mikrofon başlatılamadı.")));
      }
    }
  }

  // Hem "durdur" tuşu hem de motorun 'done' bildirimi buraya gelir;
  // _isListening bayrağı sayesinde mesaj yalnızca BİR kez gönderilir.
  Future<void> _dinlemeyiBitir() async {
    if (!_isListening) return;
    _isListening = false;
    final mesaj = _kullaniciMetni;
    if (mounted) setState(() {});
    try { await _speechToText.stop(); } catch (e) { debugPrint("Dinleme durdurulamadı: $e"); }
    await _yapayZekayaGonder(mesaj);
  }

  Future<void> _yapayZekayaGonder(String mesaj) async {
    if (mesaj.trim().isEmpty || _aiDusunuyor || !mounted) return;

    _mesajEkle("Sen", mesaj.trim());
    setState(() {
      _kullaniciMetni = "";
      _aiDusunuyor = true;
    });

    try {
      final chat = _chat;
      if (chat == null) {
        _mesajEkle("AI", "⚠️ Gemini API anahtarı tanımlı değil.");
        return;
      }
      final response = await chat.sendMessage(Content.text(mesaj.trim())).timeout(const Duration(seconds: 30));
      final cevap = response.text?.trim();
      final aiCevabi = (cevap == null || cevap.isEmpty) ? "I'm listening, but I couldn't form a sentence." : cevap;

      _mesajEkle("AI", aiCevabi);
      if (mounted) _sesliOku(aiCevabi);
    } catch (e) {
      debugPrint("AI Hatası: $e");
      final hata = e.toString();
      String aciklama = "Connection problem. Please check your internet";
      if (e is InvalidApiKey || hata.contains('API key') || hata.contains('403') || hata.contains('PERMISSION_DENIED')) {
        aciklama = "API key is invalid or not allowed";
      } else if (hata.contains('not found') || hata.contains('404')) {
        aciklama = "Model '$geminiModel' is not available";
      } else if (hata.contains('quota') || hata.contains('429')) {
        aciklama = "Daily limit reached, try again later";
      }
      _mesajEkle("AI", "Error: $aciklama.");
    } finally {
      if (mounted) setState(() => _aiDusunuyor = false);
    }
  }

  Future<void> _sesliOku(String metin) async {
    try { await _flutterTts.speak(metin); } catch (e) { debugPrint("TTS hatası: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), 
      appBar: AppBar(
        title: Text("Speaking Practice", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // YEPYENİ: Sağ üst köşedeki Ses Değiştirme Menüsü
          if (_ingilizceSesler.isNotEmpty)
            PopupMenuButton<Map<dynamic, dynamic>>(
              icon: const Icon(Icons.record_voice_over_rounded, color: Colors.white),
              tooltip: "Change Teacher Voice",
              onSelected: _sesiDegistir,
              itemBuilder: (BuildContext context) {
                // Sadece ilk 8 farklı sesi alıp kalabalığı önleyelim
                return _ingilizceSesler.take(8).map((ses) {
                  return PopupMenuItem<Map<dynamic, dynamic>>(
                    value: ses,
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 10),
                        Text("Teacher (${ses["locale"]})"),
                      ],
                    ),
                  );
                }).toList();
              },
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _mesajlar.length,
              itemBuilder: (context, index) {
                final mesaj = _mesajlar[index];
                final isSen = mesaj["gonderen"] == "Sen";
                
                return Align(
                  alignment: isSen ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: isSen ? Colors.deepPurpleAccent : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isSen ? const Radius.circular(20) : const Radius.circular(0),
                        bottomRight: isSen ? const Radius.circular(0) : const Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      mesaj["metin"]!,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_aiDusunuyor) 
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Text(
                  _isListening ? "Listening... (Tap to stop)" : "Tap to speak!",
                  style: GoogleFonts.poppins(color: _isListening ? Colors.greenAccent : Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  _kullaniciMetni,
                  style: GoogleFonts.poppins(color: Colors.white70, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // YENİ: Basılı tutmak yerine sadece dokunma mantığı
                GestureDetector(
                  onTap: _mikrofonuTetikle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(_isListening ? 30 : 20),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.greenAccent.withValues(alpha: 0.8) : Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isListening) BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 10)
                      ]
                    ),
                    child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: _isListening ? 50 : 40),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
