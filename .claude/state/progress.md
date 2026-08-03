# Durum Panosu

> Her görev sonunda buraya **tek satır** ekle. Format:
> `- [T<N>] YYYY-MM-DD · <görev kodu> <özet> · <dosya>`
> Yeni satırlar en üste.

## Genel durum

| Track | Aşama | Son işlem |
|---|---|---|
| T1 — Çekirdek | Aşama 2 (Depolama) | Sözleşmeler + transport teslim edildi |
| T2 — Okuma | Aşama 1 | Başlamadı |
| T3 — Yazma | Aşama 1 | Başlamadı |
| T4 — Araçlar | Aşama 1 | Başlamadı |
| T5 — Tasarım | Aşama 1 | Başlamadı |

**Senkronizasyon noktası:** S1 (sözleşme kilidi) — ✅ geçildi.
`nfc_core` API'si donduruldu. Değişiklik için aşağıdaki listeyi kullan.

---

## Kayıt

- [T1] 2026-08-03 · T1.1 sqflite sema v1 + migration altyapisi tamamlandi · packages/services/storage/lib/src/database/storage_database.dart
- [T1] 2026-08-03 · OTA guncelleme altyapisi eklendi · apps/nfc_toolkit/lib/src/update/update_service.dart
- [T1] 2026-08-03 · Aşama 1 tamamlandı · monorepo, nfc_core sözleşmeleri,
  shared_utils, nfc_transport adaptörü, Android yapılandırması,
  composition root iskeleti
- [T1] 2026-08-03 · `.claude/` komuta merkezi kuruldu · docs, tracks, commands

---

## Bekleyen sözleşme değişiklikleri

`nfc_core` içinde değişmesi gereken bir şey varsa buraya yaz. T1 uygular.
Kendin düzenleme.

*(boş)*

---

## Devir notları

Başka track'i etkileyen bir değişiklik yaptıysan buraya yaz.

*(boş)*

---

## Engeller

Bir şeyi bekliyorsan veya emin olamadığın bir konu varsa buraya yaz.
Beklerken durma — track dosyandaki bağımsız bir görevi al.

*(boş)*

---

## Doğrulanacak teknik noktalar

`docs/03-nfc-reference.md` içindeki ⚠️ işaretli maddeler. Doğrulayan kişi
belgeden ⚠️'yi kaldırır ve buraya not düşer.

- [ ] NTAG215 dinamik kilit byte bit eşlemesi (sayfa 0x82)
- [ ] NTAG216 dinamik kilit byte bit eşlemesi (sayfa 0xE2)
- [ ] NTAG215/216 CC değerlerinin gerçek etikette doğrulanması
