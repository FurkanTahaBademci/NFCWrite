# T4 — Etiket Araçları (Pro Özellikler)

**Sahip olduğun yollar:**
```
packages/features/feature_tools/**
packages/services/tag_ops/**
```

**Kullanabileceğin paketler:** `nfc_core`, `ndef_codec`, `design_system`,
`localization`, `shared_utils`
**YASAK:** `nfc_transport` (transport sana DI ile gelir), `storage`,
diğer `feature_*`

**Okuman gerekenler:** `docs/03-nfc-reference.md` (**tamamı**),
`docs/adr/ADR-0005-safety-gates.md`, `docs/02-feature-matrix.md` (C bölümü)

> ⚠️ **Sen en riskli track'sin.** Yazdığın kod kullanıcıların etiketlerini
> kalıcı olarak bozabilir. ADR-0005'teki dört kapıdan geçmeyen tek bir
> yıkıcı işlem bile yazma. Şüphedeysen datasheet'e bak, tahmin etme.

> Durum kodları: `[ ]` yapılmadı · `[~]` kısmi · `[x]` bitti ·
> `[!]` **`tag_ops` hazır, arayüzde kapalı**.
> Son denetim: **2026-08-06** — koddan doğrulandı.
>
> Bir aracın çalışması için **üç yerin birden** doğru olması gerekir:
> `tool_catalog.dart` (`implemented: true`) → `tool_detail_page.dart`
> (`switch` içinde `case`) → `tag_operations_impl.dart` (gerçek uygulama).
> Denetimde iki araç tam da bu yüzden sessizce kapalı bulundu (T4.12, T4.32).

---

## Aşama 1 — `tag_ops` temeli (BİTTİ)

- [x] T4.1 `TagOperationsImpl` iskeleti — `NfcSessionService` DI ile alınır
- [x] T4.2 Komut katmanı: `ntag_commands.dart` — GET_VERSION, READ, FAST_READ,
      WRITE, PWD_AUTH, READ_CNT, READ_SIG
- [x] T4.3 `identify()` — GET_VERSION + ATQA/SAK ile yonga tespiti
      (NTAG213/215/216, UL, UL EV1, Classic, ICODE SLIX/SLIX2)
- [x] T4.4 `readMemory()` — `FAST_READ` ile tam dump, transceive sınırına
      göre parçalanır; MIFARE Classic için gerçek sektör/blok okuması
- [x] T4.5 `readPage()` / `writePage()` — sınır kontrolü + yazma doğrulaması
- [x] T4.6 Yapılandırma çözümleyici — `config_parser.dart` → `NtagConfig`
- [x] T4.7 Kilit byte çözümleyici — `readLockStatus()` (statik + dinamik)
- [x] T4.8 Test altyapısı — `FakeTagHandle` (`nfc_core/testing`) ile 62 test;
      gönderilen komutlar ve yazılan sayfalar birebir doğrulanıyor

## Aşama 2 — Güvenli araçlar (risk yok)

- [x] T4.9 C14 Bellek dökümü al → `TagDump` nesnesi
- [x] T4.10 Dump'ı `.bin` ve `.json` olarak dışa/içe aktar
      (`DumpRepositoryImpl.exportToFile(asBinary:)` / `importFromFile`)
- [x] T4.11 A13 Sayaç okuma (`READ_CNT`)
- [!] T4.12 A12 ECC imza okuma + doğrulama — **arayüzde kapalı.**
      secp128r1/ECDSA motoru tam ve testli (`tag_ops/lib/src/ecc/`),
      `tool_detail_page` içinde `case 'verify_signature'` handler'ı **var**,
      ama katalogda `implemented: false` olduğu için düğme devre dışı.
      Tek gerçek eksik: `NxpOriginalityKeys.ntag21x` sabiti ⚠️ bilerek `null`.
      **Anahtar girilmeden `implemented: true` yapma** — araç
      `TagNotSupported` döner ve kullanıcı bozuk sanır.
- [ ] T4.13 C19 Komut ön ayarları listesi (hazır komut düğmeleri)

## Aşama 3 — İçerik araçları

- [x] T4.14 C3 Temizle — boş NDEF mesajı yaz (`DangerAck` gerekli)
- [x] T4.15 C1 Kopyala — iki aşamalı akış, kapasite kontrollü
- [x] T4.16 C4 Fabrika sıfırlama — kullanıcı sayfalarını 0x00 yap
- [~] T4.17 C15 Dump geri yükleme — NTAG/UL çalışıyor; **MIFARE Classic dalı
      `NotImplementedYet('T4.17')` dönüyor** (`tag_operations_impl.dart`).
      Sayfa boyutu ≠ 4 olan dökümler de reddediliyor.
- [x] T4.18 C2 Tam klon — MIFARE Classic magic (Gen2/CUID) klonlama:
      `probeMifareMagic` (blok 0 yazılabilirlik testi, tahrip edici değil) +
      `cloneMifareClassicTo` (blok 0 dahil kopya, fragmanlar varsayılan olarak
      atlanır). Hedef magic değilse `TagNotSupported`. UI: "Magic kart klonla"
      (iki dokunuş). BCC otomatik doğrulanır/düzeltilir.

## Aşama 4 — Yapılandırma araçları

- [x] T4.19 C5 Biçimlendir — CC yaz + boş NDEF TLV
- [!] T4.20 C13 `PWD_AUTH` — `authenticate()` **tag_ops'ta hazır ve testli**;
      katalogda bağımsız bir araç yok, yalnızca şifre kaldırma akışında
      dolaylı kullanılıyor. "Şifreyi dene" aracı ucuz bir eklemedir.
- [x] T4.21 C8 **Şifre koy** — yazma sırası korunuyor:
      PWD → PACK → CFG1(ACCESS) → CFG0(AUTH0)
- [x] T4.22 C9 Şifre kaldır — doğrula → AUTH0=0xFF
- [ ] T4.23 C10 Şifre değiştir — `changePassword` → `NotImplementedYet('T4.23')`;
      **katalogda araç kaydı bile yok**, arayüzde hiç görünmüyor
- [~] T4.24 C11 PROT biti — `PasswordSetup.scope` sözleşmede var ve
      uygulanıyor; **şifre koyma formunda seçici yok**, hep `writeOnly`
- [x] T4.25 C16 UID mirror yapılandırma
- [x] T4.26 C17 NFC sayaç etkinleştirme

## Aşama 5 — Geri alınamaz araçlar (UZMAN MODU)

Her biri: `DangerAck` + otomatik yedek + `DangerDialog` + uzman modu kapısı.

> ✅ **Otomatik yedek kapısı 2026-08-06'da uygulandı** (T4.46).
> Yeni yıkıcı araç eklerken `_ensureBackup` çağrısını atlama.

- [x] T4.27 C6 Salt-okunur yap — `makeNdefReadOnly()`, uzman modu + DangerDialog
- [ ] T4.28 C7 Sayfa bazlı kilitleme — `lockPages` → `NotImplementedYet('T4.28')`;
      katalogda `implemented: false`, handler yok
- [~] T4.29 C12 AUTHLIM ayarı — `PasswordSetup.authLimit` uygulanıyor
      (0–7 doğrulamalı); **formda alan yok** — bilerek, yanlış değer etiketi
      kalıcı olarak erişilemez yapar
- [ ] T4.30 CFGLCK — `lockConfiguration` → `NotImplementedYet('T4.30')`;
      katalogda `implemented: false`, handler yok

## Aşama 6 — Uzman araçları

- [~] T4.31 C18 **Ham komut konsolu** — hex giriş + cevap gösterimi (HEX+ASCII)
      + kanal seçimi çalışıyor; **komut geçmişi ve kaydedilmiş komutlar yok**
- [x] T4.32 C20 MIFARE Classic anahtar sözlüğü — **etkinleştirildi.**
      Katalogda `implemented: true`, `_runSafeTool` içinde `case 'mifare_keys'`.
      Rapor `_formatKeyScanReport` ile üretilir: `S0: A FFFFFFFFFFFF`
      biçiminde sektör sektör, açılamayan sektörler de listelenir, tamamı
      varsayılan anahtarla açıldıysa "bu kart korumasız" uyarısı eklenir.
- [~] T4.33 C21 MIFARE Classic blok okuma / yazma + sektör fragmanı düzenleyici —
      `readMemory()` gerçek sektör/blok dökümü yapıyor; blok **yazma** eklendi
      (`writeMifareClassicBlock` — sektör auth + blok 0 BCC güvenlik ağı, UI:
      "Sektör 0 / blok yaz"). Görsel sektör fragmanı (trailer) düzenleyici
      hâlâ yok — bilerek: erişim byte'ları yanlışsa sektör ölür.
- [~] T4.34 C22 ISO15693 — `readIso15693Block` çalışıyor;
      **`writeIso15693Block` → `NotImplementedYet('T4.34')`**, AFI/DSFID
      okuma-yazma yok. Ayrıca **katalogda hiç ISO15693 aracı yok** —
      okuma bile arayüzden erişilebilir değil.
- [ ] T4.35 C23 ISO15693 blok kilitleme (uzman modu)
- [ ] T4.36 C24 Etiket sağlığı testi — tüm sayfaları yaz/oku doğrula
      (verileri bozar — önce yedek, açık uyarı)

## Aşama 7 — Araç arayüzü (`feature_tools`)

- [x] T4.37 `ToolsPage` — kategori başlıklı gruplu liste, `ToolCard` ile
- [x] T4.38 Ortak ekran iskeleti — `ToolDetailPage`: açıklama → parametre
      formu → `DangerDialog` onayı → `NfcScanSheet` → sonuç
- [ ] T4.39 `ToolController` tabanı — **yok.** Tüm akış `ToolDetailPage`
      içinde `StatefulWidget` durumu olarak duruyor (~700 satır, araç
      başına `if`/`case` blokları). Yedek alma ve öncesi/sonrası karşılaştırma
      için ortak bir taban gerekiyor.
- [x] T4.40 Uzman modu filtresi — `ToolCatalog.byCategory(expertMode:)`
- [ ] T4.41 Sonuç ekranı — ne değişti, öncesi/sonrası dump farkı
      (şu an yalnızca tek satırlık metin sonucu)

## Aşama 8 — Test

- [~] T4.42 `FakeTagHandle` ile 62 test var; gönderilen komutlar
      (`sentCommands`) ve yazılan sayfalar (`writtenPages`) birebir
      doğrulanıyor. **Her komut kapsanmıyor**
- [ ] T4.43 Şifre koyma sırası testi — yazma sırası yanlışsa test kırmızı olsun
- [ ] T4.44 Kilit byte hesaplama testleri
- [ ] T4.45 Sınır kontrolü testleri (kullanıcı alanı dışına yazma reddi)

## Aşama 9 — Denetimde çıkan işler (2026-08-06)

- [x] T4.46 **Otomatik yedek uygulandı (ADR-0005 2. kapı).**
      `_ensureBackup` / `_saveBackup`: yıkıcı işlemden önce `readMemory` +
      `DumpRepository.add` (`DumpReason.automaticBackup`, etiket
      "<araç adı> öncesi yedek"). Üç akış da geçiyor: normal yıkıcı araçlar,
      "Etiketi kopyala" ve "Magic kart klonla" (ikisinde de **hedef** etiket
      yedeklenir). Yedek alınamazsa işlem **varsayılan olarak iptal** edilir;
      kullanıcı açıkça "Yedeksiz devam et" derse geçilir.
      `DangerAck.backupTaken` artık gerçek sonucu taşıyor (önceden her zaman
      diyalogdaki anahtarın değeriydi — yedek alınmadığı halde `true`).
      Ayar kapalıysa `DangerDialog`'da yedek anahtarı hiç gösterilmez.
- [ ] T4.47 **Katalog ↔ handler tutarlılık testi.** `ToolCatalog.all` içinde
      `implemented: true` olan her aracın `tool_detail_page` içinde bir
      handler'ı olduğunu doğrulayan bir birim testi yaz. T4.12/T4.32
      türü sessiz kopukluklar bir daha gözden kaçmasın.
- [ ] T4.48 **i18n borcu:** `tool_catalog.dart` tamamen gömülü Türkçe
      (başlık + açıklama), `tool_detail_page` içinde ~58 gömülü metin daha
      var. EN dilinde araç sekmesi çevrilmiyor.

---

## Notlar

- `docs/03-nfc-reference.md` içinde ⚠️ işaretli satırlar **doğrulanmamış**.
  Uygulamadan önce NXP datasheet ile karşılaştır, doğruladıktan sonra
  belgeden ⚠️'yi kaldır ve datasheet sürümünü yaz.
- Test için gözden çıkarılabilir NTAG213 etiketleri kullan. İlk kilitleme
  testinde etiket gider — bu normaldir, bekleneni bilerek yap.
- Bir işlemin ne yaptığından emin değilsen **yazma**. `state/progress.md`
  → "Engeller" bölümüne yaz.
