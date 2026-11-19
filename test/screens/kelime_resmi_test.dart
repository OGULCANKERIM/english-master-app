import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yeni_english/screens/kelime_modulu.dart';

void main() {
  test('anahtar yoksa null döner ve istek atılmaz', () async {
    var istekSayisi = 0;
    final istemci = MockClient((_) async {
      istekSayisi++;
      return http.Response('{}', 200);
    });
    expect(await kelimeResmiGetir('apple', istemci: istemci, anahtar: ''), isNull);
    expect(istekSayisi, 0);
  });

  test('ilk sonucun adresini döner, kelimeyi URL için kodlar', () async {
    late Uri istenen;
    final istemci = MockClient((istek) async {
      istenen = istek.url;
      return http.Response('{"hits":[{"webformatURL":"https://x/u.jpg"},{"webformatURL":"https://x/v.jpg"}]}', 200);
    });
    expect(await kelimeResmiGetir('ice cream', istemci: istemci, anahtar: 'k'), 'https://x/u.jpg');
    expect(istenen.host, 'pixabay.com');
    expect(istenen.queryParameters['q'], 'ice cream');
    expect(istenen.queryParameters['key'], 'k');
  });

  test('sonuç yoksa, hata kodunda ya da bozuk yanıtta null döner', () async {
    Future<String?> dene(http.Response yanit) =>
        kelimeResmiGetir('apple', istemci: MockClient((_) async => yanit), anahtar: 'k');
    expect(await dene(http.Response('{"hits":[]}', 200)), isNull);
    expect(await dene(http.Response('{}', 200)), isNull);
    expect(await dene(http.Response('oops', 500)), isNull);
    expect(await dene(http.Response('<html>', 200)), isNull);
    expect(await dene(http.Response('{"hits":[{"webformatURL":5}]}', 200)), isNull);
  });

  test('ağ hatasında null döner', () async {
    final istemci = MockClient((_) async => throw const SocketException('yok'));
    expect(await kelimeResmiGetir('apple', istemci: istemci, anahtar: 'k'), isNull);
  });
}
