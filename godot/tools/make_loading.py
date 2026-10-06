#!/usr/bin/env python3
"""Grafiki na ekran ładowania: kadry wyrenderowane w grze (tools/tour.sh, shot.sh --noui) przerabiane
na plansze w stylu okładki — miękka poświata, mocniejszy kontrast, chłodne cienie i ciepłe światła,
winieta, ziarno. Użycie: make_loading.py KATALOG_Z_KADRAMI  →  assets/loading/*.jpg (1920×1080)."""
import os, sys, random
from PIL import Image, ImageFilter, ImageEnhance, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'loading')
os.makedirs(OUT, exist_ok=True)
W, H = 1920, 1080


def grade(im, seed=1, warm=1.0):
    im = im.convert('RGB').resize((W, H), Image.LANCZOS)
    # lekko malarskie spłaszczenie detalu, potem wyostrzenie krawędzi
    soft = im.filter(ImageFilter.MedianFilter(5))
    im = Image.blend(im, soft, 0.55).filter(ImageFilter.UnsharpMask(radius=2.2, percent=90, threshold=2))
    # poświata: rozmyta kopia nałożona trybem „screen”
    glow = im.filter(ImageFilter.GaussianBlur(18))
    glow = ImageEnhance.Brightness(glow).enhance(0.55)
    im = ImageChops.screen(im, glow)
    im = ImageEnhance.Contrast(im).enhance(1.18)
    im = ImageEnhance.Color(im).enhance(1.22)
    # rozdzielone tonowanie: cienie w stronę morskiego, światła w stronę bursztynu
    r, g, b = im.split()
    lut_r = [min(255, int(v * (0.94 + 0.10 * warm * v / 255.0))) for v in range(256)]
    lut_g = [min(255, int(v * (0.98 + 0.02 * v / 255.0))) for v in range(256)]
    lut_b = [min(255, int(v * (1.10 - 0.16 * warm * v / 255.0))) for v in range(256)]
    im = Image.merge('RGB', (r.point(lut_r), g.point(lut_g), b.point(lut_b)))
    # winieta
    vig = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(vig)
    d.ellipse([-W * 0.18, -H * 0.3, W * 1.18, H * 1.3], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(220))
    dark = ImageEnhance.Brightness(im).enhance(0.38)
    im = Image.composite(im, dark, vig)
    # ziarno
    rnd = random.Random(seed)
    noise = Image.effect_noise((W // 2, H // 2), 22).resize((W, H), Image.BILINEAR).convert('L')
    noise = Image.merge('RGB', (noise, noise, noise))
    im = Image.blend(im, ImageChops.overlay(im, noise), 0.22)
    return im


if __name__ == '__main__':
    src = sys.argv[1]
    names = [('klub', 1.0), ('osiedle', 1.0), ('blok', 1.0), ('huta', 1.1), ('policja', 0.9), ('hutnicza', 1.0), ('lab', 0.6), ('wybuch', 1.2)]
    n = 0
    for name, warm in names:
        f = None
        for ext in ('.jpg', '.png'):
            for sub in ('fin', ''):
                p = os.path.join(src, sub, name + ext)
                if os.path.exists(p):
                    f = p
        if f is None:
            print('brak', name)
            continue
        n += 1
        out = grade(Image.open(f), n, warm)
        out.save(os.path.join(OUT, '%s.jpg' % name), quality=88, optimize=True)
        print(name, out.size, os.path.getsize(os.path.join(OUT, '%s.jpg' % name)) // 1024, 'KB')
