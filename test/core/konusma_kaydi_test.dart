import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/core/konusma_kaydi.dart';

KayitliSohbet _ornek([String konu = 'a']) => KayitliSohbet(
      sistem: 'sistem $konu',
      mesajlar: [
        {'gonderen': 'AI', 'metin': 'Hello şöyle', 'ceviriGoster': 'false'},
        {'gonderen': 'Sen', 'metin': 'Hi'},
      ],
      gecmis: [
        {'role': 'user', 'content': 'start'},
        {'role': 'assistant', 'content': 'Hello şöyle'},
        {'role': 'user', 'content': 'Hi'},
      ],
    );

void main() {
  test('gidiş-dönüş', () {
    final cozulen = kayitliSohbetleriCoz(kayitliSohbetleriKodla([_ornek('a'), _ornek('b')]));
    expect(cozulen.length, 2);
    expect(cozulen[1].sistem, 'sistem b');
    expect(cozulen[0].mesajlar.first['metin'], 'Hello şöyle');
    expect(cozulen[0].gecmis.length, 3);
    expect(cozulen[0].gecmis.last, {'role': 'user', 'content': 'Hi'});
  });

  test('kayıt yoksa ya da bozuksa boş liste', () {
    expect(kayitliSohbetleriCoz(null), isEmpty);
    expect(kayitliSohbetleriCoz(''), isEmpty);
    expect(kayitliSohbetleriCoz('xx{'), isEmpty);
    expect(kayitliSohbetleriCoz('{"a":1}'), isEmpty);
  });

  test('bozuk sohbet atlanır, sağlam olan kalır', () {
    final ham = json.encode([
      {'mesajlar': 'yanlış tür', 'gecmis': []},
      _ornek().toJson(),
      5,
      {
        'sistem': 's',
        'mesajlar': [
          {'gonderen': 'AI', 'metin': 'x'}
        ],
        // Eski Gemini biçimi: Claude bunu kabul etmez, sohbet atlanmalı.
        'gecmis': [
          {
            'role': 'model',
            'parts': [
              {'text': 'x'}
            ]
          }
        ],
      },
    ]);
    expect(kayitliSohbetleriCoz(ham).length, 1);
  });

  test('gecmisGecerli', () {
    expect(gecmisGecerli([]), isFalse);
    expect(gecmisGecerli([
      {'role': 'assistant', 'content': 'a'}
    ]), isFalse);
    expect(gecmisGecerli([
      {'role': 'user', 'content': 'a'},
      {'role': 'user', 'content': 'b'}
    ]), isFalse);
    expect(gecmisGecerli([
      {'role': 'user', 'content': 'a'},
      {'role': 'assistant', 'content': 'b'}
    ]), isTrue);
  });

  test('en fazla 30 sohbet saklanır, en yeniler kalır', () {
    final hepsi = List.generate(35, (i) => _ornek('$i'));
    final cozulen = kayitliSohbetleriCoz(kayitliSohbetleriKodla(hepsi));
    expect(cozulen.length, 30);
    expect(cozulen.first.sistem, 'sistem 5');
    expect(cozulen.last.sistem, 'sistem 34');
  });
}
