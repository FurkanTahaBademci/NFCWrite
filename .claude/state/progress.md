# Durum Panosu

> Her görev sonunda buraya **tek satır** ekle. Format:
> `- [T<N>] YYYY-MM-DD · <görev kodu> <özet> · <dosya>`
> Yeni satırlar en üste.

## Genel durum

| Track | Aşama | Son işlem |
|---|---|---|
| T1 — Çekirdek | Aşama 3 (Oturum saglamlastirma) | T1.6 storage testleri tamamlandi |
| T2 — Okuma | Aşama 1 | Başlamadı |
| T3 — Yazma | Aşama 3 (Yapilandirilmis kayit tipleri) | vCard codec + write sihirbaz akisi eklendi |
| T4 — Araçlar | Aşama 7 | Diger sekmesinde calisir araclar ve ham komut formu tamamlandi |
| T5 — Tasarım | Aşama 1 | Başlamadı |

**Senkronizasyon noktası:** S1 (sözleşme kilidi) — ✅ geçildi.
`nfc_core` API'si donduruldu. Değişiklik için aşağıdaki listeyi kullan.

---

## Kayıt

- [T4] 2026-08-03 · T4.19/T4.21/T4.22 Diğer sekmesinde biçimlendir + şifre koy/kaldır akışları aktif edildi ve testlendi · packages/services/tag_ops/lib/src/tag_operations_impl.dart
- [T3] 2026-08-03 · Yazma kayıt seçicide Türkçe metin düzeltmeleri ve yeni URI tabanlı kayıt tipleri eklendi (YouTube/Play Store/Instagram/BTC/ETH) · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T3] 2026-08-03 · T3.35 kayit tipi secici tam ekran + kategori + arama ile tamamlandi · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T3] 2026-08-03 · T3.19 ilk surum vCard 3.0 MIME codec + write vCard sihirbazi eklendi, kayit secici tam sayfaya tasindi · packages/features/feature_write/lib/src/presentation/widgets/record_type_sheet.dart

- [T4] 2026-08-03 · T4.9/T4.11/T4.31 diger sekmesindeki eksikler tamamlandi (aktif kartlar + ham komut formu) · packages/features/feature_tools/lib/src/presentation/pages/tool_detail_page.dart
- [T1] 2026-08-03 · T1.6 storage sqflite_ffi testleri tamamlandi (3 test) · packages/services/storage/test/storage_repositories_test.dart
- [T1] 2026-08-03 · T1.7 composition root kalici repository'lere baglandi · apps/nfc_toolkit/lib/src/di/app_dependencies.dart
- [T1] 2026-08-03 · T1.5 SettingsRepositoryImpl (shared_preferences) dogrulandi · packages/services/storage/lib/src/settings_repository_impl.dart
- [T1] 2026-08-03 · T1.4 TemplateRepositoryImpl sqflite ile tamamlandi · packages/services/storage/lib/src/template_repository_impl.dart
- [T1] 2026-08-03 · T1.3 DumpRepositoryImpl sqflite + dosya disa/ice aktarma tamamlandi · packages/services/storage/lib/src/dump_repository_impl.dart
- [T1] 2026-08-03 · T1.2 HistoryRepositoryImpl sqflite ile tamamlandi · packages/services/storage/lib/src/history_repository_impl.dart
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

- T1 (2026-08-03): `apps/nfc_toolkit` artik `HistoryRepositoryImpl`,
  `DumpRepositoryImpl`, `TemplateRepositoryImpl` ve `SettingsRepositoryImpl`
  ile calisiyor; feature katmanlari API degisikligi olmadan kalici veri
  kullanmaya basladi.

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
