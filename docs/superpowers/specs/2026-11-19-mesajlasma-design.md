# Aşama 2: Mesajlaşma — Tasarım

Tarih: 2026-11-19. Kullanıcı tasarımı sohbette onayladı ("a", ardından "devam").
Önceki aşama: `2026-11-19-hesaplar-ve-profiller-design.md`.

## Amaç

Öğrenci, seçtiği eğitmenle uygulama içinde birebir yazışır. Eğitmen, kendisini seçen her
öğrenciyle ayrı ayrı yazışır.

## Kullanıcının kararları

- Bildirim **uygulama içi** (seçenek A): uygulama açıkken mesaj anında gelir, okunmamış işareti
  görünür. Uygulama kapalıyken telefona bildirim düşmez. Telefona bildirim (FCM + Cloud
  Functions) Firebase'in ücretli Blaze planını gerektirdiği için ertelendi.

## Yaklaşımlar

- **Çift başına tek sohbet belgesi + alt koleksiyonda mesajlar (seçildi, benim kararım):**
  kurallar sade, okunmamış sayacı sohbet belgesinde durur, eğitmen tek sorguyla tüm
  sohbetlerini görür.
- Mesajları `users/{uid}` altında tutmak: profil kurallarıyla karışır, iki tarafa çift yazım ister.
- Realtime Database: ayrı ürün, ayrı kurulum; bu ölçekte kazancı yok.

## Kapsam

- Yalnızca metin; en fazla 1000 karakter. Silme ve düzenleme yok.
- Sohbeti yalnızca o öğrenci ve o eğitmen okuyabilir.
- Öğrenci: "Eğitmenim" ekranında "Mesaj yaz" düğmesi (okunmamış sayısıyla).
- Eğitmen: paneldeki her öğrenci kartı sohbeti açar ve okunmamış sayısını gösterir.
- Ana menüde "My Tutor" kartında okunmamış mesaj varsa kırmızı nokta.
- Öğrenci eğitmeni bırakır/değiştirirse o sohbete yazılamaz ve iki tarafın ekranından kalkar
  (benim kararım). Aynı eğitmen tekrar seçilirse eski mesajlar geri gelir.

## Kapsam dışı

Telefona bildirim, fotoğraf/ses, grup sohbeti, mesaj silme/düzenleme, "yazıyor…" göstergesi,
eski mesajları sayfalama (son 100 mesaj gösterilir).

## Veri modeli (Firestore)

`sohbetler/{ogrenciId}_{egitmenId}`:

| Alan | Tür | Not |
|---|---|---|
| `ogrenciId`, `egitmenId` | string | belge kimliğiyle aynı |
| `sonMesaj` | string | son mesajın ilk 100 karakteri |
| `sonGonderen` | string | uid |
| `sonZaman` | timestamp | |
| `okunmamisOgrenci`, `okunmamisEgitmen` | int | karşı taraf gönderince artar, sohbet açılınca 0 |

`sohbetler/{id}/mesajlar/{otomatik}`: `gonderen` (uid), `metin` (1–1000), `zaman` (sunucu saati).

Gönderim tek toplu yazımdır: mesaj eklenir + sohbet belgesi `merge` ile güncellenir.

## Güvenlik kuralları

- Sohbet belgesi `get`: kimliğin iki parçasından biri kendi uid'si (belge henüz yokken de çalışır).
- Sohbet belgesi `list`: `ogrenciId` veya `egitmenId` kendi uid'si.
- Sohbet oluşturma/güncelleme: taraf olmalı, kimlik alanlarla eşleşmeli ve değişmemeli,
  yalnızca izinli alanlar; **öğrencinin `egitmenId` alanı hâlâ bu eğitmen olmalı**.
- Mesaj okuma: taraf olmak. Mesaj oluşturma: taraf, `gonderen` kendi uid'si, metin 1–1000,
  `zaman == request.time`, sohbet hâlâ aktif. Güncelleme/silme yok.

Sorgular: eğitmen `where egitmenId == uid`; öğrenci belgeyi kimliğiyle okur; mesajlar
`orderBy zaman desc limit 100`.

## Kod yapısı

- `lib/hesap/mesaj_servisi.dart` — `Sohbet`, `Mesaj`, gönderme, izleme, okundu, okunmamış sayısı
- `lib/hesap/sohbet_ekrani.dart` — sohbet ekranı, ana menü için okunmamış noktası
- `lib/hesap/egitmen_ekranlari.dart` — "Mesaj yaz" düğmesi, öğrenci kartından sohbete giriş
- `lib/main.dart` — yalnızca "My Tutor" kartına nokta
- `firestore.rules` — yeni `sohbetler` kuralları

## Doğrulama

- Kurallar Firestore emülatöründe sınanır (taraf olmayan okuyamaz/yazamaz, bırakılan sohbete
  yazılamaz, sahte gönderen reddedilir).
- `flutter analyze` temiz; web ve Android release derlemesi geçer.
- İki hesapla gerçek cihaz denemesi kullanıcıya kalır.
