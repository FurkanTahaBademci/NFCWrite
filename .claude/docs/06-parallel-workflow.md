# 06 — Paralel Çalışma Düzeni

5 terminal, 5 iş kolu (track). Amaç: **aynı dosyaya iki kişi dokunmasın.**

## Dosya sahipliği tablosu — MUTLAK

| Track | Yazma yetkisi olan yollar |
|---|---|
| **T1 — Çekirdek** | `packages/core/nfc_core/**`<br>`packages/core/shared_utils/**`<br>`packages/services/nfc_transport/**`<br>`packages/services/storage/**`<br>`apps/nfc_toolkit/android/**`<br>`apps/nfc_toolkit/lib/src/di/**`<br>`apps/nfc_toolkit/lib/src/update/**` (OTA)<br>`releases/**` (OTA manifesti) |
| **T2 — Okuma** | `packages/features/feature_read/**`<br>`packages/features/feature_history/**` |
| **T3 — Yazma** | `packages/features/feature_write/**`<br>`packages/services/ndef_codec/**`<br>`docs/v/**` (GitHub Pages vCard çözücü — kartlara yazılan kalıcı adres, TAŞIMA/SİLME) |
| **T4 — Araçlar** | `packages/features/feature_tools/**`<br>`packages/services/tag_ops/**` |
| **T5 — Tasarım** | `packages/core/design_system/**`<br>`packages/core/localization/**`<br>`packages/features/feature_settings/**` |
| **Ortak (kilitli)** | `apps/nfc_toolkit/lib/main.dart`, `apps/nfc_toolkit/lib/src/app/**`, kök `pubspec.yaml`, `.claude/docs/**` → **yalnızca T1 düzenler** |

Her track kendi track dosyasında (`tracks/T<N>-*.md`) ve
`state/progress.md` içinde kendi bölümünü düzenler.

## Bağımlılık sırası (kim kimi bekliyor)

```
T1 (nfc_core sözleşmeleri)
 ├──► T3 (ndef_codec)  ──► T2 (feature_read NDEF gösterimi)
 ├──► T4 (tag_ops)     ──► T4 (feature_tools)
 └──► T2 (feature_read)
T5 (design_system)  ──► T2, T3, T4 (widget'lar)
```

**Kilitlenmeyi önleme:** T1, ilk oturumda `nfc_core` arayüzlerinin
**tamamını** (gövdesiz de olsa) yazar. Böylece T2–T5 hemen başlayabilir.
Bu iş bu commit'te **tamamlandı** — sözleşmeler hazır.

Aynı şekilde T5, `design_system` widget'larının imzalarını erken yayınlar;
içi sonra dolar. T2/T3/T4 imzalara göre kodlar.

## Git akışı

```bash
# Her track kendi dalında çalışır
git checkout -b track/T3-write

# Sık ve küçük commit
git commit -m "feat(ndef_codec): WiFi WSC kodlayıcı"

# Günde en az bir kez main'i al
git fetch origin && git rebase origin/main

# Bitince main'e
git checkout main && git merge --no-ff track/T3-write
```

Sahiplik tablosuna uyulursa rebase çakışması pratikte oluşmaz.
Çakışırsa: **çakışan dosyanın sahibi kimse o çözer.**

## Terminal başlatma

Her terminalde proje kökünde:

```
claude
```

sonra ilgili komut:

| Terminal | Komut |
|---|---|
| 1 | `/track T1` |
| 2 | `/track T2` |
| 3 | `/track T3` |
| 4 | `/track T4` |
| 5 | `/track T5` |

`/track` komutu ilgili track dosyasını okur, sahiplik kurallarını yükler ve
sıradaki görevden devam eder.

## Senkronizasyon noktaları

Şu anlarda tüm track'ler durur ve T1 birleştirme yapar:

| Nokta | Ne olur |
|---|---|
| **S1 — Sözleşme kilidi** | `nfc_core` API'si dondurulur. Bundan sonra değişiklik ancak protokolle. |
| **S2 — İlk uçtan uca** | Oku + Yaz ile gerçek bir NTAG213'te tam tur atılır. |
| **S3 — Araç entegrasyonu** | `tag_ops` composition root'a bağlanır, tüm araçlar canlı. |
| **S4 — Cilalama** | i18n tamamlanır, `flutter analyze` sıfırlanır, testler yeşile döner. |

## Çakışma çıkarsa

1. `state/progress.md` → "Engeller" bölümüne yaz.
2. Bir şeyi beklerken durma — track dosyandaki bağımsız bir görevi al.
3. Sözleşme değişikliği gerekiyorsa `state/progress.md` → "Bekleyen sözleşme
   değişiklikleri" listesine yaz, T1'in uygulamasını bekle.

## Her görev sonunda

```bash
flutter analyze          # kökten — SIFIR hata
flutter test             # kökten — hepsi yeşil
```

Sonra `state/progress.md` içine tek satır:

```
- [T3] 2026-08-03 · B12 WiFi kayıt tipi bitti · ndef_codec/wifi_record.dart
```
