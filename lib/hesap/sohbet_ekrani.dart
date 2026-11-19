import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'giris_ekrani.dart';
import 'hesap_servisi.dart';
import 'mesaj_servisi.dart';

// ==========================================
// SOHBET EKRANI (öğrenci ↔ eğitmen)
// ==========================================

class SohbetEkrani extends StatefulWidget {
  const SohbetEkrani({
    super.key,
    required this.ogrenciId,
    required this.egitmenId,
    required this.karsiAd,
  });

  final String ogrenciId;
  final String egitmenId;

  /// Karşı tarafın adı (başlıkta gösterilir).
  final String karsiAd;

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  final _metin = TextEditingController();
  late final String? _ben = HesapServisi.uid;
  late Stream<List<Mesaj>> _mesajlar = _mesajAkisi();
  StreamSubscription<Sohbet?>? _sohbetAboneligi;

  @override
  void initState() {
    super.initState();
    // Sohbet açıkken gelen mesajlar hemen okundu sayılır.
    try {
      _sohbetAboneligi = MesajServisi.sohbetiIzle(widget.ogrenciId, widget.egitmenId).listen(
        (sohbet) {
          if (sohbet != null && sohbet.okunmamis(_ben) > 0) {
            unawaited(
              MesajServisi.okunduIsaretle(widget.ogrenciId, widget.egitmenId).catchError((Object _) {}),
            );
          }
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // Giriş yoksa mesaj akışı zaten hatayı gösterir.
    }
  }

  @override
  void dispose() {
    unawaited(_sohbetAboneligi?.cancel());
    _metin.dispose();
    super.dispose();
  }

  Stream<List<Mesaj>> _mesajAkisi() {
    try {
      return MesajServisi.mesajlariIzle(widget.ogrenciId, widget.egitmenId);
    } catch (hata) {
      return Stream<List<Mesaj>>.error(hata);
    }
  }

  void _gonder() {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    final mesajci = ScaffoldMessenger.of(context);
    void hataGoster(Object hata) {
      final kapali = hata is FirebaseException && hata.code == 'permission-denied';
      mesajci
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              kapali
                  ? 'Mesaj gönderilemedi: bu sohbet artık kapalı.'
                  : 'Mesaj gönderilemedi. ${HesapServisi.hataMesaji(hata)}',
            ),
          ),
        );
    }

    try {
      // Beklenmez: mesaj yerel olarak hemen listede görünür, çevrimdışıysa
      // bağlantı gelince gönderilir.
      unawaited(
        MesajServisi.gonder(
          ogrenciId: widget.ogrenciId,
          egitmenId: widget.egitmenId,
          metin: metin,
        ).catchError(hataGoster),
      );
      _metin.clear();
    } catch (hata) {
      hataGoster(hata);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: widget.karsiAd,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Mesaj>>(
              stream: _mesajlar,
              builder: (context, anlik) {
                if (anlik.hasError) {
                  return HesapBilgi(
                    ikon: Icons.error_outline_rounded,
                    mesaj: 'Mesajlar yüklenemedi.\n${HesapServisi.hataMesaji(anlik.error!)}',
                    dugmeler: [
                      HesapDugmesi(
                        etiket: 'Tekrar dene',
                        ikon: Icons.refresh_rounded,
                        onPressed: () => setState(() => _mesajlar = _mesajAkisi()),
                      ),
                    ],
                  );
                }
                final mesajlar = anlik.data;
                if (mesajlar == null) return const HesapYukleniyor();
                if (mesajlar.isEmpty) {
                  return const HesapBilgi(
                    ikon: Icons.chat_bubble_outline_rounded,
                    mesaj: 'Henüz mesaj yok.\nİlk mesajı sen yaz.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: mesajlar.length,
                  itemBuilder: (context, sira) {
                    final mesaj = mesajlar[sira];
                    return _MesajBalonu(
                      key: ValueKey(mesaj.id),
                      mesaj: mesaj,
                      benim: mesaj.gonderen == _ben,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _metin,
                    style: hesapYazi(boyut: 15),
                    minLines: 1,
                    maxLines: 4,
                    maxLength: mesajUzunlukSiniri,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: hesapAlanDekoru('Mesaj yaz').copyWith(
                      counterText: '',
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Gönder',
                  onPressed: _gonder,
                  style: IconButton.styleFrom(
                    backgroundColor: hesapVurgu,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(52, 52),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MesajBalonu extends StatelessWidget {
  const _MesajBalonu({super.key, required this.mesaj, required this.benim});

  final Mesaj mesaj;
  final bool benim;

  static String _saat(DateTime? zaman) {
    if (zaman == null) return '';
    final yerel = zaman.toLocal();
    String iki(int sayi) => sayi.toString().padLeft(2, '0');
    final simdi = DateTime.now();
    final bugun = yerel.year == simdi.year && yerel.month == simdi.month && yerel.day == simdi.day;
    final saat = '${iki(yerel.hour)}:${iki(yerel.minute)}';
    return bugun ? saat : '${iki(yerel.day)}.${iki(yerel.month)} $saat';
  }

  @override
  Widget build(BuildContext context) {
    const kose = Radius.circular(18);
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        decoration: BoxDecoration(
          color: benim ? hesapVurgu.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.only(
            topLeft: kose,
            topRight: kose,
            bottomLeft: benim ? kose : const Radius.circular(4),
            bottomRight: benim ? const Radius.circular(4) : kose,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mesaj.metin, style: hesapYazi(boyut: 15)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_saat(mesaj.zaman), style: hesapYazi(boyut: 11, renk: Colors.white60)),
                if (benim && mesaj.bekliyor) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.schedule_rounded, size: 12, color: Colors.white60, semanticLabel: 'Gönderiliyor'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// OKUNMAMIŞ MESAJ NOKTASI (ana menü kartı için)
// ==========================================

/// Okunmamış mesaj varsa kırmızı nokta, yoksa hiçbir şey göstermez.
class OkunmamisNoktasi extends StatefulWidget {
  const OkunmamisNoktasi({super.key});

  @override
  State<OkunmamisNoktasi> createState() => _OkunmamisNoktasiState();
}

class _OkunmamisNoktasiState extends State<OkunmamisNoktasi> {
  late final Stream<int> _sayi = MesajServisi.okunmamisSayisiniIzle();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _sayi,
      builder: (context, anlik) {
        if ((anlik.data ?? 0) <= 0) return const SizedBox.shrink();
        return Semantics(
          label: 'Okunmamış mesaj var',
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        );
      },
    );
  }
}
