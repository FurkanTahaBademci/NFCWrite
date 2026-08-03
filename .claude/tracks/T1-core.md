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
- [ ] T1.2 `HistoryRepositoryImpl` — ekle/listele/ara/sil/takma ad
- [ ] T1.3 `DumpRepositoryImpl` — dump kaydet/oku/sil, dosya olarak dışa aktar
- [ ] T1.4 `TemplateRepositoryImpl` — yazma şablonları
- [ ] T1.5 `SettingsRepositoryImpl` — `shared_preferences` üzerinden
- [ ] T1.6 `storage` birim testleri (`sqflite_common_ffi` ile)
- [ ] T1.7 Composition root'ta repository override'larını bağla

## Aşama 3 — Oturum sağlamlaştırma

- [ ] T1.8 NFC uygunluk akışı: desteklenmiyor / kapalı / açık ayrımı,
      kapalıysa Android NFC ayarlarına yönlendirme (`AppSettings` intent)
- [ ] T1.9 Oturum modları: tek seferlik, sürekli tarama, işlem oturumu
- [ ] T1.10 Zaman aşımı + iptal (`CancellationToken` benzeri)
- [ ] T1.11 `TagLost` kurtarma: işlem ortasında etiket giderse temiz hata
- [ ] T1.12 Foreground dispatch — uygulama açıkken etiket başka uygulamaya
      gitmesin
- [ ] T1.13 NFC intent ile uygulamayı açma (`NDEF_DISCOVERED`, `TECH_DISCOVERED`)
      ve doğrudan okuma ekranına düşme
- [ ] T1.14 `nfc_transport` sahte (fake) uygulaması — diğer track'ler cihazsız
      test edebilsin (`FakeNfcSessionService`)

## Aşama 4 — Uygulama kabuğu

- [ ] T1.15 go_router birleştirme: tüm feature rotalarını topla, shell route
- [ ] T1.16 Alt gezinme çubuğu + sekme durumu koruma
- [ ] T1.17 Global hata yakalayıcı + `NfcFailure` → snackbar köprüsü
- [ ] T1.18 Uygulama yaşam döngüsü: arka plana geçince oturumu kapat
- [ ] T1.19 Sürüm/derleme bilgisi, `flutter build apk --release` doğrulaması
- [ ] T1.20 ProGuard/R8 kuralları (nfc_manager pigeon sınıfları)

## Aşama 5 — Kalite

- [ ] T1.21 CI betiği: `analyze` + `test` (`.claude/scripts/verify.ps1`)
- [ ] T1.22 `nfc_core` kapsam > %80
- [ ] T1.23 Uygulama ikonu + açılış ekranı
- [ ] T1.24 README (kullanıcıya yönelik)

---

## Senkronizasyon sorumluluğun

- **S1 sözleşme kilidi:** Aşama 1 bitti → `nfc_core` API'si dondu.
  Değişiklik gerekirse `state/progress.md` → "Bekleyen sözleşme değişiklikleri"
  listesini kontrol et, toplu uygula, diğer track'lere duyur.
- Diğer track'lerin `feature_*` paketini `apps/nfc_toolkit/pubspec.yaml` ve
  kök `workspace:` listesine eklemek **senin** işin.
