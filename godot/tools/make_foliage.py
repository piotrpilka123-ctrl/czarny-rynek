#!/usr/bin/env python3
"""Tekstury zieleni rysowane od zera: kępy drobnych jesiennych liści (na karty w koronach drzew i krzakach)
oraz kępy źdźbeł trawy. Wynik: assets/nature/gen_*.png (RGBA)."""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'nature')
IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''


def leaf(d, cx, cy, ln, wd, ang, col, rnd):
    """pojedynczy liść: owal z ostrym czubkiem, ciemniejszy nerw"""
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        x = (t - 0.5) * ln
        w = wd * math.sin(math.pi * t) ** 0.8 * (1.0 - 0.25 * t)
        pts.append((x, w))
    for i in range(n, -1, -1):
        t = i / n
        x = (t - 0.5) * ln
        w = wd * math.sin(math.pi * t) ** 0.8 * (1.0 - 0.25 * t)
        pts.append((x, -w))
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    d.polygon(poly, fill=col + (255,))
    dark = tuple(int(c * 0.62) for c in col)
    d.line([(cx - ln * 0.5 * ca, cy - ln * 0.5 * sa), (cx + ln * 0.5 * ca, cy + ln * 0.5 * sa)], fill=dark + (255,), width=2)


def cluster(name, seed, count, palette, size=1024, radius=0.44, leaf_len=(46, 78), twig=True):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    if twig:
        # kilka gałązek od środka
        for _ in range(7):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(0.25, radius) * size
            x, y = c, c
            pts = [(x, y)]
            for s in range(6):
                a += rnd.uniform(-0.35, 0.35)
                x += math.cos(a) * r / 6
                y += math.sin(a) * r / 6
                pts.append((x, y))
            d.line(pts, fill=(52, 40, 30, 255), width=rnd.choice([3, 4, 5]))
    items = []
    for _ in range(count):
        a = rnd.uniform(0, math.tau)
        r = (rnd.random() ** 0.62) * radius * size
        items.append((r, a))
    items.sort(reverse=True)
    for r, a in items:
        x = c + math.cos(a) * r
        y = c + math.sin(a) * r
        col = rnd.choice(palette)
        k = rnd.uniform(0.72, 1.15)
        # liście w głębi kępy ciemniejsze
        k *= 0.7 + 0.3 * min(1.0, r / (radius * size))
        col = tuple(max(0, min(255, int(ch * k))) for ch in col)
        ln = rnd.uniform(*leaf_len)
        leaf(d, x, y, ln, ln * rnd.uniform(0.2, 0.3), a + rnd.uniform(-1.2, 1.2), col, rnd)
    # kolor pod przezroczystością = kolor liści (żeby mipmapy nie ciemniały na brzegach)
    avg = tuple(int(sum(p[i] for p in palette) / len(palette)) for i in range(3))
    bg = Image.new('RGBA', (size, size), avg + (0,))
    bg.alpha_composite(im)
    bg.save(os.path.join(OUT, name + '.png'), optimize=True)
    open(os.path.join(OUT, name + '.png.import'), 'w').write(IMPORT)


def grass(name, seed, blades, palette, size=512, seeds=0):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(blades):
        x0 = size / 2 + rnd.gauss(0, size * 0.13)
        h = rnd.uniform(0.35, 0.95) * size
        lean = rnd.gauss(0, 0.28) + (x0 - size / 2) / size * 1.1
        col = rnd.choice(palette)
        k = rnd.uniform(0.7, 1.15)
        col = tuple(max(0, min(255, int(ch * k))) for ch in col)
        w0 = rnd.uniform(4.0, 9.0)
        n = 10
        left, right = [], []
        for s in range(n + 1):
            t = s / n
            x = x0 + lean * h * t * t
            y = size - 2 - h * t
            w = w0 * (1.0 - t) ** 0.7
            left.append((x - w / 2, y))
            right.append((x + w / 2, y))
        d.polygon(left + right[::-1], fill=col + (255,))
        if seeds and rnd.random() < seeds:
            xt, yt = left[-1]
            for s in range(7):
                d.ellipse([xt - 4 + rnd.uniform(-3, 3), yt + s * 7, xt + 4 + rnd.uniform(-3, 3), yt + s * 7 + 9], fill=(150, 126, 78, 255))
    avg = tuple(int(sum(p[i] for p in palette) / len(palette)) for i in range(3))
    bg = Image.new('RGBA', (size, size), avg + (0,))
    bg.alpha_composite(im)
    bg.save(os.path.join(OUT, name + '.png'), optimize=True)
    open(os.path.join(OUT, name + '.png.import'), 'w').write(IMPORT)


AUTUMN = [(214, 160, 40), (226, 178, 52), (206, 118, 30), (190, 88, 24), (168, 60, 26), (150, 140, 46), (120, 126, 44), (196, 150, 60), (140, 92, 40)]
GREEN = [(92, 118, 44), (110, 130, 50), (76, 100, 40), (132, 140, 52), (150, 146, 60), (96, 110, 38)]
RUST = [(150, 70, 30), (176, 96, 36), (128, 58, 28), (160, 120, 50), (112, 80, 40), (190, 130, 44)]
cluster('gen_leaves_autumn', 11, 300, AUTUMN)
cluster('gen_leaves_green', 12, 320, GREEN)
cluster('gen_leaves_rust', 13, 230, RUST)
cluster('gen_leaves_sparse', 14, 90, AUTUMN + RUST, leaf_len=(40, 66))
DRY = [(150, 150, 74), (132, 140, 62), (170, 160, 84), (112, 126, 54), (186, 172, 98), (98, 112, 50)]
grass('gen_grass_a', 21, 46, DRY)
grass('gen_grass_b', 22, 30, DRY, seeds=0.35)
print('ok')
