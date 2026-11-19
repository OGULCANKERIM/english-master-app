import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hesap_servisi.dart';

// ==========================================
// HESAP EKRANLARININ ORTAK PARÇALARI
// ==========================================

const LinearGradient hesapGradyani = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
);

const Color hesapVurgu = Colors.deepPurpleAccent;

BoxDecoration hesapKartDekoru() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
  );
}

InputDecoration hesapAlanDekoru(String etiket, {IconData? ikon, String? yardim, Widget? sonEk}) {
  OutlineInputBorder kenar(Color renk) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: renk),
      );
  return InputDecoration(
    labelText: etiket,
    helperText: yardim,
    helperMaxLines: 2,
    labelStyle: GoogleFonts.poppins(color: Colors.white70),
    helperStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
    errorStyle: GoogleFonts.poppins(color: Colors.orangeAccent, fontSize: 12),
    errorMaxLines: 2,
    prefixIcon: ikon == null ? null : Icon(ikon, color: Colors.white70),
    suffixIcon: sonEk,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    enabledBorder: kenar(Colors.white.withValues(alpha: 0.15)),
    focusedBorder: kenar(hesapVurgu),
    errorBorder: kenar(Colors.orangeAccent),
    focusedErrorBorder: kenar(Colors.orangeAccent),
  );
}

TextStyle hesapYazi({double boyut = 14, Color renk = Colors.white, FontWeight? kalinlik}) {
  return GoogleFonts.poppins(color: renk, fontSize: boyut, fontWeight: kalinlik);
}

void hesapMesaji(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj, style: GoogleFonts.poppins())));
}

/// Gradyan arka planlı, başlıklı sayfa iskeleti.
class HesapSayfasi extends StatelessWidget {
  const HesapSayfasi({super.key, required this.baslik, required this.child});

  final String baslik;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geriVar = Navigator.of(context).canPop();
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: hesapGradyani),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
                child: Row(
                  children: [
                    if (geriVar)
                      IconButton(
                        tooltip: 'Geri',
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        baslik,
                        maxLines: 2,
                        style: hesapYazi(boyut: 22, kalinlik: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fotoğraf yerine adın baş harfini gösteren yuvarlak avatar.
class HesapAvatari extends StatelessWidget {
  const HesapAvatari({super.key, required this.harf, this.boyut = 56});

  final String harf;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: boyut,
        height: boyut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hesapVurgu.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(harf, style: hesapYazi(boyut: boyut * 0.42, kalinlik: FontWeight.bold)),
      ),
    );
  }
}

/// Tam genişlikte ana düğme; [mesgul] iken dönen gösterge gösterir.
class HesapDugmesi extends StatelessWidget {
  const HesapDugmesi({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
    this.mesgul = false,
    this.ikincil = false,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final bool mesgul;
  final bool ikincil;

  @override
  Widget build(BuildContext context) {
    final icerik = mesgul
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  etiket,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
    final sekil = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));
    const dolgu = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    return SizedBox(
      width: double.infinity,
      child: ikincil
          ? OutlinedButton(
              onPressed: mesgul ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: dolgu,
                shape: sekil,
              ),
              child: icerik,
            )
          : ElevatedButton(
              onPressed: mesgul ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: hesapVurgu,
                foregroundColor: Colors.white,
                disabledBackgroundColor: hesapVurgu.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white70,
                padding: dolgu,
                shape: sekil,
              ),
              child: icerik,
            ),
    );
  }
}

/// Boş durum / hata / bilgi gösterimi; isteğe bağlı düğmelerle.
class HesapBilgi extends StatelessWidget {
  const HesapBilgi({super.key, required this.ikon, required this.mesaj, this.dugmeler = const []});

  final IconData ikon;
  final String mesaj;
  final List<Widget> dugmeler;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(mesaj, textAlign: TextAlign.center, style: hesapYazi(boyut: 15, renk: Colors.white70)),
            for (final dugme in dugmeler) ...[const SizedBox(height: 14), dugme],
          ],
        ),
      ),
    );
  }
}

class HesapYukleniyor extends StatelessWidget {
  const HesapYukleniyor({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

// ==========================================
// HESAP KAPISI
// ==========================================

/// Hesap gerektiren ekranların girişi: Firebase yoksa bilgi verir, giriş
/// yapılmamışsa giriş ekranını, yapılmışsa profil yüklendikten sonra [icerik]'i gösterir.
class HesapKapisi extends StatefulWidget {
  const HesapKapisi({super.key, required this.baslik, required this.icerik});

  final String baslik;
  final Widget Function(BuildContext context, Kullanici kullanici) icerik;

  @override
  State<HesapKapisi> createState() => _HesapKapisiState();
}

class _HesapKapisiState extends State<HesapKapisi> {
  late final Stream<String?> _oturum = HesapServisi.oturumuIzle();

  @override
  Widget build(BuildContext context) {
    if (!HesapServisi.hazir) {
      return HesapSayfasi(
        baslik: widget.baslik,
        child: const HesapBilgi(
          ikon: Icons.cloud_off_rounded,
          mesaj: 'Hesap özellikleri bu platformda kullanılamıyor.\nAndroid uygulamasında deneyebilirsin.',
        ),
      );
    }
    return StreamBuilder<String?>(
      stream: _oturum,
      builder: (context, anlik) {
        if (anlik.connectionState == ConnectionState.waiting) {
          return HesapSayfasi(baslik: widget.baslik, child: const HesapYukleniyor());
        }
        final uid = anlik.data;
        if (uid == null) return const GirisEkrani();
        return _ProfilYukleyici(key: ValueKey(uid), baslik: widget.baslik, icerik: widget.icerik);
      },
    );
  }
}

class _ProfilYukleyici extends StatefulWidget {
  const _ProfilYukleyici({super.key, required this.baslik, required this.icerik});

  final String baslik;
  final Widget Function(BuildContext context, Kullanici kullanici) icerik;

  @override
  State<_ProfilYukleyici> createState() => _ProfilYukleyiciState();
}

class _ProfilYukleyiciState extends State<_ProfilYukleyici> {
  StreamSubscription<Kullanici?>? _abonelik;
  Kullanici? _kullanici;
  String? _hata;
  bool _olusturuluyor = false;

  @override
  void initState() {
    super.initState();
    _dinle();
  }

  @override
  void dispose() {
    unawaited(_abonelik?.cancel());
    super.dispose();
  }

  void _dinle() {
    unawaited(_abonelik?.cancel());
    _hata = null;
    try {
      _abonelik = HesapServisi.profilimiIzle().listen(
        _profilGeldi,
        onError: (Object hata) {
          if (mounted) setState(() => _hata = HesapServisi.hataMesaji(hata));
        },
      );
    } catch (hata) {
      _hata = HesapServisi.hataMesaji(hata);
    }
  }

  void _profilGeldi(Kullanici? kullanici) {
    if (!mounted) return;
    if (kullanici == null) {
      // Girişli ama profil belgesi yok: sonradan oluştur.
      unawaited(_profiliOlustur());
      return;
    }
    setState(() {
      _kullanici = kullanici;
      _hata = null;
    });
  }

  Future<void> _profiliOlustur() async {
    if (_olusturuluyor) return;
    _olusturuluyor = true;
    try {
      await HesapServisi.profiliGarantile();
    } catch (hata) {
      if (mounted) setState(() => _hata = HesapServisi.hataMesaji(hata));
    } finally {
      _olusturuluyor = false;
    }
  }

  void _tekrarDene() {
    setState(_dinle);
  }

  Future<void> _cikis() async {
    try {
      await HesapServisi.cikisYap();
    } catch (hata) {
      if (mounted) hesapMesaji(context, HesapServisi.hataMesaji(hata));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = _kullanici;
    if (kullanici != null) return widget.icerik(context, kullanici);
    final hata = _hata;
    return HesapSayfasi(
      baslik: widget.baslik,
      child: hata == null
          ? const HesapYukleniyor()
          : HesapBilgi(
              ikon: Icons.error_outline_rounded,
              mesaj: 'Profilin yüklenemedi.\n$hata',
              dugmeler: [
                HesapDugmesi(etiket: 'Tekrar dene', ikon: Icons.refresh_rounded, onPressed: _tekrarDene),
                HesapDugmesi(etiket: 'Çıkış yap', ikincil: true, onPressed: _cikis),
              ],
            ),
    );
  }
}

// ==========================================
// GİRİŞ / KAYIT / ŞİFRE SIFIRLAMA EKRANI
// ==========================================

enum _GirisModu { giris, kayit, sifirla }

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _formAnahtari = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();

  _GirisModu _mod = _GirisModu.giris;
  bool _mesgul = false;
  bool _sifreGizli = true;
  String? _hata;
  String? _bilgi;

  @override
  void dispose() {
    _ad.dispose();
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  void _modDegistir(_GirisModu mod) {
    setState(() {
      _mod = mod;
      _hata = null;
      _bilgi = null;
    });
  }

  Future<void> _gonder() async {
    if (_mesgul) return;
    if (!(_formAnahtari.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mesgul = true;
      _hata = null;
      _bilgi = null;
    });
    String? hata;
    String? bilgi;
    try {
      switch (_mod) {
        case _GirisModu.giris:
          await HesapServisi.girisYap(eposta: _eposta.text, sifre: _sifre.text);
        case _GirisModu.kayit:
          await HesapServisi.kayitOl(ad: _ad.text, eposta: _eposta.text, sifre: _sifre.text);
        case _GirisModu.sifirla:
          await HesapServisi.sifreSifirla(_eposta.text);
          bilgi = 'Bu e-posta kayıtlıysa şifre sıfırlama bağlantısı gönderildi. '
              'Gelen kutunu (ve spam klasörünü) kontrol et.';
      }
    } catch (e) {
      hata = HesapServisi.hataMesaji(e);
    }
    // Başarılı girişte bu ekran yerini asıl sayfaya bırakmış olabilir.
    if (!mounted) return;
    setState(() {
      _mesgul = false;
      _hata = hata;
      _bilgi = bilgi;
      if (bilgi != null) _mod = _GirisModu.giris;
    });
  }

  String? _epostaDogrula(String? deger) {
    final metin = (deger ?? '').trim();
    if (metin.isEmpty) return 'E-posta adresini yaz.';
    if (!metin.contains('@') || !metin.contains('.')) return 'E-posta adresi geçerli değil.';
    return null;
  }

  String? _sifreDogrula(String? deger) {
    final metin = deger ?? '';
    if (metin.isEmpty) return 'Şifreni yaz.';
    if (_mod == _GirisModu.kayit && metin.length < 6) return 'Şifre en az 6 karakter olmalı.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (baslik, aciklama, dugme) = switch (_mod) {
      _GirisModu.giris => ('Giriş Yap', 'Eğitmenini ve profilini görmek için giriş yap.', 'Giriş yap'),
      _GirisModu.kayit => ('Kayıt Ol', 'Ücretsiz bir hesap oluştur.', 'Hesap oluştur'),
      _GirisModu.sifirla => (
          'Şifremi Unuttum',
          'E-posta adresini yaz, sana şifre sıfırlama bağlantısı gönderelim.',
          'Bağlantı gönder',
        ),
    };
    final hata = _hata;
    final bilgi = _bilgi;

    return HesapSayfasi(
      baslik: baslik,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Text(aciklama, style: hesapYazi(boyut: 15, renk: Colors.white70)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: hesapKartDekoru(),
            child: Form(
              key: _formAnahtari,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_mod == _GirisModu.kayit) ...[
                      TextFormField(
                        controller: _ad,
                        style: hesapYazi(boyut: 15),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 40,
                        decoration: hesapAlanDekoru('Adın', ikon: Icons.person_rounded).copyWith(counterText: ''),
                        validator: (deger) => (deger ?? '').trim().isEmpty ? 'Adını yaz.' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _eposta,
                      style: hesapYazi(boyut: 15),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: _mod == _GirisModu.sifirla ? TextInputAction.done : TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: hesapAlanDekoru('E-posta', ikon: Icons.mail_rounded),
                      validator: _epostaDogrula,
                      onFieldSubmitted: (_) {
                        if (_mod == _GirisModu.sifirla) unawaited(_gonder());
                      },
                    ),
                    if (_mod != _GirisModu.sifirla) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sifre,
                        style: hesapYazi(boyut: 15),
                        obscureText: _sifreGizli,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _mod == _GirisModu.kayit ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        decoration: hesapAlanDekoru(
                          'Şifre',
                          ikon: Icons.lock_rounded,
                          yardim: _mod == _GirisModu.kayit ? 'En az 6 karakter.' : null,
                          sonEk: IconButton(
                            tooltip: _sifreGizli ? 'Şifreyi göster' : 'Şifreyi gizle',
                            icon: Icon(
                              _sifreGizli ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
                          ),
                        ),
                        validator: _sifreDogrula,
                        onFieldSubmitted: (_) => unawaited(_gonder()),
                      ),
                    ],
                    if (hata != null) ...[
                      const SizedBox(height: 14),
                      _Uyari(ikon: Icons.error_outline_rounded, renk: Colors.orangeAccent, mesaj: hata),
                    ],
                    if (bilgi != null) ...[
                      const SizedBox(height: 14),
                      _Uyari(ikon: Icons.check_circle_outline_rounded, renk: Colors.greenAccent, mesaj: bilgi),
                    ],
                    const SizedBox(height: 18),
                    HesapDugmesi(etiket: dugme, mesgul: _mesgul, onPressed: () => unawaited(_gonder())),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_mod == _GirisModu.giris) ...[
            _Baglanti(etiket: 'Şifremi unuttum', onTap: () => _modDegistir(_GirisModu.sifirla)),
            _Baglanti(etiket: 'Hesabın yok mu? Kayıt ol', onTap: () => _modDegistir(_GirisModu.kayit)),
          ] else
            _Baglanti(
              etiket: _mod == _GirisModu.kayit ? 'Zaten hesabın var mı? Giriş yap' : 'Girişe dön',
              onTap: () => _modDegistir(_GirisModu.giris),
            ),
        ],
      ),
    );
  }
}

class _Uyari extends StatelessWidget {
  const _Uyari({required this.ikon, required this.renk, required this.mesaj});

  final IconData ikon;
  final Color renk;
  final String mesaj;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: renk, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(mesaj, style: hesapYazi(boyut: 13, renk: renk))),
        ],
      ),
    );
  }
}

class _Baglanti extends StatelessWidget {
  const _Baglanti({required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(etiket, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }
}
