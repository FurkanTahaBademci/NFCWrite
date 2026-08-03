# 03 — NFC Protokol Referansı

> **Uyarı:** Bu belge geliştirme sırasında hızlı başvuru içindir. Kalıcı
> kilitleme, şifre ve yapılandırma byte'ları **geri alınamaz** işlemler
> ürettiği için, `tag_ops` içinde uygulamadan önce ilgili **NXP datasheet**
> ile karşılaştırılmalıdır. ⚠️ işaretli satırlar özellikle doğrulanmalıdır.
> Doğrulama yapıldığında ⚠️ kaldırılıp yanına datasheet sürümü yazılır.

---

## 1. NDEF temel yapıları

### 1.1 Kayıt (record) başlığı

```
byte 0:  MB ME CF SR IL   TNF TNF TNF
         │  │  │  │  │    └──────────┴─ Type Name Format (3 bit)
         │  │  │  │  └────────────────── ID Length var mı (0x08)
         │  │  │  └───────────────────── Short Record: uzunluk 1 byte (0x10)
         │  │  └──────────────────────── Chunk Flag (0x20)
         │  └─────────────────────────── Message End (0x40)
         └────────────────────────────── Message Begin (0x80)
byte 1:      TYPE LENGTH (1 byte)
byte 2..:    PAYLOAD LENGTH (SR ise 1 byte, değilse 4 byte big-endian)
             [ID LENGTH (1 byte, IL ise)]
             TYPE (n byte)
             [ID (n byte)]
             PAYLOAD (n byte)
```

**TNF değerleri**

| TNF | Anlam | Kullanım |
|---|---|---|
| 0x00 | Empty | Boş kayıt |
| 0x01 | Well-known | `T` (metin), `U` (URI), `Sp` (akıllı poster) |
| 0x02 | MIME | `text/vcard`, `application/vnd.wfa.wsc` |
| 0x03 | Absolute URI | Tam URI, tip alanında |
| 0x04 | External | `android.com:pkg` (AAR), özel URN'ler |
| 0x05 | Unknown | Tip yok |
| 0x06 | Unchanged | Chunk devamı |
| 0x07 | Reserved | Kullanılmaz |

### 1.2 Metin kaydı (`T`) payload

```
byte 0:  bit7 = kodlama (0 = UTF-8, 1 = UTF-16)
         bit6 = RFU (0)
         bit5-0 = dil kodu uzunluğu (n)
byte 1..n:   dil kodu, ASCII ("tr", "en", "en-US")
byte n+1..:  metin
```

### 1.3 URI kaydı (`U`) payload

```
byte 0:  ön ek (prefix) kodu
byte 1..: URI'nin geri kalanı, UTF-8
```

**Ön ek tablosu (tamamı)**

| Kod | Ön ek | Kod | Ön ek |
|---|---|---|---|
| 0x00 | *(yok)* | 0x12 | `rtsp://` |
| 0x01 | `http://www.` | 0x13 | `urn:` |
| 0x02 | `https://www.` | 0x14 | `pop:` |
| 0x03 | `http://` | 0x15 | `sip:` |
| 0x04 | `https://` | 0x16 | `sips:` |
| 0x05 | `tel:` | 0x17 | `tftp:` |
| 0x06 | `mailto:` | 0x18 | `btspp://` |
| 0x07 | `ftp://anonymous:anonymous@` | 0x19 | `btl2cap://` |
| 0x08 | `ftp://ftp.` | 0x1A | `btgoep://` |
| 0x09 | `ftps://` | 0x1B | `tcpobex://` |
| 0x0A | `sftp://` | 0x1C | `irdaobex://` |
| 0x0B | `smb://` | 0x1D | `file://` |
| 0x0C | `nfs://` | 0x1E | `urn:epc:id:` |
| 0x0D | `ftp://` | 0x1F | `urn:epc:tag:` |
| 0x0E | `dav://` | 0x20 | `urn:epc:pat:` |
| 0x0F | `news:` | 0x21 | `urn:epc:raw:` |
| 0x10 | `telnet://` | 0x22 | `urn:epc:` |
| 0x11 | `imap:` | 0x23 | `urn:nfc:` |

### 1.4 WiFi kaydı — WSC (Wi-Fi Simple Config)

MIME tipi: `application/vnd.wfa.wsc`
Yapı: big-endian TLV (2 byte tip, 2 byte uzunluk, değer)

| Tip | Alan | Not |
|---|---|---|
| 0x100E | Credential | Diğer TLV'leri kapsayan dış zarf |
| 0x1026 | Network Index | Genelde `0x01` |
| 0x1045 | SSID | UTF-8 |
| 0x1003 | Authentication Type | 2 byte |
| 0x100F | Encryption Type | 2 byte |
| 0x1027 | Network Key | Parola |
| 0x1020 | MAC Address | 6 byte, genelde `FF:FF:FF:FF:FF:FF` |

Auth Type: `0x0001` Open · `0x0002` WPA-PSK · `0x0004` Shared ·
`0x0008` WPA-EAP · `0x0010` WPA2-EAP · `0x0020` WPA2-PSK
Encryption: `0x0001` None · `0x0002` WEP · `0x0004` TKIP · `0x0008` AES

### 1.5 TLV yapısı (Type 2 Tag bellek düzeni)

| Tip | Anlam |
|---|---|
| 0x00 | NULL (dolgu, atla) |
| 0x01 | Lock Control TLV |
| 0x02 | Memory Control TLV |
| 0x03 | **NDEF Message TLV** |
| 0xFD | Proprietary |
| 0xFE | Terminator (mesaj sonu) |

Uzunluk alanı: `< 0xFF` ise 1 byte; değilse `0xFF` + 2 byte big-endian.

---

## 2. NTAG21x (Type 2 Tag)

### 2.1 Bellek haritası

| Model | Toplam sayfa | Kullanıcı sayfaları | Kullanıcı byte | CFG0 | CFG1 | PWD | PACK | Dinamik kilit |
|---|---|---|---|---|---|---|---|---|
| NTAG213 | 45 (0x00–0x2C) | 0x04–0x27 | 144 | 0x29 | 0x2A | 0x2B | 0x2C | 0x28 |
| NTAG215 | 135 (0x00–0x86) | 0x04–0x81 | 504 | 0x83 | 0x84 | 0x85 | 0x86 | 0x82 |
| NTAG216 | 231 (0x00–0xE6) | 0x04–0xE1 | 888 | 0xE3 | 0xE4 | 0xE5 | 0xE6 | 0xE2 |

Her sayfa 4 byte'tır.

### 2.2 Sabit sayfalar

```
Sayfa 0:  UID0  UID1  UID2  BCC0     BCC0 = 0x88 ^ UID0 ^ UID1 ^ UID2
Sayfa 1:  UID3  UID4  UID5  UID6
Sayfa 2:  BCC1  INT   LOCK0 LOCK1    BCC1 = UID3^UID4^UID5^UID6
Sayfa 3:  CC0   CC1   CC2   CC3      Capability Container
```

**Capability Container (sayfa 3)**

| Model | CC değeri | Anlamı |
|---|---|---|
| NTAG213 | `E1 10 12 00` | Sihirli sayı E1, sürüm 1.0, 0x12×8 = 144 byte, tam erişim |
| NTAG215 | `E1 10 3E 00` | 0x3E×8 = 496 byte |
| NTAG216 | `E1 10 6D 00` | 0x6D×8 = 872 byte |

CC3 erişim byte'ı: üst nibble = okuma erişimi (0 = serbest),
alt nibble = yazma erişimi (0 = serbest, F = salt-okunur).

**CC bir kez yazılır (OTP benzeri) — bitler yalnızca 0→1 yapılabilir.**

### 2.3 Statik kilit byte'ları (sayfa 2, byte 2–3)

```
LOCK0 (byte 2):  bit7..bit4 → sayfa 7, 6, 5, 4 kilidi
                 bit3       → sayfa 3 (CC) kilidi
                 bit2       → BL: sayfa 10–15 blok kilidi
                 bit1       → BL: sayfa 4–9 blok kilidi
                 bit0       → BL: sayfa 3 (CC) blok kilidi
LOCK1 (byte 3):  bit7..bit0 → sayfa 15, 14, 13, 12, 11, 10, 9, 8 kilidi
```

Bir bit 1 yapıldıktan sonra **asla** 0'a dönmez. Blok-kilit (BL) bitleri
ilgili kilit bitlerinin değiştirilmesini de kalıcı olarak engeller.

### 2.4 Dinamik kilit byte'ları

⚠️ Aşağıdaki eşleme datasheet ile doğrulanmalıdır.

| Model | Sayfa | Byte 0 kapsamı | Not |
|---|---|---|---|
| NTAG213 | 0x28 | bit0→sayfa 16–19, bit1→20–23, … bit5→36–39 | 3 byte kullanılır, 4. byte RFUI |
| NTAG215 | 0x82 | her bit 16 sayfalık blok (16–31, 32–47, …) | ⚠️ |
| NTAG216 | 0xE2 | her bit 16 sayfalık blok | ⚠️ |

Dinamik kilit sayfasının son byte'ı yazılırken `0x00` verilmelidir (BD byte).

### 2.5 Yapılandırma sayfaları

**CFG0**

```
byte 0:  MIRROR
         bit7-6  MIRROR_CONF  00=kapalı 01=UID ASCII 10=NFC sayaç 11=ikisi
         bit5-4  MIRROR_BYTE  mirror'ın sayfa içindeki başlangıç byte'ı
         bit3    RFUI
         bit2    STRG_MOD_EN  güçlü modülasyon
         bit1-0  RFUI
byte 1:  RFUI (0x00)
byte 2:  MIRROR_PAGE  mirror'ın yazılacağı sayfa (0x00 = kapalı)
byte 3:  AUTH0        şifre korumasının BAŞLADIĞI sayfa
                      0xFF = koruma kapalı (varsayılan)
```

**CFG1**

```
byte 0:  ACCESS
         bit7    PROT              0 = sadece YAZMA korumalı
                                   1 = OKUMA + YAZMA korumalı
         bit6    CFGLCK            1 = yapılandırma kalıcı kilitli ⚠️ GERİ ALINAMAZ
         bit5    RFUI
         bit4    NFC_CNT_EN        NFC sayacı etkin
         bit3    NFC_CNT_PWD_PROT  sayaç okuma şifreli
         bit2-0  AUTHLIM           yanlış deneme limiti
                                   000 = sınırsız (güvenli varsayılan)
                                   n>0 = n denemeden sonra ETİKET KİLİTLENİR ⚠️
byte 1-3: RFUI (0x00)
```

**PWD sayfası:** 4 byte parola (varsayılan `FF FF FF FF`)
**PACK sayfası:** byte 0–1 = PACK cevabı (varsayılan `00 00`), byte 2–3 RFUI

### 2.6 Komut seti

| Komut | Byte dizisi | Cevap | Açıklama |
|---|---|---|---|
| GET_VERSION | `60` | 8 byte | Yonga tanımlama |
| READ | `30 <adr>` | 16 byte (4 sayfa) | Sayfa sonundan başa döner |
| FAST_READ | `3A <baş> <son>` | (son−baş+1)×4 byte | Toplu okuma |
| WRITE | `A2 <adr> <d0..d3>` | ACK | Tek sayfa yaz |
| COMPAT_WRITE | `A0 <adr> <16 byte>` | ACK | Eski uyumluluk |
| PWD_AUTH | `1B <p0..p3>` | 2 byte PACK | Kimlik doğrulama |
| READ_CNT | `39 02` | 3 byte | NFC sayaç değeri |
| READ_SIG | `3C 00` | 32 byte | ECC orijinallik imzası |
| HALT | `50 00` | — | Etiketi uyut |

**ACK/NAK:** ACK = `0x0A` (4 bit). NAK = `0x00`, `0x01`, `0x04`, `0x05`.
Android'de NAK genelde `IOException`/`TagLostException` olarak gelir.

### 2.7 GET_VERSION cevabı (8 byte)

```
byte 0: sabit başlık        0x00
byte 1: üretici (NXP)       0x04
byte 2: ürün tipi           0x03 = MIFARE Ultralight, 0x04 = NTAG
byte 3: ürün alt tipi       0x01 = 17pF, 0x02 = 50pF
byte 4: ana sürüm           0x01
byte 5: alt sürüm           0x00
byte 6: DEPOLAMA BOYUTU     ← model burada belli olur
byte 7: protokol tipi       0x03 = ISO/IEC 14443-3
```

| byte 6 | Model |
|---|---|
| 0x0B | MIFARE Ultralight EV1 (MF0UL11) — 48 byte |
| 0x0E | MIFARE Ultralight EV1 (MF0UL21) — 128 byte |
| 0x0F | **NTAG213** |
| 0x11 | **NTAG215** |
| 0x13 | **NTAG216** |

`GET_VERSION` desteklenmiyorsa (eski MIFARE Ultralight, `NAK` döner):
ATQA `0x0044` + SAK `0x00` → klasik MIFARE Ultralight, 64 byte.

### 2.8 Şifre koyma sırası (KRİTİK — sıra yanlışsa etiket kilitlenir)

```
1. PWD sayfasına 4 byte parolayı yaz
2. PACK sayfasına 2 byte PACK + 2 byte 0x00 yaz
3. CFG1 → ACCESS byte'ını ayarla (PROT, AUTHLIM). CFGLCK = 0 BIRAK.
4. CFG0 → AUTH0'ı korumanın başlayacağı sayfaya ayarla   ← EN SON
```

**AUTH0 en sona yazılır.** Önce yazılırsa PWD/PACK sayfaları hemen korumaya
girer ve parolayı yazamadan etiketi kilitlersin.

Şifre kaldırma sırası bunun tersidir:

```
1. PWD_AUTH ile doğrula
2. CFG0 → AUTH0 = 0xFF (koruma kapalı)     ← EN ÖNCE
3. PWD = FF FF FF FF, PACK = 00 00 (opsiyonel temizlik)
```

**`CFGLCK = 1` yaparsan yapılandırma sonsuza dek dondurulur.** Uygulamada bu
bit yalnızca uzman modunda, ayrı ve daha sert bir onayla yazılabilir.

---

## 3. MIFARE Classic

| Model | Sektör | Blok | Boyut |
|---|---|---|---|
| Classic 1K | 16 | 16 × 4 | 1024 byte |
| Classic 4K | 40 | 32 × 4 + 8 × 16 | 4096 byte |

- Blok = 16 byte. Her sektörün **son bloğu** sektör fragmanıdır (trailer).
- Blok 0 = üretici bloğu (UID + üretici verisi), yazılamaz.

**Sektör fragmanı düzeni**

```
byte 0-5   : Anahtar A (okunamaz, her zaman 000000000000 döner)
byte 6-9   : Erişim bitleri (+ kullanıcı byte'ı byte 9)
byte 10-15 : Anahtar B
```

**Yaygın varsayılan anahtarlar (sözlük başlangıcı)**

```
FFFFFFFFFFFF   A0A1A2A3A4A5   D3F7D3F7D3F7   000000000000
B0B1B2B3B4B5   4D3A99C351DD   1A982C7E459A   AABBCCDDEEFF
714C5C886E97   587EE5F9350F   A0478CC39091   533CB6C723F6
8FD0A4F256E9
```

- MAD (Mifare Application Directory) sektör 0, Anahtar A = `A0A1A2A3A4A5`
- NDEF sektörleri Anahtar A = `D3F7D3F7D3F7`, NDEF AID = `0x03E1`

---

## 4. ISO 15693 (NfcV / ICODE SLIX)

Android `NfcV.transceive()` şu biçimi bekler:

```
[FLAGS] [KOMUT] [ (UID 8 byte, ters sıra) if addressed ] [parametreler]
```

**Bayraklar (flags)**

| Bit | Değer | Anlam |
|---|---|---|
| 1 | 0x02 | Yüksek veri hızı (genelde açık) |
| 3 | 0x08 | Inventory |
| 5 | 0x20 | Addressed — UID belirtilir |
| 6 | 0x40 | Option |

Tipik: adressiz `0x02`, adresli `0x22`.

**Komutlar**

| Kod | Komut |
|---|---|
| 0x20 | Read Single Block |
| 0x21 | Write Single Block |
| 0x22 | Lock Block ⚠️ geri alınamaz |
| 0x23 | Read Multiple Blocks |
| 0x24 | Write Multiple Blocks |
| 0x25 | Select |
| 0x26 | Reset to Ready |
| 0x27 | Write AFI |
| 0x28 | Lock AFI ⚠️ |
| 0x29 | Write DSFID |
| 0x2A | Lock DSFID ⚠️ |
| 0x2B | Get System Information |
| 0x2C | Get Multiple Block Security Status |

Cevabın ilk byte'ı yanıt bayrağıdır; `bit0 = 1` ise hata, sonraki byte hata kodudur.

---

## 5. Android teknoloji adları (`techList`)

```
android.nfc.tech.NfcA              ISO 14443-3A
android.nfc.tech.NfcB              ISO 14443-3B
android.nfc.tech.NfcF              JIS 6319-4 (FeliCa)
android.nfc.tech.NfcV              ISO 15693
android.nfc.tech.IsoDep            ISO 14443-4
android.nfc.tech.Ndef              NDEF okunabilir
android.nfc.tech.NdefFormatable    NDEF'e biçimlendirilebilir
android.nfc.tech.MifareClassic
android.nfc.tech.MifareUltralight
android.nfc.tech.NfcBarcode        Kovio
```

## 6. UID üretici byte'ı (byte 0)

| Değer | Üretici |
|---|---|
| 0x04 | NXP Semiconductors |
| 0x02 | STMicroelectronics |
| 0x05 | Infineon |
| 0x07 | Texas Instruments |
| 0x16 | EM Microelectronic |
| 0x28 | IBM |
| 0x2B | Shanghai Fudan |

---

## 7. Uygulama kuralları (tag_ops yazarken uy)

1. **Her yazma işleminden önce oku.** İşlem öncesi tam dump al ve geçmişe yaz.
2. **Yazdıktan sonra doğrula.** Yazılan sayfayı geri oku, eşleşmiyorsa hata döndür.
3. **Sayfa sınırı kontrolü.** Kullanıcı sayfaları dışına yazma girişimini
   `tag_ops` reddetmeli — UI'ya güvenme.
4. **`CFGLCK`, statik kilit ve `AUTHLIM` için ayrı onay.** Bu üçü etiketi
   kalıcı olarak kullanılamaz hale getirebilir.
5. **`transceive` zaman aşımı**: NTAG için 100–500 ms yeterli. Uzun işlemlerde
   (tam dump) `FAST_READ` kullan, tek tek `READ` yapma.
6. **`FAST_READ` sınırı**: cevap, `getMaxTransceiveLength()` değerini aşamaz.
   Dump alırken bu sınıra göre parçala.
