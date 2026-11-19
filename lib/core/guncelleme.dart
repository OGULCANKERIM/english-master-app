import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ayarlar.dart';

/// [uzak] sürümü [yerel] sürümden yeniyse true döner ("1.10.0" > "1.9.2").
/// Boş ya da sayı olmayan sürümlerde false döner; böylece yanlış yazılmış bir
/// Remote Config değeri herkese güncelleme penceresi açmaz.
bool surumYeniMi(String uzak, String yerel) {
  List<int>? parcala(String surum) {
    final temiz = surum.trim().split('+').first;
    if (temiz.isEmpty) return null;
    final parcalar = <int>[];
    for (final parca in temiz.split('.')) {
      final sayi = int.tryParse(parca.trim());
      if (sayi == null || sayi < 0) return null;
      parcalar.add(sayi);
    }
    return parcalar;
  }

  final u = parcala(uzak);
  final y = parcala(yerel);
  if (u == null || y == null) return false;
  final uzunluk = u.length > y.length ? u.length : y.length;
  for (var i = 0; i < uzunluk; i++) {
    final a = i < u.length ? u[i] : 0;
    final b = i < y.length ? y[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

bool _kontrolEdildi = false;

/// Remote Config'teki `current_version` uygulamadan yeniyse güncelleme penceresi gösterir.
/// Uygulama açıldıktan sonra yalnızca bir kez çalışır; hata olursa sessizce geçer.
Future<void> guncellemeKontrolEt(BuildContext context) async {
  if (_kontrolEdildi || Firebase.apps.isEmpty) return;
  _kontrolEdildi = true;
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(minutes: 15),
    ));
    await remoteConfig.fetchAndActivate();
    final String yeniSurum = remoteConfig.getString('current_version');
    if (context.mounted && surumYeniMi(yeniSurum, uygulamaSurumu)) _guncellemePenceresi(context);
  } catch (e) {
    debugPrint("Güncelleme Hatası: $e");
  }
}

void _guncellemePenceresi(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("🚀 Yeni Sürüm Hazır!"),
      content: const Text("English Master'ı en iyi deneyimle kullanmak için lütfen güncelleyin."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("SONRA")),
        ElevatedButton(
          onPressed: () async {
            try {
              await launchUrl(Uri.parse('https://appdistribution.firebase.google.com/'), mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint("Güncelleme sayfası açılamadı: $e");
            }
          },
          child: const Text("GÜNCELLE"),
        ),
      ],
    ),
  );
}
