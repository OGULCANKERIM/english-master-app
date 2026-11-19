import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/claude_servisi.dart';
import '../core/globals.dart';
import '../core/seviye.dart';
import '../services/ai_coach_system.dart';

/// Claude'un telaffuz değerlendirmesini güvenli şekilde okur: puan 0-100 arasına çekilir,
/// eksik ya da beklenmeyen türde alanlar çökme yapmaz.
({int skor, String geribildirim}) okumaDegerlendirmesiniCoz(Map<String, dynamic> veri) {
  final dynamic ham = veri['skor'];
  final num sayi = ham is num ? ham : (num.tryParse((ham ?? '').toString().trim()) ?? 0);
  final int skor = sayi.isFinite ? sayi.round().clamp(0, 100) : 0;
  return (skor: skor, geribildirim: (veri['geribildirim'] ?? '').toString().trim());
}

/// Metni cümlelere böler (. ! ? sonrasındaki boşluklardan).
List<String> cumlelereBol(String metin) {
  return metin.trim().split(RegExp(r'(?<=[.!?])\s+')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
}

// ==========================================
// YAPAY ZEKA DESTEKLİ OKUMA (READING) EKRANI (TOK VE YUMUŞAK ERKEK SESİ)
// ==========================================
class OkumaPratigiEkrani extends StatefulWidget {
  const OkumaPratigiEkrani({super.key});

  @override
  State<OkumaPratigiEkrani> createState() => _OkumaPratigiEkraniState();
}

class _OkumaPratigiEkraniState extends State<OkumaPratigiEkrani> {
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speechToText;

  final List<String> _seviyeler = ["A1", "A2", "B1", "B2", "C1", "C2"];
  String _seciliSeviye = "A2";

  String _okumaMetni = "";
  List<String> _cumleler = [];

  bool _metinYukleniyor = false;
  int? _aktifOkumaIndex;
  int? _aktifDinlemeIndex;
  bool _isSpeaking = false;

  bool _sttHazirMi = false;
  int _metinIstegi = 0; // en son başlatılan metin isteği; eskiler yok sayılır

  final Map<int, Map<String, dynamic>> _kullaniciVerileri = {};

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _speechToText = stt.SpeechToText();
    _sistemleriHazirla();
    _seviyeyiCekVeBasla();
  }

  Future<void> _seviyeyiCekVeBasla() async {
    final String seviye = await mevcutSeviye();
    if (!mounted) return;
    if (_seviyeler.contains(seviye)) setState(() => _seciliSeviye = seviye);
    _yeniMetinUret();
  }

  Future<void> _sistemleriHazirla() async {
    // 1. TTS (SESLİ OKUMA) KURULUMU - KALIN VE SOFT AYARI
    try {
      final ayar = await ttsAyarlariniOku();
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(ayar.hiz * 0.8); // okuma için biraz daha sakin
      await _flutterTts.setPitch(ayar.perde);
    } catch (e) { debugPrint("TTS ayar hatası: $e"); }

    try {
      var rawVoices = await _flutterTts.getVoices;
      if (rawVoices != null) {
        List<dynamic> sesler = rawVoices;
        Map<dynamic, dynamic>? erkekSesi;

        for (var ses in sesler) {
          if (ses["locale"] != null && ses["locale"].toString().startsWith("en-US")) {
            String sesIsmi = ses["name"].toString().toLowerCase();

            // YENİ: Yüksek kaliteli (network) erkek seslerini önceliklendir
            if (sesIsmi.contains("network-male") ||
                sesIsmi.contains("male") ||
                sesIsmi.contains("alex") ||
                sesIsmi.contains("fred") ||
                sesIsmi.contains("iom") ||
                sesIsmi.contains("tpm") ||
                sesIsmi.contains("jtv")) {
              erkekSesi = ses;
              break;
            }
          }
        }

        if (erkekSesi != null) {
          await _flutterTts.setVoice({"name": erkekSesi["name"], "locale": erkekSesi["locale"]});
        } else {
           var herhangiBir = sesler.firstWhere((v) => v is Map && v["locale"].toString().startsWith("en-US"), orElse: () => null);
           if (herhangiBir != null) {
             await _flutterTts.setVoice({"name": herhangiBir["name"], "locale": herhangiBir["locale"]});
           }
        }
      }
    } catch (e) { debugPrint("Ses arama hatası: $e"); }

    _flutterTts.setStartHandler(() { if (mounted) setState(() => _isSpeaking = true); });
    _flutterTts.setCompletionHandler(() { if (mounted) setState(() { _isSpeaking = false; _aktifOkumaIndex = null; }); });
    _flutterTts.setCancelHandler(() { if (mounted) setState(() { _isSpeaking = false; _aktifOkumaIndex = null; }); });

    // 2. STT (MİKROFON) KURULUMU
    try {
      _sttHazirMi = await _speechToText.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _aktifDinlemeIndex != null) {
            int indexKopya = _aktifDinlemeIndex!;
            String okunan = (_kullaniciVerileri[indexKopya]?['okuma'] ?? "").toString();

            if (mounted) setState(() => _aktifDinlemeIndex = null);

            if (okunan.isNotEmpty && okunan != "Listening...") {
              _okumayiDegerlendir(indexKopya);
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Mikrofon Hatası: $errorNotification");
          if (mounted) setState(() => _aktifDinlemeIndex = null);
        },
      );
    } catch (e) {
      debugPrint("STT Başlatılamadı: $e");
    }
  }

  Future<void> _yeniMetinUret() async {
    final int istek = ++_metinIstegi;
    try { await _flutterTts.stop(); } catch (_) {}
    try { await _speechToText.stop(); } catch (_) {}
    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _aktifOkumaIndex = null;
      _metinYukleniyor = true;
      _kullaniciVerileri.clear();
      _cumleler = [];
      _aktifDinlemeIndex = null;
      _okumaMetni = "Generating a fresh text for $_seciliSeviye level...";
    });

    String yeniMetin;
    List<String> yeniCumleler = [];
    try {
      final String gelenMetin = await ClaudeServisi.varsayilan.sor(
        sistem: "You write short reading passages for English learners. Reply with the passage only: no title, no explanations, no markdown.",
        istem: "Write a short, interesting reading passage (about 40-50 words) in English. The vocabulary and grammar MUST be strictly at the $_seciliSeviye level. Only give me the text, no titles, no explanations.",
        maxTokens: 600,
      );
      yeniMetin = gelenMetin;
      yeniCumleler = cumlelereBol(gelenMetin);
    } on ClaudeHatasi catch (e) {
      yeniMetin = e.kullaniciMesaji;
    } catch (e) {
      debugPrint("Okuma metni üretilemedi: $e");
      yeniMetin = "Connection error.";
    }

    // Bu arada yeni bir istek başladıysa (seviye değişti vb.) eski sonucu gösterme.
    if (!mounted || istek != _metinIstegi) return;
    setState(() {
      _okumaMetni = yeniMetin;
      _cumleler = yeniCumleler;
      _metinYukleniyor = false;
    });
  }

  Future<void> _metniSesliDinle(int index) async {
    if (_aktifDinlemeIndex != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sen konuşurken öğretmeni dinleyemezsin!"), backgroundColor: Colors.redAccent));
      return;
    }

    if (_aktifOkumaIndex != null) {
      await _flutterTts.stop();
      int? oncekiIndex = _aktifOkumaIndex;
      setState(() { _isSpeaking = false; _aktifOkumaIndex = null; });
      if (oncekiIndex == index) return;
    }

    setState(() => _aktifOkumaIndex = index);
    if (index != -1 && index >= _cumleler.length) return;
    String okunacakMetin = index == -1 ? _okumaMetni : _cumleler[index];
    try { await _flutterTts.speak(okunacakMetin); } catch (e) { debugPrint("Okuma hatası: $e"); }
  }

  void _mikrofonuTetikle(int index) async {
    if (!_sttHazirMi) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mikrofon başlatılamadı. İzinleri kontrol edin."), backgroundColor: Colors.redAccent));
      return;
    }

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_aktifDinlemeIndex == index) {
      await _speechToText.stop();
      return;
    }

    if (_aktifDinlemeIndex != null) {
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _aktifDinlemeIndex = index;
      _kullaniciVerileri[index] = {
        'okuma': 'Listening...',
        'degerlendiriliyor': false,
        'geribildirim': '',
        'skor': 0
      };
    });

    try {
      await _speechToText.listen(
      onResult: (result) {
        if (mounted && _kullaniciVerileri[index] != null) setState(() { _kullaniciVerileri[index]!['okuma'] = result.recognizedWords; });
      },
      localeId: "en_US",
      pauseFor: const Duration(seconds: 4),
      listenFor: const Duration(seconds: 60),
      listenOptions: stt.SpeechListenOptions(cancelOnError: true, partialResults: true),
      );
    } catch (e) {
      debugPrint("Mikrofon dinleyemedi: $e");
      if (mounted) setState(() => _aktifDinlemeIndex = null);
    }
  }

  void _cumleyiSifirla(int index) {
    setState(() {
      _kullaniciVerileri.remove(index);
      if (_aktifDinlemeIndex == index) {
        _speechToText.stop();
        _aktifDinlemeIndex = null;
      }
    });
  }

  Future<void> _okumayiDegerlendir(int index) async {
    final Map<String, dynamic>? kayit = _kullaniciVerileri[index];
    if (kayit == null || !mounted) return;
    if (index != -1 && index >= _cumleler.length) return;
    setState(() => kayit['degerlendiriliyor'] = true);

    final String hedefMetin = index == -1 ? _okumaMetni : _cumleler[index];
    final String kullaniciOkumasi = (kayit['okuma'] ?? '').toString();

    String geriBildirim;
    int skor = 0;
    bool basarili = false;
    try {
      final Map<String, dynamic> yanit = await ClaudeServisi.varsayilan.jsonIste(
        sistem: "You are an encouraging English pronunciation teacher. You compare what a student read aloud (speech-to-text output) with the original text.",
        istem: """
I am an English student at $_seciliSeviye level.
The original text: "$hedefMetin"
What I said: "$kullaniciOkumasi"

Compare what I said with the original text.
Give me a score out of 100 and a short feedback (1-2 sentences) in English explaining my mispronounced or skipped words. Be encouraging!
Reply only with JSON: {"skor": 0-100, "geribildirim": "..."}
""",
      );
      final sonuc = okumaDegerlendirmesiniCoz(yanit);
      skor = sonuc.skor;
      geriBildirim = sonuc.geribildirim.isEmpty ? "Could not get feedback." : sonuc.geribildirim;
      basarili = sonuc.geribildirim.isNotEmpty;
    } on ClaudeHatasi catch (e) {
      geriBildirim = e.kullaniciMesaji;
    } catch (e) {
      debugPrint("Okuma değerlendirilemedi: $e");
      geriBildirim = "Connection problem.";
    }

    // Kart bu arada sıfırlandıysa ya da metin değiştiyse sonucu yazma.
    if (!mounted || !identical(_kullaniciVerileri[index], kayit)) return;
    setState(() {
      kayit['skor'] = skor;
      kayit['geribildirim'] = geriBildirim;
      kayit['degerlendiriliyor'] = false;
    });
    if (basarili) {
      try { await _flutterTts.speak(geriBildirim); } catch (e) { debugPrint("Okuma hatası: $e"); }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  Widget _pratikKartiOlustur(String metin, int index, String baslik) {
    bool isOkunuyor = _aktifOkumaIndex == index;
    bool isDinleniyor = _aktifDinlemeIndex == index;

    Map<String, dynamic>? veri = _kullaniciVerileri[index];
    bool veriVar = veri != null;
    bool degerlendiriliyor = veriVar && veri['degerlendiriliyor'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: index == -1 ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOkunuyor ? Colors.blueAccent : (isDinleniyor ? Colors.greenAccent : Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index == -1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(baslik, style: GoogleFonts.poppins(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ),

          Text(
            metin,
            style: GoogleFonts.lora(color: Colors.white, fontSize: index == -1 ? 18 : 20, height: 1.5, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (veriVar && !isDinleniyor)
                GestureDetector(
                  onTap: () => _cumleyiSifirla(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 24),
                  ),
                ),

              GestureDetector(
                onTap: () => _metniSesliDinle(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOkunuyor ? Colors.redAccent.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle
                  ),
                  child: Icon(isOkunuyor ? Icons.stop_rounded : Icons.volume_up_rounded, color: isOkunuyor ? Colors.redAccent : Colors.blueAccent, size: 24),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () => _mikrofonuTetikle(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDinleniyor ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.deepOrangeAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle
                  ),
                  child: Icon(isDinleniyor ? Icons.stop_rounded : Icons.mic_rounded, color: isDinleniyor ? Colors.greenAccent : Colors.deepOrangeAccent, size: 24),
                ),
              ),
            ],
          ),

          if (veriVar) ...[
            const Divider(color: Colors.white24, height: 30),
            Text("You said:", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 5),
            Text("\"${veri['okuma']}\"", style: GoogleFonts.poppins(color: isDinleniyor ? Colors.greenAccent : Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
            const SizedBox(height: 15),

            if (degerlendiriliyor)
              const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            else if (veri['geribildirim'].toString().isNotEmpty) ...[

              if (veri['skor'] > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pronunciation Score", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                    Text("${veri['skor']}%", style: GoogleFonts.poppins(color: _getSkorRengi(veri['skor']), fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: veri['skor'] / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_getSkorRengi(veri['skor'])),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 5),
                        Text("Teacher's Note", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(veri['geribildirim'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              )
            ]
          ]
        ],
      ),
    );
  }

  Color _getSkorRengi(int skor) {
    if (skor >= 85) return Colors.greenAccent;
    if (skor >= 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "ReadingView"),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF13131F), Color(0xFF1E1E2C), Color(0xFF2A2A3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Text("Reading Practice", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.deepOrangeAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Text(_seciliSeviye, style: const TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      color: const Color(0xFF2A2A3D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      offset: const Offset(0, 50),
                      onSelected: (seviye) {
                        setState(() => _seciliSeviye = seviye);
                        _yeniMetinUret();
                      },
                      itemBuilder: (context) => _seviyeler.map((s) => PopupMenuItem<String>(
                        value: s,
                        child: Text("Level $s", style: TextStyle(color: s == _seciliSeviye ? Colors.deepOrangeAccent : Colors.white)),
                      )).toList(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _metinYukleniyor
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (_okumaMetni.isNotEmpty)
                          _pratikKartiOlustur(_okumaMetni, -1, "FULL PASSAGE"),

                        if (_cumleler.length > 1) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text("SENTENCE BY SENTENCE", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                          ),

                          ..._cumleler.asMap().entries.map((entry) {
                            return _pratikKartiOlustur(entry.value, entry.key, "");
                          }),
                        ]
                      ],
                    ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _yeniMetinUret,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Generate New Text"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}