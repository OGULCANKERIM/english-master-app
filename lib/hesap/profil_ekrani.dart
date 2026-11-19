import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'giris_ekrani.dart';
import 'hesap_servisi.dart';

// ==========================================
// PROFİL EKRANI (role göre öğrenci veya eğitmen)
// ==========================================

class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key});

  static const String _baslik = 'Profilim';

  @override
  Widget build(BuildContext context) {
    return HesapKapisi(
      baslik: _baslik,
      icerik: (context, kullanici) => HesapSayfasi(
        baslik: _baslik,
        // Rol konsoldan değişirse form yeni role göre baştan kurulur.
        child: _ProfilFormu(key: ValueKey('${kullanici.uid}-${kullanici.rol}'), kullanici: kullanici),
      ),
    );
  }
}

class _ProfilFormu extends StatefulWidget {
  const _ProfilFormu({super.key, required this.kullanici});

  final Kullanici kullanici;

  @override
  State<_ProfilFormu> createState() => _ProfilFormuState();
}

class _ProfilFormuState extends State<_ProfilFormu> {
  final _formAnahtari = GlobalKey<FormState>();
  late final TextEditingController _ad;
  late final TextEditingController _hedef;
  late final TextEditingController _tanitim;
  late final TextEditingController _uzmanliklar;
  late final TextEditingController _diller;
  late String _seviye;
  late final Set<String> _gunler;

  bool _kaydediliyor = false;
  bool _cikiliyor = false;

  bool get _egitmen => widget.kullanici.egitmenMi;

  @override
  void initState() {
    super.initState();
    final k = widget.kullanici;
    _ad = TextEditingController(text: k.ad);
    _hedef = TextEditingController(text: k.hedef);
    _tanitim = TextEditingController(text: k.tanitim);
    _uzmanliklar = TextEditingController(text: k.uzmanliklar.join(', '));
    _diller = TextEditingController(text: k.diller);
    _seviye = k.seviye;
    _gunler = k.musaitGunler.toSet();
  }

  @override
  void dispose() {
    _ad.dispose();
    _hedef.dispose();
    _tanitim.dispose();
    _uzmanliklar.dispose();
    _diller.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;
    if (!(_formAnahtari.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _kaydediliyor = true);
    String mesaj = 'Profilin kaydedildi.';
    try {
      if (_egitmen) {
        await HesapServisi.egitmenProfiliniGuncelle(
          ad: _ad.text,
          tanitim: _tanitim.text,
          uzmanliklar: [
            for (final parca in _uzmanliklar.text.split(','))
              if (parca.trim().isNotEmpty) parca.trim(),
          ],
          diller: _diller.text,
          musaitGunler: _gunler.toList(),
        );
      } else {
        await HesapServisi.ogrenciProfiliniGuncelle(ad: _ad.text, seviye: _seviye, hedef: _hedef.text);
      }
    } catch (hata) {
      mesaj = HesapServisi.hataMesaji(hata);
    }
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    hesapMesaji(context, mesaj);
  }

  Future<void> _cikisYap() async {
    if (_cikiliyor) return;
    final gezgin = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    setState(() => _cikiliyor = true);
    try {
      await HesapServisi.cikisYap();
      // Açık kalan hesap sayfaları giriş ekranına dönmesin diye ana menüye in.
      gezgin.popUntil((rota) => rota.isFirst);
    } catch (hata) {
      mesajci.showSnackBar(SnackBar(content: Text(HesapServisi.hataMesaji(hata), style: GoogleFonts.poppins())));
      if (mounted) setState(() => _cikiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kullanici;
    final eposta = HesapServisi.eposta ?? '';
    return Form(
      key: _formAnahtari,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Row(
            children: [
              HesapAvatari(harf: k.basHarf, boyut: 64),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.gorunenAd, style: hesapYazi(boyut: 18, kalinlik: FontWeight.w600)),
                    if (eposta.isNotEmpty) Text(eposta, style: hesapYazi(boyut: 13, renk: Colors.white60)),
                    const SizedBox(height: 6),
                    _RolRozeti(egitmen: _egitmen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: hesapKartDekoru(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _ad,
                  style: hesapYazi(boyut: 15),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  decoration: hesapAlanDekoru('Ad', ikon: Icons.person_rounded).copyWith(counterText: ''),
                  validator: (deger) => (deger ?? '').trim().isEmpty ? 'Adını yaz.' : null,
                ),
                const SizedBox(height: 16),
                if (_egitmen) ..._egitmenAlanlari() else ..._ogrenciAlanlari(),
                const SizedBox(height: 20),
                HesapDugmesi(
                  etiket: 'Kaydet',
                  ikon: Icons.check_rounded,
                  mesgul: _kaydediliyor,
                  onPressed: () => unawaited(_kaydet()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HesapDugmesi(
            etiket: 'Çıkış yap',
            ikon: Icons.logout_rounded,
            ikincil: true,
            mesgul: _cikiliyor,
            onPressed: () => unawaited(_cikisYap()),
          ),
        ],
      ),
    );
  }

  List<Widget> _ogrenciAlanlari() {
    return [
      Text('Seviye', style: hesapYazi(renk: Colors.white70)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final seviye in seviyeler)
            ChoiceChip(
              label: Text(seviye),
              selected: _seviye == seviye,
              onSelected: (_) => setState(() => _seviye = seviye),
              labelStyle: hesapYazi(kalinlik: FontWeight.w600),
              selectedColor: hesapVurgu,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              checkmarkColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _hedef,
        style: hesapYazi(boyut: 15),
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 4,
        maxLength: 200,
        decoration: hesapAlanDekoru(
          'Öğrenme hedefi',
          yardim: 'Örnek: 6 ay içinde iş görüşmesi yapabilmek.',
        ),
      ),
    ];
  }

  List<Widget> _egitmenAlanlari() {
    return [
      TextFormField(
        controller: _tanitim,
        style: hesapYazi(boyut: 15),
        textCapitalization: TextCapitalization.sentences,
        minLines: 3,
        maxLines: 6,
        maxLength: 500,
        decoration: hesapAlanDekoru('Tanıtım yazısı', yardim: 'Öğrenciler eğitmen listesinde bunu görür.'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _uzmanliklar,
        style: hesapYazi(boyut: 15),
        textCapitalization: TextCapitalization.sentences,
        maxLength: 150,
        decoration: hesapAlanDekoru(
          'Uzmanlık alanları',
          yardim: 'Virgülle ayır. Örnek: IELTS, İş İngilizcesi, Konuşma',
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _diller,
        style: hesapYazi(boyut: 15),
        textCapitalization: TextCapitalization.sentences,
        maxLength: 80,
        decoration: hesapAlanDekoru('Konuştuğu diller', yardim: 'Örnek: Türkçe, İngilizce'),
      ),
      const SizedBox(height: 12),
      Text('Müsait günler', style: hesapYazi(renk: Colors.white70)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final gun in haftaGunleri)
            FilterChip(
              label: Text(gun),
              selected: _gunler.contains(gun),
              onSelected: (secili) => setState(() => secili ? _gunler.add(gun) : _gunler.remove(gun)),
              labelStyle: hesapYazi(boyut: 13, kalinlik: FontWeight.w500),
              selectedColor: hesapVurgu,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              checkmarkColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
        ],
      ),
    ];
  }
}

class _RolRozeti extends StatelessWidget {
  const _RolRozeti({required this.egitmen});

  final bool egitmen;

  @override
  Widget build(BuildContext context) {
    final renk = egitmen ? Colors.amberAccent : Colors.lightBlueAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(egitmen ? Icons.school_rounded : Icons.person_rounded, size: 14, color: renk),
          const SizedBox(width: 5),
          Text(egitmen ? 'Eğitmen' : 'Öğrenci', style: hesapYazi(boyut: 12, renk: renk, kalinlik: FontWeight.w600)),
        ],
      ),
    );
  }
}
