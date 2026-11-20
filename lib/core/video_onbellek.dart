import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Adresin son yol parçası ("https://x/y/17.mp4?z=1" -> "17.mp4"). Bozuk kodlanmış adreslerde
/// de hata atmaz (Uri.pathSegments atar).
String urlSonParcasi(String url) {
  final String yol = url.split('?').first.split('#').first;
  return yol.substring(yol.lastIndexOf('/') + 1);
}

/// Bir video adresinden, önbellekte kullanılacak güvenli ve benzersiz dosya adı üretir.
String videoDosyaAdi(String url) {
  // FNV-1a (32 bit): aynı adres her zaman aynı adı verir, farklı adresler çakışmaz.
  int ozet = 0x811c9dc5;
  for (final birim in url.codeUnits) {
    ozet ^= birim;
    ozet = (ozet * 0x01000193) & 0xFFFFFFFF;
  }
  final String son = urlSonParcasi(url);
  final String temiz = son.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final String kisa = temiz.length > 40 ? temiz.substring(temiz.length - 40) : temiz;
  return '${ozet.toRadixString(16).padLeft(8, '0')}_${kisa.isEmpty ? 'video' : kisa}';
}

/// Toplam boyut [sinir]ı aşıyorsa en eski dosyalardan başlayarak silinecekleri seçer.
List<T> silinecekEskiler<T>(List<({T oge, int boyut, DateTime degisim})> dosyalar, int sinir) {
  final sirali = [...dosyalar]..sort((a, b) => b.degisim.compareTo(a.degisim)); // yeniden eskiye
  int toplam = 0;
  final silinecek = <T>[];
  for (final d in sirali) {
    toplam += d.boyut;
    if (toplam > sinir) silinecek.add(d.oge);
  }
  return silinecek;
}

/// Reels videolarını telefona indirip saklar. İnen video dosyadan oynatıldığı için takılmaz;
/// aynı video (ör. favoriler) yeniden izlenirken internet kullanılmaz.
class VideoOnbellek {
  VideoOnbellek._();

  static const int _sinirBayt = 300 * 1024 * 1024;

  static Directory? _klasor;
  static final Map<String, Future<File?>> _suren = {};

  static Future<Directory?> _klasoruAl() async {
    if (kIsWeb) return null;
    final mevcut = _klasor;
    if (mevcut != null) return mevcut;
    try {
      final klasor = Directory('${(await getTemporaryDirectory()).path}/reels');
      await klasor.create(recursive: true);
      return _klasor = klasor;
    } catch (e) {
      debugPrint("Video önbelleği açılamadı: $e");
      return null;
    }
  }

  /// Video daha önce tamamen indiyse dosyasını, yoksa null döndürür.
  static Future<File?> hazirDosya(String url) async {
    final klasor = await _klasoruAl();
    if (klasor == null) return null;
    final dosya = File('${klasor.path}/${videoDosyaAdi(url)}');
    try {
      return await dosya.exists() ? dosya : null;
    } catch (_) {
      return null;
    }
  }

  /// Videoyu indirir (zaten indiyse hemen döner). Başarısız olursa null döner; hata atmaz.
  /// Aynı adres için aynı anda tek indirme yapılır.
  static Future<File?> indir(String url) {
    return _suren[url] ??= _indir(url).whenComplete(() => _suren.remove(url));
  }

  static Future<File?> _indir(String url) async {
    final hazir = await hazirDosya(url);
    if (hazir != null) return hazir;
    final klasor = await _klasoruAl();
    final adres = Uri.tryParse(url);
    if (klasor == null || adres == null || !adres.hasScheme) return null;

    final hedef = File('${klasor.path}/${videoDosyaAdi(url)}');
    final gecici = File('${hedef.path}.part');
    final istemci = http.Client();
    try {
      final yanit = await istemci.send(http.Request('GET', adres)).timeout(const Duration(seconds: 30));
      if (yanit.statusCode != 200) return null;
      final yazici = gecici.openWrite();
      int yazilan = 0;
      try {
        await for (final parca in yanit.stream.timeout(const Duration(seconds: 30))) {
          yazici.add(parca);
          yazilan += parca.length;
        }
      } finally {
        await yazici.close();
      }
      // Yarım inen dosya oynatılmasın: boyut sunucunun bildirdiğiyle aynı olmalı.
      final beklenen = yanit.contentLength;
      if (yazilan == 0 || (beklenen != null && beklenen != yazilan)) {
        await gecici.delete();
        return null;
      }
      return await gecici.rename(hedef.path);
    } catch (e) {
      debugPrint("Video indirilemedi: $e");
      try {
        if (await gecici.exists()) await gecici.delete();
      } catch (_) {}
      return null;
    } finally {
      istemci.close();
    }
  }

  /// Önbellek sınırı aşıldıysa en eski videoları ve yarım kalmış indirmeleri siler.
  static Future<void> temizle() async {
    final klasor = await _klasoruAl();
    if (klasor == null) return;
    try {
      final dosyalar = <({File oge, int boyut, DateTime degisim})>[];
      await for (final oge in klasor.list()) {
        if (oge is! File) continue;
        if (oge.path.endsWith('.part')) {
          if (_suren.isEmpty) await oge.delete();
          continue;
        }
        final bilgi = await oge.stat();
        dosyalar.add((oge: oge, boyut: bilgi.size, degisim: bilgi.modified));
      }
      for (final dosya in silinecekEskiler(dosyalar, _sinirBayt)) {
        await dosya.delete();
      }
    } catch (e) {
      debugPrint("Video önbelleği temizlenemedi: $e");
    }
  }
}
