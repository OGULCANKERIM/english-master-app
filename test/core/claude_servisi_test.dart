import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yeni_english/core/claude_servisi.dart';

http.Response _yanit(Object govde, [int kod = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(govde)), kod, headers: {'content-type': 'application/json'});

ClaudeServisi _servis(MockClientHandler isleyici, {String anahtar = 'test-anahtar'}) =>
    ClaudeServisi(istemci: MockClient(isleyici), anahtar: anahtar, model: 'claude-haiku-5-5');

const _mesajlar = [
  {'role': 'user', 'content': 'hi'}
];

void main() {
  test('anahtar yoksa ClaudeHatasi ve istek atılmaz', () async {
    var istekSayisi = 0;
    final servis = _servis((_) async {
      istekSayisi++;
      return _yanit({});
    }, anahtar: '');
    await expectLater(
      servis.gonder(sistem: 's', mesajlar: _mesajlar),
      throwsA(isA<ClaudeHatasi>().having((h) => h.kullaniciMesaji, 'mesaj', contains('ANTHROPIC_API_KEY'))),
    );
    expect(istekSayisi, 0);
  });

  test('istek biçimi', () async {
    late http.Request yakalanan;
    final servis = _servis((istek) async {
      yakalanan = istek;
      return _yanit({
        'content': [
          {'type': 'text', 'text': 'ok'}
        ]
      });
    });
    await servis.gonder(sistem: 'SİSTEM', mesajlar: _mesajlar);
    expect(yakalanan.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(yakalanan.headers['x-api-key'], 'test-anahtar');
    expect(yakalanan.headers['anthropic-version'], '2026-10-21');
    final govde = jsonDecode(utf8.decode(yakalanan.bodyBytes)) as Map<String, dynamic>;
    expect(govde['model'], 'claude-haiku-5-5');
    expect(govde['system'], 'SİSTEM');
    expect(govde['messages'], _mesajlar);
    expect(govde['output_config'], {'effort': 'low'});
    expect(govde['max_tokens'], 4096);
  });

  test('metin bloklarını birleştirir, Türkçe karakter bozulmaz', () async {
    final servis = _servis((_) async => _yanit({
          'content': [
            {'type': 'text', 'text': 'Hi'},
            {'type': 'thinking', 'thinking': 'x'},
            {'type': 'text', 'text': 'şöyle'}
          ]
        }));
    final yanit = await servis.gonder(sistem: 's', mesajlar: _mesajlar);
    expect(yanit.metin, 'Hi şöyle');
    expect(yanit.icerik.length, 3);
  });

  test('durum kodları anlaşılır mesaja çevrilir', () async {
    Future<String> mesaj(int kod) async {
      final servis = _servis((_) async => _yanit({
            'error': {'message': 'x'}
          }, kod));
      try {
        await servis.gonder(sistem: 's', mesajlar: _mesajlar);
      } on ClaudeHatasi catch (h) {
        return h.kullaniciMesaji;
      }
      return '';
    }

    expect(await mesaj(401), contains('API key is invalid'));
    expect(await mesaj(429), contains('Too many requests'));
    expect(await mesaj(529), contains('busy'));
    expect(await mesaj(500), contains('x'));
  });

  test('geçici ve kalıcı hatalar ayırt edilir', () async {
    Future<bool> gecici(int kod) async {
      final servis = _servis((_) async => _yanit({}, kod));
      try {
        await servis.gonder(sistem: 's', mesajlar: _mesajlar);
      } on ClaudeHatasi catch (h) {
        return h.baglantiSorunu;
      }
      return false;
    }

    expect(await gecici(429), isTrue);
    expect(await gecici(529), isTrue);
    expect(await gecici(500), isTrue);
    expect(await gecici(401), isFalse);
    expect(await gecici(404), isFalse);
  });

  test('JSON olmayan hata gövdesi çökmez', () async {
    final servis = _servis((_) async => http.Response('<html>bad gateway</html>', 502));
    await expectLater(servis.gonder(sistem: 's', mesajlar: _mesajlar), throwsA(isA<ClaudeHatasi>()));
  });

  test('refusal ClaudeHatasi verir', () async {
    final servis = _servis((_) async => _yanit({'stop_reason': 'refusal', 'content': []}));
    await expectLater(servis.gonder(sistem: 's', mesajlar: _mesajlar), throwsA(isA<ClaudeHatasi>()));
  });

  test('boş yanıt ClaudeHatasi verir', () async {
    final servis = _servis((_) async => _yanit({'content': []}));
    await expectLater(servis.gonder(sistem: 's', mesajlar: _mesajlar), throwsA(isA<ClaudeHatasi>()));
  });

  test('ağ hatası ClaudeHatasi verir', () async {
    final servis = _servis((_) async => throw const SocketException('yok'));
    await expectLater(
      servis.gonder(sistem: 's', mesajlar: _mesajlar),
      throwsA(isA<ClaudeHatasi>().having((h) => h.kullaniciMesaji, 'mesaj', contains('internet'))),
    );
  });

  group('jsonIste', () {
    ClaudeServisi metinle(String metin) => _servis((_) async => _yanit({
          'content': [
            {'type': 'text', 'text': metin}
          ]
        }));

    test('çitli blok', () async {
      expect(await metinle('```json\n{"skor": 80}\n```').jsonIste(sistem: 's', istem: 'i'), {'skor': 80});
    });
    test('metin içinde JSON', () async {
      expect(await metinle('Sure! {"a":1} hope it helps').jsonIste(sistem: 's', istem: 'i'), {'a': 1});
    });
    test('bozuk JSON ClaudeHatasi verir', () async {
      await expectLater(metinle('not json').jsonIste(sistem: 's', istem: 'i'), throwsA(isA<ClaudeHatasi>()));
      await expectLater(metinle('{broken').jsonIste(sistem: 's', istem: 'i'), throwsA(isA<ClaudeHatasi>()));
      await expectLater(metinle('[1,2]').jsonIste(sistem: 's', istem: 'i'), throwsA(isA<ClaudeHatasi>()));
    });
  });
}
