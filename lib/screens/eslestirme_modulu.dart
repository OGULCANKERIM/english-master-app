import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../core/globals.dart';
import '../services/ai_coach_system.dart';

class MatchCardModel {
  final int pairId;
  final String text;
  final bool isEnglish;
  final bool isJoker;
  bool isFlipped;
  bool isMatched;

  MatchCardModel(this.pairId, this.text, this.isEnglish, {this.isJoker = false, this.isFlipped = false, this.isMatched = false});
}

class EslestirmeModulu extends StatefulWidget {
  const EslestirmeModulu({super.key});

  @override
  State<EslestirmeModulu> createState() => _EslestirmeModuluState();
}

class _EslestirmeModuluState extends State<EslestirmeModulu> with TickerProviderStateMixin {
  List<dynamic> tumKelimeler = [];
  bool isLoading = true;
  String hataMesaji = "";

  List<MatchCardModel> boardCards = [];
  List<int> flippedIndices = [];

  int score = 0;
  int streak = 0;
  int round = 1;

  @override
  void initState() {
    super.initState();
    _fetchKelimeler();
  }

  Future<void> _fetchKelimeler() async {
    final url = Uri.parse('https://opensheet.elk.sh/1hXXqO86XDXyelpIEuRSvyWr6OZafBaTV97_LG3YsjqY/WORD');
    if (mounted) setState(() { isLoading = true; hataMesaji = ""; });
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode == 200) {
        // İngilizcesi ve Türkçesi dolu olan kelimeler oyuna girer.
        tumKelimeler = jsonListeCoz(response).where((k) => alan(k, "ing").isNotEmpty && alan(k, "tr").isNotEmpty).toList();
        if (tumKelimeler.length < 4) {
          setState(() { isLoading = false; hataMesaji = "Not enough words to play yet."; });
          return;
        }
        _generateBoard();
        setState(() { isLoading = false; });
      } else {
        setState(() { isLoading = false; hataMesaji = "Server Error: ${response.statusCode}"; });
      }
    } catch (e) {
      debugPrint("Eşleştirme kelimeleri alınamadı: $e");
      if (mounted) setState(() { isLoading = false; hataMesaji = "Connection problem. Please check your internet."; });
    }
  }

  void _generateBoard() {
    if (tumKelimeler.isEmpty) return;
    flippedIndices.clear();

    final random = Random();
    List<dynamic> havuz = List.from(tumKelimeler)..shuffle(random);

    // TAM 3x3 olması için: 4 Çift (8 kart) + 1 Joker (Bonus Kart) = 9 Kart
    final List<dynamic> secilenler = [];
    final Set<String> kullanilan = {};
    for (final k in havuz) {
      final String eng = alan(k, "ing").toLowerCase();
      final String tr = alan(k, "tr").toLowerCase();
      if (kullanilan.contains(eng) || kullanilan.contains(tr)) continue;
      kullanilan..add(eng)..add(tr);
      secilenler.add(k);
      if (secilenler.length == 4) break;
    }
    if (secilenler.length < 4) {
      // Boş masa yerine ne olduğunu söyle.
      if (mounted) setState(() { boardCards = []; hataMesaji = "Not enough different words to play yet."; });
      return;
    }

    List<MatchCardModel> tempCards = [];
    int currentId = 0;
    for (var k in secilenler) {
      final String eng = alan(k, "ing");
      final String tr = alan(k, "tr");

      tempCards.add(MatchCardModel(currentId, eng, true));
      tempCards.add(MatchCardModel(currentId, tr, false));
      currentId++;
    }

    // 9. Kart Olarak Joker Ekle
    tempCards.add(MatchCardModel(999, "★ JOKER ★", false, isJoker: true));

    tempCards.shuffle(random);
    if (!mounted) return;
    setState(() {
      boardCards = tempCards;
    });
  }

  void _onCardTap(int index) async {
    if (index >= boardCards.length || boardCards[index].isFlipped || boardCards[index].isMatched) return;
    if (flippedIndices.length == 2) return; // İkiden fazla kart aynı anda açılamaz

    if (boardCards[index].isJoker) {
      setState(() {
        boardCards[index].isFlipped = true;
        boardCards[index].isMatched = true;
        score += 50;
      });
      _checkWin();
      return;
    }

    setState(() {
      boardCards[index].isFlipped = true;
      flippedIndices.add(index);
    });

    if (flippedIndices.length == 2) {
      int idx1 = flippedIndices[0];
      int idx2 = flippedIndices[1];

      MatchCardModel firstCard = boardCards[idx1];
      MatchCardModel secondCard = boardCards[idx2];

      if (firstCard.pairId == secondCard.pairId && firstCard.isEnglish != secondCard.isEnglish) {
        // MATCH (DOĞRU EŞLEŞME)
        await Future.delayed(const Duration(milliseconds: 600)); // Başarıyı görsün diye ufak bekleyiş
        if (mounted) {
          setState(() {
            boardCards[idx1].isMatched = true;
            boardCards[idx2].isMatched = true;
            flippedIndices.clear();
            score += 15 + (streak * 5); // Combo bonus
            streak++;
          });
          _checkWin();
        }
      } else {
        // WRONG (YANLIŞ EŞLEŞME)
        await Future.delayed(const Duration(milliseconds: 1200)); // Kelimelere baksın diye 1 sn bekle
        if (mounted) {
          setState(() {
            boardCards[idx1].isFlipped = false;
            boardCards[idx2].isFlipped = false;
            flippedIndices.clear();
            streak = 0;
          });
        }
      }
    }
  }

  void _checkWin() {
      bool isWon = boardCards.every((card) => card.isMatched);
    if (isWon) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          round++;
        });
        _generateBoard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Koç düğmesi sağ altta durur (Stack içindeyken sol üstte geri düğmesini kapatıyordu).
      floatingActionButton: AiCoachSystem.globalCoachButton(context, "Eşleştirme"),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. OYUN HEADER & SKOR PANOSU
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).cardColor,
                            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 10)],
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).primaryColor, size: 20),
                        ),
                      ),
                      Column(
                        children: [
                          Text("Memory Match", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          Text("Round $round", style: GoogleFonts.playfairDisplay(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded, color: Theme.of(context).primaryColor, size: 18),
                            const SizedBox(width: 5),
                            Text("$score", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                // 2. HAFIZA KARTLARI MASASI (3x3 PERFECT FIT)
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                      : hataMesaji.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_off_rounded, size: 60, color: Theme.of(context).primaryColor),
                                  const SizedBox(height: 15),
                                  Text(hataMesaji, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(onPressed: _fetchKelimeler, icon: const Icon(Icons.refresh), label: const Text("Try Again")),
                                ],
                              ),
                            ),
                          )
                      : Center(
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: boardCards.length,
                            itemBuilder: (context, index) {
                              return _buildFlipCard(index);
                            },
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

  Widget _buildFlipCard(int index) {
    MatchCardModel card = boardCards[index];
    bool isFaceUp = card.isFlipped || card.isMatched;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: isFaceUp ? 0 : pi), // 0: Ön yüz, pi: Arka kapak
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutBack,
        builder: (context, double angle, child) {
          // Açının ortasından sonra arka yüzü render etmeye başlıyoruz
          bool isBack = angle >= (pi / 2);

          return Transform(
            // 3D Matrix Rotasyon Büyüsü
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? _buildCardBack() // Arka kapak
                : _buildCardFront(card), // Açılmış kartın yüzü
          );
        },
      ),
    );
  }

  // KARTIN ARKASI (Kapalı Hali)
  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColorDark, Theme.of(context).primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Center(
        child: Opacity(
          opacity: 0.4,
          child: Transform(
            // Arka kapak 180 derece (pi) kadar dönmüş olarak renderlanacağı için
            // içerisindeki ikon ters gözükmesin (aynalanmasın) diye ikonu da ters çeviriyoruz.
            transform: Matrix4.rotationY(pi),
            alignment: Alignment.center,
            child: Icon(Icons.psychology_alt_rounded, size: 36, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // KARTIN ÖNÜ (Açık Hali - Yazı)
  Widget _buildCardFront(MatchCardModel card) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Color> pairColors = [
      Colors.pinkAccent,
      Colors.lightBlueAccent,
      Colors.amberAccent,
      Colors.deepPurpleAccent,
      Colors.tealAccent,
      Colors.indigoAccent,
    ];

    Color frontColor = card.isMatched
        ? Colors.greenAccent.withValues(alpha: isDark ? 0.3 : 0.8)
        : (card.isJoker
            ? Colors.orange.withValues(alpha: isDark ? 0.3 : 0.8)
            : pairColors[card.pairId % pairColors.length].withValues(alpha: isDark ? 0.3 : 0.8));

    Color borderColor = card.isMatched
        ? Colors.greenAccent
        : (card.isJoker ? Colors.orangeAccent : pairColors[card.pairId % pairColors.length].withValues(alpha: 0.8));

    return Opacity(
      opacity: card.isMatched ? 0.4 : 1.0, // Eşleşen kartları hafif soluk yap
      child: Container(
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: frontColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: card.isMatched ? 3 : 2
          ),
          boxShadow: [BoxShadow(color: borderColor.withValues(alpha: isDark ? 0.3 : 0.6), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Center(
          child: card.isJoker ?
           Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 38),
               Text("JOKER", style: GoogleFonts.poppins(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
             ],
           ) :
           Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  card.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: card.isEnglish ? 15 : 13,
                    fontWeight: card.isEnglish ? FontWeight.bold : FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: card.isEnglish ? 1.0 : 0.8),
                  ),
                ),
              ),
              if (!card.isEnglish)
                 const SizedBox(height: 4),
              if (!card.isEnglish)
                 Icon(Icons.translate_rounded, size: 12, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
