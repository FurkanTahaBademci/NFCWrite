# .claude — Komuta Merkezi

Bu klasör projenin **tek doğruluk kaynağıdır**. Kod nasıl yazılacak, kim neyi
yapacak, hangi özellik nerede duruyor — hepsi burada.

## Klasör haritası

| Yol | İçerik |
|---|---|
| `docs/00-vision-and-scope.md` | Ne yapıyoruz, ne yapmıyoruz, rakip analizi |
| `docs/01-architecture.md` | Katmanlar, paket grafiği, bağımlılık kuralları |
| `docs/02-feature-matrix.md` | Tüm özelliklerin tam listesi + durum + sahip |
| `docs/03-nfc-reference.md` | NTAG/Ultralight/Classic/NfcV komut ve bellek haritaları |
| `docs/04-ui-ux-spec.md` | Ekranlar, akışlar, tasarım dili |
| `docs/05-conventions.md` | Kod stili, isimlendirme, hata yönetimi, test |
| `docs/06-parallel-workflow.md` | Track sahiplikleri, git akışı, çakışma önleme |
| `docs/adr/` | Mimari karar kayıtları (neden böyle yaptık) |
| `tracks/T1..T5-*.md` | Her iş kolunun sıralı görev listesi |
| `state/progress.md` | Canlı durum panosu — **her görev sonunda güncelle** |
| `commands/` | Slash komutları (`/track`, `/handoff`, `/verify`, `/status`) |
| `templates/` | Yeni paket / yeni kayıt tipi / yeni araç şablonları |

## Çalışma döngüsü (her oturumda)

1. **Oku:** `state/progress.md` → kendi track dosyan → `docs/01-architecture.md`
2. **Seç:** Track dosyandaki ilk `[ ]` (yapılmamış) görevi al, `[~]` yap.
3. **Yaz:** Sadece track'inin sahip olduğu dosyalarda çalış.
4. **Doğrula:** `flutter analyze` + `flutter test` temiz olmalı.
5. **İşaretle:** Görevi `[x]` yap, `state/progress.md` içine tek satır not düş.
6. **Devret:** Başka bir track'i bloke eden bir sözleşme değiştiysen
   `state/progress.md` → "Devir notları" bölümüne yaz.

## Track'ler (paralel terminaller)

| Track | Konu | Sahip olduğu paketler |
|---|---|---|
| **T1** | Çekirdek & NFC altyapısı | `nfc_core`, `shared_utils`, `nfc_transport`, `storage` |
| **T2** | Okuma özelliği | `feature_read`, `feature_history` |
| **T3** | Yazma & kayıt tipleri | `feature_write`, `ndef_codec` |
| **T4** | Etiket araçları (pro) | `feature_tools`, `tag_ops` |
| **T5** | Tasarım sistemi & i18n | `design_system`, `localization`, `feature_settings` |

Her terminalde:

```
/track T3
```

komutu ile o iş koluna girilir. Komut tanımı: `commands/track.md`

## Sözleşme değişikliği protokolü

`nfc_core` içindeki bir arayüz (interface) değişecekse:

1. Değişikliği önce `state/progress.md` → "Bekleyen sözleşme değişiklikleri"
   listesine yaz.
2. T1 sahibi onaylar ve `nfc_core` içinde uygular.
3. Diğer track'ler `flutter analyze` ile kırılmayı görür ve uyarlar.

**Hiçbir track `nfc_core` dosyalarını T1 dışında doğrudan düzenlemez.**
