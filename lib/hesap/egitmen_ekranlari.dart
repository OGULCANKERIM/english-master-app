import 'dart:async';

import 'package:flutter/material.dart';

import 'giris_ekrani.dart';
import 'hesap_servisi.dart';
import 'mesaj_servisi.dart';
import 'profil_ekrani.dart';
import 'randevu_bolumu.dart';
import 'sohbet_ekrani.dart';

// ==========================================
// "MY TUTOR" GİRİŞİ (role göre yönlendirir)
// ==========================================

/// Ana menüdeki "My Tutor" kartının açtığı ekran.
/// Eğitmende panel, öğrencide seçili eğitmen ya da eğitmen listesi gösterilir.
class EgitmenimEkrani extends StatelessWidget {
  const EgitmenimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return HesapKapisi(
      baslik: 'Eğitmenim',
      icerik: (context, kullanici) {
        if (kullanici.egitmenMi) return EgitmenPaneliEkrani(egitmen: kullanici);
        final egitmenId = kullanici.egitmenId;
        if (egitmenId == null) return const EgitmenListesiEkrani();
        return _SeciliEgitmenEkrani(key: ValueKey(egitmenId), egitmenId: egitmenId);
      },
    );
  }
}

Route<T> _sayfa<T>(Widget sayfa) => MaterialPageRoute<T>(builder: (_) => sayfa);

// ==========================================
// AKIŞ DİNLEYİCİ (yükleniyor / hata / veri)
// ==========================================

/// Akışı bir kez oluşturup saklar; yeniden çizimlerde sorgu tekrar başlamaz.
class _Akis<T> extends StatefulWidget {
  const _Akis({super.key, required this.olustur, required this.veri, this.hata});

  final Stream<T> Function() olustur;
  final Widget Function(BuildContext context, T veri) veri;
  final Widget Function(BuildContext context, String mesaj, VoidCallback tekrarDene)? hata;

  @override
  State<_Akis<T>> createState() => _AkisState<T>();
}

class _AkisState<T> extends State<_Akis<T>> {
  late Stream<T> _akis = _baslat();

  Stream<T> _baslat() {
    try {
      return widget.olustur();
    } catch (hata) {
      return Stream<T>.error(hata);
    }
  }

  void _tekrarDene() => setState(() => _akis = _baslat());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _akis,
      builder: (context, anlik) {
        if (anlik.hasError) {
          final mesaj = HesapServisi.hataMesaji(anlik.error!);
          final ozel = widget.hata;
          if (ozel != null) return ozel(context, mesaj, _tekrarDene);
          return HesapBilgi(
            ikon: Icons.error_outline_rounded,
            mesaj: mesaj,
            dugmeler: [HesapDugmesi(etiket: 'Tekrar dene', ikon: Icons.refresh_rounded, onPressed: _tekrarDene)],
          );
        }
        if (!anlik.hasData) {
          return const Padding(padding: EdgeInsets.all(30), child: HesapYukleniyor());
        }
        return widget.veri(context, anlik.data as T);
      },
    );
  }
}

// ==========================================
// EĞİTMEN LİSTESİ
// ==========================================

class EgitmenListesiEkrani extends StatelessWidget {
  const EgitmenListesiEkrani({super.key, this.seciliId, this.secinceKapat = false});

  /// Öğrencinin şu anki eğitmeni (listede işaretlenir).
  final String? seciliId;

  /// "Eğitmeni değiştir" ile açıldıysa seçimden sonra liste de kapanır.
  final bool secinceKapat;

  Future<void> _profiliAc(BuildContext context, Kullanici egitmen) async {
    final gezgin = Navigator.of(context);
    final secildi = await gezgin.push<bool>(
      _sayfa(EgitmenProfilEkrani(egitmen: egitmen, seciliMi: egitmen.uid == seciliId)),
    );
    if (secildi == true && secinceKapat && gezgin.canPop()) gezgin.pop();
  }

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: 'Eğitmen Seç',
      child: _Akis<List<Kullanici>>(
        olustur: HesapServisi.egitmenleriIzle,
        veri: (context, egitmenler) {
          if (egitmenler.isEmpty) {
            return const HesapBilgi(
              ikon: Icons.school_rounded,
              mesaj: 'Henüz eğitmen eklenmemiş.\nYakında burada görünecekler.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            itemCount: egitmenler.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, sira) {
              final egitmen = egitmenler[sira];
              return _EgitmenKarti(
                egitmen: egitmen,
                seciliMi: egitmen.uid == seciliId,
                onTap: () => unawaited(_profiliAc(context, egitmen)),
              );
            },
          );
        },
      ),
    );
  }
}

class _EgitmenKarti extends StatelessWidget {
  const _EgitmenKarti({required this.egitmen, required this.seciliMi, required this.onTap});

  final Kullanici egitmen;
  final bool seciliMi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ozet = egitmen.uzmanliklar.isNotEmpty ? egitmen.uzmanliklar.join(' · ') : egitmen.tanitim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: hesapKartDekoru(),
          child: Row(
            children: [
              HesapAvatari(harf: egitmen.basHarf),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(egitmen.gorunenAd, style: hesapYazi(boyut: 16, kalinlik: FontWeight.w600)),
                    if (ozet.isNotEmpty)
                      Text(
                        ozet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: hesapYazi(boyut: 13, renk: Colors.white60),
                      ),
                    if (seciliMi)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Eğitmenin',
                          style: hesapYazi(boyut: 12, renk: Colors.greenAccent, kalinlik: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// EĞİTMEN DETAYI (ortak gösterim)
// ==========================================

class _EgitmenDetayi extends StatelessWidget {
  const _EgitmenDetayi({required this.egitmen});

  final Kullanici egitmen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: hesapKartDekoru(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HesapAvatari(harf: egitmen.basHarf, boyut: 68),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(egitmen.gorunenAd, style: hesapYazi(boyut: 20, kalinlik: FontWeight.bold)),
                    Text('Eğitmen', style: hesapYazi(boyut: 13, renk: Colors.amberAccent)),
                  ],
                ),
              ),
            ],
          ),
          if (egitmen.tanitim.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(egitmen.tanitim, style: hesapYazi(renk: Colors.white.withValues(alpha: 0.9))),
          ],
          if (egitmen.uzmanliklar.isNotEmpty) ...[
            const _Baslik('Uzmanlık alanları'),
            _Etiketler(egitmen.uzmanliklar),
          ],
          if (egitmen.diller.isNotEmpty) ...[
            const _Baslik('Konuştuğu diller'),
            Text(egitmen.diller, style: hesapYazi()),
          ],
          if (egitmen.musaitGunler.isNotEmpty) ...[
            const _Baslik('Müsait günler'),
            _Etiketler(egitmen.musaitGunler),
          ],
        ],
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(metin, style: hesapYazi(boyut: 13, renk: Colors.white60, kalinlik: FontWeight.w500)),
    );
  }
}

class _Etiketler extends StatelessWidget {
  const _Etiketler(this.ogeler);

  final List<String> ogeler;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final oge in ogeler)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: hesapVurgu.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(oge, style: hesapYazi(boyut: 13)),
          ),
      ],
    );
  }
}

// ==========================================
// EĞİTMEN PROFİL SAYFASI ("Bu eğitmeni seç")
// ==========================================

class EgitmenProfilEkrani extends StatefulWidget {
  const EgitmenProfilEkrani({super.key, required this.egitmen, this.seciliMi = false});

  final Kullanici egitmen;
  final bool seciliMi;

  @override
  State<EgitmenProfilEkrani> createState() => _EgitmenProfilEkraniState();
}

class _EgitmenProfilEkraniState extends State<EgitmenProfilEkrani> {
  bool _mesgul = false;

  Future<void> _sec() async {
    if (_mesgul) return;
    final gezgin = Navigator.of(context);
    setState(() => _mesgul = true);
    try {
      await HesapServisi.egitmenSec(widget.egitmen.uid);
    } catch (hata) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      hesapMesaji(context, HesapServisi.hataMesaji(hata));
      return;
    }
    if (!mounted) return;
    hesapMesaji(context, '${widget.egitmen.gorunenAd} artık eğitmenin.');
    gezgin.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: 'Eğitmen Profili',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          _EgitmenDetayi(egitmen: widget.egitmen),
          const SizedBox(height: 20),
          if (widget.seciliMi)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text('Şu anki eğitmenin', style: hesapYazi(boyut: 15, renk: Colors.greenAccent)),
              ],
            )
          else
            HesapDugmesi(
              etiket: 'Bu eğitmeni seç',
              ikon: Icons.how_to_reg_rounded,
              mesgul: _mesgul,
              onPressed: () => unawaited(_sec()),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// ÖĞRENCİNİN "EĞİTMENİM" GÖRÜNÜMÜ
// ==========================================

class _SeciliEgitmenEkrani extends StatefulWidget {
  const _SeciliEgitmenEkrani({super.key, required this.egitmenId});

  final String egitmenId;

  @override
  State<_SeciliEgitmenEkrani> createState() => _SeciliEgitmenEkraniState();
}

class _SeciliEgitmenEkraniState extends State<_SeciliEgitmenEkrani> {
  bool _birakiliyor = false;

  void _degistir() {
    unawaited(
      Navigator.of(context).push<void>(
        _sayfa(EgitmenListesiEkrani(seciliId: widget.egitmenId, secinceKapat: true)),
      ),
    );
  }

  Future<void> _birak() async {
    if (_birakiliyor) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (diyalog) => AlertDialog(
        title: const Text('Eğitmeni bırak'),
        content: const Text('Eğitmenini bırakmak istediğine emin misin? İstediğin zaman yeniden seçebilirsin.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(diyalog).pop(false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.of(diyalog).pop(true), child: const Text('Bırak')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _birakiliyor = true);
    try {
      await HesapServisi.egitmeniBirak();
    } catch (hata) {
      if (!mounted) return;
      setState(() => _birakiliyor = false);
      hesapMesaji(context, HesapServisi.hataMesaji(hata));
    }
    // Başarılıysa profil akışı güncellenir ve bu ekran yerini listeye bırakır.
  }

  List<Widget> _dugmeler({required String degistirEtiketi, bool ikincil = false}) {
    return [
      HesapDugmesi(
        etiket: degistirEtiketi,
        ikon: Icons.swap_horiz_rounded,
        ikincil: ikincil,
        onPressed: _degistir,
      ),
      const SizedBox(height: 12),
      HesapDugmesi(
        etiket: 'Eğitmeni bırak',
        ikon: Icons.person_remove_rounded,
        ikincil: true,
        mesgul: _birakiliyor,
        onPressed: () => unawaited(_birak()),
      ),
    ];
  }

  Widget _bulunamadi() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        const HesapBilgi(
          ikon: Icons.person_off_rounded,
          mesaj: 'Seçtiğin eğitmen şu anda görüntülenemiyor.\nBaşka bir eğitmen seçebilirsin.',
        ),
        ..._dugmeler(degistirEtiketi: 'Başka eğitmen seç'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: 'Eğitmenim',
      child: _Akis<Kullanici?>(
        olustur: () => HesapServisi.kullaniciyiIzle(widget.egitmenId),
        // Eğitmenin rolü kaldırıldıysa kurallar okumayı reddeder; aynı ekranı göster.
        hata: (context, mesaj, tekrarDene) => _bulunamadi(),
        veri: (context, egitmen) {
          if (egitmen == null || !egitmen.egitmenMi) return _bulunamadi();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _EgitmenDetayi(egitmen: egitmen),
              const SizedBox(height: 20),
              _MesajDugmesi(egitmen: egitmen),
              const SizedBox(height: 12),
              ..._dugmeler(degistirEtiketi: 'Eğitmeni değiştir', ikincil: true),
            ],
          );
        },
      ),
    );
  }
}

/// Öğrencinin eğitmenine yazdığı sohbeti açar; okunmamış mesaj sayısını gösterir.
class _MesajDugmesi extends StatefulWidget {
  const _MesajDugmesi({required this.egitmen});

  final Kullanici egitmen;

  @override
  State<_MesajDugmesi> createState() => _MesajDugmesiState();
}

class _MesajDugmesiState extends State<_MesajDugmesi> {
  late final String? _ben = HesapServisi.uid;
  late final Stream<Sohbet?> _sohbet = _akis();

  Stream<Sohbet?> _akis() {
    final ben = _ben;
    if (ben == null) return Stream<Sohbet?>.value(null);
    try {
      return MesajServisi.sohbetiIzle(ben, widget.egitmen.uid);
    } catch (_) {
      return Stream<Sohbet?>.value(null);
    }
  }

  void _ac() {
    final ben = _ben;
    if (ben == null) return;
    unawaited(
      Navigator.of(context).push<void>(
        _sayfa(SohbetEkrani(ogrenciId: ben, egitmenId: widget.egitmen.uid, karsiAd: widget.egitmen.gorunenAd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Sohbet?>(
      stream: _sohbet,
      builder: (context, anlik) {
        final yeni = anlik.data?.okunmamis(_ben) ?? 0;
        return HesapDugmesi(
          etiket: yeni > 0 ? 'Mesaj yaz · $yeni yeni' : 'Mesaj yaz',
          ikon: yeni > 0 ? Icons.mark_chat_unread_rounded : Icons.chat_rounded,
          onPressed: _ac,
        );
      },
    );
  }
}

// ==========================================
// EĞİTMEN PANELİ (kendisini seçen öğrenciler)
// ==========================================

class EgitmenPaneliEkrani extends StatelessWidget {
  const EgitmenPaneliEkrani({super.key, required this.egitmen});

  final Kullanici egitmen;

  Widget _ogrenciListesi(BuildContext context, List<Kullanici> ogrenciler, Map<String, int> yeniMesajlar) {
    return Column(
      children: [
        for (final ogrenci in ogrenciler)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OgrenciKarti(
              ogrenci: ogrenci,
              yeniMesaj: yeniMesajlar[ogrenci.uid] ?? 0,
              onTap: () => unawaited(
                Navigator.of(context).push<void>(
                  _sayfa(
                    SohbetEkrani(ogrenciId: ogrenci.uid, egitmenId: egitmen.uid, karsiAd: ogrenci.gorunenAd),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return HesapSayfasi(
      baslik: 'Eğitmen Paneli',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: hesapKartDekoru(),
            child: Column(
              children: [
                Row(
                  children: [
                    HesapAvatari(harf: egitmen.basHarf, boyut: 60),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(egitmen.gorunenAd, style: hesapYazi(boyut: 18, kalinlik: FontWeight.w600)),
                          Text('Eğitmen', style: hesapYazi(boyut: 13, renk: Colors.amberAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                HesapDugmesi(
                  etiket: 'Profilimi düzenle',
                  ikon: Icons.edit_rounded,
                  ikincil: true,
                  onPressed: () => unawaited(Navigator.of(context).push<void>(_sayfa(const ProfilEkrani()))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Eğitmenin kendi eklediği öğrenciler ve haftalık speaking randevuları.
          RandevuBolumu(egitmenId: egitmen.uid),
          const SizedBox(height: 24),
          _Akis<List<Kullanici>>(
            olustur: HesapServisi.ogrencilerimiIzle,
            veri: (context, ogrenciler) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beni seçen öğrenciler (${ogrenciler.length})',
                  style: hesapYazi(boyut: 17, kalinlik: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (ogrenciler.isEmpty)
                  const HesapBilgi(
                    ikon: Icons.groups_rounded,
                    mesaj: 'Henüz seni seçen öğrenci yok.\nÖğrenciler seni seçtiğinde burada görünür.',
                  )
                else
                  _Akis<List<Sohbet>>(
                    olustur: MesajServisi.egitmenSohbetleriniIzle,
                    // Sohbetler okunamazsa liste yine görünür, yalnızca sayaçlar eksik kalır.
                    hata: (context, mesaj, tekrarDene) => _ogrenciListesi(context, ogrenciler, const {}),
                    veri: (context, sohbetler) => _ogrenciListesi(
                      context,
                      ogrenciler,
                      MesajServisi.egitmenOkunmamisi(ogrenciler, sohbetler),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OgrenciKarti extends StatelessWidget {
  const _OgrenciKarti({required this.ogrenci, required this.yeniMesaj, required this.onTap});

  final Kullanici ogrenci;
  final int yeniMesaj;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: hesapKartDekoru(),
          child: _icerik(),
        ),
      ),
    );
  }

  Widget _icerik() {
    return Semantics(
      button: true,
      label: '${ogrenci.gorunenAd} ile mesajlaş',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HesapAvatari(harf: ogrenci.basHarf, boyut: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ogrenci.gorunenAd, style: hesapYazi(boyut: 16, kalinlik: FontWeight.w600)),
                Text('Seviye: ${ogrenci.seviye}', style: hesapYazi(boyut: 13, renk: Colors.lightBlueAccent)),
                if (ogrenci.hedef.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Hedef: ${ogrenci.hedef}', style: hesapYazi(boyut: 13, renk: Colors.white70)),
                  ),
                if (yeniMesaj > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$yeniMesaj yeni mesaj',
                      style: hesapYazi(boyut: 13, renk: Colors.redAccent, kalinlik: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            yeniMesaj > 0 ? Icons.mark_chat_unread_rounded : Icons.chat_rounded,
            color: yeniMesaj > 0 ? Colors.redAccent : Colors.white54,
          ),
        ],
      ),
    );
  }
}
