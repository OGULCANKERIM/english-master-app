# yeni_english + english-master-app Birleştirme — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** yeni_english'teki commit edilmemiş bütün özellikleri, english-master-app'in üzerine, ekranlara bölünmüş tek bir uygulamada toplamak. Bütün yapay zekâ işleri Claude'a geçecek, hiçbir anahtar koda yazılmayacak.

**Architecture:**
- Önce english-master-app'teki büyük `main.dart` davranış değişmeden `lib/screens/` altında ekranlara bölünür.
- Sonra ortak parçalar `lib/core/` altına yazılır: Claude servisi, ayarlar, kalıcılık, temalar ve seviye yardımcısı.
- En son yeni_english'teki modüller tek tek bu parçaların üzerine taşınır.
- `lib/hesap/` klasörü olduğu gibi kalır, sadece küçük eklemeler yapılır.

**Tech Stack:** Flutter 3.47.7 (CI'da sabit), Dart `^3.10.8`, Firebase Auth ve Firestore, `http` (testlerde `package:http/testing.dart` içindeki `MockClient`), `shared_preferences`, `flutter_tts`, `speech_to_text`, `video_player`.

**Spec:** `docs/superpowers/specs/2026-11-19-projeleri-birlestirme-design.md`

**Kaynak kodlar:**
- `EM` = `B:\english master\english-master-app`: çalışılan repo.
- `YE` = `B:\yeni_english`: yalnızca okunur, **hiçbir dosyası değiştirilmez**.

## Global Constraints

- İş EM reposunda `birlestirme` dalında yapılır; `main`'e merge ve push yalnızca kullanıcı onayıyla.
- Hiçbir API anahtarı koda, `.env`'e veya asset'e girmez. Anahtarların hepsi `--dart-define` ile verilir:
  - `ANTHROPIC_API_KEY`
  - `CLAUDE_MODEL` (varsayılan `claude-haiku-5-5`)
  - `CLAUDE_YEDEK_KAPALI`
  - `PIXABAY_API_KEY`
- YE dosyalarından kod kopyalarken Gemini anahtar listeleri (`_apiSifreleri`, `_apiKeys`), `pixabayApiKey` değeri ve Deepgram ayarları **alınmaz**.
- Claude isteğinin biçimi bugünkü EM kodundaki gibi kalır:
  - URL `https://api.anthropic.com/v1/messages`
  - `anthropic-version: 2026-10-21`
  - `claudeYedekDestekli` ise `anthropic-beta: server-side-fallback-2026-07-01` başlığı ve `'fallbacks': 'default'` alanı
  - web'de `anthropic-dangerous-direct-browser-access: true`
  - `output_config: {effort: 'low'}`
  - 60 saniye zaman aşımı
- Paketler EM'deki `^` sürüm kısıtlarıyla kalır. Yeni paket eklenmez. `firebase_storage`, `image_picker`, `google_generative_ai`, `flutter_dotenv`, `web_socket_channel` ve `record` eklenmez.
- Tanımlayıcılar ve yorumlar Türkçe, arayüz metinleri İngilizce (mevcut stil).
- Girişsiz kullanım korunur. Yalnızca "My Tutor" ve "My Profile" giriş ister.
- Profil fotoğrafı, Deepgram, bildirim düğmesi ve hesap silme bu işin dışındadır.
- Her görevin sonunda `flutter analyze` yeni hata vermez ve `flutter test` geçer.

## Review Focus

1. **`ANTHROPIC_API_KEY` verilmeden derlenmiş sürüm:** Konuşma, Reading ve Nova çökmemeli. Her biri "Claude API anahtarı tanımlı değil" mesajını göstermeli. → Görev 1'deki `anahtar yoksa ClaudeHatasi` testi ve Görev 4/7/8'deki geri dönüş metni testleri.
2. **Claude'un JSON yerine düz metin ya da ```json bloğu döndürmesi:** Reading puanı ve konuşma ipuçları çökmemeli. → Görev 1'deki `jsonIste` testleri (çitli blok, metin içinde JSON, bozuk JSON) ve Görev 8'deki `okumaDegerlendirmesiniCoz` sınır testleri.
3. **Bozuk veya eski biçimde cihaz kaydı:** Favoriler, tema numarası ya da kayıtlı sohbetler bozuksa uygulama açılmalı, boş ya da varsayılan değerle devam etmeli. → Görev 2'deki bozuk-JSON ve aralık-dışı-tema testleri, Görev 7'deki bozuk-kayıt testi.
4. **`PIXABAY_API_KEY` yok ya da Pixabay hata veriyor:** Kelime kartı resimsiz gösterilmeli, hata mesajı çıkmamalı. → Görev 5'teki `kelimeResmiGetir` testleri.
5. **Giriş yapmamış kullanıcı:** Nova, Reading ve Konuşma seviyeyi yerelden (varsayılan A2) almalı, Firestore'a dokunmamalı. → Görev 2'deki `mevcutSeviye` testleri.

---

### Görev 0: Hazırlık

**Files:**
- Create: `test/` klasörü
- Commit: `docs/superpowers/specs/2026-11-19-projeleri-birlestirme-design.md`, bu plan

- [ ] **Step 1: YE'nin yedeğini al**

Run (PowerShell): `robocopy B:\yeni_english B:\yeni_english_yedek_2026-11-19 /E /XD build .dart_tool android\build`
Expected: çıkış kodu 0–7 ve `B:\yeni_english_yedek_2026-11-19\lib\screens\speaking_modulu.dart` mevcut.

- [ ] **Step 2: Dalı aç**

Run (EM'de): `git status --short` (boş olmalı, spec ve plan dışında), ardından `git switch -c birlestirme`.

- [ ] **Step 3: Temel durumu kaydet**

Run: `flutter pub get; flutter analyze`. Uyarı sayısını not et, bu sayı sonraki görevlerde başlangıç noktası olur.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers
git commit -m "Birleştirme tasarımı ve uygulama planı"
```

---

### Görev 1: Ayarlar ve Claude servisi

**Files:**
- Create: `lib/core/ayarlar.dart`, `lib/core/claude_servisi.dart`
- Test: `test/core/claude_servisi_test.dart`

**Interfaces:**
- Produces:
  - `ayarlar.dart`:
    - Değişkenler: `claudeApiKey`, `claudeModel`, `claudeYedekDestekli` ve `uygulamaSurumu` (EM `main.dart:26-32`'den taşınır).
    - `const String pixabayApiKey = String.fromEnvironment('PIXABAY_API_KEY');`
  - `class ClaudeHatasi implements Exception { final String kullaniciMesaji; }`: İngilizce, kullanıcıya gösterilecek metin.
  - `class ClaudeYaniti { final String metin; final List<dynamic> icerik; }`: `icerik`, geçmişe `assistant` olarak eklenecek ham bloklardır.
  - `class ClaudeServisi`:
    - Kurucu: `ClaudeServisi({http.Client? istemci, String anahtar = claudeApiKey, String model = claudeModel})`
    - `static final ClaudeServisi varsayilan`
    - `Future<ClaudeYaniti> gonder({required String sistem, required List<Map<String, dynamic>> mesajlar, int maxTokens = 4096})`
    - `Future<Map<String, dynamic>> jsonIste({required String sistem, required String istem})`: Yanıttaki ilk JSON nesnesini çözer.

- [ ] **Step 1: Failing testleri yaz** (`MockClient` ile)

  - `anahtar yoksa ClaudeHatasi`: `anahtar: ''` iken `gonder` → `ClaudeHatasi`. Mesajda `ANTHROPIC_API_KEY` geçer ve hiç HTTP isteği atılmaz.
  - `istek biçimi`: Yakalanan istekte URL, `x-api-key`, `anthropic-version: 2026-10-21`, `model`, `system`, `messages` ve `output_config.effort == 'low'` bulunur.
  - `metin bloklarını birleştirir`: Yanıt `{"content":[{"type":"text","text":"Hi"},{"type":"text","text":"there"}]}` ise `metin == 'Hi there'` olur.
  - `durum kodları`: 401 → mesajda `API key is invalid`, 429 → `Too many requests`, 529 → `busy`.
  - `refusal`: `stop_reason: 'refusal'` → `ClaudeHatasi`.
  - `boş yanıt`: Metin bloğu yoksa `ClaudeHatasi`.
  - `zaman aşımı/ağ`: İstemci `SocketException` atarsa `ClaudeHatasi`, mesajda `internet` geçer.
  - `jsonIste` çitli blok: metin ```` ```json\n{"skor": 80}\n``` ```` → `{'skor': 80}`.
  - `jsonIste` metin içinde: `Sure! {"a":1} hope it helps` → `{'a': 1}`.
  - `jsonIste` bozuk: `not json` → `ClaudeHatasi`.

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: `flutter test test/core/claude_servisi_test.dart` → derleme hatası veya FAIL.

- [ ] **Step 3: Uygula**

Başlıklar, gövde ve hata eşleme EM `main.dart:965-1115`'ten taşınır. `jsonIste`, `gonder`'i tek kullanıcı mesajıyla çağırır, sonra yanıttaki ilk `{` ile son `}` arasını `jsonDecode` eder.

- [ ] **Step 4: Testler geçer**

Run: `flutter test test/core/claude_servisi_test.dart` → PASS.

- [ ] **Step 5: Commit** `Ortak Claude servisi ve derleme ayarları`

---

### Görev 2: Kalıcılık, temalar ve seviye yardımcısı

**Files:**
- Create: `lib/core/globals.dart`, `lib/core/temalar.dart`, `lib/core/seviye.dart`
- Test: `test/core/globals_test.dart`, `test/core/temalar_test.dart`, `test/core/seviye_test.dart`

**Interfaces:**
- Produces:
  - `globals.dart`:
    - `List<Map<String, dynamic>> globalFavoriSahneler`
    - `Future<void> favorileriYukle()`, `Future<void> favorileriKaydet()`: anahtar `favori_sahneler`.
    - `Map<dynamic, dynamic>? globalSeciliSes`
    - `List<dynamic> jsonListeCoz(http.Response)`, `String alan(dynamic satir, String anahtar)`: EM'deki `_jsonListeCoz` ve `_alan`, artık public.
    - `Route<T> kayarakGecis<T>(Widget)`, `Route<T> alttanKayarakGecis<T>(Widget)`: EM'deki `_kayarakGecis`.
  - `temalar.dart`:
    - `class AppThemes { static final List<ThemeData> themes; }`: YE `main.dart`'taki 5 tema, sırası aynı.
    - `final ValueNotifier<int> appThemeNotifier`
    - `Future<void> temaYukle()`: anahtar `app_theme_index`; değer aralık dışıysa 0.
    - `Future<void> temaKaydet(int)`
  - `seviye.dart`:
    - `const String varsayilanSeviye = 'A2';`
    - `Future<String> mevcutSeviye({Future<String?> Function()? profilSeviyesi})`: Varsayılan `profilSeviyesi` fonksiyonu, giriş yapılmışsa `HesapServisi.profilimiIzle().first`'ten `seviye`'yi okur, yoksa `null` döner. Sonuç `null` ise yereldeki `userLevel` değeri, o da yoksa `varsayilanSeviye` kullanılır.
    - `Future<void> yerelSeviyeyiKaydet(String)`: anahtar `userLevel`.

- [ ] **Step 1: Failing testleri yaz** (`SharedPreferences.setMockInitialValues` ile)

  - `favoriler gidiş-dönüş`: Kaydedip yükleyince aynı liste gelir.
  - `bozuk favori kaydı`: `{'favori_sahneler': 'xx'}` → yükleme çökmez, liste boş kalır.
  - `alan`: `alan({'a': ' x '}, 'a') == 'x'`, `alan(null, 'a') == ''`.
  - `tema`: `AppThemes.themes.length == 5`. `temaKaydet(3)` sonra `temaYukle()` → `appThemeNotifier.value == 3`. Kayıt `9` ise sonuç `0`.
  - `seviye`:
    - Profil `'B2'` dönerse sonuç `'B2'`.
    - Profil `null` ve yerel değer `'C1'` ise sonuç `'C1'`.
    - İkisi de yoksa sonuç `'A2'`.
    - Profil fonksiyonu hata atarsa yerel değere düşer.

- [ ] **Step 2: Çalıştır, FAIL gör** → `flutter test test/core`

- [ ] **Step 3: Uygula**

Kodlar EM `main.dart:37-75, 117-130` ve YE `main.dart:30-86`'dan taşınır.

- [ ] **Step 4: Testler geçer** → `flutter test test/core` PASS

- [ ] **Step 5: Commit** `Ortak kalıcılık, temalar ve seviye yardımcısı`

---

### Görev 3: EM `main.dart`'ı davranış değiştirmeden böl

Saf yeniden düzenleme. Ekranlar aynı görünür ve aynı çalışır.

**Files:**
- Create:
  - `lib/screens/ana_menu.dart`: `AnaMenuEkrani` ve güncelleme kontrolü (EM `:114-262` ve `:329` civarı)
  - `lib/screens/kelime_modulu.dart`: `SeviyeliKelimeEkrani`, `TestEkrani`
  - `lib/screens/reels_modulu.dart`: `FavorilerEkrani`, `FilmKesitleriEkrani`, `ReelsVideoOgesi`
  - `lib/screens/speaking_modulu.dart`: `KonusmaPratigiEkrani`. Kendi `_claudeIstegi`'nin yerine `ClaudeServisi.varsayilan.gonder` kullanır; geçmiş yönetimi aynı kalır.
- Modify: `lib/main.dart`. Yalnızca `main()` ve `IngilizceUygulamam` kalır; `main()` ayrıca `temaYukle()`'yi çağırır.

**Interfaces:**
- Consumes: Görev 1 ve 2'deki her şey.

- [ ] **Step 1:** Sınıfları dosyalara taşı, importları düzelt, `_` önekli ortak yardımcılar yerine `core/` sürümlerini kullan.
- [ ] **Step 2:** Run `flutter analyze` → yeni hata yok. Run `flutter test` → PASS.
- [ ] **Step 3:** Run `flutter build apk --debug --dart-define=ANTHROPIC_API_KEY=x` → derleme başarılı.
- [ ] **Step 4: Commit** `main.dart ekranlara bölündü (davranış aynı)`

---

### Görev 4: AI koç Nova Claude'da

**Files:**
- Create: `lib/services/ai_coach_system.dart` (YE'den, Gemini kısmı çıkarılmış)
- Test: `test/services/ai_coach_test.dart`

**Interfaces:**
- Consumes: `ClaudeServisi`, `mevcutSeviye`
- Produces:
  - `class AiCoachSystem`:
    - `static String novaIstemi({required String ekran, required String ad, required String seviye, Map<String, dynamic>? veri})`
    - `static Future<String> getLiveAdviceForScreen(String screenName, {dynamic data, ClaudeServisi? servis})`
    - `static Widget globalCoachButton(BuildContext, String screenName, {dynamic data})`
  - Ekran adları: `AnaMenu`, `KelimeModulu`, `TestEkrani`, `SpeakingView`, `ProfileScreen`, `Eşleştirme`, `ReadingView`.

- [ ] **Step 1: Failing testler**

  - `novaIstemi` sonucu adı, seviyeyi ve `KelimeModulu` için `learnedCount` değerini içerir. Bilinmeyen ekran adında çökmez.
  - `getLiveAdviceForScreen`, sahte bir `ClaudeServisi` (`MockClient` ile yanıt `"Go!"`) ile `'Go!'` döner.
  - Servis `ClaudeHatasi` atarsa sonuç YE'deki geri dönüş cümlesidir (`"I'm having a little cloud connection issue..."`). Hata atılmaz.

- [ ] **Step 2:** Run `flutter test test/services` → FAIL

- [ ] **Step 3: Uygula**

İstem metni YE'deki gibi korunur ve sistem metni olarak gönderilir. `ReadingView` ve `Eşleştirme` için kısa bağlam cümleleri eklenir. Kullanıcı adı `FirebaseAuth.instance.currentUser?.displayName`'den alınır, yoksa `"Friend"` kullanılır.

- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `Nova koçu Claude ile`

---

### Görev 5: Kelime listesi ve Test (YE sürümü)

**Files:**
- Modify: `lib/screens/kelime_modulu.dart`. İçerik YE `screens/kelime_modulu.dart` ile değiştirilir.
- Test: `test/screens/kelime_resmi_test.dart`

**Interfaces:**
- Produces: `Future<String?> kelimeResmiGetir(String kelime, {http.Client? istemci, String anahtar = pixabayApiKey})`. Fonksiyon üst düzeydedir (top-level) ve sonuç olarak resim URL'si ya da `null` döner.

- [ ] **Step 1: Failing testler**

  - Anahtar `''` ise sonuç `null` olur ve istek atılmaz.
  - Pixabay `{"hits":[{"webformatURL":"u"}]}` döndürürse sonuç `'u'` olur.
  - 500 yanıtı, boş `hits` veya istisna durumunda sonuç `null` olur.

- [ ] **Step 2:** FAIL
- [ ] **Step 3: Uygula**

  - YE'nin resim kodu bu fonksiyona taşınır.
  - Ekran, sonuç `null` ise resim alanını hiç göstermez.
  - Sunucu yanıtları `jsonListeCoz` ve `alan` ile okunur (UTF-8 ve boş hücre güvenliği).
  - `AiCoachSystem.globalCoachButton` çağrıları kalır.
  - TTS, profil ses ayarlarını (Görev 10'daki `tts_perde`, `tts_hiz`; varsayılanlar 1.0 ve 0.5) okur.

- [ ] **Step 4:** Run `flutter test`, `flutter analyze` → PASS
- [ ] **Step 5: Commit** `Kelime modülü: resimli kartlar (Pixabay anahtarı derlemede)`

---

### Görev 6: Reels ve Favoriler (YE sürümü)

**Files:**
- Modify: `lib/screens/reels_modulu.dart`. İçerik YE `screens/reels_modulu.dart` ile değiştirilir.

- [ ] **Step 1:** YE kodunu taşı. Favori her eklenip çıkarıldığında `favorileriKaydet()` çağrılır; EM'de bu davranış vardı, YE'de yok. `FavorilerEkrani`'ndan reels'e dönüşte liste yenilenir; EM `:655` davranışı korunur.
- [ ] **Step 2:** Run `flutter analyze`, `flutter test` → PASS
- [ ] **Step 3:** Elle kontrol: bir sahneyi favorile, uygulamayı tamamen kapatıp aç, favori duruyor olmalı.
- [ ] **Step 4: Commit** `Reels ve favoriler: yeni arayüz, kalıcılık korunarak`

---

### Görev 7: Konuşma pratiği (YE ekranı, Claude ile)

**Files:**
- Modify: `lib/screens/speaking_modulu.dart`. İçerik YE `screens/speaking_modulu.dart` ile değiştirilir.
- Test: `test/screens/konusma_kayit_test.dart`

**Interfaces:**
- Consumes: `ClaudeServisi.gonder`, `ClaudeServisi.jsonIste`, `mevcutSeviye`, `AiCoachSystem.globalCoachButton`
- Produces:
  - `List<Map<String, dynamic>> geminiGecmisiniClaudeyeCevir(List<Map<String, dynamic>>)`: Role `'model'` → `'assistant'`, `parts[*].text` → `content` metni. Ardışık aynı roldeki mesajlar birleştirilir ve liste `user` ile başlar.
  - `Future<List<List<Map<String, dynamic>>>> kayitliSohbetleriYukle()`: anahtar `kayitliClaudeSohbetleri`; kayıt bozuksa sonuç `[]`.

- [ ] **Step 1: Failing testler**

  - Çevirici: `[{'role':'user','parts':[{'text':'hi'}]},{'role':'model','parts':[{'text':'hello'}]}]` → `[{'role':'user','content':'hi'},{'role':'assistant','content':'hello'}]`.
  - `model` ile başlayan liste → ilk eleman atılır.
  - `kayitliSohbetleriYukle` bozuk JSON ile `[]` döner.

- [ ] **Step 2:** FAIL
- [ ] **Step 3: Uygula**

  - Bütün Gemini çağrıları kaldırılır: sohbet, çeviri `_ceviriYap`, ipucu `_ipucuIste` ve karakter yanıtları.
  - Sohbet `gonder` ile yürür. Çeviri ve ipucu tek seferlik `gonder` çağrılarıdır. Çeviri istemi: "Translate to Turkish, reply with only the translation."
  - Deepgram servisi yerine `speech_to_text` kullanılır; dinleme açma/kapama mantığı EM `:1000-1075`'ten alınır.
  - Karakterler (`aiMode`), ses (`aiVoice`), konu vitrini ve seviye değiştirme olduğu gibi kalır. Başlangıç seviyesi `mevcutSeviye()`'den gelir.
  - Kayıtlı sohbetler `kayitliSohbetler` (görünen) ve `kayitliClaudeSohbetleri` (API geçmişi) anahtarlarına yazılır. Eski `kayitliApiSohbetleri` okunmaz.
  - `ClaudeHatasi.kullaniciMesaji` sohbet balonunda gösterilir. Başarısız istekte son `user` mesajı geçmişten çıkarılır (EM `:1128` kuralı).
  - `lib/services/deepgram_stt_service.dart` alınmaz.

- [ ] **Step 4:** Run `flutter test`, `flutter analyze` → PASS
- [ ] **Step 5: Commit** `Konuşma pratiği: karakterler, çeviri, ipucu ve kayıtlı sohbetler Claude ile`

---

### Görev 8: Reading Lounge (Claude ile)

**Files:**
- Create: `lib/screens/reading_modulu.dart` (YE'den)
- Test: `test/screens/okuma_test.dart`

**Interfaces:**
- Produces: `({int skor, String geribildirim}) okumaDegerlendirmesiniCoz(Map<String, dynamic>)`

- [ ] **Step 1: Failing testler**

  - `{'skor': 85, 'geribildirim': 'Good'}` → `(85, 'Good')`.
  - `{'skor': '70'}` → `(70, '')`.
  - `{'skor': 140}` → `100`, `{'skor': -5}` → `0`.
  - `{}` → `(0, '')`.

- [ ] **Step 2:** FAIL
- [ ] **Step 3: Uygula**

  - Metin üretme `gonder` ile yapılır.
  - Telaffuz değerlendirmesi `jsonIste` ile yapılır. YE `:259` istemi korunur ve sonuna şu eklenir: `Reply only with JSON: {"skor": 0-100, "geribildirim": "..."}`.
  - Seviye `mevcutSeviye()`'den gelir.
  - `ClaudeHatasi` durumunda SnackBar'da `kullaniciMesaji` gösterilir.
  - Koç ekranı adı: `ReadingView`.

- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `Reading Lounge eklendi (Claude ile)`

---

### Görev 9: Word Match

**Files:**
- Create: `lib/screens/eslestirme_modulu.dart` (YE'den). Yapay zekâ kullanmıyor; kelimeleri `opensheet` tablosundan çekiyor.

- [ ] **Step 1:** Taşı. Sunucu yanıtı `jsonListeCoz` ve `alan` ile okunur.
- [ ] **Step 2:** `flutter analyze` → PASS
- [ ] **Step 3: Commit** `Word Match eklendi`

---

### Görev 10: Açılış, ana menü, temalar ve profil eklemeleri

**Files:**
- Modify:
  - `lib/main.dart`: `theme`, `appThemeNotifier` ile değişir (YE `main.dart:88-110`); `home: AcilisKapisiEkrani()`.
  - `lib/screens/ana_menu.dart`: YE tasarımı (Cinematic, Word Vault, Voice Studio, Reading Lounge ve Word Match kartları, tema seçici) + EM'deki My Tutor kartı (`OkunmamisNoktasi` ile), My Profile kartı ve güncelleme kontrolü. Favoriler kartı da kalır.
  - `lib/hesap/profil_ekrani.dart`:
    - Tema seçimi, "Update Name", "Change Password" ve "AI Voice Settings" bölümleri eklenir.
    - Kayıtta `yerelSeviyeyiKaydet(seviye)` çağrılır.
  - `lib/hesap/hesap_servisi.dart`: ad güncelleme `ad` alanını ve `FirebaseAuth` `displayName`'i birlikte yazar.
  - `lib/hesap/*.dart`: sabit renkler gerekiyorsa `Theme.of(context)` ile değiştirilir; 5 temanın hepsinde metin okunur olmalı.
- Create: `lib/screens/acilis_ekrani.dart` (YE'den). Animasyondan sonra **her zaman** `AnaMenuEkrani`'na geçer; `LoginEkrani`'na yönlendirme kaldırılır.

**Interfaces:**
- Produces:
  - `Future<void> sifreDegistir({required String eskiSifre, required String yeniSifre})`: `HesapServisi` içinde; önce `reauthenticateWithCredential`, sonra `updatePassword`.
  - `Future<void> adiGuncelle(String ad)`.
  - TTS ayarları: `tts_perde` (0.5–2.0, varsayılan 1.0), `tts_hiz` (0.1–1.0, varsayılan 0.5).
  - Konuşma ve kelime modülleri bu değerleri okur. Görev 5 ve 7'de okuma kodu yoksa burada eklenir.

- [ ] **Step 1:** Açılış ve ana menüyü taşı, EM kartlarını ekle.
- [ ] **Step 2:** Profil eklemelerini yap. Yanlış eski şifre durumunda `"Error: Password incorrect."` SnackBar'ı gösterilir (YE metni).
- [ ] **Step 3:** Run `flutter analyze`, `flutter test` → PASS
- [ ] **Step 4:** Elle kontrol:
  - 5 temayı sırayla seç: ana menü, kelime, konuşma, profil, eğitmen ve sohbet ekranlarında yazılar okunuyor olmalı.
  - Girişsiz açılış ana menüye gidiyor.
  - My Tutor girişe yönlendiriyor.
- [ ] **Step 5: Commit** `Açılış, yeni ana menü, 5 tema ve profil ayarları`

---

### Görev 11: Android, sürüm, paketler, CI ve README

**Files:**
- Modify:
  - `android/app/src/main/AndroidManifest.xml`: YE'deki `<queries>` altındaki `android.speech.RecognitionService` intent'i ve `ACCESS_NETWORK_STATE` izni eklenir. Başka değişiklik yok.
  - `pubspec.yaml`: `version: 1.1.0+2`; `description` İngilizce kısa açıklama olur; asset listesi EM'deki gibi kalır (`.env` yok).
  - `lib/core/ayarlar.dart`: `uygulamaSurumu = "1.1.0"`.
  - `.github/workflows/flutter_build.yml:34`: derleme satırına `"--dart-define=PIXABAY_API_KEY=${{ secrets.PIXABAY_API_KEY }}"` eklenir.
  - `README.md`:
    - Modül listesine Reading Lounge, Word Match, temalar ve Nova eklenir.
    - Çalıştırma komutuna `--dart-define=PIXABAY_API_KEY=...` eklenir (isteğe bağlı olduğu yazılır).
    - CI secret listesine `PIXABAY_API_KEY` eklenir.
    - Sürüm yükseltildikten sonra Remote Config'teki sürüm değerinin güncellenmesi gerektiği yazılır.

- [ ] **Step 1:** Değişiklikleri yap.
- [ ] **Step 2:** Run `flutter pub get; flutter analyze; flutter test` → PASS
- [ ] **Step 3: Commit** `Sürüm 1.1.0, Android izinleri, CI ve README`

---

### Görev 12: Son doğrulama

- [ ] **Step 1: Anahtar taraması**

Run (EM, `lib` ve `assets`): `git grep -n -E "AIza|ghp_|55539982|deepgram|generativelanguage" -- lib assets pubspec.yaml`
Expected: çıktı yok.

- [ ] **Step 2: Derleme**

Run: `flutter build apk --release --dart-define=ANTHROPIC_API_KEY=<kullanıcının anahtarı>`
Expected: `app-release.apk` oluşur.

- [ ] **Step 3: Anahtarsız derleme**

Run: `flutter build apk --debug`. Ardından Konuşma, Reading ve Nova açılır; her biri "API anahtarı tanımlı değil" mesajını göstermeli, çökme olmamalı.

- [ ] **Step 4: Cihaz veya emülatörde gezinti** (spec §7'deki liste)

  - Girişsiz: her modül açılıyor.
  - Claude ile konuşma, çeviri, ipucu, Reading puanı ve Nova çalışıyor.
  - Tema değişimi her ekrana yansıyor.
  - Giriş yapınca profil, eğitmen seçme, mesajlaşma ve okunmamış noktası çalışıyor.
  - Favoriler uygulama yeniden açılınca duruyor.

- [ ] **Step 5:** Kullanıcıya rapor ver. `main`'e merge ve push için onay iste. Push'tan sonra CI testerlara APK gönderecek.
