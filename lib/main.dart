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

// --- YENİ EKLENEN YAPAY ZEKA VE SES PAKETLERİ ---
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';

// ==========================================
// GLOBAL HAFIZA
// ==========================================
List<Map<String, dynamic>> globalFavoriSahneler = [];

// ==========================================
// ANA GİRİŞ NOKTASI
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(); 
  } catch (e) {
    print("Firebase Başlatılamadı: $e");
  }
  
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
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
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
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: renk.withOpacity(0.2), shape: BoxShape.circle),
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
  _SeviyeliKelimeEkraniState createState() => _SeviyeliKelimeEkraniState();
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
      
      String newVersion = remoteConfig.getString('current_version');
      String currentVersion = "1.0.0"; 

      if (newVersion != currentVersion && newVersion.isNotEmpty) {
        _showUpdateDialog(); 
      }
    } catch (e) {
      print("Güncelleme Hatası: $e");
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

  void ayarlariYap() async { await flutterTts.setLanguage("en-US"); await flutterTts.setPitch(1.0); await flutterTts.awaitSpeakCompletion(true); }

  Future<void> metniOku(String metin) async {
    if (okumaYapiliyor) return; 
    setState(() => okumaYapiliyor = true);
    try {
      if (sonOkunanMetin != metin) { sonOkunanMetin = metin; siradakiOkumaYavas = false; }
      if (siradakiOkumaYavas) { await flutterTts.setSpeechRate(0.2); await flutterTts.speak(metin); siradakiOkumaYavas = false; } 
      else { await flutterTts.setSpeechRate(0.5); await flutterTts.speak(metin); siradakiOkumaYavas = true; }
    } catch (e) { print("Error: $e"); }
    setState(() => okumaYapiliyor = false);
  }

  Future<void> kelimeleriGetir() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/WORD');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) { setState(() { tumKelimeler = json.decode(response.body); isLoading = false; }); } 
      else { setState(() { hataMesaji = "Server Error: ${response.statusCode}"; isLoading = false; }); }
    } catch (e) { setState(() { hataMesaji = "Connection Error: $e"; isLoading = false; }); }
  }

  void _pencereAc({required String baslik, required List<String> liste, required String seciliDeger, required Function(String) onSecim, Map<String, Color>? renkler}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(baslik, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
                children: liste.map((String item) {
                  Color chipColor = Colors.grey[300]!;
                  if (renkler != null && renkler.containsKey(item)) { chipColor = renkler[item]!; } else if (seciliDeger == item) chipColor = Colors.deepPurple; 
                  String label = item; if (baslik.contains("Type") && turEtiketleri.containsKey(item)) label = turEtiketleri[item]!.split(" ")[0]; 
                  return ChoiceChip(
                    label: Text(label), labelStyle: TextStyle(color: seciliDeger == item ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                    selected: seciliDeger == item, selectedColor: chipColor, backgroundColor: Colors.white, side: BorderSide(color: chipColor.withOpacity(0.5)),
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
      String gelenSeviye = k["lvl"].toString().trim(); bool seviyeUyuyor = gelenSeviye == seciliSeviye;
      String kelime = k["ing"].toString().trim(); bool harfUyuyor = seciliHarf == "All" || kelime.toUpperCase().startsWith(seciliHarf);
      String gelenTur = k["type"].toString().toLowerCase().trim(); bool turUyuyor = seciliTur == "All" ? true : (gelenTur == seciliTur || gelenTur.startsWith(seciliTur));
      return seviyeUyuyor && turUyuyor && harfUyuyor;
    }).toList();

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
                                              Align(alignment: Alignment.topRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: (turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.grey))), child: Text(turEtiketleri[filtrelenmisKelimeler[index]["type"]]?.split("(")[0] ?? filtrelenmisKelimeler[index]["type"] ?? "?", style: TextStyle(color: turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.black, fontWeight: FontWeight.bold, fontSize: 12)))),
                                              const SizedBox(height: 40),
                                              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [Flexible(child: Text(filtrelenmisKelimeler[index]["ing"], style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center)), const SizedBox(width: 10), IconButton(icon: Icon(Icons.volume_up_rounded, size: 36, color: okumaYapiliyor ? Colors.grey : Colors.deepPurple), onPressed: () => metniOku(filtrelenmisKelimeler[index]["ing"]))]),
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
                                                        Text(filtrelenmisKelimeler[index]["tr"], style: TextStyle(fontSize: 24, color: Colors.green[800], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                        const SizedBox(height: 15),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Flexible(child: Text("\"${filtrelenmisKelimeler[index]["sentence"]}\"", textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey[800]))),
                                                            const SizedBox(width: 8),
                                                            IconButton(icon: Icon(Icons.volume_up_rounded, size: 28, color: Colors.deepPurple[400]), onPressed: () => metniOku(filtrelenmisKelimeler[index]["sentence"]))
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
  _TestEkraniState createState() => _TestEkraniState();
}

class _TestEkraniState extends State<TestEkrani> {
  final List<String> seviyeListesi = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String seciliSeviye = "A1"; bool testDevamEdiyor = false; List<dynamic> testKelimeleri = [];
  int soruIndex = 0; int puan = 0; dynamic dogruKelime; List<String> secenekler = []; bool cevapSecildi = false; String secilenCevap = "";

  void testiBaslat() {
    testKelimeleri = widget.tumKelimeler.where((k) => k["lvl"].toString().trim() == seciliSeviye).toList();
    if (testKelimeleri.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu seviyede yeterli kelime yok!"))); return; }
    testKelimeleri.shuffle(); setState(() { testDevamEdiyor = true; soruIndex = 0; puan = 0; }); yeniSoruHazirla();
  }

  void yeniSoruHazirla() {
    if (soruIndex >= 10 || soruIndex >= testKelimeleri.length) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Text("Test Finished! 🎉", textAlign: TextAlign.center), content: Text("Your Score: $puan / ${min(10, testKelimeleri.length)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center), actions: [ TextButton(child: const Text("Close"), onPressed: () { Navigator.of(ctx).pop(); setState(() => testDevamEdiyor = false); }) ])); return;
    }
    cevapSecildi = false; secilenCevap = ""; dogruKelime = testKelimeleri[soruIndex];
    List<String> havuz = widget.tumKelimeler.where((k) => k["tr"] != dogruKelime["tr"]).map((k) => k["tr"].toString()).toSet().toList();
    havuz.shuffle(); secenekler = [dogruKelime["tr"]]; secenekler.addAll(havuz.take(3)); secenekler.shuffle(); setState(() {});
  }

  void cevapKontrol(String cevap) {
    if (cevapSecildi) return; setState(() { cevapSecildi = true; secilenCevap = cevap; if (cevap == dogruKelime["tr"]) puan++; });
    Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) { setState(() { soruIndex++; }); yeniSoruHazirla(); } });
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
  Widget _soruEkrani() { return Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Question: ${soruIndex + 1} / ${min(10, testKelimeleri.length)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text("Score: $puan", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))]), const SizedBox(height: 40), Card(elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), child: Column(children: [Text("What does this mean?", style: TextStyle(color: Colors.grey[600], fontSize: 16)), const SizedBox(height: 10), Text(dogruKelime["ing"], style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center)]))), const SizedBox(height: 40), Expanded(child: ListView.builder(itemCount: secenekler.length, itemBuilder: (context, index) {String secenek = secenekler[index]; Color butonRengi = Colors.white; Color yaziRengi = Colors.black87; if (cevapSecildi) { if (secenek == dogruKelime["tr"]) { butonRengi = Colors.green; yaziRengi = Colors.white; } else if (secenek == secilenCevap) { butonRengi = Colors.red; yaziRengi = Colors.white; } else { butonRengi = Colors.grey[300]!; } } return Padding(padding: const EdgeInsets.only(bottom: 15.0), child: SizedBox(height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: butonRengi, foregroundColor: yaziRengi, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: cevapSecildi ? 0 : 5), onPressed: () => cevapKontrol(secenek), child: Text(secenek, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center)))); }))])); }
}

// ==========================================
// FAVORİ VİDEOLAR EKRANI
// ==========================================
class FavorilerEkrani extends StatelessWidget {
  const FavorilerEkrani({super.key});

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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.movie_creation_rounded, color: Colors.pinkAccent)),
                    title: Text(sahne["kaynak"] ?? "Reels Video ${index + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)), 
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28), onPressed: () { 
                      globalFavoriSahneler.removeAt(index);
                      Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation1, animation2) => const FavorilerEkrani(), transitionDuration: Duration.zero));
                    }),
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani(ozelListe: globalFavoriSahneler, baslangicIndex: index))); },
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
  _FilmKesitleriEkraniState createState() => _FilmKesitleriEkraniState();
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
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> gelenVeri = json.decode(response.body);
        gelenVeri.shuffle(); 
        setState(() { _sahneler = gelenVeri; _isLoading = false; });
      } else {
        setState(() { _hataMesaji = "Sunucu Hatası: ${response.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _hataMesaji = "Bağlantı Hatası: İnternetinizi kontrol edin."; _isLoading = false; });
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
    if (_hataMesaji.isNotEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: Center(child: Text(_hataMesaji, style: const TextStyle(color: Colors.white))));
    if (_sahneler.isEmpty) return  Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: Center(child: Text("Excel tablonda henüz video yok.", style: TextStyle(color: Colors.white))));

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
                else { globalFavoriSahneler.add(sahne); }
              });
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
  _ReelsVideoOgesiState createState() => _ReelsVideoOgesiState();
}

class _ReelsVideoOgesiState extends State<ReelsVideoOgesi> {
  VideoPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _sesAcik = true; 

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.sahne["videoUrl"]))
      ..initialize().then((_) {
        setState(() { _isPlayerReady = true; });
        _controller!.setVolume(1.0); 
        _controller!.setLooping(true); 
        if (widget.isFocused) { _controller!.play(); } 
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
            : const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),

        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomRight, end: Alignment.center, colors: [Colors.black.withOpacity(0.4), Colors.transparent]))),

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
// YAPAY ZEKA DESTEKLİ KONUŞMA PRATİĞİ EKRANI
// ==========================================
class KonusmaPratigiEkrani extends StatefulWidget {
  const KonusmaPratigiEkrani({super.key});

  @override
  _KonusmaPratigiEkraniState createState() => _KonusmaPratigiEkraniState();
}

class _KonusmaPratigiEkraniState extends State<KonusmaPratigiEkrani> {
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _kullaniciMetni = "";
  
  final List<Map<String, String>> _mesajlar = [];
  bool _aiDusunuyor = false;

  // GOOGLE GEMINI API ŞİFREN BURAYA EKLENDİ!
  final String apiKey = "AIzaSyBJH9mdLFIuf4b7BbaoBkSsSTNxULnxuoA"; 
  late GenerativeModel _model;
  late ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _sesAyarlariniYap();
    _yapayZekayiBaslat();
  }

  void _sesAyarlariniYap() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.1); 
    await _flutterTts.setSpeechRate(0.45); 
  }

  void _yapayZekayiBaslat() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system("Sen arkadaş canlısı ve cesaretlendirici bir İngilizce öğretmenisin. Karşındaki kişi A2 seviyesinde İngilizce pratik yapmak istiyor. Onunla sadece İngilizce konuş. Yanıtların çok kısa, günlük hayattan ve anlaşılır olsun (en fazla 2-3 cümle). Eğer İngilizce gramer hatası yaparsa, çok nazikçe doğrusunu söyleyip sohbete devam et."),
    );
    _chat = _model.startChat();
    
    _mesajEkle("AI", "Hello! I am your English teacher. How are you doing today?");
    _sesliOku("Hello! I am your English teacher. How are you doing today?");
  }

  void _mesajEkle(String gonderen, String metin) {
    setState(() {
      _mesajlar.add({"gonderen": gonderen, "metin": metin});
    });
  }

  void _dinlemeyiBaslat() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) => print('Durum: $status'),
      onError: (errorNotification) => print('Hata: $errorNotification'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _kullaniciMetni = result.recognizedWords;
          });
          if (result.finalResult) {
            _isListening = false;
            _yapayZekayaGonder(_kullaniciMetni);
          }
        },
        localeId: "en_US", 
      );
    }
  }

  void _dinlemeyiDurdur() {
    _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _yapayZekayaGonder(String mesaj) async {
    if (mesaj.trim().isEmpty) return;
    
    _mesajEkle("Sen", mesaj);
    setState(() {
      _kullaniciMetni = "";
      _aiDusunuyor = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text(mesaj));
      final aiCevabi = response.text ?? "I didn't understand that.";
      
      _mesajEkle("AI", aiCevabi);
      _sesliOku(aiCevabi);
    } catch (e) {
      _mesajEkle("AI", "Oops! Connection error. Let's try again.");
    } finally {
      setState(() => _aiDusunuyor = false);
    }
  }

  Future<void> _sesliOku(String metin) async {
    await _flutterTts.speak(metin);
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                      color: isSen ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.1),
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
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Text(
                  _isListening ? "Listening... (Speak in English)" : "Tap the mic and speak!",
                  style: GoogleFonts.poppins(color: _isListening ? Colors.greenAccent : Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  _kullaniciMetni,
                  style: GoogleFonts.poppins(color: Colors.white70, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTapDown: (_) => _dinlemeyiBaslat(),
                  onTapUp: (_) => _dinlemeyiDurdur(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(_isListening ? 30 : 20),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.greenAccent.withOpacity(0.8) : Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isListening) BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 10)
                      ]
                    ),
                    child: Icon(Icons.mic_rounded, color: Colors.white, size: _isListening ? 50 : 40),
                  ),
                ),
                const SizedBox(height: 10),
                Text("Hold to speak", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}