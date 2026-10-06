#!/usr/bin/env python3
"""Znaki skrytek: małe szablony odbite białym sprejem (PNG z przezroczystością) -> assets/tex/gen_znak_0..5.png.
Liść, woreczek, czaszka, krzyżyk, kryształ, śnieżynka — wszystkie w jednym stylu: szablon z mostkami,
nierówne krycie, mgiełka farby dookoła i zaciek. Rysowane od zera."""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 512


def new():
    im = Image.new('L', (N, N), 0)
    return im, ImageDraw.Draw(im)


def lisc():
    im, d = new()
    base = (256, 392)
    cuts = []
    for ang, ln in ((0, 262), (-31, 226), (31, 226), (-61, 170), (61, 170), (-97, 96), (97, 96)):
        a = math.radians(ang)
        ux, uy = math.sin(a), -math.cos(a)
        px, py = uy, -ux
        left, right = [], []
        for i in range(21):
            t = i / 20.0
            w = 0.115 * ln * math.sin(math.pi * t) ** 0.9 * (1.0 - 0.28 * t)
            if 0 < i < 20:
                w *= 1.2 if i % 2 else 0.84      # ząbki na brzegu
            cx, cy = base[0] + ux * ln * t, base[1] + uy * ln * t
            left.append((cx + px * w, cy + py * w))
            right.append((cx - px * w, cy - py * w))
        d.polygon(left + right[::-1], fill=255)
        cuts.append(((base[0] + ux * ln * 0.1, base[1] + uy * ln * 0.1), (base[0] + ux * ln * 0.82, base[1] + uy * ln * 0.82)))
    d.line([base, (252, 462)], fill=255, width=11)
    for a, b in cuts:                           # nerw każdego listka = mostek szablonu
        d.line([a, b], fill=0, width=5)
    return im


def woreczek():
    im, d = new()
    d.rounded_rectangle([150, 128, 362, 412], 20, outline=255, width=15)
    d.line([150, 176, 362, 176], fill=255, width=9)
    d.line([150, 200, 362, 200], fill=255, width=9)
    d.rounded_rectangle([318, 162, 352, 214], 6, fill=255)      # suwak
    for (x, y, rx, ry) in ((212, 350, 44, 38), (286, 356, 50, 34), (250, 318, 40, 30), (306, 322, 28, 24), (198, 312, 24, 20)):
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=255)   # towar na dnie
    d.line([176, 300, 336, 372], fill=0, width=5)
    d.line([230, 392, 300, 292], fill=0, width=5)
    return im


def czaszka():
    im, d = new()
    d.ellipse([132, 96, 380, 348], fill=255)
    d.rounded_rectangle([192, 290, 320, 412], 24, fill=255)
    d.polygon([(150, 270), (192, 300), (192, 350), (160, 318)], fill=255)
    d.polygon([(362, 270), (320, 300), (320, 350), (352, 318)], fill=255)
    for sx in (-1, 1):
        e = Image.new('L', (N, N), 0)
        ImageDraw.Draw(e).ellipse([256 + sx * 54 - 37, 232 - 40, 256 + sx * 54 + 37, 232 + 40], fill=255)
        e = e.rotate(-sx * 12, center=(256 + sx * 54, 232))
        im.paste(0, mask=e)
    d = ImageDraw.Draw(im)
    d.polygon([(256, 284), (236, 326), (249, 330), (256, 316), (263, 330), (276, 326)], fill=0)
    d.line([196, 352, 316, 352], fill=0, width=6)
    for x in (224, 256, 288):
        d.line([x, 352, x, 414], fill=0, width=6)
    return im


def krzyzyk():
    im, d = new()
    for a, b in (((120, 116), (392, 400)), ((396, 120), (116, 396))):
        d.line([a, b], fill=255, width=52)
        for p in (a, b):
            d.ellipse([p[0] - 26, p[1] - 26, p[0] + 26, p[1] + 26], fill=255)
    d.ellipse([256 - 20, 258 - 20, 256 + 20, 258 + 20], fill=0)
    return im


def krysztal():
    im, d = new()
    d.polygon([(150, 206), (206, 132), (306, 132), (362, 206), (256, 412)], fill=255)
    d.line([150, 206, 362, 206], fill=0, width=6)
    for top, mid in (((206, 132), (224, 206)), ((306, 132), (288, 206))):
        d.line([top, mid], fill=0, width=5)
        d.line([mid, (256, 412)], fill=0, width=5)
    d.line([256, 132, 256, 206], fill=0, width=5)
    for (x, y, r) in ((392, 150, 13), (116, 300, 10), (404, 318, 8)):   # błyski
        d.line([x - r * 2, y, x + r * 2, y], fill=255, width=7)
        d.line([x, y - r * 2, x, y + r * 2], fill=255, width=7)
    return im


def sniezynka():
    im, d = new()
    c = (256, 258)
    for k in range(6):
        a = math.radians(k * 60)
        ux, uy = math.sin(a), -math.cos(a)
        tip = (c[0] + ux * 158, c[1] + uy * 158)
        d.line([(c[0] + ux * 30, c[1] + uy * 30), tip], fill=255, width=19)
        for at, bl in ((0.5, 54), (0.78, 36)):
            p = (c[0] + ux * 158 * at, c[1] + uy * 158 * at)
            for s in (-1, 1):
                b = a + math.radians(s * 58)
                d.line([p, (p[0] + math.sin(b) * bl, p[1] - math.cos(b) * bl)], fill=255, width=14)
    d.regular_polygon((c[0], c[1], 20), 6, fill=255)
    return im


def sprej(mask, seed):
    """odbicie szablonu: nierówne krycie, miękka krawędź, mgiełka, kropelki i zaciek"""
    rnd = random.Random(seed)
    mask = mask.rotate(rnd.uniform(-4, 4), resample=Image.BICUBIC)
    dr = ImageDraw.Draw(mask)
    for _ in range(3):                                   # zacieki z miejsc, gdzie farby było za dużo
        x, y = rnd.randint(150, 362), rnd.randint(200, 380)
        if mask.getpixel((x, y)) > 128:
            ln = rnd.randint(34, 80)
            dr.line([x, y, x + rnd.randint(-2, 2), y + ln], fill=255, width=rnd.randint(4, 6))
            dr.ellipse([x - 4, y + ln - 4, x + 4, y + ln + 5], fill=255)
    soft = mask.filter(ImageFilter.GaussianBlur(2.6))
    halo = mask.filter(ImageFilter.GaussianBlur(17))
    grain = Image.new('L', (N // 2, N // 2))
    grain.putdata([rnd.randint(105, 255) for _ in range((N // 2) ** 2)])
    grain = grain.resize((N, N), Image.BICUBIC)
    big = Image.new('L', (N // 26, N // 26))
    big.putdata([rnd.randint(140, 255) for _ in range((N // 26) ** 2)])
    big = big.resize((N, N), Image.BICUBIC)
    alpha = ImageChops.multiply(ImageChops.multiply(soft, grain), big)
    alpha = ImageChops.lighter(alpha, halo.point(lambda v: int(v * 0.16)))
    sp = Image.new('L', (N, N), 0)
    ds = ImageDraw.Draw(sp)
    for _ in range(700):
        x, y = rnd.randint(0, N - 1), rnd.randint(0, N - 1)
        if halo.getpixel((x, y)) > 12:
            r = rnd.choice([1, 1, 1, 2])
            ds.ellipse([x - r, y - r, x + r, y + r], fill=rnd.randint(80, 190))
    alpha = ImageChops.lighter(alpha, sp).resize((256, 256), Image.LANCZOS)
    return Image.merge('RGBA', (Image.new('L', (256, 256), 255),) * 3 + (alpha,))


for i, fn in enumerate((lisc, woreczek, czaszka, krzyzyk, krysztal, sniezynka)):
    sprej(fn(), 40 + i * 7).save(os.path.join(ROOT, 'assets', 'tex', 'gen_znak_%d.png' % i))
    print('gen_znak_%d.png' % i, fn.__name__)
