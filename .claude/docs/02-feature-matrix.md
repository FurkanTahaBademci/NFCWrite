# 02 — Özellik Matrisi

Durum kodları: `[ ]` yapılmadı · `[~]` devam ediyor · `[x]` bitti · `[-]` kapsam dışı

---

## A. OKUMA (Track T2 · `feature_read`)

| # | Özellik | Durum | Not |
|---|---|---|---|
| A1 | Etiket tarama oturumu (bekle / bulundu / hata durumları) | [ ] | Ön yüz animasyonlu tarama sayfası |
| A2 | UID / seri numarası (hex + ters sıra + ondalık gösterim) | [x] | `formatUidDecimal` (shared_utils) + `TagInfoView`'da satır |
| A3 | Etiket teknolojileri listesi (NfcA, Ndef, MifareUltralight...) | [ ] | Android techList |
| A4 | Yonga (IC) tanımlama: NTAG213/215/216, Ultralight EV1, Classic 1K/4K, ICODE SLIX | [x] | ICODE SLIX/SLIX2 artık `GET_SYSTEM_INFO` IC referansıyla ayrılıyor — ⚠️ eşleme doğrulanmadı, bkz. progress.md |
| A5 | Üretici tanımlama (UID byte 0 → IC üreticisi) | [ ] | ISO/IEC 7816-6 tablosu |
| A6 | Bellek bilgisi: toplam / kullanılan / boş byte, sayfa sayısı | [ ] | |
| A7 | Yazılabilir mi / salt-okunur mu / biçimlendirilmiş mi | [ ] | |
| A8 | NDEF mesaj çözümleme — kayıt kayıt liste | [ ] | Tip ikonları ile |
| A9 | Her kayıt için: TNF, tip, id, payload (metin + hex) | [ ] | Genişletilebilir kart |
| A10 | Kayıt içeriğine göre eylem (URL aç, ara, telefon, e-posta, WiFi bağlan) | [x] | `RecordContentActions` — url_launcher; WiFi için doğrudan bağlanma yok, bilgi diyaloğu gösterir |
| A11 | Ham bellek dökümü (hex viewer, sayfa/blok numaralı) | [x] | MIFARE Classic artık `tag_ops`'ta gerçek sektör/blok okuma yapıyor (önceden `NotImplementedYet`) |
| A12 | ECC orijinallik imzası okuma (`READ_SIG`) + NXP anahtarıyla doğrulama | [~] | secp128r1/ECDSA motoru tam ve test edilmiş; NXP genel anahtarı ⚠️ doğrulanmadığı için bilerek `null` — `TagNotSupported` döner |
| A13 | NFC sayaç değeri okuma (`READ_CNT`) | [ ] | NTAG21x |
| A14 | Yapılandırma sayfaları çözümlemesi (AUTH0, PROT, CFGLCK, MIRROR) | [ ] | İnsan-okunur |
| A15 | Kilit byte'ları çözümlemesi (statik + dinamik) | [ ] | Hangi sayfa kilitli |
| A16 | MIFARE Classic sektör/blok okuma (anahtar sözlüğü ile) | [x] | `scanMifareClassicKeys` varsayılan sözlükle tüm sektörleri dener |
| A17 | Sürekli tarama modu (arka arkaya etiket okuma) | [x] | `ContinuousReadController` + liste/sayaç alt sayfası |
| A18 | Okuma sonucunu paylaş / JSON dışa aktar | [x] | `tagInfoToJsonString` + share_plus |

## B. YAZMA (Track T3 · `feature_write` + `ndef_codec`)

### B.0 Yazma motoru

| # | Özellik | Durum | Not |
|---|---|---|---|
| B0.1 | Kayıt listesi ekranı (ekle / sil / sırala / düzenle) | [ ] | Sürükle-bırak sıralama |
| B0.2 | Boyut hesaplayıcı — "X byte / etikette Y byte var" | [ ] | Yazmadan önce uyar |
| B0.3 | Yazma oturumu + sonuç ekranı | [ ] | |
| B0.4 | Çoklu yazma modu (aynı içeriği N etikete) | [ ] | Sayaçlı |
| B0.5 | Yazdıktan sonra otomatik kilitle seçeneği | [ ] | Onay şart |
| B0.6 | Şablon kaydetme / yükleme | [ ] | `storage` üzerinden |

### B.1 Kayıt tipleri (her biri ayrı sihirbaz)

| # | Kayıt tipi | NDEF karşılığı | Durum |
|---|---|---|---|
| B1 | Metin | TNF 1, `T`, dil kodlu | [ ] |
| B2 | URL / URI | TNF 1, `U`, ön ek tablosu | [ ] |
| B3 | Arama (Google/DuckDuckGo/YouTube...) | URI | [ ] |
| B4 | Sosyal medya (X, Instagram, Facebook, LinkedIn, TikTok, Snapchat, Telegram, WhatsApp, YouTube, GitHub) | URI | [ ] |
| B5 | Video (YouTube / Vimeo) | URI | [ ] |
| B6 | Telefon numarası | `tel:` URI | [ ] |
| B7 | SMS (numara + mesaj) | `sms:` URI | [ ] |
| B8 | E-posta (adres + konu + gövde) | `mailto:` URI | [ ] |
| B9 | Kişi kartı (vCard 3.0) | MIME `text/vcard` | [ ] |
| B10 | Konum (enlem/boylam) | `geo:` URI | [ ] |
| B11 | Adres (arama sorgusu olarak harita) | URI | [ ] |
| B12 | WiFi ağı (SSID, şifreleme, parola, gizli) | MIME `application/vnd.wfa.wsc` | [ ] |
| B13 | Bluetooth eşleştirme (MAC + isim) | MIME `application/vnd.bluetooth.ep.oob` | [ ] |
| B14 | Bluetooth LE eşleştirme | MIME `application/vnd.bluetooth.le.oob` | [ ] |
| B15 | Uygulama başlat (paket adı → AAR) | TNF 4, `android.com:pkg` | [ ] |
| B16 | Play Store bağlantısı | URI | [ ] |
| B17 | Özel MIME verisi (tip + içerik) | TNF 2 | [ ] |
| B18 | Harici tip (URN) | TNF 4 | [ ] |
| B19 | Ham veri (hex girişi) | TNF 5 / unknown | [ ] |
| B20 | Kripto ödeme adresi (BTC/ETH/USDT) | URI | [ ] |
| B21 | Dosya (küçük dosya gömme) | MIME | [ ] |
| B22 | Akıllı poster (URI + başlık + eylem) | TNF 1, `Sp` | [ ] |
| B23 | Takvim etkinliği (iCal) | MIME `text/calendar` | [ ] |
| B24 | Acil durum bilgisi (kan grubu, alerji, kontak) | vCard/metin | [ ] |
| B25 | FaceTime / görüntülü arama | URI | [ ] |
| B26 | Boş kayıt (TNF 0) | | [ ] |

## C. ARAÇLAR — "Diğer" (Track T4 · `feature_tools` + `tag_ops`)

| # | Özellik | Durum | Risk | Not |
|---|---|---|---|---|
| C1 | **Etiketi kopyala** — kaynak oku → hedefe yaz | [ ] | Orta | NDEF seviyesi |
| C2 | **Tam klon** — ham sayfa sayfa kopya (kopyalanabilir UID'li kartlar) | [ ] | Yüksek | Yalnız uyumlu etiketlerde |
| C3 | **Temizle / sil** — boş NDEF mesajı yaz | [ ] | Orta | |
| C4 | **Fabrika sıfırlama** — tüm kullanıcı sayfalarını 0x00 yap | [ ] | Yüksek | |
| C5 | **Biçimlendir (NDEF format)** — CC yaz + boş mesaj | [ ] | Yüksek | `NdefFormatable` veya elle CC |
| C6 | **Salt-okunur yap** — kalıcı kilit | [ ] | ÇOK YÜKSEK | Geri alınamaz, çift onay |
| C7 | **Sayfa bazlı kilitleme** — statik/dinamik lock byte seçimi | [ ] | ÇOK YÜKSEK | Uzman modu |
| C8 | **Şifre koy** — PWD + PACK yaz, AUTH0 ayarla | [ ] | Yüksek | NTAG21x / UL EV1 |
| C9 | **Şifre kaldır** — kimlik doğrula, AUTH0=0xFF | [ ] | Orta | Şifre bilinmeli |
| C10 | **Şifre değiştir** | [ ] | Orta | |
| C11 | **Koruma kapsamı** — PROT biti (yazma mı, okuma+yazma mı) | [ ] | Orta | |
| C12 | **Deneme limiti** — AUTHLIM ayarı | [ ] | Yüksek | Yanlış ayar = kalıcı kilitlenme |
| C13 | **Şifre ile kimlik doğrulama** (`PWD_AUTH`) | [ ] | Düşük | Diğer işlemler için ön koşul |
| C14 | **Bellek dökümü al** — dosyaya kaydet (.bin + .json) | [ ] | Düşük | |
| C15 | **Dökümü geri yükle** — dosyadan etikete yaz | [ ] | Yüksek | |
| C16 | **UID mirror** yapılandırma | [ ] | Orta | MIRROR_PAGE + MIRROR_BYTE |
| C17 | **Sayaç (counter)** etkinleştir + mirror | [ ] | Orta | NFC_CNT_EN |
| C18 | **Ham komut konsolu** — hex komut gönder, cevabı gör | [ ] | Yüksek | Uzman modu, geçmişli |
| C19 | **Komut ön ayarları** — GET_VERSION, READ, FAST_READ, READ_SIG... | [ ] | Düşük | Konsolda hazır düğmeler |
| C20 | **MIFARE Classic anahtar sözlüğü** deneme | [ ] | Düşük | Varsayılan anahtar listesi |
| C21 | **MIFARE Classic sektör yazma** | [ ] | Yüksek | |
| C22 | **ISO15693 blok okuma/yazma + AFI/DSFID** | [ ] | Orta | ICODE SLIX |
| C23 | **ISO15693 blok kilitleme** | [ ] | ÇOK YÜKSEK | |
| C24 | **Etiket sağlığı testi** — tüm sayfaları yaz/oku doğrula | [ ] | Yüksek | Verileri bozar, uyar |
| C25 | **Görev zinciri (otomasyon)** — sıralı işlem tanımla ve çalıştır | [ ] | Değişken | v1.1 |

## D. GEÇMİŞ & YEDEK (Track T2 · `feature_history`)

| # | Özellik | Durum |
|---|---|---|
| D1 | Taranan her etiketi geçmişe kaydet (UID, tip, zaman, NDEF özeti) | [x] |
| D2 | Geçmiş listesi: arama, filtre (tip/tarih), silme | [x] |
| D3 | Geçmiş kaydından detay ekranı | [x] |
| D4 | Etikete takma ad verme (UID → "Ofis kapısı") | [x] |
| D5 | Dump arşivi — kayıtlı bellek dökümleri | [x] |
| D6 | Tümünü JSON dışa aktar / içe aktar | [x] |
| D7 | Bir geçmiş kaydını "yazma" ekranına yükle | [x] |

## E. TASARIM & AYARLAR (Track T5 · `design_system`, `localization`, `feature_settings`)

| # | Özellik | Durum |
|---|---|---|
| E1 | Tasarım tokenları (renk, tipografi, boşluk, yarıçap, gölge) | [ ] |
| E2 | Açık / koyu / sistem teması + Material 3 dinamik renk | [ ] |
| E3 | Ortak widget kitaplığı (NfcScanSheet, TagBadge, HexViewer, InfoRow, DangerDialog...) | [ ] |
| E4 | TR + EN çeviriler, `NfcFailure` → kullanıcı mesajı eşlemesi | [ ] |
| E5 | Ayarlar: dil, tema, titreşim, ses, otomatik geçmiş kaydı | [ ] |
| E6 | Uzman modu anahtarı (tehlikeli araçları görünür yapar) | [ ] |
| E7 | Onay davranışı ayarı (her zaman sor / uzmanda atla) | [ ] |
| E8 | Hakkında, lisanslar, gizlilik metni | [ ] |
| E9 | Erişilebilirlik: kontrast, dokunma hedefi ≥48dp, ekran okuyucu etiketleri | [ ] |

## F. ÇEKİRDEK ALTYAPI (Track T1)

| # | Özellik | Durum |
|---|---|---|
| F1 | `nfc_core`: varlıklar, arayüzler, `Result`, `NfcFailure` | [ ] |
| F2 | `shared_utils`: hex/byte dönüşümleri, CRC, bit alanı yardımcıları, logger | [ ] |
| F3 | `nfc_transport`: oturum yönetimi, tag soyutlaması, transceive köprüsü | [ ] |
| F4 | NFC uygunluk kontrolü (destekli mi / açık mı) + ayarlara yönlendirme | [ ] |
| F5 | Oturum yaşam döngüsü: tek seferlik / sürekli, iptal, zaman aşımı | [ ] |
| F6 | `storage`: sqflite şeması, geçmiş/dump/şablon repository'leri | [ ] |
| F7 | Ayar deposu (`shared_preferences`) | [ ] |
| F8 | Android manifest, izinler, NFC intent filtreleri | [ ] |
| F9 | Uygulama dışından NFC intent ile açılma (etiket dokununca uygulama açılsın) | [ ] |
