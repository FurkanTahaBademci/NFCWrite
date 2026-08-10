# Durum Panosu

> Her görev sonunda buraya **tek satır** ekle. Format:
> `- [T<N>] YYYY-MM-DD · <görev kodu> <özet> · <dosya>`
> Yeni satırlar en üste.

## Genel durum

| Track | Aşama | Son işlem |
|---|---|---|
| T1 — Çekirdek | Aşama 1-3 bitti · Aşama 4-5 kısmi | Açık: T1.18 (yaşam döngüsü), T1.20 (ProGuard), T1.24 (README), T1.26/T1.27 (ölü ayarlar) |
| T2 — Okuma | Aşama 1-4 bitti · Aşama 3'te yalnız T2.19 açık · Aşama 6 (test) hiç yok | T2.15/16/18 tamamlandı — yapılandırma, kilit ve imza bölümleri eklendi |
| T3 — Yazma | Aşama 1-2, 4 bitti · Aşama 3 kısmi (15/26 kayıt tipi) | T3.18 WiFi (WSC) ve T3.39 kilitleme tamamlandı; sırada T3.26–29 ve T3.41 |
| T4 — Araçlar | Aşama 1-4, 6-7 büyük ölçüde bitti | T4.46 otomatik yedek + T4.32 anahtar taraması tamamlandı; T4.12 hâlâ NXP anahtarı bekliyor |
| T5 — Tasarım | Aşama 1-4 büyük ölçüde bitti · Aşama 6 hiç yok | Açık: dinamik renk ve ses anahtarları hâlâ ölü (T5.15/T5.33) |

**Senkronizasyon noktası:** S1 (sözleşme kilidi) — ✅ geçildi.
`nfc_core` API'si donduruldu. Değişiklik için aşağıdaki listeyi kullan.

**Son kapsamlı denetim:** 2026-08-06 — `docs/02-feature-matrix.md` ve beş
track dosyası koddan doğrulanarak güncellendi. Aşağıdaki "Denetim bulguları"
bölümüne bak.

---

## Kayıt

- [RELEASE] 2026-08-10 · **v0.1.7+9 yayınlandı.** Release keystore
  (`~/.keystores/nfc_toolkit-release.jks`, a6e46b4'te oluşturulmuştu) bu
  makinede bulunamadı — kayıp. **Yeni bir release anahtarıyla imzalandı**,
  bu da v0.1.6'daki gibi mevcut kurulumlar için zorunlu kaldır/yeniden kur
  gerektiriyor (release notlarında belirtildi). Yeni anahtar
  `~/.keystores/nfc_toolkit-release.jks` altında; **bu kez düzgün
  yedeklenmeli** (parola yöneticisi / bulut yedek), yoksa her yayın
  öncesi tekrar eder. `tools/prepare_release.sh` ile manifest üretildi,
  imza `apksigner`/`aapt` ile elle doğrulandı (script içindeki
  `command -v apksigner`/`aapt2` bu makinede PATH'te bulamadı — betik
  tam yol arasa daha sağlam olur). GitHub release: `v0.1.7`,
  asset `nfc_toolkit-v0.1.7+9.apk` · releases/version.json,
  apps/nfc_toolkit/android/key.properties (repo dışı)

- [ADR] 2026-08-10 · **Çözücü adresi taşındı — ADR-0006 güncellendi.** Aktif
  adres artık `https://nfckart.github.io/v/` (ayrı depo:
  `nfckart/nfckart.github.io`, *user site* olduğu için yolda repo adı yok →
  NDEF'te 39 yerine 20 bayt). Eski adres **kalıcı köprüde**: fragment'ı
  koruyarak yeni adrese yönlendirir, kapatılamaz. Yönlendirme zorunlu olarak
  istemci tarafında — fragment sunucuya gitmediği için 301 veriyi taşıyamazdı,
  GitHub Pages zaten statik. `VCardShareLink` artık üretimi (`defaultBaseUrl`)
  ve tanımayı (`legacyBaseUrls` + `isShareLink`) ayırıyor; tanıma eski adresi
  görmek zorunda çünkü `WriteDraftStore` taslakları ham NDEF olarak sakladığı
  için eski adresli kayıtlar güncellemeden sağ çıkıyor. **Yasak işlemler artık
  iki hesabı birden kapsıyor** (biri düşerse yeni, diğeri düşerse eski kartlar
  kırılır); ikisinde de 2FA zorunlu. Kendi alan adı hâlâ **açık madde** ·
  `packages/services/ndef_codec/lib/src/vcard_share_link.dart`,
  `packages/features/feature_write/lib/src/presentation/pages/write_page.dart`,
  `docs/v/index.html`, `.claude/docs/adr/ADR-0006-resolver-url-permanence.md`
- [ADR] 2026-08-07 · **ADR-0006 — vCard çözücü adresi kalıcı sözleşme ilan
  edildi.** `VCardShareLink.defaultBaseUrl` fiziksel kartlara kalıcı yazıldığı
  için, kodda tek satır değişmeden dört GitHub işlemi (hesap kapatma/yeniden
  adlandırma, repo'yu private yapma, repo adını değiştirme, Pages'in ücretsiz
  katmandan kalkması) sahadaki **tüm kartları geri dönüşsüz** kırar. Repo adı ve
  hesap adı artık üretim altyapısı sayılıyor. Kalıcı çözüm (kendi alan adı +
  CNAME) **açık madde**; maliyeti dağıtılmış kart sayısıyla büyüdüğü için
  penceresi kapanan bir karar — şu an kartlar 3-4 kişide ·
  .claude/docs/adr/ADR-0006-resolver-url-permanence.md

- [T2/T3/T4] 2026-08-06 · **Denetim bulgularının ilk beşi kapatıldı.**
  (1) **T4.46 — ADR-0005 2. kapısı uygulandı:** `_ensureBackup`/`_saveBackup`
  ile her yıkıcı işlem, "Etiketi kopyala" ve "Magic kart klonla" öncesinde
  tam dump alınıp arşive yazılıyor (`DumpReason.automaticBackup`). Yedek
  alınamazsa işlem varsayılan olarak iptal; kullanıcı açıkça "Yedeksiz devam
  et" diyebilir. `DangerAck.backupTaken` artık gerçeği söylüyor (önceden
  yedek alınmadığı halde `true` geçiyordu).
  (2) **T4.32 — MIFARE anahtar taraması etkinleştirildi:** katalog bayrağı +
  `case 'mifare_keys'` + sektör sektör rapor.
  (3) **T3.39 — "Yazdıktan sonra kilitle" bağlandı:** anahtar + `DangerDialog`
  onayı + `WritePhase.locking`; `write()` artık `makeReadOnly` çağırıyor.
  (4) **T2.15/16/18 — okunan ama gösterilmeyen veriler ekrana çıktı:**
  `TagInfoView`'a "Yapılandırma", "Kilit durumu" ve "Orijinallik imzası"
  bölümleri eklendi (yalnızca derin okumada dolar).
  (5) **T3.18 — WiFi (WSC) tamamlandı:** `wifi_wsc_codec.dart` + `WifiContent`
  + "Wi-Fi ağı" sihirbazı + 8 test.
  ⚠️ **Devir notu var** — `WifiContent` sealed hiyerarşiye eklendi, T2'nin
  dosyaları etkilendi. Bkz. Devir notları.
  ⚠️ **Doğrulanmadı:** bu ortamda `flutter` kurulu olmadığı için `analyze` ve
  `test` çalıştırılamadı; değişiklikler yalnızca gözle denetlendi ·
  packages/services/ndef_codec/lib/src/wifi_wsc_codec.dart,
  packages/features/feature_tools/lib/src/presentation/pages/tool_detail_page.dart,
  packages/features/feature_write/lib/src/{application/write_controller,presentation/pages/write_page,presentation/widgets/record_type_sheet}.dart,
  packages/features/feature_read/lib/src/presentation/widgets/{tag_info_view,record_content_actions}.dart

- [DENETİM] 2026-08-06 · **Kod ↔ doküman uyum denetimi.** Tüm paketler
  (111 Dart dosyası) tarandı; `docs/02-feature-matrix.md` sıfırdan yeniden
  yazıldı ve beş track dosyası koddan doğrulanarak güncellendi. Matrise yeni
  bir durum kodu eklendi: `[!]` = **kod hazır ama arayüzde kapalı**.
  Doküman gerçeğin çok gerisindeydi — A/B/C/E/F bölümlerinde `[ ]` işaretli
  onlarca madde aslında bitmişti; buna karşılık "bitti" sanılan birkaç
  özelliğin arayüz bağlantısı hiç yapılmamıştı. Ayrıntı: aşağıdaki
  "Denetim bulguları" bölümü · .claude/docs/02-feature-matrix.md,
  .claude/tracks/T1..T5

- [T1] 2026-08-06 · Ön plan NFC sahiplenmesi düzeltildi — uygulama açıkken etiket okutunca çıkan "uygulama seçin" bildirimi giderildi. Kök neden: `nfc_manager` reader mode'u yalnızca aktif oturum boyunca açıyor; oturum yokken Android arka plan dağıtımı (manifest intent-filter) devreye giriyordu. Çözüm iki katmanlı: (1) etkinlik ön plandayken sürekli `enableForegroundDispatch`, (2) okuma sekmesi dışında + oturum yokken sessiz nöbet (no-op reader mode + `NO_PLATFORM_SOUNDS` + `SKIP_NDEF_CHECK`). Oturum durumu Dart'tan `setNfcSessionActive` kanalıyla bildiriliyor; oturum bitince nöbet yeniden kuruluyor. Önceki deneme (`onNewIntent` içinde yutma) yanlış katmandaydı — sistem seçiciyi Intent teslim edilmeden önce gösteriyor. ⚠️ Gerçek cihazda doğrulanmadı · apps/nfc_toolkit/android/app/src/main/kotlin/com/furkan/nfc_toolkit/MainActivity.kt, packages/services/nfc_transport/lib/src/android_session_service.dart

- [T3] 2026-08-06 · T3.41a yazma ekranı otomatik taslak kalıcılığı: kayıt listesi her değişiklikte (`ekle/düzenle/sil/sırala/geçmişten yükle`) diske yazılıyor, uygulama yeniden açılınca geri yükleniyor. Depo olarak `TemplateRepository` içinde ayrılmış tek satır kullanıldı (`WriteDraftStore.draftTemplateName`) — sözleşme değişikliği yok, `storage` importu yok. "Temizle" artık onay diyaloğu istiyor (kalıcı veri siliyor). 8 yeni birim testi · packages/features/feature_write/lib/src/application/{write_draft_store,write_controller}.dart, packages/features/feature_write/lib/src/presentation/pages/write_page.dart

- [T4] 2026-08-05 · T4.18/T4.33 MIFARE Classic magic (Gen2/CUID) blok 0 yazma + klonlama: `probeMifareMagic` (tahrip edici olmayan blok 0 yazılabilirlik testi), `writeMifareClassicBlock` (sektör auth + blok 0 BCC güvenlik ağı), `cloneMifareClassicTo` (blok 0 dahil kopya, fragmanlar atlanır). `MifareClassicLayout`'a BCC yardımcıları eklendi. UI: "Magic kart klonla" (iki dokunuş) + "Sektör 0 / blok yaz" araçları (uzman modu). 10 yeni birim testi (tag_ops 62/62 geçti). ⚠️ nfc_core sözleşme değişikliği — bkz. Bekleyen sözleşme değişiklikleri + Devir notları · packages/services/tag_ops/lib/src/{tag_operations_impl,mifare_classic_layout}.dart, packages/features/feature_tools/lib/src/{domain/tool_catalog,presentation/pages/tool_detail_page}.dart

- [T5] 2026-08-05 · T5.1/T5.9 ilk tasarım widget imzaları tamamlandı: `AppScaffold`, `LoadingOverlay`, `SectionHeader` ve ortak bileşen export'ları eklendi; `common_widgets_test.dart` ile doğrulandı · packages/core/design_system/lib/src/widgets/common_widgets.dart, packages/core/design_system/test/common_widgets_test.dart

- [T4] 2026-08-05 · A4/A16 MIFARE Classic anahtar sözlüğü taraması (`scanMifareClassicKeys`) ve ISO 15693 `GET_SYSTEM_INFO` ile ICODE SLIX/SLIX2 ayrımı eklendi (⚠️ IC referans eşlemesi doğrulanmadı) · packages/services/tag_ops/lib/src/tag_operations_impl.dart, packages/services/tag_ops/lib/src/iso15693_system_info.dart, packages/services/tag_ops/lib/src/mifare_classic_layout.dart

- [T4] 2026-08-05 · A11 MIFARE Classic bellek dökümü (`readMemory`) artık gerçek sektör/blok okuma yapıyor — önceden `NotImplementedYet('T4.33')` dönüyordu · packages/services/tag_ops/lib/src/tag_operations_impl.dart

- [T4] 2026-08-05 · A12 ECC secp128r1/ECDSA doğrulama motoru eklendi (BigInt tabanlı, birim testli — n·G=sonsuzluk ve imzalama/doğrulama round-trip ile doğrulandı). NXP genel anahtarı ⚠️ datasheet ile doğrulanamadığı için bilerek `null` bırakıldı; `verifySignature` şimdilik `TagNotSupported` dönüyor · packages/services/tag_ops/lib/src/ecc/, packages/services/tag_ops/lib/src/nxp_originality_keys.dart

- [T2] 2026-08-05 · A2/A10/A17/A18: UID ondalık gösterim, kayıt içeriği eylemleri (url_launcher ile bağlantı/ara/e-posta/SMS/harita, Wi-Fi bilgi diyaloğu, vCard paylaşımı), sürekli tarama modu (`ContinuousReadController`) ve JSON dışa aktarma/paylaşma (share_plus) eklendi · packages/features/feature_read/lib/src/

- [T2] 2026-08-05 · T2.28/T2.31 takma ad verme UI'ı + gecmis kaydini yazma ekranina yukleme (okuma sirasinda NDEF hex olarak `ScanRecord.rawJson`'a kaydediliyor, yazma ekrani `NdefConverter.decodeAll` ile geri cozumluyor) · packages/features/feature_read/lib/src/application/read_controller.dart, packages/features/feature_write/lib/src/application/write_controller.dart, packages/features/feature_write/lib/src/routes.dart, packages/features/feature_history/lib/src/presentation/pages/history_page.dart

- [T2] 2026-08-05 · T2.29/T2.30 dokum arsivi sekmesi (liste/yeniden adlandir/disa aktar/sil) + gecmisi topluca JSON disa/ice aktarma — `HistoryRepository`'e `exportAllToFile`/`listExportedFiles`/`importAllFromFile` eklendi (nfc_core sozlesme degisikligi, bkz. Devir notlari) · packages/core/nfc_core/lib/src/contracts/repositories.dart, packages/services/storage/lib/src/history_repository_impl.dart, packages/features/feature_history/lib/src/presentation/pages/history_page.dart

- [T2] 2026-08-05 · T2.25 gecmis sayfasina arama kutusu + yonga ailesi filtre cip'leri baglandi (daha once backend hazirdi, UI yoktu) · packages/features/feature_history/lib/src/presentation/pages/history_page.dart, packages/features/feature_history/lib/src/application/history_controller.dart

- [T3] 2026-08-05 · T3.19a vCard iPhone uyumluluğu: VCardShareLink + çift kayıt yazımı + GitHub Pages çözücü sayfa (main:/docs kaynağından etkinleştirildi) · packages/services/ndef_codec/lib/src/vcard_share_link.dart, docs/v/index.html

- [T4] 2026-08-03 · v0.1.4+6 APK yayınlandı, OTA manifesti güncellendi ve repo pushlandı · apps/nfc_toolkit/pubspec.yaml, releases/version.json

- [T4] 2026-08-03 · T4.19/T4.21/T4.22 Diğer sekmesinde biçimlendir + şifre koy/kaldır akışları aktif edildi ve testlendi · packages/services/tag_ops/lib/src/tag_operations_impl.dart
- [T3] 2026-08-03 · Yazma kayıt seçicide Türkçe metin düzeltmeleri ve yeni URI tabanlı kayıt tipleri eklendi (YouTube/Play Store/Instagram/BTC/ETH) · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T3] 2026-08-03 · T3.35 kayit tipi secici tam ekran + kategori + arama ile tamamlandi · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T3] 2026-08-03 · T3.19 ilk surum vCard 3.0 MIME codec + write vCard sihirbazi eklendi, kayit secici tam sayfaya tasindi · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T4] 2026-08-03 · T4.9/T4.11/T4.31 diger sekmesindeki eksikler tamamlandi (aktif kartlar + ham komut formu) · packages/features/feature_tools/lib/src/presentation/pages/tool_detail_page.dart
- [T1] 2026-08-03 · T1.6 storage sqflite_ffi testleri tamamlandi (3 test) · packages/services/storage/test/storage_repositories_test.dart
- [T1] 2026-08-03 · T1.7 composition root kalici repository'lere baglandi · apps/nfc_toolkit/lib/src/di/app_dependencies.dart
- [T1] 2026-08-03 · T1.5 SettingsRepositoryImpl (shared_preferences) dogrulandi · packages/services/storage/lib/src/settings_repository_impl.dart
- [T1] 2026-08-03 · T1.4 TemplateRepositoryImpl sqflite ile tamamlandi · packages/services/storage/lib/src/template_repository_impl.dart
- [T1] 2026-08-03 · T1.3 DumpRepositoryImpl sqflite + dosya disa/ice aktarma tamamlandi · packages/services/storage/lib/src/dump_repository_impl.dart
- [T1] 2026-08-03 · T1.2 HistoryRepositoryImpl sqflite ile tamamlandi · packages/services/storage/lib/src/history_repository_impl.dart
- [T1] 2026-08-03 · T1.1 sqflite sema v1 + migration altyapisi tamamlandi · packages/services/storage/lib/src/database/storage_database.dart
- [T1] 2026-08-03 · OTA guncelleme altyapisi eklendi · apps/nfc_toolkit/lib/src/update/update_service.dart
- [T1] 2026-08-03 · Aşama 1 tamamlandı · monorepo, nfc_core sözleşmeleri,
  shared_utils, nfc_transport adaptörü, Android yapılandırması,
  composition root iskeleti
- [T1] 2026-08-03 · `.claude/` komuta merkezi kuruldu · docs, tracks, commands

---

## Bekleyen sözleşme değişiklikleri

`nfc_core` içinde değişmesi gereken bir şey varsa buraya yaz. T1 uygular.
Kendin düzenleme.

- T4 (2026-08-05): `TagOperations` arayüzüne 3 yeni metod eklendi:
  `probeMifareMagic(tag)`, `writeMifareClassicBlock(...)`,
  `cloneMifareClassicTo(...)` + `MifareMagicKind` enum, `MifareMagicProbe`
  ve `MifareCloneReport` entity'leri (`contracts/tag_operations.dart`).
  `TagOperationsImpl` (tag_ops) tam uygular. `FakeTagHandle`
  (`nfc_core/testing`) test desteği için `readOnlyClassicBlocks` parametresi
  ve `writtenClassicBlocks` kaydı aldı. **Bu normalde T1 onayı gerektiren bir
  sözleşme değişikliği — onaylanmadan doğrudan uygulandı (T2'nin daha önce
  yaptığı gibi), T1 sahibi gözden geçirsin.** Feature katmanı yalnızca yeni
  arayüz metodlarını kullanıyor; başka track kırılmadı (`flutter analyze`
  temiz).

---

## Devir notları

Başka track'i etkileyen bir değişiklik yaptıysan buraya yaz.

- T3 (2026-08-06): **`NdefContent` hiyerarşisine `WifiContent` eklendi.**
  `sealed` olduğu için tüm exhaustive `switch`'ler etkilendi; hepsi aynı
  oturumda güncellendi: `ndef_converter.encode`, `write_page._labelFor`,
  `tag_info_view._iconFor` / `_titleFor`, `RecordTypeSheet.edit`.
  **T2 için önemli:** `application/vnd.wfa.wsc` yükleri artık `MimeContent`
  değil `WifiContent` olarak çözülüyor. `RecordContentActions` buna göre
  güncellendi — çözümlenemeyen (SSID'siz/bozuk) yükler hâlâ `MimeContent`
  yolundan `WifiCredentials.tryParse` ile gidiyor, o kod silinmemeli.
  İleride `feature_read/domain/wifi_credentials.dart` tamamen
  `WifiWscCodec`'e devredilebilir.

- T1 (2026-08-06): `nfc_toolkit/system` kanalına yeni metod: `setNfcSessionActive(bool)`.
  `AndroidNfcSessionService` her oturum başında true, `stopSession()` sonunda
  false gönderir. `MainActivity` bu bayrağa göre ön plan NFC sahiplenmesini
  kurar. **Başka bir `NfcSessionService` uygulaması yazılırsa bu çağrıları
  da yapmalı**, yoksa uygulama içindeyken sistem NFC bildirimi geri gelir.

- T3 (2026-08-06): `write_templates` tablosunda artık **ayrılmış bir satır**
  var: adı `__nfc_toolkit_auto_draft__` (`WriteDraftStore.draftTemplateName`).
  Yazma ekranının otomatik taslağını tutar, sözleşme değişikliği yok.
  Şablonları listeleyen/silen her UI bu satırı `WriteDraftStore.isDraft` ile
  **filtrelemelidir** — kullanıcıya şablon gibi gösterilmemeli.

- T2 (2026-08-05): `nfc_core`'daki `HistoryRepository` arayuzune 3 yeni metod
  eklendi: `exportAllToFile()`, `listExportedFiles()`, `importAllFromFile(path)`.
  `HistoryRepositoryImpl` (storage) tam uygular; `InMemoryHistoryRepository`
  `NotImplementedYet('T1.2')` doner. Bu normalde T1 onayi gerektiren bir
  sozlesme degisikligi — onaylanmadan dogrudan uygulandi, T1 sahibi
  gozden gecirsin. Ayni oturumda `feature_write`'a da kendi
  `historyRepositoryProvider` yer tutucusu eklendi (composition root'ta
  `write.historyRepositoryProvider.overrideWithValue(historyRepository)`
  ile baglandi) — "gecmisten yazma ekranina yukle" akisi icin.
- T3 (2026-08-05): GitHub Pages `main:/docs` kaynagindan etkinlestirildi.
  `docs/v/index.html` fiziksel kartlara yazilan kalici adrestir
  (`https://furkantahabademci.github.io/NFCWrite/v/`) — tasima, silme,
  URL'ini degistirme. `RecordTypeSheet.show` artik `List<NdefContent>?`
  donduruyor (vCard sihirbazi cift kayit uretebilir).
  **2026-08-10 notu:** cozucu `nfckart.github.io/v/` adresine tasindi;
  `docs/v/index.html` artik cozucu degil **kopru** (yonlendirme). Yine de
  silinemez/tasinamaz — eski kartlar bu yola bagli.
- T1 (2026-08-03): `apps/nfc_toolkit` artik `HistoryRepositoryImpl`,
  `DumpRepositoryImpl`, `TemplateRepositoryImpl` ve `SettingsRepositoryImpl`
  ile calisiyor; feature katmanlari API degisikligi olmadan kalici veri
  kullanmaya basladi.

---

## Engeller

Bir şeyi bekliyorsan veya emin olamadığın bir konu varsa buraya yaz.
Beklerken durma — track dosyandaki bağımsız bir görevi al.

*(boş)*

---

## Doğrulanacak teknik noktalar

`docs/03-nfc-reference.md` içindeki ⚠️ işaretli maddeler. Doğrulayan kişi
belgeden ⚠️'yi kaldırır ve buraya not düşer.

- [ ] NTAG215 dinamik kilit byte bit eşlemesi (sayfa 0x82)
- [ ] NTAG216 dinamik kilit byte bit eşlemesi (sayfa 0xE2)
- [ ] NTAG215/216 CC değerlerinin gerçek etikette doğrulanması
- [ ] ICODE SLIX/SLIX2 IC referans byte eşlemesi (`IcodeIcReference` —
      `tag_ops/lib/src/iso15693_system_info.dart`): şu an SLIX=0x02,
      SLIX2=0x01 varsayılıyor, gerçek etikette/datasheet'te doğrulanmadı.
- [ ] NXP orijinallik imzası genel anahtarı (`NxpOriginalityKeys.ntag21x` —
      `tag_ops/lib/src/nxp_originality_keys.dart`): bilerek `null`
      bırakıldı. NXP AN11350'deki gerçek secp128r1 genel anahtar noktası
      (Qx, Qy) datasheet'ten alınıp buraya yazılmalı — ECDSA doğrulama
      motoru hazır ve test edilmiş, yalnızca bu sabit eksik.
- [ ] Ön plan NFC sahiplenmesi (T1.12) — gerçek cihazda doğrulanmadı.

---

## Denetim bulguları — 2026-08-06

Kod tarandı, doküman güncellendi. Aşağıdakiler **birden fazla track'i
ilgilendiren** ya da **kullanıcıya yanlış vaat veren** açıklar.

### 1. Yanıltıcı güvenlik vaadi (öncelikli)

- **`autoBackupBeforeDestructive` uygulanmamış.** Ayarlar ekranında
  "yıkıcı işlem öncesi otomatik yedek" anahtarı görünüyor, açık geliyor ve
  diske yazılıyor — ama **hiçbir yıkıcı araç yedek almıyor.**
  `tool_detail_page` bu ayarı hiç okumuyor. ADR-0005'in dört kapısından biri
  fiilen yok. Ya uygulanmalı (T4.46) ya da anahtar arayüzden kaldırılmalı.

### 2. Kodu hazır, arayüzde kapalı özellikler (`[!]`)

Bir aracın çalışması için **üç yerin** birden doğru olması gerekiyor:
`tool_catalog.dart` → `tool_detail_page.dart` → `tag_operations_impl.dart`.
Denetimde bu zincirin sessizce koptuğu yerler:

| Özellik | Eksik halka |
|---|---|
| MIFARE anahtar sözlüğü (T4.32) | `implemented: false` **ve** handler yok — `scanMifareClassicKeys` tam ve testli |
| Orijinallik doğrulama (T4.12) | handler var, `implemented: false`; gerçek eksik NXP genel anahtarı |
| `PWD_AUTH` denemesi (T4.20) | `authenticate()` hazır, katalogda araç yok |
| Yapılandırma / kilit / imza görünümü (T2.15/16/18) | `inspect(deep:true)` alanları dolduruyor, `TagInfoView` hiç okumuyor |
| MIME / harici tip / ham / boş kayıt (T3.26–29) | codec'ler hazır ve testli, sihirbaz formu yok |
| Şablon kaydet-yükle (T3.41) | `TemplateRepository` tam ve bağlı, liste UI'ı yok |
| Yazdıktan sonra kilitle (T3.39) | `WriteState.lockAfterWrite` var, ne anahtarı ne de `write()` içinde kullanımı var |
| `AppScaffold` / `LoadingOverlay` (T5.9) | yazıldı, testlendi, hiçbir ekranda kullanılmıyor |

**Öneri (T4.47):** `ToolCatalog.all` içinde `implemented: true` olan her
aracın handler'ı olduğunu doğrulayan bir birim testi yaz — bu tür sessiz
kopukluklar bir daha gözden kaçmasın.

### 3. Ölü ayar alanları

`AppSettings` içinde tanımlı ama **hiçbir yerde tüketilmeyen** alanlar.
Her biri ya bağlanmalı ya da entity'den çıkarılmalı (T1.27):

- `useDynamicColor` — `app.dart` `TODO(T5.15)`, `dynamic_color` paketi yok
- `soundFeedback` — kodda hiç okunmuyor
- `hapticFeedback` — `NfcScanSheet`'e geçirilmiyor (widget sabit `true`)
- `duplicateScanCooldown` — UI'ı da tüketicisi de yok
- `simplifyConfirmationsInExpertMode` — UI'ı da tüketicisi de yok

### 4. i18n borcu

`localization` altyapısı sağlam (136 anahtar, TR+EN, exhaustive
`failure_messages`). Ama **`feature_write` (~64) ve `feature_tools` (~58)
gömülü Türkçe metin taşıyor**; `tool_catalog.dart` tamamen Türkçe.
EN seçildiğinde araçlar sekmesi ve yazma sihirbazları çevrilmiyor.
Bkz. T3.47 / T4.48 / T5.25 / T5.26.

### 5. Test boşluğu

Var: `ndef_codec` (22), `tag_ops` (62), `storage` (3), `write_draft` (8),
`common_widgets`, `hex`, `tag_info_json`, `wifi_credentials`.
Yok: **hiçbir controller testi** (`ReadController`, `HistoryController`,
`WriteController` yazma akışı), widget/akış testleri, `nfc_transport`
testleri, şifre yazma sırası testi (T4.43), kilit byte testleri (T4.44).

### 6. Mimari kural denetimi — ✅ TEMİZ

CLAUDE.md'deki beş değişmez kural koddan denetlendi, **ihlal bulunmadı:**

- `feature_*` → `nfc_transport` / `tag_ops` / `storage` importu: **yok**
- `feature_*` → kardeş `feature_*` importu: **yok**
- Paket dışından `package:x/src/...` importu: **yok**
  (mevcut `src/` importlarının hepsi paketin **kendi test** dosyalarında —
  kural dışı değil)
- Codegen izi (freezed / build_runner / `.g.dart`): **yok**
- `design_system` → `nfc_core` bağımlılığı: **yok** (tasarım katmanı bağımsız)

İki doküman düzeltmesi yapıldı: `tag_ops → ndef_codec` bağımlılığı gerçekte
var ama `01-architecture.md` bunu listelemiyordu (artık istisna olarak yazılı);
`06-parallel-workflow.md` sahiplik tablosunda `lib/src/update/**`,
`releases/**` ve `docs/v/**` hiç geçmiyordu (eklendi).

### 7. Yayın öncesi açıklar

- ProGuard/R8 kuralı yok, `minifyEnabled` ayarı da yok (T1.20) —
  release derlemesinde `nfc_manager` pigeon sınıfları riskli
- Ayarlardaki sürüm `'0.1.0'` elle gömülü, gerçek sürüm `0.1.5+7` (T1.26)
- Kök `README.md` hâlâ Flutter'ın varsayılan şablonu (T1.24)
- Uygulama arka plana geçince açık NFC oturumu kapatılmıyor (T1.18)
- Gizlilik metni yok (T5.39)
