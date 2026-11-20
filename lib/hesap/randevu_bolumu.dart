import 'dart:async';

import 'package:flutter/material.dart';

import '../core/randevu.dart';
import 'giris_ekrani.dart';

// ==========================================
// EĞİTMENİN KENDİ ÖĞRENCİLERİ VE SPEAKING RANDEVULARI
// ==========================================

/// Eğitmen panelindeki "Speaking randevuları" bölümü. Eğitmen öğrenci ekler, her öğrenciye
/// haftalık bir speaking günü ve saati verir. Liste en yakın randevuya göre sıralanır.
class RandevuBolumu extends StatefulWidget {
  const RandevuBolumu({super.key, required this.egitmenId});

  final String egitmenId;

  @override
  State<RandevuBolumu> createState() => _RandevuBolumuState();
}

class _RandevuBolumuState extends State<RandevuBolumu> {
  late final RandevuDeposu _depo = RandevuDeposu(widget.egitmenId);
  List<OgrenciKaydi>? _ogrenciler;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    unawaited(_yukle());
  }

  Future<void> _yukle() async {
    try {
      final liste = await _depo.yukle();
      if (mounted) setState(() { _ogrenciler = liste; _hata = false; });
    } catch (e) {
      debugPrint("Öğrenciler yüklenemedi: $e");
      if (mounted) setState(() => _hata = true);
    }
  }

  Future<void> _kaydet(List<OgrenciKaydi> yeni) async {
    setState(() => _ogrenciler = yeni);
    try {
      await _depo.kaydet(yeni);
    } catch (e) {
      debugPrint("Öğrenciler kaydedilemedi: $e");
      if (mounted) hesapMesaji(context, 'Değişiklik kaydedilemedi. Lütfen tekrar dene.');
    }
  }

  Future<void> _duzenle([OgrenciKaydi? mevcut]) async {
    final sonuc = await showModalBottomSheet<OgrenciKaydi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF24243e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _OgrenciFormu(mevcut: mevcut),
    );
    if (sonuc == null || !mounted) return;
    final liste = List<OgrenciKaydi>.of(_ogrenciler ?? const []);
    final int sira = liste.indexWhere((o) => o.id == sonuc.id);
    if (sira >= 0) {
      liste[sira] = sonuc;
    } else {
      liste.add(sonuc);
    }
    await _kaydet(liste);
  }

  Future<void> _sil(OgrenciKaydi ogrenci) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (diyalog) => AlertDialog(
        title: const Text('Öğrenciyi sil'),
        content: Text('${ogrenci.ad} ve speaking randevusu silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(diyalog).pop(false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.of(diyalog).pop(true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    await _kaydet([for (final o in _ogrenciler ?? const <OgrenciKaydi>[]) if (o.id != ogrenci.id) o]);
  }

  @override
  Widget build(BuildContext context) {
    final ogrenciler = _ogrenciler;
    final simdi = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Speaking randevuları${ogrenciler == null ? '' : ' (${ogrenciler.length})'}',
                style: hesapYazi(boyut: 17, kalinlik: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: ogrenciler == null ? null : () => unawaited(_duzenle()),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Öğrenci ekle'),
              style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_hata)
          HesapBilgi(
            ikon: Icons.error_outline_rounded,
            mesaj: 'Öğrenciler yüklenemedi.',
            dugmeler: [HesapDugmesi(etiket: 'Tekrar dene', ikon: Icons.refresh_rounded, onPressed: () => unawaited(_yukle()))],
          )
        else if (ogrenciler == null)
          const Padding(padding: EdgeInsets.all(20), child: HesapYukleniyor())
        else if (ogrenciler.isEmpty)
          const HesapBilgi(
            ikon: Icons.event_available_rounded,
            mesaj: 'Henüz öğrenci eklemedin.\n"Öğrenci ekle" ile ilk speaking randevunu oluştur.',
          )
        else
          for (final ogrenci in randevuyaGoreSirala(ogrenciler, simdi))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RandevuKarti(
                ogrenci: ogrenci,
                simdi: simdi,
                onDuzenle: () => unawaited(_duzenle(ogrenci)),
                onSil: () => unawaited(_sil(ogrenci)),
              ),
            ),
        if (ogrenciler != null && ogrenciler.isNotEmpty)
          Text(
            'Bu liste yalnızca bu telefonda saklanır.',
            style: hesapYazi(boyut: 12, renk: Colors.white38),
          ),
      ],
    );
  }
}

class _RandevuKarti extends StatelessWidget {
  const _RandevuKarti({required this.ogrenci, required this.simdi, required this.onDuzenle, required this.onSil});

  final OgrenciKaydi ogrenci;
  final DateTime simdi;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDuzenle,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(15, 12, 6, 12),
          decoration: hesapKartDekoru(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HesapAvatari(harf: ogrenci.basHarf, boyut: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ogrenci.ad, style: hesapYazi(boyut: 16, kalinlik: FontWeight.w600)),
                    Text('Seviye: ${ogrenci.seviye}', style: hesapYazi(boyut: 13, renk: Colors.lightBlueAccent)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_rounded, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Her ${ogrenci.gunAdi} ${ogrenci.saatMetni}',
                            style: hesapYazi(boyut: 14, renk: Colors.amberAccent, kalinlik: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Text('Sıradaki: ${ogrenci.neZaman(simdi)}', style: hesapYazi(boyut: 13, renk: Colors.white70)),
                    if (ogrenci.konu.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Konu: ${ogrenci.konu}', style: hesapYazi(boyut: 13, renk: Colors.white60)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '${ogrenci.ad} kaydını sil',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: onSil,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Öğrenci ekleme / düzenleme formu. Kaydedilince [OgrenciKaydi] ile kapanır.
class _OgrenciFormu extends StatefulWidget {
  const _OgrenciFormu({this.mevcut});

  final OgrenciKaydi? mevcut;

  @override
  State<_OgrenciFormu> createState() => _OgrenciFormuState();
}

class _OgrenciFormuState extends State<_OgrenciFormu> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ad = TextEditingController(text: widget.mevcut?.ad ?? '');
  late final TextEditingController _konu = TextEditingController(text: widget.mevcut?.konu ?? '');
  late String _seviye = widget.mevcut?.seviye ?? 'A2';
  late int _gun = widget.mevcut?.gun ?? DateTime.now().weekday;
  late TimeOfDay _saat = TimeOfDay(hour: widget.mevcut?.saat ?? 19, minute: widget.mevcut?.dakika ?? 0);

  @override
  void dispose() {
    _ad.dispose();
    _konu.dispose();
    super.dispose();
  }

  Future<void> _saatSec() async {
    final secilen = await showTimePicker(
      context: context,
      initialTime: _saat,
      helpText: 'Speaking saati',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (secilen != null && mounted) setState(() => _saat = secilen);
  }

  void _kaydet() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(OgrenciKaydi(
      id: widget.mevcut?.id ?? 'o-${DateTime.now().microsecondsSinceEpoch}',
      ad: _ad.text.trim(),
      seviye: _seviye,
      gun: _gun,
      saat: _saat.hour,
      dakika: _saat.minute,
      konu: _konu.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final String saatMetni = '${_saat.hour.toString().padLeft(2, '0')}:${_saat.minute.toString().padLeft(2, '0')}';
    return Padding(
      // Klavye açılınca form yukarı kayar.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.mevcut == null ? 'Öğrenci ekle' : 'Öğrenciyi düzenle',
                style: hesapYazi(boyut: 19, kalinlik: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ad,
                style: hesapYazi(boyut: 15),
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: hesapAlanDekoru('Öğrencinin adı', ikon: Icons.person_rounded),
                validator: (deger) => (deger ?? '').trim().isEmpty ? 'Ad boş olamaz.' : null,
              ),
              const SizedBox(height: 6),
              Text('Seviye', style: hesapYazi(boyut: 13, renk: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final seviye in randevuSeviyeleri)
                    ChoiceChip(
                      label: Text(seviye),
                      selected: _seviye == seviye,
                      onSelected: (_) => setState(() => _seviye = seviye),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Speaking günü', style: hesapYazi(boyut: 13, renk: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < randevuGunleri.length; i++)
                    ChoiceChip(
                      label: Text(randevuGunleri[i]),
                      selected: _gun == i + 1,
                      onSelected: (_) => setState(() => _gun = i + 1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => unawaited(_saatSec()),
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Saat: $saatMetni'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _konu,
                style: hesapYazi(boyut: 15),
                maxLength: 60,
                decoration: hesapAlanDekoru('Konu / not (isteğe bağlı)', ikon: Icons.topic_rounded),
              ),
              const SizedBox(height: 8),
              HesapDugmesi(etiket: 'Kaydet', ikon: Icons.check_rounded, onPressed: _kaydet),
            ],
          ),
        ),
      ),
    );
  }
}
