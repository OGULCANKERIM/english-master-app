import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeni_english/core/claude_servisi.dart';
import 'package:yeni_english/services/ai_coach_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('novaIstemi', () {
    test('adı, seviyeyi ve kelime sayısını içerir', () {
      final istem = AiCoachSystem.novaIstemi(
        ekran: 'KelimeModulu',
        ad: 'Deniz',
        seviye: 'B1',
        veri: {'currentType': 'Verb', 'learnedCount': 7},
      );
      expect(istem, contains('Deniz'));
      expect(istem, contains('B1'));
      expect(istem, contains('7'));
      expect(istem, contains('Verb'));
    });

    test('bilinmeyen ekran ve veri olmadan çökmez', () {
      expect(AiCoachSystem.novaIstemi(ekran: 'YokBöyleEkran', ad: 'A', seviye: 'A2'), contains('A2'));
      expect(AiCoachSystem.novaIstemi(ekran: 'KelimeModulu', ad: 'A', seviye: 'A2', veri: const {}), isNotEmpty);
    });

    test('her bilinen ekranın kendi bağlamı var', () {
      final ekranlar = ['AnaMenu', 'KelimeModulu', 'TestEkrani', 'SpeakingView', 'ProfileScreen', 'Eşleştirme', 'ReadingView'];
      final istemler = ekranlar.map((e) => AiCoachSystem.novaIstemi(ekran: e, ad: 'A', seviye: 'A2')).toSet();
      expect(istemler.length, ekranlar.length);
    });
  });

  group('getLiveAdviceForScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Claude yanıtını döndürür', () async {
      final servis = ClaudeServisi(
        anahtar: 'k',
        istemci: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Go! Harikasın!'}
              ]
            })),
            200)),
      );
      expect(await AiCoachSystem.getLiveAdviceForScreen('AnaMenu', servis: servis), 'Go! Harikasın!');
    });

    test('hata olursa hata atmaz, yedek cümle döner', () async {
      final servis = ClaudeServisi(anahtar: 'k', istemci: MockClient((_) async => http.Response('{}', 500)));
      expect(await AiCoachSystem.getLiveAdviceForScreen('AnaMenu', servis: servis), contains('keep pushing forward'));
    });

    test('geçersiz anahtar gibi kalıcı hatada gerçek nedeni söyler', () async {
      final servis = ClaudeServisi(anahtar: 'k', istemci: MockClient((_) async => http.Response('{}', 401)));
      expect(await AiCoachSystem.getLiveAdviceForScreen('AnaMenu', servis: servis), contains('API key is invalid'));
    });

    test('anahtar yoksa bunu açıkça söyler', () async {
      final servis = ClaudeServisi(anahtar: '', istemci: MockClient((_) async => http.Response('{}', 200)));
      expect(await AiCoachSystem.getLiveAdviceForScreen('AnaMenu', servis: servis), contains('ANTHROPIC_API_KEY'));
    });
  });
}
