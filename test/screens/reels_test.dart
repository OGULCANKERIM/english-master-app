import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/core/video_onbellek.dart';
import 'package:yeni_english/screens/reels_modulu.dart';

void main() {
  group('reelBasligi', () {
    test('ad yoksa video dosyasından türetilir', () {
      expect(reelBasligi({'videoUrl': 'https://example.com/videos/17.mp4'}), 'Reel 17');
      expect(reelBasligi({'videoUrl': 'https://example.com/v/friends_coffee-scene.mp4'}), 'friends coffee scene');
      expect(reelBasligi({'videoUrl': 'https://example.com/v/my%20clip.mp4'}), 'my clip');
    });

    test('tablodaki ya da kullanıcının verdiği ad önceliklidir', () {
      expect(reelBasligi({'videoUrl': 'https://example.com/1.mp4', 'baslik': 'Friends – kahve sahnesi'}), 'Friends – kahve sahnesi');
      expect(reelBasligi({'videoUrl': 'https://example.com/1.mp4', 'kaynak': 'The Office'}), 'The Office');
      expect(reelBasligi({'videoUrl': 'https://example.com/1.mp4', 'baslik': '  '}), 'Reel 1');
    });

    test('aynı video her zaman aynı adı alır, sıraya bağlı değildir', () {
      final a = {'videoUrl': 'https://example.com/9.mp4'};
      expect(reelBasligi(a), reelBasligi(Map<String, dynamic>.from(a)));
    });

    test('bozuk veride çökmez', () {
      expect(reelBasligi(null), 'Reel');
      expect(reelBasligi({'videoUrl': ''}), 'Reel');
      expect(reelBasligi({'videoUrl': 'https://example.com/%E0%A4%A.mp4'}), isNotEmpty);
    });
  });

  group('video önbelleği', () {
    test('dosya adı güvenli, kararlı ve adrese özgüdür', () {
      final a = videoDosyaAdi('https://example.com/a/1.mp4');
      expect(a, videoDosyaAdi('https://example.com/a/1.mp4'));
      expect(a, isNot(videoDosyaAdi('https://example.com/b/1.mp4')));
      expect(a, matches(RegExp(r'^[0-9a-f]{8}_[A-Za-z0-9._-]+$')));
      expect(videoDosyaAdi('https://example.com/x/çok uzun ad?.mp4'), matches(RegExp(r'^[0-9a-f]{8}_[A-Za-z0-9._-]+$')));
      expect(videoDosyaAdi(''), endsWith('_video'));
    });

    test('sınır aşılınca en eski dosyalar silinir, yeniler kalır', () {
      final dosyalar = [
        (oge: 'eski', boyut: 100, degisim: DateTime(2026, 1, 1)),
        (oge: 'yeni', boyut: 100, degisim: DateTime(2026, 3, 1)),
        (oge: 'orta', boyut: 100, degisim: DateTime(2026, 2, 1)),
      ];
      expect(silinecekEskiler(dosyalar, 250), ['eski']);
      expect(silinecekEskiler(dosyalar, 1000), isEmpty);
      expect(silinecekEskiler(dosyalar, 50), ['yeni', 'orta', 'eski']);
    });
  });
}
