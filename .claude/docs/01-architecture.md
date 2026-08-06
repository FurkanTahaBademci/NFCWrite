# 01 — Mimari

## Neden "micro-package"?

İstek: *microservice mimarisine, ölçeklenebilir*. Bir mobil istemcide gerçek
microservice (ağ üzerinden konuşan ayrı süreçler) yoktur — karşılığı
**micro-package / modüler monolit**tir. Aynı faydaları verir:

| Microservice faydası | Bizdeki karşılığı |
|---|---|
| Bağımsız dağıtım | Bağımsız `pubspec.yaml`, bağımsız sürüm, bağımsız test |
| Net servis sınırı | `lib/<paket>.dart` barrel = public API; `src/` kapalı |
| Sözleşme ile konuşma | `nfc_core` içindeki soyut arayüzler |
| Takım bağımsızlığı | Her track kendi paketlerinin tek sahibi → git çakışması yok |
| Değiştirilebilirlik | `nfc_manager` → başka paket geçişi sadece `nfc_transport`'u etkiler |
| Ölçeklenebilirlik | Yeni özellik = yeni `feature_*` paketi, mevcut kod değişmez |

## Katmanlar

```
┌──────────────────────────────────────────────────────────────┐
│  apps/nfc_toolkit          COMPOSITION ROOT                  │
│  - DI kablolaması (Riverpod override'ları)                   │
│  - Router birleştirme, tema, uygulama kabuğu                 │
│  - Somut uygulamaları soyutlamalara BAĞLAYAN tek yer         │
└───────────────┬──────────────────────────────────────────────┘
                │ depends on ↓ (her şeyi görür)
┌───────────────┴──────────────────────────────────────────────┐
│  packages/features/*       ÖZELLİK KATMANI                   │
│  feature_read  feature_write  feature_tools                  │
│  feature_history  feature_settings                           │
│  - UI + Riverpod state + kullanım senaryoları                │
│  - SADECE nfc_core soyutlamalarını kullanır                  │
└───────────────┬──────────────────────────────────────────────┘
                │ depends on ↓
┌───────────────┴──────────────────────────────────────────────┐
│  packages/core/nfc_core    SÖZLEŞME KATMANI                  │
│  - Varlıklar (entity): NfcTagInfo, TagMemory, NdefMessage... │
│  - Arayüzler: NfcSessionService, TagOperations, Repositories │
│  - Hata tipleri: NfcFailure hiyerarşisi, Result<T>           │
│  - Flutter bağımlılığı YOK. Saf Dart.                        │
└───────────────┬──────────────────────────────────────────────┘
                │ implemented by ↑
┌───────────────┴──────────────────────────────────────────────┐
│  packages/services/*       UYGULAMA (IMPL) KATMANI           │
│  nfc_transport  → NfcSessionService implementasyonu          │
│  tag_ops        → TagOperations implementasyonu              │
│  ndef_codec     → NDEF kodlama/çözme + kayıt üreticileri     │
│  storage        → Repository implementasyonları (sqflite)    │
└──────────────────────────────────────────────────────────────┘
```

Yatay destek paketleri (herkes kullanabilir, kimseye bağımlı değiller):
`shared_utils` (byte/hex/CRC/log), `design_system` (tema + widget),
`localization` (TR/EN).

## Bağımlılık kuralları — MUTLAK

```
✅ feature_*      →  nfc_core, ndef_codec, design_system, localization, shared_utils
❌ feature_*      →  nfc_transport, tag_ops, storage        (YASAK)
❌ feature_*      →  feature_*                              (YASAK — kardeş bağımlılık yok)

✅ services/*     →  nfc_core, shared_utils
✅ tag_ops        →  ndef_codec       (NDEF yazma/biçimlendirme için — tek istisna)
❌ services/*     →  feature_*, design_system               (YASAK)

✅ nfc_core       →  (hiçbir şey — sadece dart:*, meta, collection)
❌ nfc_core       →  flutter                                (YASAK)

✅ apps/*         →  her şey
```

`feature_*` paketleri birbirini görmez. Ortak ihtiyaç çıkarsa → `nfc_core`
(sözleşme) veya `design_system` (widget) içine taşınır.

## Bir isteğin akışı (örnek: "Etiketi kilitle")

```
feature_tools/LockTagPage
   └─ ref.read(lockTagControllerProvider.notifier).lock()
        └─ LockTagController (feature_tools, Riverpod Notifier)
             └─ TagOperations.makeReadOnly()        ← nfc_core ARAYÜZÜ
                  ⋮ (runtime'da composition root şunu bağlar)
                  └─ TagOperationsImpl (tag_ops)
                       └─ NfcSessionService.transceive()  ← nfc_core ARAYÜZÜ
                            └─ AndroidSessionService (nfc_transport)
                                 └─ nfc_manager → Android NFC API
```

> Örnekteki `LockTagPage` / `LockTagController` kavramsaldır. Gerçekte tüm
> araçlar tek bir `ToolDetailPage` üzerinden yürüyor; araç başına ayrı
> controller **yok** (bkz. T4.39 — `ToolController` tabanı açık bir iş).

`feature_tools` ne `tag_ops`'u ne `nfc_manager`'ı bilir. Test ederken sahte
(fake) `TagOperations` verilir — NFC donanımı gerekmez.

## Hata yönetimi

Beklenen hatalar `throw` edilmez, `Result<T>` ile döndürülür:

```dart
sealed class Result<T> { }
final class Ok<T>    extends Result<T> { final T value; }
final class Err<T>   extends Result<T> { final NfcFailure failure; }
```

`NfcFailure` sealed hiyerarşisi kullanıcıya gösterilecek mesajı taşımaz —
sadece makine-okunur bir sebep taşır. Çeviri `localization` katmanında yapılır.
Bu sayede `nfc_core` Flutter'a bağımlı olmaz.

## Yeni özellik nasıl eklenir?

1. Sözleşme gerekiyorsa `nfc_core` içine arayüz + varlık ekle (T1 onayı).
2. `packages/features/feature_<ad>` paketi oluştur
   (`templates/new_feature_package.md`).
3. `apps/nfc_toolkit/pubspec.yaml` içine ekle, `workspace:` listesine ekle.
4. Rotayı `feature_<ad>/routes.dart` içinde tanımla, kabukta birleştir.
5. `docs/02-feature-matrix.md` tablosunu güncelle.

Mevcut hiçbir paket değişmez. **Ölçeklenebilirlik bu demek.**
