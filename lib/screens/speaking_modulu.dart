import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/claude_servisi.dart';
import '../core/dikte.dart';
import '../core/konusma_kaydi.dart';
import '../core/seviye.dart';
import '../services/ai_coach_system.dart';

// ==========================================
// YAPAY ZEKA DESTEKLİ KONUŞMA PRATİĞİ (GERÇEKÇİ 5 FARKLI SES & 5 MOD)
// ==========================================
class KonusmaPratigiEkrani extends StatefulWidget {
  const KonusmaPratigiEkrani({super.key});

  @override
  State<KonusmaPratigiEkrani> createState() => _KonusmaPratigiEkraniState();
}

class _KonusmaPratigiEkraniState extends State<KonusmaPratigiEkrani> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechHazir = false;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  // Yazı kutusu: sesle söylenen de buraya yazılır, istenirse elle düzeltilip gönderilir.
  final TextEditingController _yazi = TextEditingController();
  final FocusNode _yaziOdak = FocusNode();
  final DikteMetni _dikte = DikteMetni();
  // Mikrofonun o anki ses düzeyi (0..1); dalga göstergesini besler.
  final ValueNotifier<double> _sesDuzeyi = ValueNotifier<double>(0);
  // Bir dinleme parçası sürüyor mu (aynı parçanın bitişi iki kez işlenmesin diye).
  bool _parcaAcik = false;
  // Durdurulduktan sonra gelen son sonucu kaçırmamak için kısa bekleme süresi.
  bool _sonlandiriliyor = false;
  // Konuşma bitince mesaj kendiliğinden gönderilsin mi (kapalıysa önce düzeltilebilir).
  bool _otomatikGonder = true;
  String? _yerelKimlik;
  // Dinleme başlarken yazı kutusunda duran metin (yeni bir şey söylendi mi diye bakılır).
  String _dinlemeOncesiMetin = '';

  final List<Map<String, String>> _mesajlar = [];
  bool _aiDusunuyor = false;
  bool _ipucuBekleniyor = false;
  bool _konuSecimEkraninda = true;

  // Claude'a her istekte gönderilen sohbet geçmişi (user / assistant sırayla, düz metin).
  final List<Map<String, dynamic>> _sohbetGecmisi = [];
  // Açık sohbetin sistem metni (karakter + seviye + konu); sohbet başlarken belirlenir.
  String _aktifSistem = "";
  // Her yeni/yüklenen sohbette artar; geç gelen bir yanıt başka sohbete yazılmasın diye kullanılır.
  int _sohbetNo = 0;
  final List<KayitliSohbet> _kayitliSohbetler = [];
  static const String _kayitAnahtari = 'konusmaKayitlari';

  final List<String> _seviyeler = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String _seciliSeviye = "A2";

  // YAPAY ZEKA MODLARI
  final Map<String, Map<String, dynamic>> _aiModlari = {
    "toxic": {
      "isim": "Toxic Teacher",
      "ikon": Icons.sentiment_very_dissatisfied_rounded,
      "renk": Colors.redAccent,
      "prompt": "Sen kibirli, laf sokan, alaycı ve toksik bir İngilizce öğretmenisin. Öğrencinle dalga geç, hatalarını küçümse ama doğrusunu da söyle. Kısa cevaplar ver.",
      "acilislar": ["I hope your English is better today...", "Impress me, if you can.", "Let's see how many mistakes you make today."]
    },
    "flirt": {
      "isim": "Charming Partner",
      "ikon": Icons.favorite_rounded,
      "renk": Colors.pinkAccent,
      "prompt": "Sen son derece çekici, flörtöz, romantik ve tatlı dilli bir İngilizce konuşma partnerisin. Öğrenciyle sürekli flört et, iltifatlar et ve sohbeti romantik bir havada tut. Hatalarını çok tatlı bir şekilde düzelt. Kısa cevaplar ver.",
      "acilislar": ["Hey there, good looking... Tell me about your day.", "I've been waiting to talk to you all day. How are you?", "Your accent is so cute. Let's practice together."]
    },
    "fun": {
      "isim": "Funny Bestie",
      "ikon": Icons.emoji_emotions_rounded,
      "renk": Colors.orangeAccent,
      "prompt": "Sen aşırı enerjik, komik, sürekli espriler yapan ve çok samimi bir kankasın. Sokak ağzı (slang) kullan, şakalar yap ve çok sıcakkanlı ol. Kısa cevaplar ver.",
      "acilislar": ["What's up buddy! Ready to chat?", "Yo! Tell me some juicy gossip today.", "Hahaha! I missed our talks. What's on your mind?"]
    },
    "classic": {
      "isim": "Classic Tutor",
      "ikon": Icons.school_rounded,
      "renk": Colors.blueAccent,
      "prompt": "Sen profesyonel, sabırlı, kibar ve çok destekleyici bir IELTS/TOEFL eğitmenisin. Öğrenciyi sürekli motive et, kelime dağarcığını geliştirmesi için destek ol. Kısa cevaplar ver.",
      "acilislar": ["Hello. Let's improve your English together.", "Welcome to today's lesson. Take a deep breath.", "I am here to help you. Let's start."]
    },
    "coach": {
      "isim": "Life Coach",
      "ikon": Icons.local_fire_department_rounded,
      "renk": Colors.amber,
      "prompt": "Sen Tony Robbins gibi aşırı gaza getiren, enerjik, motive eden bir yaşam koçusun. Öğrenciye sürekli 'Sen yaparsın, harikasın!' tarzı şeyler söyle ve enerjiyi tavanda tut. Kısa cevaplar ver.",
      "acilislar": ["YOU ARE AMAZING! Let's crush this English practice!", "Wake up! Today is your day to shine! Speak to me!", "Don't hold back! Give me 100% of your energy!"]
    }
  };

  // YENİ: GERÇEKÇİ AKSANLARA DAYALI SES PROFİLLERİ
  final Map<String, Map<String, dynamic>> _sesProfilleri = {
    "f_us_soft": {"isim": "Soft & Sexy (US)", "kimlik": "f_us", "pitch": 0.90, "rate": 0.35, "ikon": Icons.face_3_rounded, "renk": Colors.pinkAccent},
    "f_gb_elegant": {"isim": "Elegant (British)", "kimlik": "f_gb", "pitch": 1.05, "rate": 0.40, "ikon": Icons.face_3_rounded, "renk": Colors.purpleAccent},
    "m_us_deep": {"isim": "Deep Alpha (US)", "kimlik": "m_us", "pitch": 0.65, "rate": 0.40, "ikon": Icons.face_6_rounded, "renk": Colors.indigoAccent},
    "m_gb_charming": {"isim": "Charming (British)", "kimlik": "m_gb", "pitch": 0.85, "rate": 0.42, "ikon": Icons.face_6_rounded, "renk": Colors.lightBlueAccent},
    "m_au_tough": {"isim": "Tough (Aussie)", "kimlik": "m_au", "pitch": 0.60, "rate": 0.38, "ikon": Icons.face_6_rounded, "renk": Colors.tealAccent},
  };

  String _seciliAiModu = "toxic";
  String _seciliSesProfili = "m_us_deep";

  // Cihazdan çekilecek gerçek farklı ses dosyaları
  Map<dynamic, dynamic>? _kadinSesiUS;
  Map<dynamic, dynamic>? _kadinSesiGB;
  Map<dynamic, dynamic>? _erkekSesiUS;
  Map<dynamic, dynamic>? _erkekSesiGB;
  Map<dynamic, dynamic>? _erkekSesiAU;

  final Map<String, List<String>> _kategoriHavuzu = {
    "🗣️ Social & Daily": ["Small Talk", "Friendship Dynamics", "Modern Dating", "Work-Life Balance", "Social Media Impact"],
    "🎭 Fun & Entertainment": ["Viral Internet Trends", "Stand-up Comedy", "Pranks & Jokes", "Video Games vs Board Games", "Party Stories"],
    "🔬 Science & Tech": ["Artificial Intelligence", "Space Colonization", "Quantum Physics", "Genetic Engineering", "Future of Internet"],
    "🎬 Cinema & TV": ["Marvel vs DC", "Binge-Watching Culture", "Evolution of Anime", "Overrated Movies", "Classic Masterpieces"],
    "⚽ Sports & Fitness": ["E-Sports as Real Sports", "Extreme Sports", "Gym Culture & Diets", "History of Olympics", "Football Legends"],
    "✈️ Travel & Culture": ["Culture Shock", "Backpacking vs Luxury", "Must-Visit Historical Places", "Local Street Foods", "Living Abroad"],
    "🧠 Deep Thoughts": ["Meaning of Happiness", "Simulation Theory", "Determinism vs Free Will", "Is Morality Subjective?", "Life in 2050"],
  };

  late String _seciliKategori;
  late String _seciliKonu;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();

    _seciliKategori = _kategoriHavuzu.keys.first;
    _seciliKonu = _kategoriHavuzu[_seciliKategori]!.first;

    _ilkKurulum();
  }

  Future<void> _ilkKurulum() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Kayıtlı sohbetler en başta yüklenir: sonradan yüklenseydi bu arada saklanan
      // bir sohbet eski kayıtların üzerine yazardı.
      _sohbetleriYukle(prefs);

      String? kayitliMod = prefs.getString('aiMode');
      if (kayitliMod != null && _aiModlari.containsKey(kayitliMod)) _seciliAiModu = kayitliMod;

      String? kayitliSes = prefs.getString('aiVoice');
      if (kayitliSes != null && _sesProfilleri.containsKey(kayitliSes)) _seciliSesProfili = kayitliSes;
      _otomatikGonder = prefs.getBool('speakingAutoSend') ?? true;
      if (mounted) setState(() {});

      final String kayitliSeviye = await mevcutSeviye();
      // Kullanıcı bu arada sohbete başladıysa seviyesi değiştirilmez.
      if (mounted && _konuSecimEkraninda && _seviyeler.contains(kayitliSeviye)) setState(() => _seciliSeviye = kayitliSeviye);
    } catch (e) {
      debugPrint("Konuşma ayarları yüklenemedi: $e");
    }
    await _cihazSesleriniBul();
    await _ttsAyarlariniUygula(okumaYap: false);
    if (mounted) setState(() {});
  }

  // YENİ: CİHAZDAKİ FARKLI AKSANLARI BULARAK GERÇEK KİŞİLER YARATMA
  Future<void> _cihazSesleriniBul() async {
    try {
      var rawVoices = await _flutterTts.getVoices;
      if (rawVoices != null) {
        List<dynamic> sesler = rawVoices;

        for (var ses in sesler) {
          if (ses["locale"] == null) continue;
          String loc = ses["locale"].toString().toLowerCase();
          String name = ses["name"].toString().toLowerCase();

          // Erkek olup olmadığını isimdeki şifrelerden anlıyoruz
          bool isMale = name.contains("male") || name.contains("daniel") || name.contains("arthur") || name.contains("iom") || name.contains("tpm") || name.contains("rjs") || name.contains("bruce");
          bool isFemale = !isMale; // Erkek değilse muhtemelen kadındır (TTS genelde kadın default'tur)

          if (loc.contains("en-us")) {
            if (isFemale && _kadinSesiUS == null) _kadinSesiUS = ses;
            if (isMale && _erkekSesiUS == null) _erkekSesiUS = ses;
          } else if (loc.contains("en-gb")) {
            if (isFemale && _kadinSesiGB == null) _kadinSesiGB = ses;
            if (isMale && _erkekSesiGB == null) _erkekSesiGB = ses;
          } else if (loc.contains("en-au") || loc.contains("en-ie") || loc.contains("en-in")) {
            if (isMale && _erkekSesiAU == null) _erkekSesiAU = ses;
          }
        }

        // Eğer cihazda İngiliz veya Avustralya aksanı yüklü değilse, uygulamanın çökmemesi için kopyalama (Fallback) yapıyoruz
        _kadinSesiGB ??= _kadinSesiUS;
        _erkekSesiUS ??= _kadinSesiUS;
        _erkekSesiGB ??= _erkekSesiUS;
        _erkekSesiAU ??= _erkekSesiUS;
      }
    } catch (e) { debugPrint("Ses arama hatası: $e"); }
  }

  // YENİ: AKSAN + PITCH + RATE KOMBİNASYONUNU UYGULAMA
  Future<void> _ttsAyarlariniUygula({bool okumaYap = true}) async {
    final profil = _sesProfilleri[_seciliSesProfili]!;
    try {
      await _flutterTts.setPitch(profil["pitch"]);
      await _flutterTts.setSpeechRate(profil["rate"]);
    } catch (e) { debugPrint("TTS ayar hatası: $e"); }

    Map<dynamic, dynamic>? secilecekSes;
    switch (profil["kimlik"]) {
      case "f_us": secilecekSes = _kadinSesiUS; break;
      case "f_gb": secilecekSes = _kadinSesiGB; break;
      case "m_us": secilecekSes = _erkekSesiUS; break;
      case "m_gb": secilecekSes = _erkekSesiGB; break;
      case "m_au": secilecekSes = _erkekSesiAU; break;
    }

    try {
      if (secilecekSes != null) {
        await _flutterTts.setVoice({"name": secilecekSes["name"].toString(), "locale": secilecekSes["locale"].toString()});
      } else {
        await _flutterTts.setLanguage("en-US"); // Hiçbir şey bulamazsa varsayılan
      }
    } catch (e) { debugPrint("Ses seçilemedi: $e"); }

    if (okumaYap) {
      _sesliOku("Setting applied. How do I sound?");
    }
  }

  Future<void> _ayarlariKaydet(String tur, String deger) async {
    final prefs = await SharedPreferences.getInstance();
    if (tur == "mod") {
      setState(() => _seciliAiModu = deger);
      await prefs.setString('aiMode', deger);
      // Konu seçim ekranındayken sohbet başlatılmaz; seçilen karakter ilk sohbette kullanılır.
      if (mounted && !_konuSecimEkraninda) _yeniSohbetBaslat();
    } else if (tur == "ses") {
      setState(() => _seciliSesProfili = deger);
      await prefs.setString('aiVoice', deger);
      _ttsAyarlariniUygula(okumaYap: true);
    }
  }

  void _sohbetleriYukle(SharedPreferences prefs) {
    // Bu oturumda eklenmiş sohbet varsa korunur (kayıtlılar başa eklenir).
    _kayitliSohbetler.insertAll(0, kayitliSohbetleriCoz(prefs.getString(_kayitAnahtari)));
  }

  Future<void> _sohbetleriKaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kayitAnahtari, kayitliSohbetleriKodla(_kayitliSohbetler));
    } catch (e) {
      debugPrint("Sohbetler kaydedilemedi: $e");
    }
  }

  /// Açık sohbette kullanıcı en az bir şey söylediyse onu kayıtlı sohbetlere ekler.
  void _acikSohbetiSakla() {
    // Yanıtı gelmemiş son mesaj ile hata/uyarı balonları saklanmaz; kullanıcı hiç yanıt
    // almadıysa (yalnızca açılış cümlesi varsa) saklanacak bir sohbet yoktur.
    final KayitliSohbet? kayit = kaydaHazirla(
      konu: _seciliKonu,
      mod: _seciliAiModu,
      seviye: _seciliSeviye,
      sistem: _aktifSistem,
      gecmis: _sohbetGecmisi,
    );
    if (kayit == null) return;
    _kayitliSohbetler.add(kayit);
    _sohbetleriKaydet();
  }

  void _konuyuSecVeBasla(String kategori, String konu) {
    setState(() {
      _seciliKategori = kategori;
      _seciliKonu = konu;
      _konuSecimEkraninda = false;
    });
    _yeniSohbetBaslat();
  }

  void _yeniSohbetBaslat() {
    _acikSohbetiSakla();
    _dinlemeyiIptalEt();
    _sohbetNo++;

    setState(() {
      _mesajlar.clear();
      _sohbetGecmisi.clear();
      _yazi.clear();
      _aiDusunuyor = false;
    });

    _yapayZekayiBaslat();
  }

  void _eskiSohbetiYukle(int index) {
    if (index < 0 || index >= _kayitliSohbetler.length) return;
    // Açık sohbet kaybolmasın; eklenen kayıt listenin sonuna gider, index değişmez.
    _acikSohbetiSakla();
    _dinlemeyiIptalEt();
    _flutterTts.stop();
    final KayitliSohbet kayit = _kayitliSohbetler.removeAt(index);
    _sohbetNo++;
    setState(() {
      _konuSecimEkraninda = false;
      // Sohbet kendi konusu, karakteri ve seviyesiyle açılır; eski kayıtlarda bunlar yoksa
      // ekrandaki seçimler kalır.
      if (kayit.konu.isNotEmpty) _seciliKonu = kayit.konu;
      if (_aiModlari.containsKey(kayit.mod)) _seciliAiModu = kayit.mod;
      if (_seviyeler.contains(kayit.seviye)) _seciliSeviye = kayit.seviye;
      _aiDusunuyor = false;
      _yazi.clear();
      _aktifSistem = kayit.sistem.isNotEmpty ? kayit.sistem : _sistemMetni();
      _mesajlar
        ..clear()
        ..addAll(kayit.mesajlar.map((m) => Map<String, String>.from(m)));
      _sohbetGecmisi
        ..clear()
        ..addAll(kayit.gecmis.map((m) => Map<String, dynamic>.from(m)));
    });
    _sohbetleriKaydet();
    Navigator.pop(context);
  }

  void _sohbetiSil(int index) {
    if (index < 0 || index >= _kayitliSohbetler.length) return;
    setState(() => _kayitliSohbetler.removeAt(index));
    _sohbetleriKaydet();
  }

  /// Seçili karakter, seviye ve konuya göre Claude'a verilen sistem metni.
  String _sistemMetni() {
    final mod = _aiModlari[_seciliAiModu]!;
    return "${mod['prompt']} Karşındaki kişi $_seciliSeviye seviyesinde. Konu: '$_seciliKonu'. Sadece İngilizce konuş. "
        "Yanıtların sesli okunacak: emoji, markdown, madde işareti veya sahne açıklaması kullanma; en fazla 2-3 kısa cümle yaz.";
  }

  void _yapayZekayiBaslat() {
    final mod = _aiModlari[_seciliAiModu]!;
    final List<String> acilislar = List<String>.from(mod["acilislar"]);
    final rastgeleMesaj = "${acilislar[Random().nextInt(acilislar.length)]} Let's talk about '$_seciliKonu'.";

    _aktifSistem = _sistemMetni();
    // Claude geçmişi "user" ile başlamak zorunda; açılış cümlesi asistanın ilk yanıtı sayılır.
    _sohbetGecmisi.add({"role": "user", "content": "Hi! Let's start our conversation about '$_seciliKonu'."});
    _sohbetGecmisi.add({"role": "assistant", "content": rastgeleMesaj});

    _mesajEkle("AI", rastgeleMesaj);
    if (!ClaudeServisi.varsayilan.anahtarVar) _mesajEkle("AI", ClaudeServisi.anahtarYokMesaji);
    _sesliOku(rastgeleMesaj);
  }

  void _mesajEkle(String gonderen, String metin) {
    if (mounted) setState(() => _mesajlar.add({"gonderen": gonderen, "metin": metin, "ceviriGoster": "false"}));
  }

  Future<void> _ceviriYap(int index, String metin) async {
    if (index < 0 || index >= _mesajlar.length) return;
    final Map<String, String> mesaj = _mesajlar[index];
    if (mesaj["ceviriGoster"] == "yukleniyor") return;
    if (mesaj.containsKey("ceviri")) {
      setState(() => mesaj["ceviriGoster"] = mesaj["ceviriGoster"] == "true" ? "false" : "true");
      return;
    }
    setState(() => mesaj["ceviriGoster"] = "yukleniyor");
    try {
      final String ceviri = await ClaudeServisi.varsayilan.sor(
        sistem: "You are a translator. Translate the user's English text into natural Turkish. Reply with only the translation, nothing else.",
        istem: metin,
        maxTokens: 800,
      );
      if (mounted) setState(() { mesaj["ceviri"] = ceviri; mesaj["ceviriGoster"] = "true"; });
    } on ClaudeHatasi catch (e) {
      if (!mounted) return;
      setState(() => mesaj["ceviriGoster"] = "false");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.kullaniciMesaji)));
    } catch (e) {
      debugPrint("Çeviri hatası: $e");
      if (mounted) setState(() => mesaj["ceviriGoster"] = "false");
    }
  }

  Future<void> _ipucuIste() async {
    if (_aiDusunuyor || _ipucuBekleniyor || !gecmisGecerli(_sohbetGecmisi)) return;
    setState(() => _ipucuBekleniyor = true);
    String ipuclari;
    try {
      // Konuşmanın tamamı tek bir metin olarak verilir; böylece sohbetin kendi akışı bozulmaz.
      final String dokum = _sohbetGecmisi.skip(1).map((m) => "${m['role'] == 'assistant' ? 'Teacher' : 'Student'}: ${m['content']}").join("\n");
      ipuclari = await ClaudeServisi.varsayilan.sor(
        sistem: "You help an English learner at $_seciliSeviye level keep a conversation going. Plain text only, no markdown.",
        istem: "Here is our conversation about $_seciliKonu so far:\n\n$dokum\n\nSuggest 3 very short and natural English sentences the Student can say next to reply to the Teacher. Only output the 3 sentences, each on its own line starting with '• '. Do not translate to Turkish, do not write explanations.",
        maxTokens: 400,
      );
    } on ClaudeHatasi catch (e) {
      ipuclari = e.kullaniciMesaji;
    } catch (e) {
      debugPrint("İpucu hatası: $e");
      ipuclari = "Bağlantı sorunu oluştu.";
    }
    if (!mounted) return;
    setState(() => _ipucuBekleniyor = false);
    _ipucuPenceresiniGoster(ipuclari);
  }

  void _ipucuPenceresiniGoster(String ipuclari) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF2A2A3D), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(padding: const EdgeInsets.all(25.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 30), const SizedBox(width: 10), Text("You can say:", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]), const Divider(color: Colors.white24, height: 30), Text(ipuclari, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16, height: 1.5)), const SizedBox(height: 20), Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white), child: const Text("Got it!")))])),
    );
  }

  void _uyar(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj), duration: const Duration(seconds: 4)));
  }

  void _kutuyuGuncelle(String metin) {
    _yazi.value = TextEditingValue(text: metin, selection: TextSelection.collapsed(offset: metin.length));
  }

  /// Konuşma tanımayı bir kez kurar; kurulamazsa false döner.
  Future<bool> _konusmayiHazirla() async {
    if (_speechHazir) return true;
    _speechHazir = await _speechToText.initialize(
      onStatus: (durum) {
        // Telefon kısa bir sessizlikte parçayı kendiliğinden bitirir.
        if (durum == 'done') _parcaBitti();
      },
      onError: (hata) {
        debugPrint('Konuşma tanıma hatası: ${hata.errorMsg}');
        if (sessizlikHatasiMi(hata.errorMsg)) {
          _parcaBitti();
          return;
        }
        final String? mesaj = konusmaHatasiMesaji(hata.errorMsg);
        if (mesaj == null) return;
        _dinlemeyiBitir(gonder: false, sessizUyari: true);
        _uyar(mesaj);
      },
    );
    if (_speechHazir) {
      try {
        _yerelKimlik = ingilizceYerelSec((await _speechToText.locales()).map((l) => l.localeId));
      } catch (e) {
        debugPrint("Konuşma dilleri okunamadı: $e");
      }
    }
    return _speechHazir;
  }

  // Mikrofona dokunma: dinlemiyorsa başlatır, dinliyorsa bitirir.
  Future<void> _mikrofonuTetikle() async {
    if (_aiDusunuyor || _sonlandiriliyor) return;
    if (_isListening) {
      await _dinlemeyiBitir();
      return;
    }

    try {
      final bool hazir = await _konusmayiHazirla();
      if (!mounted) return;
      if (!hazir) {
        _uyar("Mikrofon izni alınamadı ya da telefonda konuşma tanıma yok. Yazarak da devam edebilirsin.");
        return;
      }

      // Öğretmen konuşurken dinlemeye başlarsak mikrofon öğretmenin sesini yazar.
      await _flutterTts.stop();
      if (!mounted) return;
      _yaziOdak.unfocus();
      _dikte.basla(_yazi.text);
      _dinlemeOncesiMetin = _yazi.text.trim();
      setState(() => _isListening = true);
      await _parcayiDinle();
    } catch (e) {
      debugPrint("Mikrofon başlatılamadı: $e");
      _isListening = false;
      _parcaAcik = false;
      if (mounted) setState(() {});
      _uyar("Mikrofon başlatılamadı. Tekrar dene ya da yazarak devam et.");
    }
  }

  /// Bir dinleme parçası başlatır. Kullanıcı durdurana ya da susana kadar parçalar art arda
  /// eklenir; böylece cümle ortasında düşünmek için durmak sözü kesmez.
  Future<void> _parcayiDinle() async {
    _parcaAcik = true;
    await _speechToText.listen(
      onResult: (sonuc) {
        if (!mounted || !(_isListening || _sonlandiriliyor)) return;
        _dikte.parcaGuncelle(sonuc.recognizedWords);
        _kutuyuGuncelle(_dikte.metin);
      },
      onSoundLevelChange: (duzey) => _sesDuzeyi.value = sesDuzeyiOrani(duzey),
      localeId: _yerelKimlik,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(minutes: 2),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        autoPunctuation: true,
      ),
    );
  }

  /// Telefon bir parçayı bitirdiğinde çağrılır: söz varsa dinlemeye devam eder, yoksa bitirir.
  Future<void> _parcaBitti() async {
    if (!_isListening || !_parcaAcik) return;
    _parcaAcik = false;
    final bool sozVardi = _dikte.parcayiBitir();
    if (!sozVardi) {
      await _dinlemeyiBitir();
      return;
    }
    // Biten parçanın gecikmeli bildirimleri yeni parçayla karışmasın diye kısa bir ara verilir.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_isListening) return;
    try {
      await _parcayiDinle();
    } catch (e) {
      debugPrint("Dinleme sürdürülemedi: $e");
      await _dinlemeyiBitir();
    }
  }

  // Hem "durdur" dokunuşu hem de sessizlik buraya gelir; _isListening bayrağı sayesinde
  // yalnızca BİR kez çalışır. [gonder] verilmezse "otomatik gönder" ayarı geçerlidir.
  Future<void> _dinlemeyiBitir({bool? gonder, bool sessizUyari = false}) async {
    if (!_isListening) return;
    final int buSohbet = _sohbetNo;
    _isListening = false;
    _parcaAcik = false;
    _sonlandiriliyor = true;
    _sesDuzeyi.value = 0;
    if (mounted) setState(() {});
    try { await _speechToText.stop(); } catch (e) { debugPrint("Dinleme durdurulamadı: $e"); }
    // Durdurulduktan hemen sonra gelen son sonucu da metne kat.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _sonlandiriliyor = false;
    // Bu arada başka sohbete geçildiyse söylenen o sohbete yazılmaz.
    if (!mounted || buSohbet != _sohbetNo) return;
    _dikte.parcayiBitir();
    _kutuyuGuncelle(_dikte.metin);
    setState(() {});
    // Hiçbir şey duyulmadıysa uyarılır; kutuda önceden yazılmış metin kendiliğinden gönderilmez.
    if (_yazi.text.trim() == _dinlemeOncesiMetin) {
      if (!sessizUyari) _uyar(konusmaHatasiMesaji('error_no_match')!);
      return;
    }
    if (gonder ?? _otomatikGonder) await _yazilaniGonder();
  }

  // Dinlemeyi, söyleneni göndermeden keser (yeni sohbete geçerken).
  void _dinlemeyiIptalEt() {
    if (!_isListening) return;
    _isListening = false;
    _parcaAcik = false;
    _sesDuzeyi.value = 0;
    _speechToText.cancel().catchError((Object e) { debugPrint("Dinleme iptal edilemedi: $e"); });
  }

  /// Yazı kutusundaki metni gönderir (elle yazılmış ya da sesle söylenmiş).
  Future<void> _yazilaniGonder() async {
    if (_isListening) {
      // Dinlerken gönder'e basıldı: dinleme kapatılır, kutudaki metin aşağıda gönderilir.
      await _dinlemeyiBitir(gonder: false, sessizUyari: true);
      if (!mounted) return;
    }
    final String metin = _yazi.text.trim();
    if (metin.isEmpty || _aiDusunuyor) return;
    _yazi.clear();
    await _yapayZekayaGonder(metin);
  }

  Future<void> _otomatikGonderiDegistir() async {
    setState(() => _otomatikGonder = !_otomatikGonder);
    _uyar(_otomatikGonder
        ? "Otomatik gönder açık: konuşman bitince mesaj kendiliğinden gider."
        : "Otomatik gönder kapalı: söylediğin yazı kutusunda kalır, düzeltip gönderebilirsin.");
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('speakingAutoSend', _otomatikGonder);
    } catch (e) {
      debugPrint("Ayar kaydedilemedi: $e");
    }
  }

  Future<void> _yapayZekayaGonder(String mesaj) async {
    if (mesaj.trim().isEmpty || _aiDusunuyor || !mounted) return;

    _mesajEkle("Sen", mesaj.trim());
    setState(() => _aiDusunuyor = true);

    // Yanıt gelene kadar kullanıcı başka sohbete geçerse (yeni konu, kayıtlı sohbet, ekrandan
    // çıkış) bu yanıt yok sayılır: o sohbetin ne balonlarına ne geçmişine ne de durumuna dokunulur.
    final int buSohbet = _sohbetNo;
    bool guncel() => mounted && buSohbet == _sohbetNo;

    _sohbetGecmisi.add({"role": "user", "content": mesaj.trim()});
    String? hata;
    try {
      final yanit = await ClaudeServisi.varsayilan.gonder(sistem: _aktifSistem, mesajlar: List.of(_sohbetGecmisi));
      if (!guncel()) return;
      _sohbetGecmisi.add({"role": "assistant", "content": yanit.metin});
      _mesajEkle("AI", yanit.metin);
      _sesliOku(yanit.metin);
    } on ClaudeHatasi catch (e) {
      hata = e.kullaniciMesaji;
    } catch (e) {
      debugPrint("AI hatası: $e");
      hata = "Error: Connection problem. Please check your internet.";
    }
    if (!guncel()) return;
    if (hata != null) {
      // Yanıt alınamadı: kullanıcı mesajını geçmişten çıkar; yoksa sıra (user/assistant) bozulur.
      if (_sohbetGecmisi.length > 1 && _sohbetGecmisi.last['role'] == 'user') _sohbetGecmisi.removeLast();
      _mesajEkle("AI", hata);
    }
    setState(() => _aiDusunuyor = false);
  }

  Future<void> _sesliOku(String metin) async {
    try {
      await _flutterTts.speak(metin);
    } catch (e) {
      debugPrint("Sesli okuma hatası: $e");
    }
  }

  @override
  void dispose() {
    // Ekrandan çıkınca sohbet saklanır; öğretmen konuşmaya ve mikrofon dinlemeye devam etmez.
    _acikSohbetiSakla();
    _sohbetNo++;
    _speechToText.cancel();
    _flutterTts.stop();
    _yazi.dispose();
    _yaziOdak.dispose();
    _sesDuzeyi.dispose();
    super.dispose();
  }

  // YAPAY ZEKA AYAR PANELİ (BOTTOM SHEET)
  void _aiAyarPaneliniGoster(ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final colorTitle = theme.textTheme.bodyLarge?.color ?? Colors.white;
          final colorTextSecondary = colorTitle.withValues(alpha: 0.6);
          final colorBg = theme.scaffoldBackgroundColor.withValues(alpha: 0.85);

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                padding: const EdgeInsets.all(25.0),
                decoration: BoxDecoration(color: colorBg, border: Border(top: BorderSide(color: theme.primaryColor.withValues(alpha: 0.2)))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: colorTitle.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    Text("AI Personality", style: GoogleFonts.poppins(color: colorTitle, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: _aiModlari.length,
                        itemBuilder: (context, index) {
                          String modId = _aiModlari.keys.elementAt(index);
                          var modData = _aiModlari[modId]!;
                          bool seciliMi = _seciliAiModu == modId;
                          return GestureDetector(
                            onTap: () { setModalState(() => _seciliAiModu = modId); _ayarlariKaydet("mod", modId); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), width: 100, margin: const EdgeInsets.only(right: 15),
                              decoration: BoxDecoration(color: seciliMi ? modData["renk"].withValues(alpha: isDark ? 0.2 : 0.1) : colorTitle.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: seciliMi ? modData["renk"] : Colors.transparent)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(modData["ikon"], color: seciliMi ? modData["renk"] : colorTextSecondary, size: 30),
                                  const SizedBox(height: 8),
                                  Text(modData["isim"], textAlign: TextAlign.center, style: GoogleFonts.poppins(color: seciliMi ? (isDark ? Colors.white : Colors.black) : colorTextSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text("AI Voice", style: GoogleFonts.poppins(color: colorTitle, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: _sesProfilleri.length,
                        itemBuilder: (context, index) {
                          String sesId = _sesProfilleri.keys.elementAt(index);
                          var sesData = _sesProfilleri[sesId]!;
                          bool seciliMi = _seciliSesProfili == sesId;
                          return GestureDetector(
                            onTap: () { setModalState(() => _seciliSesProfili = sesId); _ayarlariKaydet("ses", sesId); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), width: 100, margin: const EdgeInsets.only(right: 15),
                              decoration: BoxDecoration(color: seciliMi ? sesData["renk"].withValues(alpha: isDark ? 0.2 : 0.1) : colorTitle.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: seciliMi ? sesData["renk"] : Colors.transparent)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(sesData["ikon"], color: seciliMi ? sesData["renk"] : colorTextSecondary, size: 30),
                                  const SizedBox(height: 8),
                                  Text(sesData["isim"], textAlign: TextAlign.center, style: GoogleFonts.poppins(color: seciliMi ? (isDark ? Colors.white : Colors.black) : colorTextSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildDrawer(theme, isDark),
      // Sohbet açıkken Nova düğmesi gönder düğmesinin üstüne binmesin diye gizlenir.
      floatingActionButton: _konuSecimEkraninda ? AiCoachSystem.globalCoachButton(context, "SpeakingView") : null,
      body: _konuSecimEkraninda ? _buildVitrinEkrani(theme, isDark) : _buildSohbetEkrani(theme, isDark),
    );
  }

  Widget _buildVitrinEkrani(ThemeData theme, bool isDark) {
    final colorTitle = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) => IconButton(icon: Icon(Icons.menu_rounded, color: colorTitle, size: 30), onPressed: () => Scaffold.of(context).openDrawer()),
                ),
                Text("Discovery", style: GoogleFonts.poppins(color: colorTitle, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),

                GestureDetector(
                  onTap: () => _aiAyarPaneliniGoster(theme, isDark),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _aiModlari[_seciliAiModu]!["renk"].withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: _aiModlari[_seciliAiModu]!["renk"].withValues(alpha: 0.5))),
                    child: Icon(_aiModlari[_seciliAiModu]!["ikon"], color: _aiModlari[_seciliAiModu]!["renk"], size: 24),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(), itemCount: _kategoriHavuzu.length,
              itemBuilder: (context, index) {
                String kategori = _kategoriHavuzu.keys.elementAt(index);
                List<String> konular = _kategoriHavuzu[kategori]!;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 25.0), child: Text(kategori, style: GoogleFonts.poppins(color: colorTitle, fontSize: 18, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: konular.length,
                          itemBuilder: (context, i) {
                            String konu = konular[i];
                            final colorPrimary = index % 2 == 0 ? theme.primaryColor : (isDark ? Colors.tealAccent.shade400 : Colors.teal.shade600);
                            final colorSecondary = index % 2 == 0 ? theme.primaryColor.withValues(alpha: 0.6) : (isDark ? Colors.teal.shade300 : Colors.tealAccent.shade700);

                            return GestureDetector(
                              onTap: () => _konuyuSecVeBasla(kategori, konu),
                              child: Container(
                                width: 140, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colorPrimary, colorSecondary]),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [BoxShadow(color: colorPrimary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
                                  border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24)),
                                    const Spacer(),
                                    Text(konu, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSohbetEkrani(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 15, left: 10, right: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 5))]
          ),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color), onPressed: () { setState(() => _konuSecimEkraninda = true); _flutterTts.stop(); }),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Topic:", style: GoogleFonts.poppins(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)), Text(_seciliKonu, style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)])),

              PopupMenuButton<String>(
                icon: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Text(_seciliSeviye, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                color: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), offset: const Offset(0, 50),
                onSelected: (yeni) { setState(() => _seciliSeviye = yeni); _yeniSohbetBaslat(); },
                itemBuilder: (context) => _seviyeler.map((s) => PopupMenuItem<String>(value: s, child: Text("Level $s", style: TextStyle(color: s == _seciliSeviye ? theme.primaryColor : theme.textTheme.bodyLarge?.color)))).toList(),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20), itemCount: _mesajlar.length,
            itemBuilder: (context, index) {
              final mesaj = _mesajlar[index];
              final isSen = mesaj["gonderen"] == "Sen";
              return Align(
                alignment: isSen ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: EdgeInsets.only(bottom: 20, left: isSen ? 50 : 0, right: isSen ? 0 : 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    gradient: isSen ? LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)]) : null,
                    color: isSen ? null : theme.cardColor,
                    boxShadow: [BoxShadow(color: isSen ? theme.primaryColor.withValues(alpha: 0.3) : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(25), topRight: const Radius.circular(25), bottomLeft: Radius.circular(isSen ? 25 : 5), bottomRight: Radius.circular(isSen ? 5 : 25)),
                    border: isSen ? null : Border.all(color: theme.dividerColor.withValues(alpha: isDark ? 0.1 : 0.4), width: 1)
                  ),
                  child: Column(
                    crossAxisAlignment: isSen ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(mesaj["metin"]!, style: GoogleFonts.poppins(color: isSen ? Colors.white : theme.textTheme.bodyLarge?.color, fontSize: 15)),
                      if (!isSen) ...[
                        const SizedBox(height: 12),
                        GestureDetector(onTap: () => _ceviriYap(index, mesaj["metin"]!), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.g_translate_rounded, color: theme.primaryColor, size: 14), const SizedBox(width: 5), Text("Translate", style: GoogleFonts.poppins(color: theme.primaryColor, fontSize: 12))]))),
                        if (mesaj["ceviriGoster"] == "yukleniyor") Padding(padding: const EdgeInsets.only(top: 10.0), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2))),
                        if (mesaj["ceviriGoster"] == "true" && mesaj["ceviri"] != null) Padding(padding: const EdgeInsets.only(top: 10.0), child: Text(mesaj["ceviri"]!, style: GoogleFonts.poppins(color: isDark ? Colors.greenAccent : Colors.green.shade700, fontSize: 14, fontStyle: FontStyle.italic))),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_aiDusunuyor) Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator(color: theme.primaryColor)),

        _buildYaziCubugu(theme, isDark),
      ],
    );
  }

  // YAZI + SES ÇUBUĞU: söylenen yazı kutusuna düşer; kutuya elle de yazılabilir.
  Widget _buildYaziCubugu(ThemeData theme, bool isDark) {
    final Color yaziRengi = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final Color dinlemeRengi = isDark ? Colors.greenAccent : Colors.green.shade700;

    Widget kucukDugme({required IconData ikon, required String ipucu, required VoidCallback onTap, Color? renk, bool dolu = false}) {
      return Tooltip(
        message: ipucu,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: (renk ?? yaziRengi).withValues(alpha: dolu ? 0.2 : 0.06), shape: BoxShape.circle),
            child: Icon(ikon, color: renk ?? yaziRengi.withValues(alpha: 0.6), size: 22),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12, top: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: isDark ? 0.95 : 1.0),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1), blurRadius: 25, offset: const Offset(0, 10))],
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _isListening ? dinlemeRengi.withValues(alpha: 0.7) : Colors.white.withValues(alpha: isDark ? 0.05 : 0.5), width: _isListening ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isListening)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      _SesDalgasi(duzey: _sesDuzeyi, renk: dinlemeRengi),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Listening… take your time. Tap ■ when you finish.", style: GoogleFonts.poppins(color: dinlemeRengi, fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              TextField(
                controller: _yazi,
                focusNode: _yaziOdak,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.poppins(color: yaziRengi, fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: _isListening ? "Speak now…" : "Tap the mic and speak, or type here",
                  hintStyle: GoogleFonts.poppins(color: yaziRengi.withValues(alpha: 0.4), fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  kucukDugme(ikon: Icons.refresh_rounded, ipucu: "Yeni sohbet", onTap: _yeniSohbetBaslat),
                  const SizedBox(width: 8),
                  _ipucuBekleniyor
                      ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)))
                      : kucukDugme(ikon: Icons.lightbulb_rounded, ipucu: "Ne diyebilirim?", onTap: _ipucuIste, renk: Colors.amber, dolu: true),
                  const SizedBox(width: 8),
                  kucukDugme(
                    ikon: _otomatikGonder ? Icons.bolt_rounded : Icons.edit_note_rounded,
                    ipucu: _otomatikGonder ? "Otomatik gönder açık" : "Otomatik gönder kapalı",
                    onTap: _otomatikGonderiDegistir,
                    renk: _otomatikGonder ? theme.primaryColor : null,
                    dolu: _otomatikGonder,
                  ),
                  const Spacer(),
                  // Kutuda yazı varsa gönder düğmesi görünür.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _yazi,
                    builder: (context, deger, _) {
                      if (deger.text.trim().isEmpty || _aiDusunuyor) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Semantics(
                          button: true,
                          label: "Gönder",
                          child: InkResponse(
                            onTap: _yazilaniGonder,
                            radius: 28,
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: theme.primaryColor.withValues(alpha: 0.6))),
                              child: Icon(Icons.send_rounded, color: theme.primaryColor, size: 22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Semantics(
                    button: true,
                    label: _isListening ? "Dinlemeyi bitir" : "Konuşmaya başla",
                    child: GestureDetector(
                      onTap: _mikrofonuTetikle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _isListening ? 64 : 58, height: _isListening ? 64 : 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _isListening ? (isDark ? [Colors.greenAccent.shade400, Colors.tealAccent.shade400] : [Colors.green.shade500, Colors.teal.shade500]) : [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)]),
                          shape: BoxShape.circle,
                          boxShadow: [if (_isListening) BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4) else BoxShadow(color: theme.primaryColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(ThemeData theme, bool isDark) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(20.0), child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); setState(() => _konuSecimEkraninda = true); }, icon: const Icon(Icons.dashboard_customize_rounded, color: Colors.white), label: const Text("Topic Library", style: TextStyle(color: Colors.white, fontSize: 16)), style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
            Divider(color: theme.dividerColor),
            Expanded(child: _kayitliSohbetler.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.2), size: 60), const SizedBox(height: 10), Text("No past conversations", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)))])) : ListView.builder(itemCount: _kayitliSohbetler.length, itemBuilder: (context, index) { return ListTile(leading: Icon(Icons.chat_bubble_outline_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.7)), title: Text(_kayitliSohbetler[index].konu.isNotEmpty ? _kayitliSohbetler[index].konu : "Saved Conversation ${index + 1}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)), subtitle: Text("${_kayitliSohbetler[index].mesajlar.length} messages", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5), fontSize: 12)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _sohbetiSil(index)), onTap: () => _eskiSohbetiYukle(index)); })),
          ],
        ),
      ),
    );
  }
}

/// Mikrofonun duyduğu sese göre oynayan küçük dalga göstergesi.
class _SesDalgasi extends StatelessWidget {
  const _SesDalgasi({required this.duzey, required this.renk});

  final ValueListenable<double> duzey;
  final Color renk;

  static const List<double> _agirliklar = [0.5, 0.85, 1.0, 0.7, 0.45];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ValueListenableBuilder<double>(
        valueListenable: duzey,
        builder: (context, deger, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final agirlik in _agirliklar)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 5 + 17 * deger * agirlik,
                decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      ),
    );
  }
}
