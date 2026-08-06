#!/usr/bin/env python3
"""Uygulama ikonlarini tek bir master logodan uretir.

Kaynak: logo.png (beyaz zeminli, yuvarlatilmis kare icinde beyaz NFC glifi)

Uretilenler:
  * Adaptive icon (API 26+): foreground + monochrome PNG'ler + renk kaynagi
  * Legacy launcher ikonlari (yuvarlatilmis kare) ve round ikonlar (daire)
  * Google Play magaza ikonu: 512x512, tam kare, saydamsiz
  * Saydam zeminli master logo (pazarlama/dokuman kullanimi)

Kullanim:  python3 tool/generate_app_icons.py
"""

from __future__ import annotations

import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "logo.png"
RES = ROOT / "apps/nfc_toolkit/android/app/src/main/res"
STORE = ROOT / "store/play"

# Adaptive icon: 108dp tuval, ortadaki 72dp gorunur, 66dp guvenli alan.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
LEGACY_DP = 48
ADAPTIVE_DP = 108

# Kaynaktaki glifin kareye orani korunur; adaptive'de 72dp gorunur alana
# ayni oranla yerlestirilir -> otomatik olarak 66dp guvenli alanin icinde kalir.
VISIBLE_DP = 72
SUPERSAMPLE = 4


def extract() -> tuple[Image.Image, tuple[int, int, int], float]:
    """Kaynaktan glifi saydam maske olarak cikarir.

    Donen deger: (kare tuvale normalize edilmis glif RGBA, teal rengi,
    glifin kare kenarina orani).
    """
    rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.int16)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]

    # 1) Yuvarlatilmis karenin sinirlari: doygun teal pikseller (golge notrdur).
    teal = (b > r + 25) & (g > r + 25)
    ys, xs = np.nonzero(teal)
    y0, y1, x0, x1 = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
    box_w, box_h = x1 - x0 + 1, y1 - y0 + 1

    # Baskin teal tonu = arka plan rengi.
    inside_colors = rgb[y0 : y1 + 1, x0 : x1 + 1].reshape(-1, 3)
    mask_flat = teal[y0 : y1 + 1, x0 : x1 + 1].reshape(-1)
    vals, counts = np.unique(inside_colors[mask_flat], axis=0, return_counts=True)
    bg = tuple(int(v) for v in vals[counts.argmax()])

    # 2) Karenin ic bolgesi: her satirda en sol/en sag teal pikselin arasi
    #    (yuvarlatilmis kare disbukey oldugu icin bu dolgu tam kareyi verir).
    region = teal[y0 : y1 + 1, x0 : x1 + 1]
    inside = np.zeros_like(region)
    for row in range(box_h):
        cols = np.nonzero(region[row])[0]
        if cols.size:
            inside[row, cols.min() : cols.max() + 1] = True

    # Kenar yumusatma halkasi da beyaza yakin oldugu icin maskeyi biraz asindir;
    # aksi halde karenin dis konturu glifin bir parcasi sanilir.
    erode = max(3, (min(box_w, box_h) // 100) * 2 + 1)
    pad = erode  # MinFilter kenarlarda pikselleri kopyalar; disari bosluk birak.
    padded = np.pad(inside.astype(np.uint8) * 255, pad)
    inside = (
        np.asarray(Image.fromarray(padded).filter(ImageFilter.MinFilter(erode)))[
            pad:-pad, pad:-pad
        ]
        > 127
    )

    # 3) Alfa = teal'den beyaza gecis (kenar yumusatmasi korunur).
    src_r = rgb[y0 : y1 + 1, x0 : x1 + 1, 0].astype(np.float32)
    alpha = np.clip((src_r - bg[0]) / (255.0 - bg[0]), 0.0, 1.0)
    alpha[~inside] = 0.0

    glyph = Image.fromarray((alpha * 255).astype(np.uint8), mode="L")

    # 4) Kaynak kare tam kare degil (dikeyde gerilmis); kare tuvale normalize et.
    side = max(box_w, box_h) * SUPERSAMPLE
    glyph = glyph.resize((side, side), Image.LANCZOS)

    # 5) Glifi kirp ve tam ortala.
    bbox = glyph.point(lambda v: 255 if v > 127 else 0).getbbox()
    glyph = glyph.crop(bbox)
    ratio = max(glyph.size) / side

    return glyph, bg, ratio


def place(glyph: Image.Image, canvas: int, target: int, color: tuple[int, int, int]) -> Image.Image:
    """Glifi `canvas` boyutlu saydam tuvale, uzun kenari `target` olacak sekilde ortalar."""
    scale = target / max(glyph.size)
    size = (max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale)))
    mask = glyph.resize(size, Image.LANCZOS)

    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    tinted = Image.new("RGBA", size, (*color, 255))
    layer.paste(tinted, ((canvas - size[0]) // 2, (canvas - size[1]) // 2), mask)
    return layer


def rounded_square(size: int, color: tuple[int, int, int], radius_ratio: float = 0.20) -> Image.Image:
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=int(big * radius_ratio), fill=(*color, 255)
    )
    return img.resize((size, size), Image.LANCZOS)


def circle(size: int, color: tuple[int, int, int]) -> Image.Image:
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((0, 0, big - 1, big - 1), fill=(*color, 255))
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    glyph, bg, ratio = extract()
    print(f"arka plan  : #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}")
    print(f"glif orani : {ratio:.3f} (kare kenarina gore)")

    STORE.mkdir(parents=True, exist_ok=True)

    for density, factor in DENSITIES.items():
        out = RES / f"mipmap-{density}"
        out.mkdir(parents=True, exist_ok=True)

        # --- Adaptive icon katmanlari (108dp tuval) ---
        canvas = round(ADAPTIVE_DP * factor)
        target = round(VISIBLE_DP * factor * ratio)
        place(glyph, canvas, target, (255, 255, 255)).save(out / "ic_launcher_foreground.png")
        # Monochrome (Android 13+ temali ikon): sistem renklendirir, siyah + alfa.
        place(glyph, canvas, target, (0, 0, 0)).save(out / "ic_launcher_monochrome.png")

        # --- Legacy (API 25 ve altı) ---
        legacy = round(LEGACY_DP * factor)
        glyph_px = round(legacy * ratio)

        square = rounded_square(legacy, bg)
        square.alpha_composite(place(glyph, legacy, glyph_px, (255, 255, 255)))
        square.save(out / "ic_launcher.png")

        round_icon = circle(legacy, bg)
        round_icon.alpha_composite(place(glyph, legacy, round(glyph_px * 0.88), (255, 255, 255)))
        round_icon.save(out / "ic_launcher_round.png")

        print(f"{density:<8} adaptive {canvas}px | legacy {legacy}px")

    # --- Google Play magaza ikonu: 512x512, tam kare, saydamsiz. ---
    # Play kose yuvarlatma ve golgeyi kendisi uygular; onceden uygulanmis
    # kose/golge iceren gorseller reddedilir.
    play = Image.new("RGBA", (512, 512), (*bg, 255))
    play.alpha_composite(place(glyph, 512, round(512 * ratio), (255, 255, 255)))
    play.save(STORE / "icon-512.png")
    print("store/play/icon-512.png (512x512, tam kare, opak)")

    # --- Saydam zeminli master (dokuman/pazarlama) ---
    master = rounded_square(1024, bg)
    master.alpha_composite(place(glyph, 1024, round(1024 * ratio), (255, 255, 255)))
    master.save(ROOT / "store/logo-1024-transparent.png")
    print("store/logo-1024-transparent.png (yuvarlatilmis kare, saydam zemin)")


if __name__ == "__main__":
    main()
