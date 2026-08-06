# T1 — Çekirdek & NFC Altyapısı

**Sahip olduğun yollar** (başka yere yazma):
```
packages/core/nfc_core/**
packages/core/shared_utils/**
packages/services/nfc_transport/**
packages/services/storage/**
apps/nfc_toolkit/android/**
apps/nfc_toolkit/lib/**
pubspec.yaml (kök)
.claude/docs/**
```

**Rolün:** Sen altyapısın. Diğer 4 track senin sözleşmelerine göre kodluyor.
Bir şeyi geciktirirsen herkes bekler. Öncelik sırasına harfiyen uy.

**Okuman gerekenler:** `docs/01-architecture.md`, `docs/05-conventions.md`,
`docs/03-nfc-reference.md`

---

## Aşama 1 — Sözleşmeler (BİTTİ, bu commit'te teslim edildi)

- [x] `nfc_core`: `Result<T>`, `NfcFailure` hiyerarşisi
- [x] `nfc_core`: varlıklar — `NfcTagInfo`, `TagTechnology`, `TagIdentity`,
      `TagMemory`, `NdefMessageEntity`, `NdefRecordEntity`
- [x] `nfc_core`: arayüzler — `NfcSessionService`, `NfcTagHandle`,
      `TagOperations`, `HistoryRepository`, `DumpRepository`,
      `TemplateRepository`, `SettingsRepository`
- [x] `nfc_core`: `DangerAck` güvenlik tipi
- [x] `shared_utils`: hex/byte dönüşümleri, bit alanı yardımcıları, logger
- [x] `nfc_transport`: `nfc_manager` adaptörü, oturum yönetimi, transceive
- [x] Android manifest + NFC izinleri
- [x] Composition root iskeleti + provider override mekanizması

## Aşama 2 — Depolama (SIRADAKİ)

- [x] T1.1 `storage`: sqflite şema v1 — `scan_history`, `tag_dumps`,
      `write_templates`, `tag_aliases` tabloları + migration altyapısı
- [x] T1.2 `HistoryRepositoryImpl` — ekle/listele/ara/sil/takma ad
- [x] T1.3 `DumpRepositoryImpl` — dump kaydet/oku/sil, dosya olarak dışa aktar
- [x] T1.4 `TemplateRepositoryImpl` — yazma şablonları
- [x] T1.5 `SettingsRepositoryImpl` — `shared_preferences` üzerinden
- [x] T1.6 `storage` birim testleri (`sqflite_common_ffi` ile)
- [x] T1.7 Composition root'ta repository override'larını bağla

## Aşama 3 — Oturum sağlamlaştırma (BİTTİ)

- [x] T1.8 NFC uygunluk akışı: `NfcUnavailable(reason:)` ayrımı; kapalıysa
      snackbar eylemi → `openNfcSettings()` (MainActivity method channel)
- [x] T1.9 Oturum modları: `runOnce`, sürekli tarama, işlem oturumu
- [x] T1.10 Zaman aşımı + iptal (`runOnce(timeout:)` → `OperationTimeout`,
      `stopSession()`)
- [x] T1.11 `TagLost` kurtarma — `error_mapper.dart` `TagLostException` → `TagLost`
- [x] T1.12 Foreground dispatch — iki katmanlı: etkinlik ön plandayken
      sürekli `enableForegroundDispatch`, okuma sekmesi dışında + oturum
      yokken sessiz nöbet (no-op reader mode + `NO_PLATFORM_SOUNDS` +
      `SKIP_NDEF_CHECK`). Durum iki kanaldan bildiriliyor:
      `setReadPageVisible` (`shell_page.dart`) ve `setNfcSessionActive`
      (`android_session_service.dart`). ⚠️ Gerçek cihazda doğrulanmadı.
- [x] T1.13 NFC intent ile uygulamayı açma — manifest'te NDEF/TECH/TAG
      DISCOVERED + `nfc_tech_filter.xml`; `onNfcIntent` okuma ekranını tarar
- [~] T1.14 Sahte (fake) uygulama — `FakeNfcSessionService` ve `FakeTagHandle`
      **`nfc_core/testing`** içinde (planlandığı gibi `nfc_transport`'ta değil).
      Sözleşme paketinde durması feature testlerinin transport'a bağımlı
      olmamasını sağlıyor — bilinçli sapma, taşınmayacak.

## Aşama 4 — Uygulama kabuğu

- [x] T1.15 go_router birleştirme — `createRouter()`, `StatefulShellRoute`
- [x] T1.16 Alt gezinme çubuğu + sekme durumu koruma (`indexedStack`)
- [~] T1.17 `NfcFailure` → snackbar köprüsü **feature başına** yapılıyor
      (`read_page`, `write_page`, `tool_detail_page`). Global bir hata
      yakalayıcı (`FlutterError.onError` / zone) yok.
- [ ] T1.18 Uygulama yaşam döngüsü: arka plana geçince oturumu kapat —
      `didChangeAppLifecycleState` dinleyicisi hiçbir yerde yok. Uygulama
      arka plana atılınca açık NFC oturumu kapanmıyor.
- [x] T1.19 Sürüm/derleme bilgisi — `0.1.5+7`, release APK yayınlandı
- [ ] T1.20 ProGuard/R8 kuralları (nfc_manager pigeon sınıfları) —
      kural dosyası yok, `build.gradle`'da `minifyEnabled` ayarı da yok

## Aşama 5 — Kalite

- [~] T1.21 CI betiği: `.claude/scripts/verify.ps1` var; otomatik çalışan
      bir CI (GitHub Actions vb.) yok
- [ ] T1.22 `nfc_core` kapsam > %80 — kapsam ölçümü hiç alınmadı
- [x] T1.23 Uygulama ikonu (adaptive + monochrome + round, tüm dpi'lar)
- [ ] T1.24 README (kullanıcıya yönelik) — kök `README.md` hâlâ Flutter'ın
      varsayılan şablonu

## Aşama 6 — Tespit edilen açıklar (denetim 2026-08-06)

- [ ] T1.25 **`autoBackupBeforeDestructive` uygulanmıyor.** Ayar ekranında
      görünüyor ve diske yazılıyor ama hiçbir yıkıcı araç yedek almıyor.
      ADR-0005'in dört kapısından biri fiilen yok. Ya uygulanmalı ya da
      anahtar arayüzden kaldırılmalı.
- [ ] T1.26 Ayar sürümü elle gömülü — `settings_page.dart` `'0.1.0'`
      yazıyor, gerçek sürüm `0.1.5+7`. `package_info_plus` zaten bağımlılık
      olarak var, oradan okunmalı.
- [ ] T1.27 Kullanılmayan ayar alanları: `duplicateScanCooldown`,
      `simplifyConfirmationsInExpertMode`, `soundFeedback`, `useDynamicColor`.
      Her biri ya bağlanmalı ya da `AppSettings`'ten çıkarılmalı.

---

## Senkronizasyon sorumluluğun

- **S1 sözleşme kilidi:** Aşama 1 bitti → `nfc_core` API'si dondu.
  Değişiklik gerekirse `state/progress.md` → "Bekleyen sözleşme değişiklikleri"
  listesini kontrol et, toplu uygula, diğer track'lere duyur.
- Diğer track'lerin `feature_*` paketini `apps/nfc_toolkit/pubspec.yaml` ve
  kök `workspace:` listesine eklemek **senin** işin.
