# 02 — Özellik Matrisi

Durum kodları:
`[ ]` yapılmadı · `[~]` devam ediyor · `[x]` bitti · `[-]` kapsam dışı
`[!]` **kod hazır ama arayüzde kapalı / bağlanmamış** — en kısa yoldan
kazanılacak özellikler bunlardır.

> **Son denetim: 2026-08-06.** Bu tablo koddan doğrulanarak güncellendi.
> Bir satırı değiştirirken kaynağı da yaz (dosya yolu), yoksa bir sonraki
> denetimde tekrar doğrulanması gerekir.

---

## A. OKUMA (Track T2 · `feature_read`)

| # | Özellik | Durum | Not |
|---|---|---|---|
| A1 | Etiket tarama oturumu (bekle / bulundu / hata durumları) | [x] | `ReadController` + `NfcScanSheet` + hata snackbar'ı (eylemli) |
| A2 | UID / seri numarası (hex + ters sıra + ondalık gösterim) | [x] | `formatUidDecimal` (shared_utils) + `TagInfoView`'da satır |
| A3 | Etiket teknolojileri listesi (NfcA, Ndef, MifareUltralight...) | [x] | `_IdentityTab` içinde `TagBadge` listesi |
| A4 | Yonga (IC) tanımlama: NTAG213/215/216, Ultralight EV1, Classic 1K/4K, ICODE SLIX | [x] | ICODE SLIX/SLIX2 `GET_SYSTEM_INFO` IC referansıyla ayrılıyor — ⚠️ eşleme doğrulanmadı |
| A5 | Üretici tanımlama (UID byte 0 → IC üreticisi) | [x] | `TagManufacturer.fromUidByte` + `readManufacturer` satırı |
| A6 | Bellek bilgisi: toplam / kullanılan / boş byte, sayfa sayısı | [x] | `identity.totalBytes` / `userBytes` + `CapacityBar` |
| A7 | Yazılabilir mi / salt-okunur mu / biçimlendirilmiş mi | [x] | Üç `TagBadge` rozeti |
| A8 | NDEF mesaj çözümleme — kayıt kayıt liste | [x] | `_NdefTab` + `_RecordCard` |
| A9 | Her kayıt için: TNF, tip, id, payload (metin + hex) | [x] | Genişletilebilir `_RecordCard` |
| A10 | Kayıt içeriğine göre eylem (URL aç, ara, telefon, e-posta, WiFi bağlan) | [x] | `RecordContentActions` — url_launcher; WiFi için doğrudan bağlanma yok, bilgi diyaloğu gösterir |
| A11 | Ham bellek dökümü (hex viewer, sayfa/blok numaralı) | [x] | `HexDumpView`; MIFARE Classic gerçek sektör/blok okuması yapıyor |
| A12 | ECC orijinallik imzası okuma (`READ_SIG`) + NXP anahtarıyla doğrulama | [~] | İmza artık okuma ekranında **gösteriliyor**. Doğrulama motoru tam ve testli; **NXP genel anahtarı hâlâ `null`** → araç katalogda kapalı. Tek eksik: AN11350 sabiti |
| A13 | NFC sayaç değeri okuma (`READ_CNT`) | [x] | `readCounter` + "Sayaç oku" aracı + `TagInfoView` satırı |
| A14 | Yapılandırma sayfaları çözümlemesi (AUTH0, PROT, CFGLCK, MIRROR) | [x] | `TagInfoView` → "Yapılandırma" bölümü: AUTH0, PROT, AUTHLIM, sayaç, MIRROR, güçlü modülasyon + CFGLCK rozeti. Yalnızca derin okumada dolar |
| A15 | Kilit byte'ları çözümlemesi (statik + dinamik) | [x] | `TagInfoView` → "Kilit durumu": kilitli sayfalar aralık olarak (`4-9, 12`), block-lock, CC kilidi, kalıcı salt-okunur rozeti |
| A16 | MIFARE Classic sektör/blok okuma (anahtar sözlüğü ile) | [x] | "MIFARE anahtar taraması" aracı **etkinleştirildi**: sektör sektör hangi anahtarla açıldığı raporlanır, tamamı varsayılan anahtarlıysa uyarır |
| A17 | Sürekli tarama modu (arka arkaya etiket okuma) | [x] | `ContinuousReadController` + liste/sayaç alt sayfası |
| A18 | Okuma sonucunu paylaş / JSON dışa aktar | [x] | `tagInfoToJsonString` + share_plus |

## B. YAZMA (Track T3 · `feature_write` + `ndef_codec`)

### B.0 Yazma motoru

| # | Özellik | Durum | Not |
|---|---|---|---|
| B0.1 | Kayıt listesi ekranı (ekle / sil / sırala / düzenle) | [x] | `ReorderableListView` + `Dismissible` + otomatik taslak kalıcılığı |
| B0.2 | Boyut hesaplayıcı — "X byte / etikette Y byte var" | [x] | `_CapacitySection` + `probeTargetCapacity()` (hedef etiketi okuyup gerçek kapasiteyi alır) |
| B0.3 | Yazma oturumu + sonuç ekranı | [x] | `NfcScanSheet` + sonuç snackbar'ı |
| B0.4 | Çoklu yazma modu (aynı içeriği N etikete) | [ ] | Sayaçlı — yok |
| B0.5 | Yazdıktan sonra otomatik kilitle seçeneği | [x] | Yazma ekranında anahtar + `DangerDialog` onayı; `write()` sonrası `makeReadOnly` çalışır, `WritePhase.locking` fazı eklendi |
| B0.6 | Şablon kaydetme / yükleme | [!] | `TemplateRepository` tam ve bağlı; şu an yalnızca otomatik taslak satırı için kullanılıyor, kullanıcıya şablon listesi UI'ı yok |
| B0.7 | Yazma sonrası geri okuyup doğrulama | [x] | `writeNdef(verify: true)` varsayılan; farklıysa `VerificationFailed` |

### B.1 Kayıt tipleri (her biri ayrı sihirbaz)

Arayüzdeki seçicide (`record_type_sheet.dart`) **15 tip** var.

| # | Kayıt tipi | NDEF karşılığı | Durum | Not |
|---|---|---|---|---|
| B1 | Metin | TNF 1, `T` | [x] | |
| B2 | URL / URI | TNF 1, `U`, ön ek tablosu | [x] | 36 ön ek `uri_prefixes.dart`'ta |
| B3 | Arama (Google/DuckDuckGo/YouTube...) | URI | [~] | Yalnız Google |
| B4 | Sosyal medya (X, Instagram, Facebook, LinkedIn, TikTok...) | URI | [~] | Yalnız Instagram |
| B5 | Video (YouTube / Vimeo) | URI | [~] | Yalnız YouTube |
| B6 | Telefon numarası | `tel:` URI | [x] | |
| B7 | SMS (numara + mesaj) | `sms:` URI | [x] | |
| B8 | E-posta (adres + konu + gövde) | `mailto:` URI | [x] | |
| B9 | Kişi kartı (vCard 3.0) | MIME `text/vcard` | [x] | + iPhone uyumlu çift kayıt (bkz. B9a) |
| B9a | vCard iPhone uyumluluğu | URI + MIME çifti | [x] | `VCardShareLink` + `nfckart.github.io/v/` çözücü sayfası (`docs/v/index.html` eski adres köprüsü — bkz. ADR-0006) |
| B10 | Konum (enlem/boylam) | `geo:` URI | [x] | |
| B11 | Adres (arama sorgusu olarak harita) | URI | [x] | |
| B12 | **WiFi ağı (SSID, şifreleme, parola)** | MIME `application/vnd.wfa.wsc` | [x] | `WifiWscCodec` + `WifiContent` + sihirbaz. 5 auth tipi, parola doğrulama, SSID 32 byte sınırı. Okuma tarafı da `WifiContent` üzerinden zenginleşti. 8 test |
| B13 | Bluetooth eşleştirme (MAC + isim) | MIME `application/vnd.bluetooth.ep.oob` | [ ] | |
| B14 | Bluetooth LE eşleştirme | MIME `application/vnd.bluetooth.le.oob` | [ ] | |
| B15 | Uygulama başlat (paket adı → AAR) | TNF 4, `android.com:pkg` | [ ] | `ExternalContent` kodlayıcısı hazır — sihirbaz eklenirse çalışır |
| B16 | Play Store bağlantısı | URI | [x] | |
| B16a | Google İşletme Yorumu (arama tabanlı, Place ID gerektirmez) | URI | [x] | İşletme adını Google'da aratıp "yorum" ekler; kullanıcı sonuçlardan işletmesini seçip yorum alanını kendisi açar. Sabit/kırılgan bir Place ID linkine bağımlı değil |
| B17 | Özel MIME verisi (tip + içerik) | TNF 2 | [!] | `MimeContent` kodlayıcı/çözücü **hazır**, sihirbaz UI'ı yok |
| B18 | Harici tip (URN) | TNF 4 | [!] | `ExternalContent` **hazır**, sihirbaz UI'ı yok |
| B19 | Ham veri (hex girişi) | TNF 5 / unknown | [!] | `RawContent` **hazır**, sihirbaz UI'ı yok |
| B20 | Kripto ödeme adresi (BTC/ETH/USDT) | URI | [~] | BTC + ETH var, USDT yok |
| B21 | Dosya (küçük dosya gömme) | MIME | [ ] | |
| B22 | Akıllı poster (URI + başlık + eylem) | TNF 1, `Sp` | [ ] | İç içe mesaj kodlaması gerekiyor |
| B23 | Takvim etkinliği (iCal) | MIME `text/calendar` | [ ] | |
| B24 | Acil durum bilgisi (kan grubu, alerji, kontak) | vCard/metin | [ ] | |
| B25 | FaceTime / görüntülü arama | URI | [ ] | |
| B26 | Boş kayıt (TNF 0) | | [!] | `EmptyContent` **hazır**, sihirbaz UI'ı yok |

## C. ARAÇLAR — "Diğer" (Track T4 · `feature_tools` + `tag_ops`)

Kaynak: `tool_catalog.dart` (`implemented` bayrağı) ↔ `tool_detail_page.dart`
(handler `switch`'i) ↔ `tag_operations_impl.dart` (gerçek uygulama).
**Üçü birden doğru olmadan araç çalışmaz.**

| # | Özellik | Durum | Risk | Not |
|---|---|---|---|---|
| C1 | **Etiketi kopyala** — kaynak oku → hedefe yaz | [x] | Orta | İki aşamalı akış, kapasite kontrollü |
| C2 | **Tam klon** — ham sayfa sayfa kopya | [x] | Yüksek | MIFARE Classic magic (Gen2/CUID). NTAG/UL için tam klon yok (UID yazılamaz) |
| C3 | **Temizle / sil** — boş NDEF mesajı yaz | [x] | Orta | |
| C4 | **Fabrika sıfırlama** — kullanıcı sayfalarını 0x00 yap | [x] | Yüksek | |
| C5 | **Biçimlendir (NDEF format)** | [x] | Yüksek | |
| C6 | **Salt-okunur yap** — kalıcı kilit | [x] | ÇOK YÜKSEK | `makeNdefReadOnly()` üzerinden, uzman modu |
| C7 | **Sayfa bazlı kilitleme** — statik/dinamik lock byte | [ ] | ÇOK YÜKSEK | `lockPages` → `NotImplementedYet('T4.28')`, katalogda kapalı |
| C8 | **Şifre koy** — PWD + PACK + AUTH0 | [x] | Yüksek | Yazma sırası korunuyor |
| C9 | **Şifre kaldır** | [x] | Orta | |
| C10 | **Şifre değiştir** | [ ] | Orta | `changePassword` → `NotImplementedYet('T4.23')`; **katalogda araç kaydı bile yok** |
| C11 | **Koruma kapsamı** — PROT biti | [~] | Orta | `PasswordSetup.scope` sözleşmede ve uygulamada var; şifre koyma formunda seçici yok |
| C12 | **Deneme limiti** — AUTHLIM | [~] | Yüksek | `PasswordSetup.authLimit` uygulanıyor; formda alan yok (bilerek — yanlış değer etiketi öldürür) |
| C13 | **Şifre ile kimlik doğrulama** (`PWD_AUTH`) | [!] | Düşük | `authenticate()` tag_ops'ta **hazır**; bağımsız araç yok, yalnız şifre kaldırma içinde dolaylı kullanılıyor |
| C14 | **Bellek dökümü al** — dosyaya kaydet | [x] | Düşük | |
| C15 | **Dökümü geri yükle** | [~] | Yüksek | NTAG/UL çalışıyor; **MIFARE Classic dalı** `NotImplementedYet('T4.17')` |
| C16 | **UID mirror** yapılandırma | [x] | Orta | |
| C17 | **Sayaç (counter)** etkinleştir + mirror | [x] | Orta | |
| C18 | **Ham komut konsolu** | [x] | Yüksek | Uzman modu. Komut **geçmişi ve kayıtlı komutlar yok** |
| C19 | **Komut ön ayarları** — GET_VERSION, READ, FAST_READ... | [ ] | Düşük | Konsolda hazır düğme yok |
| C20 | **MIFARE Classic anahtar sözlüğü** deneme | [x] | Düşük | Etkinleştirildi (uzman modu). Rapor sektör sektör: `S0: A FFFFFFFFFFFF`; açılamayanlar da listelenir |
| C21 | **MIFARE Classic sektör yazma** | [~] | Yüksek | Tek blok yazma + magic klon var; görsel sektör fragmanı (trailer) düzenleyici yok (bilerek) |
| C22 | **ISO15693 blok okuma/yazma + AFI/DSFID** | [~] | Orta | `readIso15693Block` var; `writeIso15693Block` → `NotImplementedYet('T4.34')`. AFI/DSFID yok. **Arayüzde ISO15693 aracı hiç yok** |
| C23 | **ISO15693 blok kilitleme** | [ ] | ÇOK YÜKSEK | |
| C24 | **Etiket sağlığı testi** | [ ] | Yüksek | |
| C25 | **Görev zinciri (otomasyon)** | [ ] | Değişken | v1.1 |
| C26 | **Yapılandırmayı dondur (CFGLCK)** | [ ] | ÇOK YÜKSEK | `lockConfiguration` → `NotImplementedYet('T4.30')`; katalogda kapalı, handler yok |

## D. GEÇMİŞ & YEDEK (Track T2 · `feature_history`)

| # | Özellik | Durum | Not |
|---|---|---|---|
| D1 | Taranan her etiketi geçmişe kaydet | [x] | `autoSaveHistory` ayarına bağlı |
| D2 | Geçmiş listesi: arama, filtre (tip/tarih), silme | [x] | Arama + yonga ailesi filtresi |
| D3 | Geçmiş kaydından detay ekranı | [x] | |
| D4 | Etikete takma ad verme | [x] | |
| D5 | Dump arşivi — kayıtlı bellek dökümleri | [x] | Sekme + yeniden adlandır/dışa aktar/sil |
| D6 | Tümünü JSON dışa aktar / içe aktar | [x] | |
| D7 | Bir geçmiş kaydını "yazma" ekranına yükle | [x] | Rota parametresi ile |

## E. TASARIM & AYARLAR (Track T5)

| # | Özellik | Durum | Not |
|---|---|---|---|
| E1 | Tasarım tokenları (renk, tipografi, boşluk, yarıçap, gölge) | [x] | `tokens.dart` |
| E2 | Açık / koyu / sistem teması + Material 3 dinamik renk | [~] | Tema tam; **dinamik renk yok** — `app.dart` `TODO(T5.15)`, `dynamic_color` paketi eklenmedi. Ayar anahtarı **hiçbir şey yapmıyor** |
| E3 | Ortak widget kitaplığı | [x] | `AppScaffold` ve `LoadingOverlay` yazıldı ama **hiçbir ekranda kullanılmıyor** |
| E4 | TR + EN çeviriler, `NfcFailure` → kullanıcı mesajı eşlemesi | [~] | `AppStrings` (136 anahtar) + `failure_messages.dart` tam. Ama `feature_write` (~64) ve `feature_tools` (~58) **gömülü Türkçe metin** taşıyor; araç kataloğu tamamen TR → EN'de araçlar ve yazma sihirbazları çevrilmiyor |
| E5 | Ayarlar: dil, tema, titreşim, ses, otomatik geçmiş kaydı | [~] | Anahtarlar var; **titreşim ayarı `NfcScanSheet`'e geçirilmiyor**, **ses ayarı hiç tüketilmiyor** |
| E6 | Uzman modu anahtarı | [x] | `ToolCatalog.byCategory(expertMode:)` ile filtreliyor |
| E7 | Onay davranışı ayarı (her zaman sor / uzmanda atla) | [ ] | `AppSettings.simplifyConfirmationsInExpertMode` alanı var, UI yok, **kullanılmıyor** |
| E8 | Hakkında, lisanslar, gizlilik metni | [~] | Sürüm + `showLicensePage` var; **gizlilik metni yok**. Sürüm numarası `'0.1.0'` olarak **elle gömülü** (pubspec 0.1.5+7) |
| E9 | Erişilebilirlik: kontrast, dokunma hedefi ≥48dp, ekran okuyucu | [ ] | Denetim yapılmadı |
| E10 | Veri yönetimi: geçmişi temizle, arşivi temizle, tümünü dışa aktar | [~] | Dışa/içe aktarma geçmiş sekmesinde; ayarlarda toplu temizleme yok |
| E11 | Tekrar okuma engeli süresi ayarı | [ ] | `AppSettings.duplicateScanCooldown` (3 sn) alanı var ama **hiç kullanılmıyor**; `ContinuousReadController` sabit "art arda aynı UID" mantığı kullanıyor |
| E12 | Yıkıcı işlem öncesi otomatik yedek | [x] | **Uygulandı.** Her yıkıcı araç + kopyalama + klonlama önce tam dump alıp arşive yazar (`DumpReason.automaticBackup`). Yedek alınamazsa işlem varsayılan olarak iptal; kullanıcı açıkça "yedeksiz devam et" diyebilir. `DangerAck.backupTaken` artık gerçeği söylüyor |
| E13 | Widget kataloğu ekranı (hata ayıklama) | [ ] | |
| E14 | `AppIcons` — kayıt tipi / araç / teknoloji ikon eşlemesi | [ ] | İkonlar dosyalara dağılmış durumda |

## F. ÇEKİRDEK ALTYAPI (Track T1)

| # | Özellik | Durum | Not |
|---|---|---|---|
| F1 | `nfc_core`: varlıklar, arayüzler, `Result`, `NfcFailure` | [x] | S1 kilidi geçildi |
| F2 | `shared_utils`: hex/byte, CRC, bit alanı, logger | [x] | |
| F3 | `nfc_transport`: oturum, tag soyutlaması, transceive | [x] | |
| F4 | NFC uygunluk kontrolü + ayarlara yönlendirme | [x] | `NfcUnavailable(disabled)` → snackbar eylemi → `openNfcSettings()` (MainActivity) |
| F5 | Oturum yaşam döngüsü: tek seferlik / sürekli, iptal, zaman aşımı | [x] | `runOnce(timeout:)`, `stopSession()`, sürekli mod |
| F6 | `storage`: sqflite şeması, geçmiş/dump/şablon repository'leri | [x] | 4 tablo + migration + testler |
| F7 | Ayar deposu (`shared_preferences`) | [x] | |
| F8 | Android manifest, izinler, NFC intent filtreleri | [x] | NDEF/TECH/TAG_DISCOVERED + `nfc_tech_filter.xml` + url_launcher `<queries>` |
| F9 | Uygulama dışından NFC intent ile açılma | [x] | `MainActivity.onNewIntent` → `onNfcIntent` → okuma ekranı taraması |
| F10 | Foreground dispatch (etiket başka uygulamaya gitmesin) | [x] | `setReadPageVisible` köprüsü |
| F11 | OTA güncelleme (manifest + APK indirme) | [x] | `update_service.dart` + `releases/version.json` |
| F12 | ProGuard/R8 kuralları | [ ] | Kural dosyası yok, `minifyEnabled` ayarı yok — release derlemesinde pigeon sınıfları riskli |
| F13 | CI betiği (`analyze` + `test`) | [~] | `.claude/scripts/verify.ps1` var; otomatik çalışan bir CI yok |

---

## Test kapsamı (gerçek durum)

Var: `hex_test`, `ndef_codec_test`, `tag_operations_test` (62), `storage_repositories_test`,
`common_widgets_test`, `write_draft_test` (8), `tag_info_json_test`, `wifi_credentials_test`.

Yok: `ReadController` (T2.32), `HistoryController` (T2.33), `WriteController` (T3.46),
widget/akış testleri (T2.34), `nfc_transport` testleri, şifre yazma sırası testi (T4.43),
kilit byte hesaplama testleri (T4.44).

## En hızlı kazançlar (kod hazır, yalnızca bağlantı gerekiyor)

2026-08-06 denetiminde belirlenen ilk beş madde **kapatıldı** (C20, A14, A15,
B0.5, B12 + E12 güvenlik açığı). Kalan `[!]` işaretliler:

1. **B17/B18/B19/B26 kayıt tipleri** — codec hazır ve testli, yalnız sihirbaz
   formu gerekiyor. `_WifiInputPage` bunun için taze bir örnek.
2. **B0.6 şablon kaydet/yükle** — `TemplateRepository` tam ve bağlı;
   liste UI'ı yazılırken taslak satırı `WriteDraftStore.isDraft` ile gizlenmeli.
3. **C13 `PWD_AUTH` denemesi** — `authenticate()` hazır, katalogda araç yok.
4. **A12 orijinallik doğrulama** — yalnız NXP genel anahtar sabiti eksik;
   imza zaten okunuyor ve ekranda gösteriliyor.
5. **T5.9 `AppScaffold` / `LoadingOverlay`** — ya benimsensin ya kaldırılsın.
