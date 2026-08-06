# Magaza gorselleri

Tum ikonlar tek bir master dosyadan uretilir: depo kokundeki `logo.png`.

```bash
python3 tool/generate_app_icons.py
```

## Icerik

| Dosya | Kullanim | Kural |
| --- | --- | --- |
| `play/icon-512.png` | Google Play Console → Uygulama ikonu | 512×512, 32-bit PNG, **tam kare**, saydamlik yok, ≤ 1 MB |
| `logo-1024-transparent.png` | README, sunum, web | Yuvarlatilmis kare, saydam zemin |

**Play ikonu neden yuvarlatilmis degil?** Play, kose yuvarlatmayi ve golgeyi
kendisi uygular. Onceden yuvarlatilmis ya da golgeli gorseller magazada cift
kose/golge olarak gorunur ve inceleme sirasinda reddedilebilir.

## Uygulama ikonu (Android)

`apps/nfc_toolkit/android/app/src/main/res/` altina uretilir:

- `mipmap-anydpi-v26/ic_launcher.xml` — adaptive icon (API 26+)
- `mipmap-<dpi>/ic_launcher_foreground.png` — 108dp tuval, glif 66dp guvenli alanda
- `mipmap-<dpi>/ic_launcher_monochrome.png` — Android 13+ temali ikon katmani
- `mipmap-<dpi>/ic_launcher.png` — API 25 ve altı icin yuvarlatilmis kare
- `mipmap-<dpi>/ic_launcher_round.png` — API 25 round launcher varyanti
- `values/ic_launcher_background.xml` — `#46B5C9` marka teali

## Henuz uretilmeyen

Play listeleme icin ayrica gerekli: **feature graphic** (1024×500) ve en az
2 telefon ekran goruntusu (16:9 veya 9:16, kisa kenar ≥ 320 px).
