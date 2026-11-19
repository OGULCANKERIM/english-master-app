import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/core/konusma_kaydi.dart';

KayitliSohbet _ornek([String konu = 'a']) => KayitliSohbet(
      konu: 'Konu $konu',
      mod: 'fun',
      seviye: 'B1',
      sistem: 'sistem $konu',
      mesajlar: [
        {'gonderen': 'AI', 'metin': 'Hello şöyle', 'ceviriGoster': 'false'},
        {'gonderen': 'Sen', 'metin': 'Hi'},
      ],
      gecmis: [
        {'role': 'user', 'content': 'start'},
        {'role': 'assistant', 'content': 'Hello şöyle'},
        {'role': 'user', 'content': 'Hi'},
        {'role': 'assistant', 'content': 'Nice to meet you'},
      ],
    );

void main() {
  test('gidiş-dönüş', () {
    final cozulen = kayitliSohbetleriCoz(kayitliSohbetleriKodla([_ornek('a'), _ornek('b')]));
    expect(cozulen.length, 2);
    expect(cozulen[1].sistem, 'sistem b');
    expect(cozulen[0].mesajlar.first['metin'], 'Hello şöyle');
    expect(cozulen[0].gecmis.length, 4);
    expect(cozulen[0].gecmis.last, {'role': 'assistant', 'content': 'Nice to meet you'});
    expect(cozulen[1].konu, 'Konu b');
    expect(cozulen[1].mod, 'fun');
    expect(cozulen[1].seviye, 'B1');
  });

  test('konu, karakter ve seviye olmayan eski kayıt da açılır', () {
    final veri = _ornek().toJson()
      ..remove('konu')
      ..remove('mod')
      ..remove('seviye');
    final sohbet = KayitliSohbet.fromJson(veri)!;
    expect(sohbet.konu, '');
    expect(sohbet.mod, '');
    expect(sohbet.seviye, '');
  });

  group('yanıtsız son mesaj', () {
    final gecmis = [
      {'role': 'user', 'content': 'start'},
      {'role': 'assistant', 'content': 'Hello'},
      {'role': 'user', 'content': 'Hi'},
      {'role': 'assistant', 'content': 'Good'},
      {'role': 'user', 'content': 'yanıtı gelmedi'},
    ];
    final mesajlar = [
      {'gonderen': 'AI', 'metin': 'Hello'},
      {'gonderen': 'Sen', 'metin': 'Hi'},
      {'gonderen': 'AI', 'metin': 'Good'},
      {'gonderen': 'Sen', 'metin': 'yanıtı gelmedi'},
      {'gonderen': 'AI', 'metin': 'Error: Connection problem.'},
    ];

    test('kayda hazırlarken yanıtsız kullanıcı mesajı ve sonrası atılır', () {
      final sohbet = kaydaHazirla(konu: 'k', mod: 'fun', seviye: 'A2', sistem: 's', gecmis: gecmis)!;
      expect(sohbet.gecmis.length, 4);
      expect(sohbet.gecmis.last['role'], 'assistant');
      expect(sohbet.mesajlar.map((m) => m['metin']), ['Hello', 'Hi', 'Good']);
      // Kaynak listeler değişmez.
      expect(gecmis.length, 5);

    });

    test('kullanıcı hiç yanıt almadıysa sohbet kaydedilmez', () {
      expect(
        kaydaHazirla(konu: 'k', mod: 'fun', seviye: 'A2', sistem: 's', gecmis: gecmis.sublist(0, 2)),
        isNull,
      );
      expect(
        kaydaHazirla(konu: 'k', mod: 'fun', seviye: 'A2', sistem: 's', gecmis: [gecmis[0], gecmis[1], gecmis[4]]),
        isNull,
      );
    });

    test('rol sırası bozuk geçmiş kaydedilmez', () {
      expect(
        kaydaHazirla(konu: 'k', mod: 'fun', seviye: 'A2', sistem: 's', gecmis: [gecmis[0], gecmis[1], gecmis[1], gecmis[3]]),
        isNull,
      );
    });

    test('eski kayıtta kalmış yanıtsız mesaj okunurken temizlenir', () {
      final veri = {
        'sistem': 's',
        'mesajlar': mesajlar.sublist(0, 4),
        'gecmis': gecmis,
      };
      final sohbet = KayitliSohbet.fromJson(veri)!;
      expect(sohbet.gecmis.last['role'], 'assistant');
      expect(sohbet.gecmis.length, 4);
    });
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
