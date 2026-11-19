import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../core/globals.dart';

// ==========================================
// FAVORİ VİDEOLAR EKRANI
// ==========================================
class FavorilerEkrani extends StatelessWidget {
  const FavorilerEkrani({super.key});

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
                Text("Double tap videos to save them here!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white54))
              ]
            )
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            itemCount: globalFavoriSahneler.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final sahne = globalFavoriSahneler[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.pinkAccent)
                  ),
                  title: Text(sahne["kaynak"] ?? "Reels Video ${index + 1}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                    onPressed: () {
                      if (index < globalFavoriSahneler.length) globalFavoriSahneler.removeAt(index);
                      favorileriKaydet();
                      Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation1, animation2) => const FavorilerEkrani(), transitionDuration: Duration.zero));
                    }
                  ),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => FilmKesitleriEkrani(ozelListe: List.of(globalFavoriSahneler), baslangicIndex: index)));
                    if (!context.mounted) return;
                    Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation1, animation2) => const FavorilerEkrani(), transitionDuration: Duration.zero));
                  },
                ),
              );
            }
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

  @override
  void initState() {
    super.initState();
    if (widget.ozelListe != null) {
      _sahneler = widget.ozelListe!;
      _suankiIndex = widget.baslangicIndex;
      _pageController = PageController(initialPage: _suankiIndex);
      _isLoading = false;
      _videolariPreload();
    } else {
      _suankiIndex = 0;
      _pageController = PageController(initialPage: 0);
      _videolariGetir();
    }
  }

  void _videolariPreload() {
    final int targetIndex = _suankiIndex;
    // Mevcut, bir önceki ve sonraki 2 videoyu önceden yükle
    for (int i = targetIndex - 1; i <= targetIndex + 2; i++) {
      if (i >= 0 && i < _sahneler.length) {
        if (!_controllers.containsKey(i)) {
          final Uri? adres = Uri.tryParse(alan(_sahneler[i], "videoUrl"));
          if (adres == null || !adres.hasScheme) continue;
          final controller = VideoPlayerController.networkUrl(adres);
          _controllers[i] = controller;
          controller.initialize().then((_) {
            if (mounted) setState(() {});
          }).catchError((Object e) {
            debugPrint("Video açılamadı: $e");
          });
        }
      }
    }

    // Çok uzaktaki videoların controller'larını temizle (bellek tasarrufu için)
    final keysToRemove = _controllers.keys.where((k) => (k - targetIndex).abs() > 2).toList();
    for (int k in keysToRemove) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
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
        _videolariPreload();
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
        // DÜZELTME 1: Orijinal ve stabil kaydırma fiziğine geri döndük. "Mıknatıs" gibi oturacak.
        physics: const PageScrollPhysics(),
        itemCount: _sahneler.length,
        onPageChanged: (index) {
          setState(() { _suankiIndex = index; });
          _videolariPreload();
        },
        itemBuilder: (context, index) {
          final sahne = _sahneler[index];
          final isFavori = globalFavoriSahneler.any((f) => f["videoUrl"] == sahne["videoUrl"]);

          return ReelsVideoOgesi(
            sahne: sahne,
            isFocused: _suankiIndex == index,
            isFavori: isFavori,
            controller: _controllers[index],
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

  const ReelsVideoOgesi({super.key, required this.sahne, required this.isFocused, required this.isFavori, required this.onFavoriToggle, this.controller});

  @override
  State<ReelsVideoOgesi> createState() => _ReelsVideoOgesiState();
}

class _ReelsVideoOgesiState extends State<ReelsVideoOgesi> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _sesAcik = true;

  // Animasyon Değişkenleri
  bool _ekrandaIkonGoster = false;
  IconData _ekranIkonu = Icons.play_arrow_rounded;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    if (_controller != null) {
      if (_controller!.value.isInitialized) {
        _isPlayerReady = true;
        _setupController();
      } else {
        _controller!.addListener(_listener);
      }
    }
  }

  void _listener() {
    if (_controller != null && _controller!.value.isInitialized && !_isPlayerReady) {
      if (mounted) {
        setState(() {
          _isPlayerReady = true;
        });
        _setupController();
      }
    }
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
      if (!_isPlayerReady) {
        _controller?.addListener(_listener);
      } else {
        _setupController();
      }
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

        // Yükleniyor Göstergesi
        if (!_isPlayerReady)
          const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),

        // EKRAN ORTASI BÜYÜK İKON ANİMASYONU
        Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _ekrandaIkonGoster || (!_isPlayerReady ? false : !_controller!.value.isPlaying) ? 1.0 : 0.0,
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
        ),

        // ALT KARARTMA (Menü Çakışmasını Önlemek İçin)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.center,
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent]
            )
          )
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