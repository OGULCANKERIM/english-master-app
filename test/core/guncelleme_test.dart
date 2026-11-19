import 'package:flutter_test/flutter_test.dart';
import 'package:yeni_english/core/guncelleme.dart';

void main() {
  test('uzak sürüm yeniyse true', () {
    expect(surumYeniMi('1.2.0', '1.1.0'), isTrue);
    expect(surumYeniMi('1.10.0', '1.9.2'), isTrue);
    expect(surumYeniMi('2.0', '1.9.9'), isTrue);
    expect(surumYeniMi('1.1.1', '1.1'), isTrue);
    expect(surumYeniMi(' 1.2.0+7 ', '1.1.0'), isTrue);
  });

  test('aynı ya da eski sürümde false', () {
    expect(surumYeniMi('1.1.0', '1.1.0'), isFalse);
    expect(surumYeniMi('1.1', '1.1.0'), isFalse);
    // Remote Config henüz güncellenmemişse (eski sürüm yazıyorsa) yeni derleme uyarı göstermemeli.
    expect(surumYeniMi('1.0.0', '1.1.0'), isFalse);
  });

  test('boş ya da bozuk sürümde false', () {
    expect(surumYeniMi('', '1.1.0'), isFalse);
    expect(surumYeniMi('yeni', '1.1.0'), isFalse);
    expect(surumYeniMi('1.x.0', '1.1.0'), isFalse);
    expect(surumYeniMi('1.2.0', ''), isFalse);
  });
}
