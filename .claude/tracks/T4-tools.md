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

---

## Aşama 1 — `tag_ops` temeli

- [ ] T4.1 `TagOperationsImpl` iskeleti — `NfcSessionService` DI ile alınır
- [ ] T4.2 Komut katmanı: `Ntag21xCommands` — GET_VERSION, READ, FAST_READ,
      WRITE, PWD_AUTH, READ_CNT, READ_SIG, HALT (`docs/03 §2.6`)
- [ ] T4.3 `identify()` — GET_VERSION + ATQA/SAK ile yonga tespiti,
      `TagIdentity` döndür (NTAG213/215/216, UL, UL EV1, Classic, ICODE)
- [ ] T4.4 `readMemory()` — `FAST_READ` ile tam dump,
      `getMaxTransceiveLength()` sınırına göre parçala
- [ ] T4.5 `readPage()` / `writePage()` — sınır kontrolü, yazma sonrası doğrulama
- [ ] T4.6 Yapılandırma çözümleyici: CFG0/CFG1 → `NtagConfig` nesnesi
      (AUTH0, PROT, CFGLCK, AUTHLIM, MIRROR, NFC_CNT_EN)
- [ ] T4.7 Kilit byte çözümleyici: statik + dinamik → hangi sayfa kilitli
- [ ] T4.8 `FakeTransport` test altyapısı — beklenen komut / sahte cevap

## Aşama 2 — Güvenli araçlar (risk yok)

- [ ] T4.9 C14 Bellek dökümü al → `TagDump` nesnesi
- [ ] T4.10 Dump'ı `.bin` ve `.json` olarak dışa aktar
- [ ] T4.11 A13 Sayaç okuma (`READ_CNT`)
- [~] T4.12 A12 ECC imza okuma (`READ_SIG`) + NXP açık anahtarıyla doğrulama —
      secp128r1/ECDSA motoru tamam ve test edilmiş (`tag_ops/lib/src/ecc/`);
      NXP genel anahtarı ⚠️ doğrulanamadığından bilerek `null`
      (`NxpOriginalityKeys`), `verifySignature` `TagNotSupported` dönüyor
- [ ] T4.13 C19 Komut ön ayarları listesi (hazır komut düğmeleri)

## Aşama 3 — İçerik araçları

- [ ] T4.14 C3 Temizle — boş NDEF mesajı yaz (`DangerAck` gerekli)
- [ ] T4.15 C1 Kopyala — kaynak oku → hedefe yaz, kapasite kontrolü,
      iki aşamalı akış (önce kaynak, sonra hedef), aradaki durumu göster
- [ ] T4.16 C4 Fabrika sıfırlama — kullanıcı sayfalarını 0x00 yap
- [ ] T4.17 C15 Dump geri yükleme — dosyadan oku, uyumluluk kontrolü, yaz
- [x] T4.18 C2 Tam klon — MIFARE Classic magic (Gen2/CUID) klonlama:
      `probeMifareMagic` (blok 0 yazılabilirlik testi, tahrip edici değil) +
      `cloneMifareClassicTo` (blok 0 dahil kopya, fragmanlar varsayılan olarak
      atlanır). Hedef magic değilse `TagNotSupported`. UI: "Magic kart klonla"
      (iki dokunuş). BCC otomatik doğrulanır/düzeltilir.

## Aşama 4 — Yapılandırma araçları

- [ ] T4.19 C5 Biçimlendir — CC yaz + boş NDEF TLV.
      `NdefFormatable` varsa onu kullan, yoksa elle CC yaz
- [ ] T4.20 C13 `PWD_AUTH` — kimlik doğrulama, PACK karşılaştırma
- [ ] T4.21 C8 **Şifre koy** — `docs/03 §2.8` sırasına **harfiyen** uy:
      PWD → PACK → CFG1(ACCESS) → CFG0(AUTH0). AUTH0 en son.
- [ ] T4.22 C9 Şifre kaldır — doğrula → AUTH0=0xFF → PWD/PACK temizle
- [ ] T4.23 C10 Şifre değiştir (doğrula → yeni PWD/PACK yaz)
- [ ] T4.24 C11 PROT biti — yazma-koruma / okuma+yazma-koruma seçimi
- [ ] T4.25 C16 UID mirror yapılandırma (MIRROR_CONF + MIRROR_PAGE + MIRROR_BYTE)
- [ ] T4.26 C17 NFC sayaç etkinleştirme + sayaç mirror

## Aşama 5 — Geri alınamaz araçlar (UZMAN MODU)

Her biri: `DangerAck` + otomatik yedek + `DangerDialog` + uzman modu kapısı.

- [ ] T4.27 C6 Salt-okunur yap — CC erişim byte'ı + statik kilit
- [ ] T4.28 C7 Sayfa bazlı kilitleme — görsel sayfa seçici, ne olacağını göster
- [ ] T4.29 C12 AUTHLIM ayarı — "n denemeden sonra etiket ERİŞİLEMEZ olur"
      uyarısı zorunlu
- [ ] T4.30 CFGLCK — en sert onay, ayrı ekran, "yapılandırma sonsuza dek
      dondurulacak"

## Aşama 6 — Uzman araçları

- [ ] T4.31 C18 **Ham komut konsolu** — hex giriş, cevap gösterimi, komut
      geçmişi, kaydedilmiş komutlar, sürekli oturum
- [x] T4.32 C20 MIFARE Classic anahtar sözlüğü — varsayılan anahtarları dene,
      hangi sektör hangi anahtarla açıldı raporu
- [~] T4.33 C21 MIFARE Classic blok okuma / yazma + sektör fragmanı düzenleyici —
      `readMemory()` gerçek sektör/blok dökümü yapıyor; blok **yazma** eklendi
      (`writeMifareClassicBlock` — sektör auth + blok 0 BCC güvenlik ağı, UI:
      "Sektör 0 / blok yaz"). Görsel sektör fragmanı (trailer) düzenleyici
      hâlâ yok — bilerek: erişim byte'ları yanlışsa sektör ölür.
- [ ] T4.34 C22 ISO15693 blok okuma/yazma, AFI/DSFID okuma-yazma
- [ ] T4.35 C23 ISO15693 blok kilitleme (uzman modu)
- [ ] T4.36 C24 Etiket sağlığı testi — tüm sayfaları yaz/oku doğrula
      (verileri bozar — önce yedek, açık uyarı)

## Aşama 7 — Araç arayüzü (`feature_tools`)

- [ ] T4.37 `ToolsPage` — risk seviyesine göre gruplu ızgara
      (Güvenli / İçerik / Yapılandırma / Geri alınamaz)
- [ ] T4.38 Her araç için ortak ekran iskeleti: açıklama → parametreler →
      onay → yürütme → sonuç
- [ ] T4.39 `ToolController` tabanı — ortak akış, hata gösterimi, yedek alma
- [ ] T4.40 Uzman modu filtresi (ayardan gelir, `SettingsRepository` arayüzü)
- [ ] T4.41 Sonuç ekranı — ne değişti, öncesi/sonrası dump farkı

## Aşama 8 — Test

- [ ] T4.42 Her komut için `FakeTransport` ile birim testi —
      **gönderilen byte dizisi birebir doğrulanmalı**
- [ ] T4.43 Şifre koyma sırası testi — yazma sırası yanlışsa test kırmızı olsun
- [ ] T4.44 Kilit byte hesaplama testleri
- [ ] T4.45 Sınır kontrolü testleri (kullanıcı alanı dışına yazma reddi)

---

## Notlar

- `docs/03-nfc-reference.md` içinde ⚠️ işaretli satırlar **doğrulanmamış**.
  Uygulamadan önce NXP datasheet ile karşılaştır, doğruladıktan sonra
  belgeden ⚠️'yi kaldır ve datasheet sürümünü yaz.
- Test için gözden çıkarılabilir NTAG213 etiketleri kullan. İlk kilitleme
  testinde etiket gider — bu normaldir, bekleneni bilerek yap.
- Bir işlemin ne yaptığından emin değilsen **yazma**. `state/progress.md`
  → "Engeller" bölümüne yaz.
