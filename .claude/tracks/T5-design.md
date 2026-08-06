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

> Durum kodları: `[ ]` yapılmadı · `[~]` kısmi · `[x]` bitti ·
> `[-]` kapsam dışı · `[!]` **yazıldı ama hiçbir yerde kullanılmıyor**.
> Son denetim: **2026-08-06** — koddan doğrulandı.

## Aşama 1 — Widget imzaları (BİTTİ — gövdeleriyle birlikte)

- [x] T5.1 `NfcScanSheet` — durum geçişleri, `onCancel`, özel mesaj
- [x] T5.2 `DangerDialog` — başlık, açıklama, risk seviyesi, hedef UID,
      kaydırarak onay
- [x] T5.3 `HexDumpView` — `Uint8List`, sayfa boyutu, başlangıç sayfa no,
      ASCII sütunu
- [x] T5.4 `InfoRow` — etiket + değer + kopyala + ikon
- [x] T5.5 `TagBadge` — teknoloji/durum rozeti, risk renk varyantları
- [x] T5.6 `CapacityBar` — kullanılan/toplam, taşma durumu
- [x] T5.7 `ToolCard` — ikon, ad, açıklama, risk rozeti, `enabled` bayrağı
- [x] T5.8 `EmptyState` — ikon, başlık, açıklama, eylem düğmesi
- [~] T5.9 `SectionHeader` ✅ kullanılıyor · `AppScaffold` ve `LoadingOverlay`
      **[!] yazıldı, testlendi, hiçbir ekranda kullanılmıyor.** Ya benimsensin
      (özellik ekranları bunlara geçsin) ya da paketten çıkarılsın.

## Aşama 2 — Tasarım tokenları ve tema

- [~] T5.10 `AppSpacing` ✅ · `AppRadius` ✅ · **`AppElevation` yok**
- [x] T5.11 `AppColors` — risk renkleri (`RiskLevel`) + semantik roller
- [x] T5.12 `AppTypography` — ölçek + monospace (hex) stili
- [x] T5.13 Material 3 açık tema
- [x] T5.14 Material 3 koyu tema
- [ ] T5.15 **Dinamik renk desteği yok.** `dynamic_color` paketi eklenmedi,
      `app.dart` içinde `TODO(T5.15)` duruyor. Buna rağmen ayarlar ekranında
      "dinamik renk" anahtarı **görünüyor ve hiçbir şey yapmıyor** —
      ya paket eklenmeli ya anahtar gizlenmeli.
- [ ] T5.16 `AppIcons` — yok; ikonlar `tool_catalog`, `record_type_sheet` ve
      `tag_info_view` içinde dağınık `Icons.*` sabitleri olarak duruyor

## Aşama 3 — Widget gövdeleri

- [x] T5.17 `NfcScanSheet` nabız animasyonu + durum geçişleri + haptik
      (`AnimationController` + `HapticFeedback`)
- [x] T5.18 `DangerDialog` kaydırarak onay bileşeni (`_dragPosition`)
- [x] T5.19 `HexDumpView` — `ListView.builder` + `Semantics` desteği
- [x] T5.20 Kalan widget'ların gövdeleri
- [ ] T5.21 Widget kataloğu ekranı (`/settings/design-catalog`)

## Aşama 4 — Çeviriler (`localization`)

- [-] T5.22 `l10n.yaml` + ARB — **kapsam dışı bırakıldı.** ARB akışı
      `flutter gen-l10n` kod üretimi gerektiriyor, ADR-0003 codegen'i
      yasaklıyor. Yerine elle yazılmış `AppStrings` arayüzü +
      `strings_tr.dart` / `strings_en.dart` kullanılıyor (136 anahtar).
      Yeni anahtar eklenince iki dil de derleme hatası verir — ARB'nin
      sağladığı güvenceyi bu şekilde koruyoruz.
- [x] T5.23 Ortak metinler: eylemler, durumlar, hatalar, onaylar
- [x] T5.24 Okuma ekranı metinleri
- [~] T5.25 Yazma ekranı — sayfa iskeleti çevrili ama **`feature_write`
      içinde ~64 gömülü Türkçe metin var** (sihirbaz etiketleri, kayıt tipi
      başlık/açıklamaları). EN'de çevrilmiyor.
- [ ] T5.26 Araç ekranı — **`tool_catalog.dart` tamamen gömülü Türkçe**
      (16 aracın başlık + açıklaması) ve `tool_detail_page` içinde ~58 metin
      daha var. EN dilinde araçlar sekmesi hiç çevrilmiyor.
- [x] T5.27 `NfcFailure` → kullanıcı mesajı eşlemesi (`failure_messages.dart`,
      `sealed` üzerinde exhaustive `switch` + `actionLabelFor`)
- [ ] T5.28 Teknik terim sözlüğü — yazılı bir sözlük yok
- [x] T5.29 Dil değiştirme — yeniden başlatmadan (`MaterialApp.router.locale`
      `settingsProvider`'dan besleniyor)

## Aşama 5 — Ayarlar (`feature_settings`)

- [x] T5.30 `SettingsController` — `SettingsRepository` arayüzü üzerinden
- [~] T5.31 Görünüm — tema seçimi çalışıyor; **dinamik renk anahtarı ölü**
      (bkz. T5.15)
- [x] T5.32 Dil seçimi (TR/EN/sistem)
- [~] T5.33 Geri bildirim — iki anahtar da var ama **hiçbiri etkili değil:**
      `hapticFeedback` `NfcScanSheet`'e geçirilmiyor (widget varsayılan
      `true` ile çalışıyor), `soundFeedback` kodda hiç okunmuyor
- [~] T5.34 Tarama — "otomatik geçmişe kaydet" çalışıyor;
      **"tekrar okuma engeli süresi" yok** (`duplicateScanCooldown` alanı
      `AppSettings`'te duruyor ama ne UI'ı ne tüketicisi var)
- [x] T5.35 **Uzman modu** anahtarı — açıklama metni + uyarı diyaloğu
- [~] T5.36 Güvenlik — "otomatik yedek" anahtarı **görünüyor ama işlevi yok**
      (bkz. T4.46 — hiçbir yıkıcı araç yedek almıyor);
      "onay diyaloğunu basitleştir" (`simplifyConfirmationsInExpertMode`)
      alanı var, **UI'ı da tüketicisi de yok**
- [~] T5.37 Veri — toplu dışa/içe aktarma **geçmiş sekmesinde** var;
      ayarlar ekranında "geçmişi temizle / arşivi temizle" yok
      (`HistoryRepository.clear` ve `DumpRepository.clear` **hazır**)
- [~] T5.38 Hakkında — sürüm + `showLicensePage` var, ama **sürüm `'0.1.0'`
      olarak elle gömülü** (gerçek sürüm `0.1.5+7`). `package_info_plus`
      zaten bağımlılık — oradan okunmalı.
- [ ] T5.39 Gizlilik metni — yok

## Aşama 6 — Erişilebilirlik & cila (HİÇBİRİ YAPILMADI)

- [ ] T5.40 Tüm dokunma hedefleri ≥ 48dp denetimi
- [ ] T5.41 Ekran okuyucu etiketleri — `HexDumpView` `Semantics` kullanıyor,
      diğer ekranlarda denetim yapılmadı
- [ ] T5.42 Metin ölçeklendirme %200 testi
- [ ] T5.43 Kontrast denetimi (WCAG AA)
- [ ] T5.44 Widget testleri — yalnızca `common_widgets_test.dart` var;
      tema, `DangerDialog` akışı ve `HexDumpView` test edilmedi

---

## Notlar

- Widget imzasını değiştireceksen **önce** `state/progress.md` →
  "Devir notları" bölümüne yaz. Üç track'i birden kırabilirsin.
- `design_system` `nfc_core`'a bağımlı **değildir**. Widget'lar ham tipler
  alır (`Uint8List`, `String`, `enum`), alan modeli almaz. Bu sayede
  tasarım katmanı bağımsız test edilir.
- Risk renklerini yalnız renkle ifade etme — ikon + metin de olsun.
