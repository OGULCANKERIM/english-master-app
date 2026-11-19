import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeni_english/core/globals.dart';
import 'package:yeni_english/core/seviye.dart';
import 'package:yeni_english/core/temalar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('favoriler', () {
    test('gidiş-dönüş', () async {
      SharedPreferences.setMockInitialValues({});
      globalFavoriSahneler = [
        {'video': 'a.mp4', 'ceviri': 'şöyle'}
      ];
      await favorileriKaydet();
      globalFavoriSahneler = [];
      await favorileriYukle();
      expect(globalFavoriSahneler, [
        {'video': 'a.mp4', 'ceviri': 'şöyle'}
      ]);
    });

    test('bozuk kayıt çökmez, liste boş kalır', () async {
      SharedPreferences.setMockInitialValues({'favori_sahneler': 'xx'});
      globalFavoriSahneler = [];
      await favorileriYukle();
      expect(globalFavoriSahneler, isEmpty);
    });

    test('liste olmayan kayıt çökmez', () async {
      SharedPreferences.setMockInitialValues({'favori_sahneler': '{"a":1}'});
      globalFavoriSahneler = [];
      await favorileriYukle();
      expect(globalFavoriSahneler, isEmpty);
    });
  });

  group('yardımcılar', () {
    test('alan', () {
      expect(alan({'a': ' x '}, 'a'), 'x');
      expect(alan({'a': null}, 'a'), '');
      expect(alan(null, 'a'), '');
      expect(alan({'a': 5}, 'a'), '5');
    });

    test('jsonListeCoz UTF-8 çözer, liste değilse boş döner', () {
      final liste = jsonListeCoz(http.Response.bytes(utf8.encode('[{"k":"çğş"}]'), 200));
      expect(liste, [
        {'k': 'çğş'}
      ]);
      expect(jsonListeCoz(http.Response.bytes(utf8.encode('{"error":"x"}'), 200)), isEmpty);
    });
  });

  group('tema', () {
    // Test ortamında Poppins yazı tipi indirilemez; temalar ilk kez burada, yazı tipi
    // hatasını yutan bir bölgede kurulur ki asıl testleri düşürmesin.
    setUpAll(() async {
      await runZonedGuarded(() async {
        AppThemes.themes;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }, (_, _) {});
    });

    test('5 tema var', () => expect(AppThemes.themes.length, 5));

    test('kaydet ve yükle', () async {
      SharedPreferences.setMockInitialValues({});
      await temaKaydet(3);
      appThemeNotifier.value = 0;
      await temaYukle();
      expect(appThemeNotifier.value, 3);
    });

    test('aralık dışı kayıt 0 olur', () async {
      SharedPreferences.setMockInitialValues({'app_theme_index': 9});
      appThemeNotifier.value = 2;
      await temaYukle();
      expect(appThemeNotifier.value, 0);
      SharedPreferences.setMockInitialValues({'app_theme_index': -1});
      await temaYukle();
      expect(appThemeNotifier.value, 0);
    });

    test('aralık dışı tema kaydedilmez', () async {
      SharedPreferences.setMockInitialValues({});
      appThemeNotifier.value = 1;
      await temaKaydet(7);
      expect(appThemeNotifier.value, 1);
    });

    test('her temada gövde yazısı arka plandan ayırt edilir', () {
      for (final ThemeData tema in AppThemes.themes) {
        final yazi = tema.textTheme.bodyLarge!.color!;
        final zemin = tema.scaffoldBackgroundColor;
        expect((yazi.computeLuminance() - zemin.computeLuminance()).abs(), greaterThan(0.4));
      }
    });
  });

  group('seviye', () {
    test('profil seviyesi önceliklidir', () async {
      SharedPreferences.setMockInitialValues({'userLevel': 'C1'});
      expect(await mevcutSeviye(profilSeviyesi: () async => 'B2'), 'B2');
    });
    test('profil yoksa yerel değer', () async {
      SharedPreferences.setMockInitialValues({'userLevel': 'C1'});
      expect(await mevcutSeviye(profilSeviyesi: () async => null), 'C1');
    });
    test('hiçbiri yoksa A2', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await mevcutSeviye(profilSeviyesi: () async => null), 'A2');
    });
    test('profil hata verirse yerel değere düşer', () async {
      SharedPreferences.setMockInitialValues({'userLevel': 'B1'});
      expect(await mevcutSeviye(profilSeviyesi: () async => throw Exception('ağ yok')), 'B1');
    });
    test('geçersiz yerel değer A2 sayılır', () async {
      SharedPreferences.setMockInitialValues({'userLevel': 'Z9'});
      expect(await mevcutSeviye(profilSeviyesi: () async => null), 'A2');
    });
    test('yerelSeviyeyiKaydet', () async {
      SharedPreferences.setMockInitialValues({});
      await yerelSeviyeyiKaydet('B2');
      expect(await mevcutSeviye(profilSeviyesi: () async => null), 'B2');
    });
  });
}
