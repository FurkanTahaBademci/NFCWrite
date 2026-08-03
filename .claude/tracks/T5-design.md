# T5 — Tasarım Sistemi, Çeviriler & Ayarlar

**Sahip olduğun yollar:**
```
packages/core/design_system/**
packages/core/localization/**
packages/features/feature_settings/**
```

**Kullanabileceğin paketler:** `nfc_core` (yalnızca `feature_settings` ve
`localization` için), Flutter
**YASAK:** `nfc_transport`, `tag_ops`, `storage`, `ndef_codec`,
diğer `feature_*`

**Okuman gerekenler:** `docs/04-ui-ux-spec.md` (**tamamı**),
`docs/05-conventions.md`

> **Sen üç track'i besliyorsun.** T2, T3, T4 senin widget'larını bekliyor.
> Aşama 1'i (imzalar) mümkün olan en hızlı şekilde bitir — içleri boş olsa
> bile imzalar yayında olsun ki diğerleri kodlayabilsin.

---

## Aşama 1 — Widget imzaları (ACİL — 3 track bekliyor)

Önce **sadece imzaları** yaz, gövde `Placeholder()` olabilir. Sonra doldur.

- [ ] T5.1 `NfcScanSheet` — durum: `idle/scanning/tagFound/working/success/failure`,
      `onCancel`, ilerleme yüzdesi, özel mesaj
- [ ] T5.2 `DangerDialog` — başlık, açıklama, risk seviyesi, hedef UID,
      "yedek al" anahtarı, kaydırarak onay
- [ ] T5.3 `HexDumpView` — `Uint8List`, sayfa boyutu, başlangıç sayfa no,
      vurgulanacak aralıklar, ASCII sütunu
- [ ] T5.4 `InfoRow` — etiket + değer + kopyala + isteğe bağlı ikon
- [ ] T5.5 `TagBadge` — teknoloji/durum rozeti, renk varyantları
- [ ] T5.6 `CapacityBar` — kullanılan/toplam, taşma durumu
- [ ] T5.7 `ToolCard` — ikon, ad, açıklama, risk rozeti
- [ ] T5.8 `EmptyState` — ikon, başlık, açıklama, eylem düğmesi
- [ ] T5.9 `SectionHeader`, `AppScaffold`, `LoadingOverlay`

## Aşama 2 — Tasarım tokenları ve tema

- [ ] T5.10 `AppSpacing` (4/8/12/16/24/32), `AppRadius`, `AppElevation`
- [ ] T5.11 `AppColors` — risk renkleri (güvenli/dikkat/tehlike) + semantik roller
- [ ] T5.12 `AppTypography` — ölçek + monospace stil (hex için)
- [ ] T5.13 Material 3 açık tema
- [ ] T5.14 Material 3 koyu tema
- [ ] T5.15 Dinamik renk desteği (Android 12+), yedek tohum `#2563EB`
- [ ] T5.16 `AppIcons` — kayıt tipi ikon eşlemesi (26 tip), araç ikonları,
      teknoloji ikonları

## Aşama 3 — Widget gövdeleri

- [ ] T5.17 `NfcScanSheet` nabız animasyonu + durum geçişleri + haptik
- [ ] T5.18 `DangerDialog` kaydırarak onay bileşeni
- [ ] T5.19 `HexDumpView` — performans (uzun dump'ta `ListView.builder`),
      seçilebilir metin, byte vurgulama, ekran okuyucu desteği
- [ ] T5.20 Kalan widget'ların gövdeleri
- [ ] T5.21 Widget kataloğu ekranı (`/settings/design-catalog`, hata ayıklama)

## Aşama 4 — Çeviriler (`localization`)

- [ ] T5.22 `l10n.yaml` + `app_tr.arb` + `app_en.arb` kurulumu
- [ ] T5.23 Ortak metinler: eylemler, durumlar, hatalar, onaylar
- [ ] T5.24 Okuma ekranı metinleri
- [ ] T5.25 Yazma ekranı + 26 kayıt tipi adı/açıklaması
- [ ] T5.26 Araç ekranı + 25 araç adı/açıklaması/uyarısı
- [ ] T5.27 **`NfcFailure` → kullanıcı mesajı eşlemesi** (`failure_messages.dart`)
      — `sealed` üzerinde exhaustive `switch`, yeni hata eklenince derleme
      hatası versin
- [ ] T5.28 Teknik terim sözlüğü — TR karşılıkları tutarlı olsun
      (tag=etiket, dump=bellek dökümü, lock=kilitleme, format=biçimlendirme)
- [ ] T5.29 Dil değiştirme — uygulama yeniden başlatmadan

## Aşama 5 — Ayarlar (`feature_settings`)

- [ ] T5.30 `SettingsController` — `SettingsRepository` arayüzü üzerinden
- [ ] T5.31 Görünüm: tema (açık/koyu/sistem), dinamik renk anahtarı
- [ ] T5.32 Dil seçimi (TR/EN/sistem)
- [ ] T5.33 Geri bildirim: titreşim, ses, ikisi de kapatılabilir
- [ ] T5.34 Tarama: otomatik geçmişe kaydet, tekrar okuma engeli süresi
- [ ] T5.35 **Uzman modu** anahtarı — açıklama metni + ilk açılışta uyarı
- [ ] T5.36 Güvenlik: "yıkıcı işlem öncesi otomatik yedek" (varsayılan açık),
      "onay diyaloğunu uzman modunda basitleştir"
- [ ] T5.37 Veri: geçmişi temizle, dump arşivini temizle, tümünü dışa aktar
- [ ] T5.38 Hakkında: sürüm, lisanslar (`showLicensePage`), gizlilik metni
- [ ] T5.39 Gizlilik metni — "hiçbir veri cihazdan çıkmaz" (doğruysa)

## Aşama 6 — Erişilebilirlik & cila

- [ ] T5.40 Tüm dokunma hedefleri ≥ 48dp denetimi
- [ ] T5.41 Ekran okuyucu etiketleri (`Semantics`) — özellikle hex dump
- [ ] T5.42 Metin ölçeklendirme %200 testi
- [ ] T5.43 Kontrast denetimi (WCAG AA)
- [ ] T5.44 Widget testleri — tema, danger dialog akışı, hex view

---

## Notlar

- Widget imzasını değiştireceksen **önce** `state/progress.md` →
  "Devir notları" bölümüne yaz. Üç track'i birden kırabilirsin.
- `design_system` `nfc_core`'a bağımlı **değildir**. Widget'lar ham tipler
  alır (`Uint8List`, `String`, `enum`), alan modeli almaz. Bu sayede
  tasarım katmanı bağımsız test edilir.
- Risk renklerini yalnız renkle ifade etme — ikon + metin de olsun.
