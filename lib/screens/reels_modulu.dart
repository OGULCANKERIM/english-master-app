import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../core/globals.dart';
import '../core/video_onbellek.dart';

/// Bir reels videosunun ekranda görünen adı. Tabloda (ya da favoride) `baslik` gibi bir ad
/// varsa o kullanılır; yoksa ad video dosyasından türetilir ("17.mp4" -> "Reel 17").
/// Böylece aynı video her yerde aynı adla görünür.
String reelBasligi(dynamic sahne) {
  for (final anahtar in const ['baslik', 'title', 'kaynak', 'ad', 'name']) {
    final String deger = alan(sahne, anahtar);
    if (deger.isNotEmpty) return deger;
  }
  final String son = urlSonParcasi(alan(sahne, 'videoUrl'));
  String ad = son;
  try {
    ad = Uri.decodeComponent(son);
  } catch (_) {
    // Bozuk kodlanmış ad olduğu gibi kullanılır.
  }
  ad = ad.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '').replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (ad.isEmpty) return 'Reel';
  return int.tryParse(ad) != null ? 'Reel $ad' : ad;
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
  Future<void> _adiDegistir(Map<String, dynamic> sahne) async {
    final denetleyici = TextEditingController(text: reelBasligi(sahne));
    final String? yeniAd = await showDialog<String>(
      context: context,
      builder: (diyalog) => AlertDialog(
        title: const Text("Videoya ad ver"),
        content: TextField(
          controller: denetleyici,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: "Örn. Friends – kahve sahnesi"),
          onSubmitted: (deger) => Navigator.of(diyalog).pop(deger),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(diyalog).pop(), child: const Text("Vazgeç")),
          TextButton(onPressed: () => Navigator.of(diyalog).pop(denetleyici.text), child: const Text("Kaydet")),
        ],
      ),
    );
    denetleyici.dispose();
    if (yeniAd == null || !mounted) return;
    setState(() {
      // Boş bırakılırsa ad yeniden video dosyasından türetilir.
      if (yeniAd.trim().isEmpty) {
        sahne.remove('baslik');
      } else {
        sahne['baslik'] = yeniAd.trim();
      }
    });
    await favorileriKaydet();
  }

  void _sil(Map<String, dynamic> sahne) {
    setState(() => globalFavoriSahneler.remove(sahne));
    favorileriKaydet();
  }

  Future<void> _oynat(int index) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani(ozelListe: List.of(globalFavoriSahneler), baslangicIndex: index)));
    // Oynatıcıda favoriden çıkarılmış olabilir.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Text("Favorite Reels", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: globalFavoriSahneler.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.heart_broken_rounded, size: 80, color: Colors.pinkAccent),
                ),
                const SizedBox(height: 20),
                Text("No favorites yet.", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                const Text("Double tap videos to save them here!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white54))
              ]
            )
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            itemCount: globalFavoriSahneler.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final sahne = globalFavoriSahneler[index];
              final String url = alan(sahne, "videoUrl");
              return Container(
                key: ValueKey(url),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  // Videonun ilk karesi: ad ile içerik birbirine karışmasın.
                  leading: _ReelOnizleme(url: url),
                  title: Text(reelBasligi(sahne), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("Tap to watch", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Adını değiştir",
                        icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 22),
                        onPressed: () => _adiDegistir(sahne),
                      ),
                      IconButton(
                        tooltip: "Favorilerden çıkar",
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
                        onPressed: () => _sil(sahne),
                      ),
                    ],
                  ),
                  onTap: () => _oynat(index),
                ),
              );
            }
          ),
    );
  }
}

/// Favori listesindeki küçük video önizlemesi (ilk kare, sessiz, oynatılmaz).
class _ReelOnizleme extends StatefulWidget {
  const _ReelOnizleme({required this.url});

  final String url;

  @override
  State<_ReelOnizleme> createState() => _ReelOnizlemeState();
}

class _ReelOnizlemeState extends State<_ReelOnizleme> {
  VideoPlayerController? _controller;
  bool _hazir = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final Uri? adres = Uri.tryParse(widget.url);
    if (adres == null || !adres.hasScheme) return;
    try {
      final dosya = await VideoOnbellek.hazirDosya(widget.url);
      if (!mounted) return;
      final controller = dosya != null ? VideoPlayerController.file(dosya) : VideoPlayerController.networkUrl(adres);
      _controller = controller;
      await controller.setVolume(0);
      await controller.initialize();
      if (mounted) setState(() => _hazir = true);
    } catch (e) {
      debugPrint("Önizleme açılamadı: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.pinkAccent.withValues(alpha: 0.2)),
            if (_hazir && controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)),
              ),
            const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black87, blurRadius: 8)])),
          ],
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
  final Map<int, VideoPlayerController> _controllers = {};
  // Oynatıcısı şu an kurulmakta olan videolar (aynı video iki kez kurulmasın).
  final Set<int> _kuruluyor = {};
  // Açılamayan videolar; ekranda "tekrar dene" gösterilir.
  final Set<int> _hatali = {};
  bool _kapandi = false;

  @override
  void initState() {
    super.initState();
    unawaited(VideoOnbellek.temizle());
    if (widget.ozelListe != null) {
      _sahneler = widget.ozelListe!;
      _suankiIndex = widget.baslangicIndex;
      _pageController = PageController(initialPage: _suankiIndex);
      _isLoading = false;
      _videolariHazirla();
    } else {
      _suankiIndex = 0;
      _pageController = PageController(initialPage: 0);
      _videolariGetir();
    }
  }

  String _url(int i) => alan(_sahneler[i], "videoUrl");

  /// Ekrandaki ve bir sonraki videonun oynatıcısını hazırlar, uzaktakileri kapatır.
  ///
  /// Aynı anda en fazla üç oynatıcı açık kalır (önceki, şimdiki, sonraki). Daha fazlası
  /// telefonun video çözücülerini ve interneti paylaştırıp oynatmayı takılmalı hâle getirir.
  void _videolariHazirla() {
    final int hedef = _suankiIndex;
    for (final int k in _controllers.keys.where((k) => (k - hedef).abs() > 1).toList()) {
      _controllers.remove(k)?.dispose();
    }
    _oynaticiKur(hedef);
    _siradakileriIndir(hedef);
  }

  /// Sıradaki iki videoyu telefona indirir; inen video dosyadan, yani takılmadan oynar.
  Future<void> _siradakileriIndir(int hedef) async {
    for (final int i in [hedef + 1, hedef + 2]) {
      if (_kapandi || hedef != _suankiIndex) return;
      if (i < 0 || i >= _sahneler.length) continue;
      if (!kIsWeb) await VideoOnbellek.indir(_url(i));
      if (_kapandi || hedef != _suankiIndex) return;
      if (i == hedef + 1) await _oynaticiKur(i);
    }
  }

  Future<void> _oynaticiKur(int i) async {
    if (i < 0 || i >= _sahneler.length || _controllers.containsKey(i) || _kuruluyor.contains(i)) return;
    final Uri? adres = Uri.tryParse(_url(i));
    if (adres == null || !adres.hasScheme) {
      if (mounted) setState(() => _hatali.add(i));
      return;
    }
    _kuruluyor.add(i);
    VideoPlayerController? controller;
    try {
      final dosya = await VideoOnbellek.hazirDosya(_url(i));
      // Beklerken ekran kapandıysa ya da kullanıcı uzaklaştıysa oynatıcı açılmaz.
      if (_kapandi || (i - _suankiIndex).abs() > 1) return;
      controller = dosya != null ? VideoPlayerController.file(dosya) : VideoPlayerController.networkUrl(adres);
      _controllers[i] = controller;
      _hatali.remove(i);
      if (mounted) setState(() {});
      await controller.initialize();
    } catch (e) {
      debugPrint("Video açılamadı: $e");
      if (controller != null && identical(_controllers[i], controller)) {
        _controllers.remove(i);
        controller.dispose();
      }
      _hatali.add(i);
    } finally {
      _kuruluyor.remove(i);
      if (mounted) setState(() {});
    }
  }

  void _tekrarDene(int i) {
    _controllers.remove(i)?.dispose();
    setState(() => _hatali.remove(i));
    _oynaticiKur(i);
  }

  Future<void> _videolariGetir() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/VIDEO');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> gelenVeri = jsonListeCoz(response).where((satir) => alan(satir, "videoUrl").isNotEmpty).toList();
        gelenVeri.shuffle();
        setState(() { _sahneler = gelenVeri; _isLoading = false; });
        _videolariHazirla();
      } else {
        setState(() { _hataMesaji = "Sunucu Hatası: ${response.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      debugPrint("Videolar alınamadı: $e");
      if (mounted) setState(() { _hataMesaji = "Bağlantı Hatası: İnternetinizi kontrol edin."; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _kapandi = true;
    _pageController?.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.pinkAccent),
              const SizedBox(height: 20),
              Text("Loading Reels...", style: GoogleFonts.poppins(color: Colors.white54, letterSpacing: 1.5))
            ],
          )
        )
      );
    }
    if (_hataMesaji.isNotEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: Center(child: Text(_hataMesaji, style: const TextStyle(color: Colors.white))));
    if (_sahneler.isEmpty) return  Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: const Center(child: Text("Excel tablonda henüz video yok.", style: TextStyle(color: Colors.white))));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 30),
        title: Text("Reels", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, shadows: [const Shadow(color: Colors.black87, blurRadius: 10)])),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(),
        itemCount: _sahneler.length,
        onPageChanged: (index) {
          setState(() { _suankiIndex = index; });
          _videolariHazirla();
        },
        itemBuilder: (context, index) {
          final sahne = _sahneler[index];
          final isFavori = globalFavoriSahneler.any((f) => f["videoUrl"] == sahne["videoUrl"]);

          return ReelsVideoOgesi(
            sahne: sahne,
            isFocused: _suankiIndex == index,
            isFavori: isFavori,
            controller: _controllers[index],
            hatali: _hatali.contains(index),
            onTekrarDene: () => _tekrarDene(index),
            onFavoriToggle: () {
              setState(() {
                if (isFavori) { globalFavoriSahneler.removeWhere((f) => f["videoUrl"] == sahne["videoUrl"]); }
                else if (sahne is Map) { globalFavoriSahneler.add(Map<String, dynamic>.from(sahne)); }
              });
              favorileriKaydet();
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// VİDEO OYNATICI
// ==========================================
class ReelsVideoOgesi extends StatefulWidget {
  final dynamic sahne;
  final bool isFocused;
  final bool isFavori;
  final VoidCallback onFavoriToggle;
  final VideoPlayerController? controller;

  /// Video açılamadı; yükleniyor göstergesi yerine "tekrar dene" gösterilir.
  final bool hatali;
  final VoidCallback? onTekrarDene;

  const ReelsVideoOgesi({super.key, required this.sahne, required this.isFocused, required this.isFavori, required this.onFavoriToggle, this.controller, this.hatali = false, this.onTekrarDene});

  @override
  State<ReelsVideoOgesi> createState() => _ReelsVideoOgesiState();
}

class _ReelsVideoOgesiState extends State<ReelsVideoOgesi> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _sesAcik = true;
  // Oynarken internet beklendiği için video durduysa küçük bir gösterge çıkar.
  bool _bekliyor = false;

  // Animasyon Değişkenleri
  bool _ekrandaIkonGoster = false;
  IconData _ekranIkonu = Icons.play_arrow_rounded;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    if (_controller != null) {
      _controller!.addListener(_listener);
      if (_controller!.value.isInitialized) {
        _isPlayerReady = true;
        _setupController();
      }
    }
  }

  void _listener() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final deger = controller.value;
    if (deger.isInitialized && !_isPlayerReady) {
      setState(() => _isPlayerReady = true);
      _setupController();
    }
    // Yalnızca durum değişince yeniden çizilir; her kare için değil.
    final bool bekliyor = deger.isInitialized && deger.isBuffering && deger.isPlaying;
    if (bekliyor != _bekliyor) setState(() => _bekliyor = bekliyor);
  }

  void _setupController() {
    if (!mounted) return;
    _controller!.setVolume(_sesAcik ? 1.0 : 0.0);
    _controller!.setLooping(true);
    if (widget.isFocused) {
      _controller!.play();
    }
  }

  @override
  void didUpdateWidget(ReelsVideoOgesi oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Eğer controller değiştiyse (nadir durum ama yakalayalım)
    if (widget.controller != oldWidget.controller) {
      _controller?.removeListener(_listener);
      _controller = widget.controller;
      _isPlayerReady = _controller?.value.isInitialized ?? false;
      _bekliyor = false;
      _controller?.addListener(_listener);
      if (_isPlayerReady) _setupController();
    }

    if (widget.isFocused && !oldWidget.isFocused) {
      if (_isPlayerReady) {
        _controller?.play();
        _controller?.setVolume(_sesAcik ? 1.0 : 0.0);
      }
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _controller?.pause(); _controller?.seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    // controller'ı biz oluşturmadığımız için dispose etmiyoruz. Üst sınıf (_FilmKesitleriEkraniState) hallediyor.
    super.dispose();
  }

  void _videoDurumunuDegistir() {
    if (_controller == null || !_isPlayerReady) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _ekranIkonu = Icons.pause_rounded;
        _ekrandaIkonGoster = true;
      } else {
        _controller!.play();
        _ekranIkonu = Icons.play_arrow_rounded;
        _ekrandaIkonGoster = true;

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _ekrandaIkonGoster = false);
        });
      }
    });
  }

  // DÜZELTME 3: Çift tıklama mantığı daha stabil hale getirildi.
  void _ciftTiklamaFavori() {
    widget.onFavoriToggle(); // Kalbi ana hafızaya kaydet/sil

    setState(() {
      // Ekranda dev kalp göster
      _ekranIkonu = Icons.favorite_rounded;
      _ekrandaIkonGoster = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _ekrandaIkonGoster = false);
    });
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
        GestureDetector(
          onTap: _videoDurumunuDegistir,
          onDoubleTap: _ciftTiklamaFavori,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _isPlayerReady ? 1.0 : 0.0,
            child: _isPlayerReady
              ? SizedBox.expand(
                  child: FittedBox(
                    // DÜZELTME 2: BoxFit.cover yerine BoxFit.contain yaptık. Videonun altındaki ve üstündeki yazılar artık kesilmeyecek.
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!)
                    ),
                  ),
                )
              : Container(color: Colors.black),
          ),
        ),

        // Yükleniyor Göstergesi (açılamadıysa: tekrar dene)
        if (widget.hatali)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 56),
                const SizedBox(height: 12),
                Text("Video açılamadı.", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: widget.onTekrarDene,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Tekrar dene"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                ),
              ],
            ),
          )
        else if (!_isPlayerReady)
          const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),

        if (_bekliyor)
          const Positioned(
            top: 100, left: 0, right: 0,
            child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5))),
          ),

        // EKRAN ORTASI BÜYÜK İKON ANİMASYONU
        IgnorePointer(child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _ekrandaIkonGoster ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: _ekrandaIkonGoster ? 1.2 : 1.0,
              curve: Curves.easeOutBack,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: Icon(_ekranIkonu, color: _ekranIkonu == Icons.favorite_rounded ? Colors.redAccent : Colors.white, size: 60),
              ),
            ),
          ),
        )),

        // ALT KARARTMA (Menü Çakışmasını Önlemek İçin)
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.center,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent]
              )
            )
          ),
        ),

        // VİDEONUN ADI (favorilerde de aynı adla görünür)
        Positioned(
          left: 18, right: 90, bottom: 46,
          child: IgnorePointer(
            child: Text(
              reelBasligi(widget.sahne),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, shadows: [const Shadow(color: Colors.black, blurRadius: 6)]),
            ),
          ),
        ),

        // SAĞ ALT BUTONLAR (Favori & Ses)
        Positioned(
          right: 15, bottom: 40,
          child: Column(
            children: [
              GestureDetector(
                onTap: _sesiDegistir,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Icon(_sesAcik ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: widget.onFavoriToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Icon(widget.isFavori ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: widget.isFavori ? Colors.redAccent : Colors.white, size: 35),
                ),
              ),
              const SizedBox(height: 5),
              Text(widget.isFavori ? "Saved" : "Save", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [const Shadow(color: Colors.black, blurRadius: 5)])),
            ],
          ),
        ),
      ],
    );
  }
}