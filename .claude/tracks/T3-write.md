# T3 — Yazma & NDEF Kayıt Tipleri

**Sahip olduğun yollar:**
```
packages/features/feature_write/**
packages/services/ndef_codec/**
```

**Kullanabileceğin paketler:** `nfc_core`, `design_system`, `localization`,
`shared_utils`
**YASAK:** `nfc_transport`, `tag_ops`, `storage`, diğer `feature_*`

**Okuman gerekenler:** `docs/03-nfc-reference.md` (§1 tamamı — NDEF yapıları),
`docs/02-feature-matrix.md` (B bölümü), `docs/04-ui-ux-spec.md`

> **Kritik:** `ndef_codec` saf Dart'tır ve **tüm** uygulamanın NDEF
> doğruluk kaynağıdır. T2 okuma tarafında senin çözücülerini kullanacak.
> Her kodlayıcı için mutlaka çift yönlü test yaz (encode → decode → eşit).

---

## Aşama 1 — `ndef_codec` çekirdeği (ÖNCE BU — T2 bunu bekliyor)

- [ ] T3.1 `NdefRecord` / `NdefMessage` düşük seviye kodlayıcı-çözücü
      (başlık bitleri, SR, IL, chunk, TNF) — `docs/03 §1.1`
- [ ] T3.2 TLV katmanı: Type 2 Tag bellek → NDEF mesaj (0x03 TLV, terminator)
- [ ] T3.3 `NdefContent` sealed hiyerarşisi — her kayıt tipinin çözümlenmiş hali
- [ ] T3.4 `NdefDecoder.decode(record) → NdefContent` — tip tespiti
- [ ] T3.5 Boyut hesaplayıcı: `message.byteLength`, kayıt başına maliyet
- [ ] T3.6 Çift yönlü test altyapısı (`roundTrip(content)` yardımcısı)

## Aşama 2 — Temel kayıt tipleri

- [ ] T3.7 Metin (`T`) — dil kodu, UTF-8/UTF-16 seçimi
- [ ] T3.8 URI (`U`) — 36 ön ekin tamamı, en kısa kodlamayı otomatik seç
- [ ] T3.9 Telefon (`tel:`)
- [ ] T3.10 SMS (`sms:` + gövde)
- [ ] T3.11 E-posta (`mailto:` + konu + gövde, yüzde kodlama)
- [ ] T3.12 Konum (`geo:` enlem,boylam[,yükseklik])
- [ ] T3.13 Adres — harita arama URI'si
- [ ] T3.14 Arama — motor seçimli (Google, DuckDuckGo, YouTube, Wikipedia)
- [ ] T3.15 Sosyal medya — 10+ platform, kullanıcı adı → derin bağlantı
- [ ] T3.16 Video — YouTube / Vimeo
- [ ] T3.17 Kripto ödeme — BTC / ETH / USDT, `bitcoin:` `ethereum:` URI şemaları

## Aşama 3 — Yapılandırılmış kayıt tipleri

- [ ] T3.18 **WiFi (WSC)** — `docs/03 §1.4`, TLV kodlayıcı, tüm auth tipleri
- [ ] T3.19 **vCard 3.0** — ad, telefon(lar), e-posta(lar), şirket, unvan,
      adres, web, not; satır katlama (folding) doğru olmalı
- [ ] T3.20 **Bluetooth OOB** — klasik eşleştirme (MAC + isim + sınıf)
- [ ] T3.21 **Bluetooth LE OOB**
- [ ] T3.22 **Akıllı poster (`Sp`)** — iç içe URI + başlık + eylem kaydı
- [ ] T3.23 **Takvim (iCal)** — VEVENT, başlangıç/bitiş/başlık/konum
- [ ] T3.24 **AAR** (`android.com:pkg`) — uygulama başlatma
- [ ] T3.25 Play Store bağlantısı
- [ ] T3.26 Özel MIME — tip + metin/hex içerik
- [ ] T3.27 Harici tip (URN, TNF 4)
- [ ] T3.28 Ham / bilinmeyen (TNF 5) — doğrudan hex payload
- [ ] T3.29 Boş kayıt (TNF 0)
- [ ] T3.30 Acil durum bilgisi — kan grubu, alerji, ilaç, acil kontak
- [ ] T3.31 Dosya gömme — küçük dosya → MIME kaydı (boyut uyarısı ile)

## Aşama 4 — Yazma arayüzü (`feature_write`)

- [ ] T3.32 `WriteController` — kayıt listesi durumu, ekle/sil/sırala/düzenle
- [ ] T3.33 `WritePage` — kayıt kartları, sürükle-bırak sıralama,
      kaydırarak silme
- [ ] T3.34 Kapasite çubuğu — `X / Y byte`, taşınca kırmızı + yazma engeli
- [ ] T3.35 Kayıt tipi seçici — kategorili, arama kutulu tam ekran
- [ ] T3.36 Her tip için sihirbaz ekranı (form + canlı önizleme + doğrulama)
- [ ] T3.37 Yazma oturumu — `NfcScanSheet` ile, ilerleme + sonuç
- [ ] T3.38 Yazma sonrası doğrulama — geri oku, karşılaştır, farklıysa uyar
- [ ] T3.39 "Yazdıktan sonra kilitle" anahtarı (`DangerDialog` ile onay)
- [ ] T3.40 Çoklu yazma modu — N etikete arka arkaya, sayaçlı, hata toleranslı
- [ ] T3.41 Şablon kaydet / yükle (`TemplateRepository` arayüzü üzerinden)
- [ ] T3.42 Geçmişten yükleme (`/write?fromHistory=<id>` rota parametresi)

## Aşama 5 — Test

- [ ] T3.43 Her kayıt tipi için çift yönlü test (encode → decode → eşit)
- [ ] T3.44 Bilinen gerçek NDEF byte dizileriyle doğrulama (altın örnekler)
- [ ] T3.45 Kenar durumlar: boş payload, 255+ byte payload (SR=0),
      çoklu kayıt, chunk'lı kayıt, UTF-16 metin
- [ ] T3.46 `WriteController` birim testi

---

## Notlar

- **Altın örnek dosyaları** `packages/services/ndef_codec/test/fixtures/`
  altına koy. Gerçek etiketlerden alınmış hex dizileri en değerli testtir.
- Yeni kayıt tipi eklerken `templates/new_record_type.md` şablonunu izle.
- Kapasite hesabında TLV ve terminator byte'ını unutma — kullanıcıya
  "sığar" deyip yazmada patlamak en kötü hata.
