---
description: Mimari kuralları, analiz ve testleri doğrula
---

Projeyi baştan sona doğrula ve bulguları raporla.

## 1. Statik analiz

```
flutter analyze
```

Sıfır hata ve sıfır uyarı bekleniyor. Hata varsa dosya:satır ile listele.

## 2. Testler

```
flutter test
```

## 3. Mimari sınır denetimi

`.claude/docs/01-architecture.md` içindeki bağımlılık kurallarını doğrula.
Şunları ara ve **her bulgu bir ihlaldir**:

- `packages/features/*/pubspec.yaml` içinde `nfc_transport`, `tag_ops`
  veya `storage` var mı?
- `packages/features/*/pubspec.yaml` içinde başka bir `feature_*` var mı?
- `packages/core/nfc_core/pubspec.yaml` içinde `flutter` var mı?
- `packages/services/*/pubspec.yaml` içinde `design_system` veya
  `feature_*` var mı?
- Herhangi bir yerde `package:<paket>/src/` import'u var mı?
  (kendi paketi içinden göreli import hariç)

## 4. Güvenlik kapısı denetimi

`packages/services/tag_ops/` içindeki yıkıcı işlemleri bul
(kilitleme, şifre, biçimlendirme, silme, CFGLCK, AUTHLIM).
Her birinin `DangerAck` parametresi aldığını doğrula.
Almayan varsa ADR-0005 ihlali olarak raporla.

## 5. Belge tutarlılığı

- `.claude/docs/02-feature-matrix.md` içindeki `[x]` işaretli özelliklerin
  kodda gerçekten karşılığı var mı? (birkaç örnekle sınama)
- Kök `pubspec.yaml` `workspace:` listesi ile `packages/` altındaki gerçek
  paketler eşleşiyor mu?

## Rapor

```
✅ / ❌  Statik analiz      (N hata, M uyarı)
✅ / ❌  Testler            (N geçti, M kaldı)
✅ / ❌  Mimari sınırlar    (N ihlal)
✅ / ❌  Güvenlik kapıları  (N ihlal)
✅ / ❌  Belge tutarlılığı

İHLALLER
1. <dosya:satır> — <ne> — <nasıl düzeltilir>
```

Bulduğun ihlalleri **düzeltme**, sadece raporla. Düzeltme ilgili track'in işi.
