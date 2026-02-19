import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart'; 

// ==========================================
// GLOBAL HAFIZA (Favori videoları burada tutuyoruz)
// ==========================================
List<Map<String, dynamic>> globalFavoriSahneler = [];

void main() => runApp(IngilizceUygulamam());

class IngilizceUygulamam extends StatelessWidget {
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
      home: SeviyeliKelimeEkrani(),
    );
  }
}

// ==========================================
// ANA EKRAN (KELİME LİSTESİ)
// ==========================================
class SeviyeliKelimeEkrani extends StatefulWidget {
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
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
                children: liste.map((String item) {
                  Color chipColor = Colors.grey[300]!;
                  if (renkler != null && renkler.containsKey(item)) chipColor = renkler[item]!; else if (seciliDeger == item) chipColor = Colors.deepPurple; 
                  String label = item; if (baslik.contains("Type") && turEtiketleri.containsKey(item)) label = turEtiketleri[item]!.split(" ")[0]; 
                  return ChoiceChip(
                    label: Text(label), labelStyle: TextStyle(color: seciliDeger == item ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                    selected: seciliDeger == item, selectedColor: chipColor, backgroundColor: Colors.white, side: BorderSide(color: chipColor.withOpacity(0.5)),
                    onSelected: (bool selected) { onSecim(item); Navigator.of(context).pop(); }, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(child: Text("Close"), onPressed: () => Navigator.of(context).pop())],
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
            DrawerHeader(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book_rounded, size: 60, color: Colors.white), SizedBox(height: 10), Text("English Master", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))])),
            ListTile(leading: Icon(Icons.quiz_rounded, color: Colors.orangeAccent, size: 28), title: Text("Vocabulary Test", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); if (tumKelimeler.isNotEmpty) { Navigator.push(context, MaterialPageRoute(builder: (context) => TestEkrani(tumKelimeler: tumKelimeler))); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lütfen kelimelerin yüklenmesini bekleyin!"))); } }),
            ListTile(leading: Icon(Icons.play_circle_fill_rounded, color: Colors.pinkAccent, size: 28), title: Text("Reels Mode", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani())); }),
            ListTile(leading: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 28), title: Text("Favorite Videos", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => FavorilerEkrani())); }),
            ListTile(leading: Icon(Icons.refresh, color: Colors.blue, size: 28), title: Text("Refresh Words", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); setState(() { isLoading = true; hataMesaji = ""; }); kelimeleriGetir(); }),
            Divider(thickness: 1, color: Colors.grey[300]),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("FILTERS", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            ListTile(leading: Icon(Icons.bar_chart_rounded, color: seviyeRenkleri[seciliSeviye] ?? Colors.deepPurple), title: Text("Level", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: seviyeRenkleri[seciliSeviye], borderRadius: BorderRadius.circular(12)), child: Text(seciliSeviye, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Level", liste: seviyeListesi, seciliDeger: seciliSeviye, renkler: seviyeRenkleri, onSecim: (val) => setState(() { seciliSeviye = val; index = 0; anlamigoster = false; })); }),
            ListTile(leading: Icon(Icons.sort_by_alpha_rounded, color: Colors.orangeAccent), title: Text("Letter", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)), child: Text(seciliHarf == "All" ? "A-Z" : seciliHarf, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Letter", liste: alfabeListesi, seciliDeger: seciliHarf, onSecim: (val) => setState(() { seciliHarf = val; index = 0; anlamigoster = false; })); }),
            ListTile(leading: Icon(Icons.category_rounded, color: turRenkleri[seciliTur] ?? Colors.deepPurple), title: Text("Word Type", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)), trailing: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: turRenkleri[seciliTur], borderRadius: BorderRadius.circular(12)), child: Text(turEtiketleri[seciliTur]?.split(" ")[0] ?? "Type", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), onTap: () { _pencereAc(baslik: "Select Word Type", liste: turEtiketleri.keys.toList(), seciliDeger: seciliTur, renkler: turRenkleri, onSecim: (val) => setState(() { seciliTur = val; index = 0; anlamigoster = false; })); }),
          ],
        ),
      ),
      appBar: AppBar(title: Text("English Master", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
      body: Container(
        width: double.infinity, height: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])),
        child: SafeArea(
          child: isLoading ? Center(child: CircularProgressIndicator(color: Colors.white))
              : hataMesaji.isNotEmpty ? Center(child: Text(hataMesaji, style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center))
                  : Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: filtrelenmisKelimeler.isEmpty ? Padding(padding: const EdgeInsets.all(20.0), child: Text("No words found for:\nLevel: $seciliSeviye\nLetter: $seciliHarf\nType: ${turEtiketleri[seciliTur]}", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center))
                                : Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Card(
                                      elevation: 12, shadowColor: Colors.black45, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                      child: Container(
                                        width: double.infinity, padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Align(alignment: Alignment.topRight, child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: (turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.grey))), child: Text(turEtiketleri[filtrelenmisKelimeler[index]["type"]]?.split("(")[0] ?? filtrelenmisKelimeler[index]["type"] ?? "?", style: TextStyle(color: turRenkleri[filtrelenmisKelimeler[index]["type"]] ?? Colors.black, fontWeight: FontWeight.bold, fontSize: 12)))),
                                              SizedBox(height: 40),
                                              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [Flexible(child: Text(filtrelenmisKelimeler[index]["ing"], style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center)), SizedBox(width: 10), IconButton(icon: Icon(Icons.volume_up_rounded, size: 36, color: okumaYapiliyor ? Colors.grey : Colors.deepPurple), onPressed: () => metniOku(filtrelenmisKelimeler[index]["ing"]))]),
                                              SizedBox(height: 40),
                                              if (anlamigoster) ...[
                                                Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)), child: Column(children: [Text(filtrelenmisKelimeler[index]["tr"], style: TextStyle(fontSize: 24, color: Colors.green[700], fontWeight: FontWeight.w600), textAlign: TextAlign.center), SizedBox(height: 15), Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [Flexible(child: Text("\"${filtrelenmisKelimeler[index]["sentence"]}\"", textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey[700]))), SizedBox(width: 8), IconButton(icon: Icon(Icons.volume_up_rounded, size: 24, color: Colors.deepPurple[300]), onPressed: () => metniOku(filtrelenmisKelimeler[index]["sentence"]))])])),
                                              ] else ...[ Padding(padding: const EdgeInsets.all(20.0), child: Text("Tap to reveal", style: TextStyle(color: Colors.grey[400], fontSize: 12))) ],
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
                              ElevatedButton(onPressed: () { setState(() { if (index > 0) { index--; anlamigoster = false; } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Start of list!"))); } }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Icon(Icons.arrow_back)),
                              ElevatedButton.icon(onPressed: () { setState(() { anlamigoster = !anlamigoster; }); }, icon: Icon(anlamigoster ? Icons.visibility_off : Icons.visibility), label: Text(anlamigoster ? "Hide" : "Show"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
                              ElevatedButton(onPressed: () { setState(() { if (index < filtrelenmisKelimeler.length - 1) { index++; anlamigoster = false; } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("End of list!"))); } }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Icon(Icons.arrow_forward)),
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
// TEST / QUIZ EKRANI
// ==========================================
class TestEkrani extends StatefulWidget {
  final List<dynamic> tumKelimeler;
  TestEkrani({required this.tumKelimeler});
  @override
  _TestEkraniState createState() => _TestEkraniState();
}

class _TestEkraniState extends State<TestEkrani> {
  final List<String> seviyeListesi = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String seciliSeviye = "A1"; bool testDevamEdiyor = false; List<dynamic> testKelimeleri = [];
  int soruIndex = 0; int puan = 0; dynamic dogruKelime; List<String> secenekler = []; bool cevapSecildi = false; String secilenCevap = "";

  void testiBaslat() {
    testKelimeleri = widget.tumKelimeler.where((k) => k["lvl"].toString().trim() == seciliSeviye).toList();
    if (testKelimeleri.length < 4) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bu seviyede yeterli kelime yok!"))); return; }
    testKelimeleri.shuffle(); setState(() { testDevamEdiyor = true; soruIndex = 0; puan = 0; }); yeniSoruHazirla();
  }

  void yeniSoruHazirla() {
    if (soruIndex >= 10 || soruIndex >= testKelimeleri.length) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: Text("Test Finished! 🎉", textAlign: TextAlign.center), content: Text("Your Score: $puan / ${min(10, testKelimeleri.length)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center), actions: [ TextButton(child: Text("Close"), onPressed: () { Navigator.of(ctx).pop(); setState(() => testDevamEdiyor = false); }) ])); return;
    }
    cevapSecildi = false; secilenCevap = ""; dogruKelime = testKelimeleri[soruIndex];
    List<String> havuz = widget.tumKelimeler.where((k) => k["tr"] != dogruKelime["tr"]).map((k) => k["tr"].toString()).toSet().toList();
    havuz.shuffle(); secenekler = [dogruKelime["tr"]]; secenekler.addAll(havuz.take(3)); secenekler.shuffle(); setState(() {});
  }

  void cevapKontrol(String cevap) {
    if (cevapSecildi) return; setState(() { cevapSecildi = true; secilenCevap = cevap; if (cevap == dogruKelime["tr"]) puan++; });
    Future.delayed(Duration(milliseconds: 1500), () { if (mounted) { setState(() { soruIndex++; }); yeniSoruHazirla(); } });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text("Vocabulary Test", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
      body: Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFFC466B), Color(0xFF3F5EFB)])), child: SafeArea(child: !testDevamEdiyor ? _testGirisEkrani() : _soruEkrani())),
    );
  }

  Widget _testGirisEkrani() { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.school_rounded, size: 80, color: Colors.deepPurple), SizedBox(height: 20), Text("Select Level for Quiz", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 20), DropdownButton<String>(value: seciliSeviye, isExpanded: true, items: seviyeListesi.map((String value) { return DropdownMenuItem<String>(value: value, child: Center(child: Text("Level $value", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))); }).toList(), onChanged: (yeniDeger) { setState(() { seciliSeviye = yeniDeger!; }); }), SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: testiBaslat, child: Text("START TEST", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5))))]))))); }
  Widget _soruEkrani() { return Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Question: ${soruIndex + 1} / ${min(10, testKelimeleri.length)}", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Container(padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text("Score: $puan", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))]), SizedBox(height: 40), Card(elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20), child: Column(children: [Text("What does this mean?", style: TextStyle(color: Colors.grey[600], fontSize: 16)), SizedBox(height: 10), Text(dogruKelime["ing"], style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center)]))), SizedBox(height: 40), Expanded(child: ListView.builder(itemCount: secenekler.length, itemBuilder: (context, index) {String secenek = secenekler[index]; Color butonRengi = Colors.white; Color yaziRengi = Colors.black87; if (cevapSecildi) { if (secenek == dogruKelime["tr"]) { butonRengi = Colors.green; yaziRengi = Colors.white; } else if (secenek == secilenCevap) { butonRengi = Colors.red; yaziRengi = Colors.white; } else { butonRengi = Colors.grey[300]!; } } return Padding(padding: const EdgeInsets.only(bottom: 15.0), child: SizedBox(height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: butonRengi, foregroundColor: yaziRengi, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: cevapSecildi ? 0 : 5), onPressed: () => cevapKontrol(secenek), child: Text(secenek, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center)))); }))])); }
}

// ==========================================
// FAVORİ VİDEOLAR EKRANI
// ==========================================
class FavorilerEkrani extends StatefulWidget {
  @override
  _FavorilerEkraniState createState() => _FavorilerEkraniState();
}

class _FavorilerEkraniState extends State<FavorilerEkrani> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Favorite Videos", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF6A11CB), iconTheme: IconThemeData(color: Colors.white)),
      body: Container(
        width: double.infinity, height: double.infinity, decoration: BoxDecoration(color: Colors.grey[100]),
        child: globalFavoriSahneler.isEmpty 
          ? Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.heart_broken_rounded, size: 80, color: Colors.grey[400]), SizedBox(height: 20), Text("No favorites yet.", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[600])), SizedBox(height: 10), Text("Watch videos and tap the heart icon to save them here!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[500]))])))
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 10), itemCount: globalFavoriSahneler.length,
              itemBuilder: (context, index) {
                final sahne = globalFavoriSahneler[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8), elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.movie_creation_rounded, color: Colors.pinkAccent)),
                    title: Text(sahne["kaynak"] ?? "Reels Video ${index + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)), 
                    trailing: IconButton(icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28), onPressed: () { setState(() { globalFavoriSahneler.removeAt(index); }); }),
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani(ozelListe: globalFavoriSahneler, baslangicIndex: index))).then((_) => setState(() {})); },
                  ),
                );
              }
            ),
      ),
    );
  }
}

// ==========================================
// TIKTOK / REELS TARZI VİDEO EKRANI (SAF MOD)
// ==========================================
class FilmKesitleriEkrani extends StatefulWidget {
  final List<dynamic>? ozelListe;
  final int baslangicIndex;

  FilmKesitleriEkrani({this.ozelListe, this.baslangicIndex = 0});

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
    if (_isLoading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));
    if (_hataMesaji.isNotEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: Center(child: Text(_hataMesaji, style: TextStyle(color: Colors.white))));
    if (_sahneler.isEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: Center(child: Text("Excel tablonda henüz video yok.", style: TextStyle(color: Colors.white))));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white, size: 30)),
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

// ==========================================
// TEK BİR REELS VİDEO OYNATICISI (EKRANA SIĞDIRMA + SES BUTONLU)
// ==========================================
class ReelsVideoOgesi extends StatefulWidget {
  final dynamic sahne;
  final bool isFocused;
  final bool isFavori;
  final VoidCallback onFavoriToggle;

  ReelsVideoOgesi({required this.sahne, required this.isFocused, required this.isFavori, required this.onFavoriToggle});

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
        // 1. TAM EKRAN VİDEO KATMANI (BoxFit.contain İLE EKRANA SIĞDIRMA)
        _isPlayerReady
            ? GestureDetector(
                onTap: () { setState(() { if (_controller!.value.isPlaying) { _controller!.pause(); } else { _controller!.play(); } }); },
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain, // Videoyu kesilmekten kurtaran satır
                    child: SizedBox(width: _controller!.value.size.width ?? 0, height: _controller!.value.size.height ?? 0, child: VideoPlayer(_controller!)),
                  ),
                ),
              )
            : Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),

        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomRight, end: Alignment.center, colors: [Colors.black.withOpacity(0.4), Colors.transparent]))),

        // 3. SAĞ ALT - FAVORİ VE SES BUTONLARI
        Positioned(
          right: 15, bottom: 40,
          child: Column(
            children: [
              GestureDetector(
                onTap: _sesiDegistir,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Icon(_sesAcik ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white, size: 30),
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: widget.onFavoriToggle,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
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