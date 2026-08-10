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

> Durum kodları: `[ ]` yapılmadı · `[~]` kısmi · `[x]` bitti ·
> `[!]` **codec hazır, sihirbaz UI'ı yok** (en ucuz işler bunlar).
> Son denetim: **2026-08-06** — koddan doğrulandı.

---

## Aşama 1 — `ndef_codec` çekirdeği (BİTTİ)

- [x] T3.1 `NdefRecord` / `NdefMessage` düşük seviye kodlayıcı-çözücü
      (`ndef_binary_codec.dart` — başlık bitleri, SR, IL, chunk, TNF)
- [x] T3.2 TLV katmanı: Type 2 Tag bellek → NDEF mesaj (0x03 TLV, terminator)
- [x] T3.3 `NdefContent` sealed hiyerarşisi — `Text`, `Uri`, `VCard`,
      `Wifi`, `Mime`, `External`, `Empty`, `Raw`.
      ⚠️ **Yeni tip eklerken** `ndef_converter` encode `switch`'i,
      `write_page._labelFor`, `tag_info_view._iconFor`/`_titleFor` ve
      `RecordTypeSheet.edit` birlikte güncellenmeli — ilk üçü exhaustive.
- [x] T3.4 `NdefConverter.decode(record) → NdefContent` — tip tespiti
- [x] T3.5 Boyut hesaplayıcı: `byteLength` + `byteLengthOnTag` (TLV dahil)
- [x] T3.6 Çift yönlü test altyapısı (`ndef_codec_test.dart`, 22 test)

## Aşama 2 — Temel kayıt tipleri

- [x] T3.7 Metin (`T`) — dil kodu, UTF-8/UTF-16 seçimi
- [x] T3.8 URI (`U`) — 36 ön ek (`uri_prefixes.dart`), en kısa kodlama seçilir
- [x] T3.9 Telefon (`tel:`)
- [x] T3.10 SMS (`sms:` + gövde)
- [x] T3.11 E-posta (`mailto:` + konu + gövde)
- [x] T3.12 Konum (`geo:`)
- [x] T3.13 Adres — harita arama URI'si
- [~] T3.14 Arama — **yalnız Google**; DuckDuckGo / YouTube / Wikipedia yok
- [~] T3.15 Sosyal medya — **yalnız Instagram**; hedeflenen 10+ platformdan 1'i
- [~] T3.16 Video — **yalnız YouTube**; Vimeo yok
- [~] T3.17 Kripto ödeme — BTC + ETH var, **USDT yok**

## Aşama 3 — Yapılandırılmış kayıt tipleri

- [x] T3.18 **WiFi (WSC)** — `wifi_wsc_codec.dart`: TLV kodlayıcı/çözücü,
      `Credential` (0x100E) zarfı, 5 auth tipi (`WifiAuthType`), 5 şifreleme
      tipi, SSID 32 byte ve parola 8-64 karakter doğrulaması.
      `WifiContent` sealed hiyerarşiye eklendi, `NdefConverter` çift yönlü
      bağlandı, seçiciye "Wi-Fi ağı" sihirbazı eklendi (parola göster/gizle,
      açık ağda parola alanı gizlenir, düz metin uyarısı). 8 test.
      ⚠️ Okuma tarafı etkilendi: WSC yükleri artık `MimeContent` değil
      `WifiContent` olarak çözülüyor — `RecordContentActions` buna göre
      güncellendi (çözülemeyen yükler için eski `MimeContent` yolu duruyor).
- [~] T3.19 **vCard 3.0** — ad, telefon(lar), e-posta(lar), şirket, unvan,
      adres, web, not; satır katlama (folding) doğru olmalı
- [x] T3.19a **vCard iPhone uyumluluğu** — iOS arka plan okuması MIME
      vCard'ı yok sayar; `VCardShareLink` vCard'ı base64url olarak URL
      fragment'ına gömer, sihirbaz "record stacking" ile vCard + URI çift
      kaydı yazar. Çözücü sayfa: `docs/v/index.html` (GitHub Pages,
      adres kartlara kalıcı yazılır — TAŞIMA/SİLME)
- [ ] T3.20 **Bluetooth OOB** — klasik eşleştirme (MAC + isim + sınıf)
- [ ] T3.21 **Bluetooth LE OOB**
- [ ] T3.22 **Akıllı poster (`Sp`)** — iç içe URI + başlık + eylem kaydı
- [ ] T3.23 **Takvim (iCal)** — VEVENT, başlangıç/bitiş/başlık/konum
- [ ] T3.24 **AAR** (`android.com:pkg`) — uygulama başlatma.
      `ExternalContent` kodlayıcısı hazır, yalnızca sihirbaz gerekiyor
- [x] T3.25 Play Store bağlantısı
- [x] T3.25a **Google İşletme Yorumu** — Place ID gerektirmeyen, arama
      tabanlı yaklaşım: işletme adı `https://www.google.com/search?q=`
      sorgusuna " yorum" eklenerek gönderilir; kullanıcı arama sonuçlarından
      kendi işletmesini seçip yorum alanını açar. Doğrudan `g.page/r/.../review`
      gibi kalıcı bir bağlantı yazılmıyor — bkz. ADR-0006'daki kalıcı-adres
      riski, aynı tuzağa düşülmedi
- [!] T3.26 Özel MIME — `MimeContent` codec'i **hazır ve testli**, sihirbaz UI'ı yok
- [!] T3.27 Harici tip (URN, TNF 4) — `ExternalContent` **hazır**, UI yok
- [!] T3.28 Ham / bilinmeyen (TNF 5) — `RawContent` **hazır**, UI yok
- [!] T3.29 Boş kayıt (TNF 0) — `EmptyContent` **hazır**, UI yok
- [ ] T3.30 Acil durum bilgisi — kan grubu, alerji, ilaç, acil kontak
- [ ] T3.31 Dosya gömme — küçük dosya → MIME kaydı (boyut uyarısı ile)

## Aşama 4 — Yazma arayüzü (`feature_write`)

- [x] T3.32 `WriteController` — kayıt listesi durumu, ekle/sil/sırala/düzenle
- [x] T3.33 `WritePage` — `ReorderableListView` + `Dismissible` ile silme
- [x] T3.34 Kapasite çubuğu — `_CapacitySection` + `probeTargetCapacity()`
      (hedef etiket okunup gerçek kapasite alınır)
- [x] T3.35 Kayıt tipi seçici — kategorili, arama kutulu tam ekran (15 tip)
- [x] T3.36 Her tip için sihirbaz ekranı (form + doğrulama)
- [x] T3.37 Yazma oturumu — `NfcScanSheet` ile, ilerleme + sonuç
- [x] T3.38 Yazma sonrası doğrulama — `writeNdef(verify: true)` geri okur,
      farklıysa `VerificationFailed` döner
- [x] T3.39 **"Yazdıktan sonra kilitle"** — `_LockAfterWriteSwitch`
      (açıkken tehlike rengi + "GERİ ALINAMAZ" alt metni). Yazma başlatılırken
      `DangerDialog` onayı alınır; onay verilmezse **hiçbir şey yazılmaz**.
      `write()` yazma başarılıysa `makeReadOnly` çağırır; yeni
      `WritePhase.locking` fazı tarama sayfasında "kilitleniyor" gösterir.
- [ ] T3.40 Çoklu yazma modu — N etikete arka arkaya, sayaçlı, hata toleranslı
- [!] T3.41 **Şablon kaydet / yükle UI'ı yok.** `TemplateRepository` tam
      uygulanmış ve `templateRepositoryProvider` composition root'ta bağlı;
      şu an yalnızca otomatik taslak satırı için kullanılıyor.
- [x] T3.41a **Otomatik taslak kalıcılığı** — yazma listesi her değişiklikte
      diske yazılır, uygulama yeniden açılınca geri yüklenir
      (`WriteDraftStore`, `TemplateRepository` içinde ayrılmış tek satır).
      T3.41 şablon listesi UI'ı yazılırken bu satır `WriteDraftStore.isDraft`
      ile **listeden gizlenmelidir.**
- [x] T3.42 Geçmişten yükleme (`/write?fromHistory=<id>` rota parametresi)

## Aşama 5 — Test

- [~] T3.43 Çift yönlü testler — 22 test var ama **her kayıt tipi için değil**;
      temel tipler kapsanıyor, yeni eklenen URI tipleri kapsanmıyor
- [ ] T3.44 Altın örnekler — `test/fixtures/` klasörü **hiç oluşturulmadı**
- [~] T3.45 Kenar durumlar — boş/uzun payload ve TLV testleri var;
      **chunk'lı kayıt ve UTF-16 metin testleri yok**
- [~] T3.46 `WriteController` testi — yalnızca **taslak kalıcılığı** test
      edilmiş (`write_draft_test.dart`, 8 test). Yazma akışı, kapasite
      ölçümü ve geçmişten yükleme test edilmedi.

---

## Notlar

- **Altın örnek dosyaları** `packages/services/ndef_codec/test/fixtures/`
  altına koy. Gerçek etiketlerden alınmış hex dizileri en değerli testtir.
- Yeni kayıt tipi eklerken `templates/new_record_type.md` şablonunu izle.
- Kapasite hesabında TLV ve terminator byte'ını unutma — kullanıcıya
  "sığar" deyip yazmada patlamak en kötü hata.

## Denetimde çıkan ek işler (2026-08-06)

- [ ] T3.47 **i18n borcu:** `feature_write` içinde ~64 gömülü Türkçe metin var
      (sihirbaz etiketleri, kayıt tipi başlık/açıklamaları, doğrulama
      mesajları). EN dili seçildiğinde bunlar Türkçe kalıyor.
      T5.25 ile birlikte `localization`'a taşınmalı.
- [ ] T3.48 **Sıradaki en verimli iş sırası:** T3.26–T3.29 (codec hazır,
      yalnız form — `_WifiInputPage` taze bir örnek) → T3.41 şablon UI'ı
      (repository hazır) → T3.14–T3.17 eksik URI varyantları (arama motoru,
      sosyal medya, Vimeo, USDT) → T3.40 çoklu yazma.
      T3.18 WiFi ve T3.39 kilitleme **kapatıldı**.
