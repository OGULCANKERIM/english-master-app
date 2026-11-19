import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/claude_servisi.dart';
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
  String _kullaniciMetni = "";

  final List<Map<String, String>> _mesajlar = [];
  bool _aiDusunuyor = false;
  bool _ipucuBekleniyor = false;
  bool _konuSecimEkraninda = true;

  // Claude'a her istekte gönderilen sohbet geçmişi (user / assistant sırayla, düz metin).
  final List<Map<String, dynamic>> _sohbetGecmisi = [];
  // Açık sohbetin sistem metni (karakter + seviye + konu); sohbet başlarken belirlenir.
  String _aktifSistem = "";
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
    final prefs = await SharedPreferences.getInstance();

    final String kayitliSeviye = await mevcutSeviye();
    if (_seviyeler.contains(kayitliSeviye)) _seciliSeviye = kayitliSeviye;

    String? kayitliMod = prefs.getString('aiMode');
    if (kayitliMod != null && _aiModlari.containsKey(kayitliMod)) _seciliAiModu = kayitliMod;

    String? kayitliSes = prefs.getString('aiVoice');
    if (kayitliSes != null && _sesProfilleri.containsKey(kayitliSes)) _seciliSesProfili = kayitliSes;

    _sohbetleriYukle(prefs);
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
    _kayitliSohbetler
      ..clear()
      ..addAll(kayitliSohbetleriCoz(prefs.getString(_kayitAnahtari)));
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
    if (_mesajlar.length <= 1 || !gecmisGecerli(_sohbetGecmisi)) return;
    _kayitliSohbetler.add(KayitliSohbet(
      sistem: _aktifSistem,
      // Çeviri durumu gibi geçici alanlar saklanmaz.
      mesajlar: _mesajlar.map((m) => {"gonderen": m["gonderen"] ?? "", "metin": m["metin"] ?? "", "ceviriGoster": "false"}).toList(),
      gecmis: _sohbetGecmisi.map((m) => Map<String, dynamic>.from(m)).toList(),
    ));
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

    setState(() {
      _mesajlar.clear();
      _sohbetGecmisi.clear();
      _kullaniciMetni = "";
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
    setState(() {
      _konuSecimEkraninda = false;
      _seciliKonu = "Saved Conversation ${index + 1}";
      _aiDusunuyor = false;
      _kullaniciMetni = "";
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

  // Mikrofona dokunma: dinlemiyorsa başlatır, dinliyorsa durdurup gönderir.
  Future<void> _mikrofonuTetikle() async {
    if (_aiDusunuyor) return;
    if (_isListening) {
      await _dinlemeyiBitir();
      return;
    }

    try {
      // Motor yalnızca bir kez kurulur; her dokunuşta yeniden kurmak çift tetiklemeye yol açar.
      if (!_speechHazir) {
        _speechHazir = await _speechToText.initialize(
          onStatus: (status) {
            // Kullanıcı susarsa otomatik olarak gönder.
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
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint("Mikrofon başlatılamadı: $e");
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mikrofon başlatılamadı.")));
      }
    }
  }

  // Hem "durdur" dokunuşu hem de motorun 'done' bildirimi buraya gelir;
  // _isListening bayrağı sayesinde mesaj yalnızca BİR kez gönderilir.
  Future<void> _dinlemeyiBitir() async {
    if (!_isListening) return;
    _isListening = false;
    final mesaj = _kullaniciMetni;
    if (mounted) setState(() {});
    try { await _speechToText.stop(); } catch (e) { debugPrint("Dinleme durdurulamadı: $e"); }
    await _yapayZekayaGonder(mesaj);
  }

  // Dinlemeyi, söyleneni göndermeden keser (yeni sohbete geçerken).
  void _dinlemeyiIptalEt() {
    if (!_isListening) return;
    _isListening = false;
    _speechToText.cancel().catchError((Object e) { debugPrint("Dinleme iptal edilemedi: $e"); });
  }

  Future<void> _yapayZekayaGonder(String mesaj) async {
    if (mesaj.trim().isEmpty || _aiDusunuyor || !mounted) {
      if (mounted) setState(() => _kullaniciMetni = "");
      return;
    }

    _mesajEkle("Sen", mesaj.trim());
    setState(() {
      _kullaniciMetni = "";
      _aiDusunuyor = true;
    });

    // Yanıt gelene kadar kullanıcı başka sohbete geçerse bu yanıt o sohbete yazılmaz.
    final List<Map<String, String>> buSohbet = _mesajlar;
    final int sohbetBoyu = _mesajlar.length;
    _sohbetGecmisi.add({"role": "user", "content": mesaj.trim()});
    bool basarili = false;
    try {
      final yanit = await ClaudeServisi.varsayilan.gonder(sistem: _aktifSistem, mesajlar: List.of(_sohbetGecmisi));
      if (!mounted || !identical(buSohbet, _mesajlar) || _mesajlar.length != sohbetBoyu) return;
      _sohbetGecmisi.add({"role": "assistant", "content": yanit.metin});
      basarili = true;
      _mesajEkle("AI", yanit.metin);
      _sesliOku(yanit.metin);
    } on ClaudeHatasi catch (e) {
      if (mounted && _mesajlar.length == sohbetBoyu) _mesajEkle("AI", e.kullaniciMesaji);
    } catch (e) {
      debugPrint("AI hatası: $e");
      if (mounted && _mesajlar.length == sohbetBoyu) _mesajEkle("AI", "Error: Connection problem. Please check your internet.");
    } finally {
      // Yanıt alınamadıysa kullanıcı mesajını geçmişten çıkar; yoksa sıra (user/assistant) bozulur.
      if (!basarili && _sohbetGecmisi.isNotEmpty && _sohbetGecmisi.last['role'] == 'user' && _sohbetGecmisi.length > 1) _sohbetGecmisi.removeLast();
      if (mounted) setState(() => _aiDusunuyor = false);
    }
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
    _speechToText.cancel();
    _flutterTts.stop();
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
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "SpeakingView"),
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
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100), itemCount: _mesajlar.length,
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

        // YÜZEN AKSİYON ÇUBUĞU (FLOATING PILL)
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: isDark ? 0.95 : 1.0),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1), blurRadius: 25, offset: const Offset(0, 10))],
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.5), width: 1)
            ),
            child: Column(
              children: [
                Text(_isListening ? "Listening... (Tap to stop)" : "Tap to speak!", style: GoogleFonts.poppins(color: _isListening ? (isDark ? Colors.greenAccent : Colors.green.shade700) : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                if (_kullaniciMetni.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_kullaniciMetni, style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8), fontStyle: FontStyle.italic, fontSize: 15), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(onTap: _yeniSohbetBaslat, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.05), shape: BoxShape.circle), child: Icon(Icons.refresh_rounded, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6), size: 24))),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _mikrofonuTetikle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.all(_isListening ? 25 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _isListening ? (isDark ? [Colors.greenAccent.shade400, Colors.tealAccent.shade400] : [Colors.green.shade500, Colors.teal.shade500]) : [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)]),
                          shape: BoxShape.circle,
                          boxShadow: [if (_isListening) BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.6), blurRadius: 25, spreadRadius: 10) else BoxShadow(color: theme.primaryColor.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))]
                        ),
                        child: Icon(_isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: Colors.white, size: _isListening ? 35 : 30)
                      )
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(onTap: _ipucuIste, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle), child: _ipucuBekleniyor ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)) : const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24))),
                  ],
                ),
              ],
            ),
          ),
        )
      ],
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
            Expanded(child: _kayitliSohbetler.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.2), size: 60), const SizedBox(height: 10), Text("No past conversations", style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)))])) : ListView.builder(itemCount: _kayitliSohbetler.length, itemBuilder: (context, index) { return ListTile(leading: Icon(Icons.chat_bubble_outline_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.7)), title: Text("Saved Conversation ${index + 1}", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _sohbetiSil(index)), onTap: () => _eskiSohbetiYukle(index)); })),
          ],
        ),
      ),
    );
  }
}